use std::{
    env,
    fs::{self, read_dir},
    path::{Path, PathBuf},
};

use super::logger::log_to_dart;

pub struct InstalledFont {
    pub path: String,
    pub full_name: String,
}

pub fn get_installed_fonts() -> Option<Vec<InstalledFont>> {
    _get_installed_fonts().ok()
}

pub fn inspect_font_file(path: String) -> Option<InstalledFont> {
    inspect_font_path(Path::new(&path)).ok()
}

fn inspect_font_path(path: &Path) -> anyhow::Result<InstalledFont> {
    let font = fs::read(path)?;
    let face = ttf_parser::Face::parse(&font, 0)?;
    let full_name = face
        .names()
        .into_iter()
        .find(|name| name.name_id == ttf_parser::name_id::FULL_NAME)
        .and_then(|name| name.to_string())
        .ok_or_else(|| anyhow::anyhow!("font does not contain a full name"))?;
    Ok(InstalledFont {
        path: path.to_string_lossy().to_string(),
        full_name,
    })
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
            "ttf" | "ttc" | "otf" => match inspect_font_path(&path) {
                Ok(font) => result.push(font),
                Err(err) => {
                    log_to_dart(err.to_string());
                    continue;
                }
            },
            _ => continue,
        }
    }

    Ok(())
}

fn _get_installed_fonts() -> Result<Vec<InstalledFont>, anyhow::Error> {
    let mut installed_fonts: Vec<InstalledFont> = vec![];

    let system_installed_fonts_path = Path::new("C:\\Windows\\Fonts");
    let _ = _read_fonts_in_folder(system_installed_fonts_path, &mut installed_fonts);

    let user_installed_fonts_path =
        PathBuf::from(env::var("USERPROFILE")?).join("AppData\\Local\\Microsoft\\Windows\\Fonts");
    let _ = _read_fonts_in_folder(&user_installed_fonts_path, &mut installed_fonts);

    Ok(installed_fonts)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_missing_font_file() {
        assert!(inspect_font_file("missing-font-file.ttf".to_string()).is_none());
    }
}
