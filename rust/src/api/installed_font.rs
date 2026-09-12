use std::{
    env,
    fs::{self, read_dir},
    path::{Path, PathBuf},
};

use super::logger::log_to_dart;

pub struct InstalledFont {
    pub path: String,
    pub full_name: String,
    pub family_name: Option<String>,
    pub style_name: Option<String>,
    pub weight: Option<u16>,
    pub is_italic: Option<bool>,
}

pub fn get_installed_fonts() -> Option<Vec<InstalledFont>> {
    _get_installed_fonts().ok()
}

pub fn inspect_font_file(path: String) -> Option<InstalledFont> {
    inspect_font_path(Path::new(&path)).ok()
}

fn pick_preferred_name(face: &ttf_parser::Face, name_ids: &[u16]) -> Option<String> {
    let mut zh = None;
    let mut en = None;
    let mut other = None;

    for &target_id in name_ids {
        for name in face.names() {
            if name.name_id == target_id {
                if let Some(s) = name.to_string() {
                    let s = s.trim();
                    if !s.is_empty() {
                        let lang = format!("{:?}", name.language());
                        let is_cjk = s
                            .chars()
                            .any(|c| ('\u{4e00}'..='\u{9fff}').contains(&c) || ('\u{3400}'..='\u{4dbf}').contains(&c));
                        if (lang.contains("Chinese") || is_cjk) && zh.is_none() {
                            zh = Some(s.to_string());
                        } else if (lang.contains("English")
                            || name.language() == ttf_parser::Language::English_UnitedStates)
                            && en.is_none()
                        {
                            en = Some(s.to_string());
                        } else if other.is_none() {
                            other = Some(s.to_string());
                        }
                    }
                }
            }
        }
        if zh.is_some() {
            return zh;
        }
    }

    zh.or(en).or(other)
}

struct FaceDetails {
    full_name: String,
    family_name: String,
    style_name: String,
    weight: u16,
    is_italic: bool,
}

fn extract_face_details(face: &ttf_parser::Face) -> Option<FaceDetails> {
    let family_name = pick_preferred_name(face, &[16, 1])?;
    let style_name = pick_preferred_name(face, &[17, 2]).unwrap_or_else(|| "Regular".to_string());
    let full_name = pick_preferred_name(face, &[4]).unwrap_or_else(|| {
        if style_name.eq_ignore_ascii_case("Regular") || style_name == "常规" {
            family_name.clone()
        } else {
            format!("{} {}", family_name, style_name)
        }
    });

    let weight = face.weight().to_number();
    let is_italic = face.is_italic();

    Some(FaceDetails {
        full_name,
        family_name,
        style_name,
        weight,
        is_italic,
    })
}

fn inspect_font_path(path: &Path) -> anyhow::Result<InstalledFont> {
    let font = fs::read(path)?;
    let count = ttf_parser::fonts_in_collection(&font).unwrap_or(1);
    for i in 0..count {
        if let Ok(face) = ttf_parser::Face::parse(&font, i) {
            if let Some(details) = extract_face_details(&face) {
                return Ok(InstalledFont {
                    path: path.to_string_lossy().to_string(),
                    full_name: details.full_name,
                    family_name: Some(details.family_name),
                    style_name: Some(details.style_name),
                    weight: Some(details.weight),
                    is_italic: Some(details.is_italic),
                });
            }
        }
    }

    Err(anyhow::anyhow!("font does not contain a valid name"))
}

fn inspect_font_path_faces(path: &Path, result: &mut Vec<InstalledFont>) -> anyhow::Result<()> {
    let font = fs::read(path)?;
    let count = ttf_parser::fonts_in_collection(&font).unwrap_or(1);
    let mut added = false;
    for i in 0..count {
        if let Ok(face) = ttf_parser::Face::parse(&font, i) {
            if let Some(details) = extract_face_details(&face) {
                result.push(InstalledFont {
                    path: path.to_string_lossy().to_string(),
                    full_name: details.full_name,
                    family_name: Some(details.family_name),
                    style_name: Some(details.style_name),
                    weight: Some(details.weight),
                    is_italic: Some(details.is_italic),
                });
                added = true;
            }
        }
    }
    if added {
        Ok(())
    } else {
        Err(anyhow::anyhow!("no font names extracted from path"))
    }
}

fn _read_fonts_in_folder(path: &Path, result: &mut Vec<InstalledFont>) -> anyhow::Result<()> {
    log_to_dart(format!("read fonts in: {}", path.to_string_lossy()));

    let dir = match read_dir(path) {
        Ok(val) => val,
        Err(err) => {
            log_to_dart(err.to_string());
            return Err(err.into());
        }
    };

    for entry_result in dir {
        let entry = match entry_result {
            Ok(value) => value,
            Err(err) => {
                log_to_dart(err.to_string());
                continue;
            }
        };
        let path = entry.path();
        let extension = match path.extension() {
            Some(value) => match value.to_str() {
                Some(value) => value,
                None => continue,
            },
            None => continue,
        };
        match extension.to_lowercase().as_str() {
            "ttf" | "ttc" | "otf" => {
                if let Err(err) = inspect_font_path_faces(&path, result) {
                    log_to_dart(format!("{}: {}", path.display(), err));
                }
            }
            _ => continue,
        }
    }

    Ok(())
}

fn _get_installed_fonts() -> Result<Vec<InstalledFont>, anyhow::Error> {
    let mut installed_fonts: Vec<InstalledFont> = vec![];

    let system_root = env::var("SystemRoot").unwrap_or_else(|_| "C:\\Windows".to_string());
    let system_installed_fonts_path = PathBuf::from(system_root).join("Fonts");
    let _ = _read_fonts_in_folder(&system_installed_fonts_path, &mut installed_fonts);

    if let Ok(userprofile) = env::var("USERPROFILE") {
        let user_installed_fonts_path =
            PathBuf::from(userprofile).join("AppData\\Local\\Microsoft\\Windows\\Fonts");
        let _ = _read_fonts_in_folder(&user_installed_fonts_path, &mut installed_fonts);
    }

    let mut seen = std::collections::HashSet::new();
    installed_fonts.retain(|f| {
        seen.insert((
            f.full_name.to_lowercase(),
            f.weight.unwrap_or(400),
            f.is_italic.unwrap_or(false),
        ))
    });

    installed_fonts.sort_by(|a, b| {
        let fam_a = a.family_name.as_deref().unwrap_or(&a.full_name).to_lowercase();
        let fam_b = b.family_name.as_deref().unwrap_or(&b.full_name).to_lowercase();
        match fam_a.cmp(&fam_b) {
            std::cmp::Ordering::Equal => {
                let w_a = a.weight.unwrap_or(400);
                let w_b = b.weight.unwrap_or(400);
                match w_a.cmp(&w_b) {
                    std::cmp::Ordering::Equal => a.full_name.to_lowercase().cmp(&b.full_name.to_lowercase()),
                    other => other,
                }
            }
            other => other,
        }
    });

    Ok(installed_fonts)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_missing_font_file() {
        assert!(inspect_font_file("missing-font-file.ttf".to_string()).is_none());
    }

    #[test]
    fn test_reads_system_fonts() {
        let fonts = get_installed_fonts();
        assert!(fonts.is_some());
        let list = fonts.unwrap();
        assert!(!list.is_empty());
        let has_yahei = list.iter().any(|f| {
            f.full_name.contains("YaHei")
                || f.full_name.contains("雅黑")
                || f.family_name.as_deref().unwrap_or("").contains("雅黑")
        });
        let has_simsun = list.iter().any(|f| {
            f.full_name.contains("SimSun")
                || f.full_name.contains("宋体")
                || f.family_name.as_deref().unwrap_or("").contains("宋体")
        });
        let has_arial = list.iter().any(|f| {
            f.full_name.contains("Arial")
                || f.family_name.as_deref().unwrap_or("").contains("Arial")
        });
        assert!(has_arial);
        assert!(has_simsun);
        assert!(has_yahei);

        // Check that family_name and weight are extracted
        let yahei_fonts: Vec<_> = list
            .iter()
            .filter(|f| f.family_name.as_deref().unwrap_or("").contains("雅黑"))
            .collect();
        assert!(!yahei_fonts.is_empty());
        for f in &yahei_fonts {
            assert!(f.weight.is_some());
        }
    }
}
