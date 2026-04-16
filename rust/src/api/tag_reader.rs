use std::{
    collections::{HashMap, HashSet},
    fs::{self},
    io::{self, Cursor, Write},
    path::{Path, PathBuf},
    time::{Duration, UNIX_EPOCH},
};

use image::imageops;
use lofty::prelude::{Accessor, AudioFile, ItemKey, TaggedFileExt};
use windows::{
    core::Interface,
    core::HSTRING,
    Storage::{
        FileProperties::ThumbnailMode,
        StorageFile,
        Streams::{DataReader, IInputStream},
    },
};

use crate::frb_generated::StreamSink;

use super::logger::log_to_dart;

/// K: extension, V: can read tags by using Lofty
static SUPPORT_FORMAT: phf::Map<&'static str, bool> = phf::phf_map! {
    "mp3" => true, "mp2" => false, "mp1" => false,
    "ogg" => true,
    "wav" => true, "wave" => true,
    "aif" => true, "aiff" => true, "aifc" => true,
    // 通过 Windows 系统支持
    "asf" => false, "wma" => false,
    "aac" => true, "adts" => true,
    "dts" => false,
    "m4a" => true,
    "ac3" => false,
    "amr" => false, "3ga" => false,
    "flac" => true,
    "mpc" => true,
    // 插件支持
    "mid" => false,
    "wv" => true, "wvc" => true,
    "opus" => true,
    "dsf" => false, "dff" => false,
    "ape" => true,
};

const CURRENT_INDEX_VERSION: u64 = 112;

pub struct IndexActionState {
    /// completed / total
    pub progress: f64,

    /// describe action state
    pub message: String,
}

fn normalize_path_for_key(path: impl AsRef<Path>) -> String {
    let path = path.as_ref();
    let normalized = path
        .canonicalize()
        .unwrap_or_else(|_| path.to_path_buf())
        .to_string_lossy()
        .replace('/', "\\");

    normalized
        .trim_end_matches('\\')
        .to_ascii_lowercase()
        .to_string()
}

fn normalize_text_for_key(value: &str) -> String {
    value.trim().to_ascii_lowercase()
}

fn file_size_for_identity(path: &str) -> u64 {
    fs::metadata(path).map(|value| value.len()).unwrap_or(0)
}

fn build_audio_identity_key(
    title: &str,
    artist: &str,
    album: &str,
    disc: u32,
    track: u32,
    duration: u64,
    bitrate: u32,
    sample_rate: u32,
    cue_start_ms: u64,
    cue_end_ms: u64,
    file_size: u64,
    file_name: &str,
) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        normalize_text_for_key(title),
        normalize_text_for_key(artist),
        normalize_text_for_key(album),
        disc,
        track,
        duration,
        bitrate,
        sample_rate,
        cue_start_ms,
        cue_end_ms,
        file_size,
        normalize_text_for_key(file_name),
    )
}

fn audio_identity_key_from_audio(audio: &Audio) -> String {
    let source_or_path = audio.source_path.as_deref().unwrap_or(&audio.path);
    let file_size = file_size_for_identity(source_or_path);
    let file_name = Path::new(source_or_path)
        .file_name()
        .map(|value| value.to_string_lossy().to_string())
        .unwrap_or_default();

    build_audio_identity_key(
        &audio.title,
        &audio.artist,
        &audio.album,
        audio.disc.unwrap_or(0),
        audio.track.unwrap_or(0),
        audio.duration,
        audio.bitrate.unwrap_or(0),
        audio.sample_rate.unwrap_or(0),
        audio.cue_start_ms.unwrap_or(0),
        audio.cue_end_ms.unwrap_or(0),
        file_size,
        &file_name,
    )
}

fn audio_identity_key_from_json(audio: &serde_json::Value) -> String {
    let path = audio["path"].as_str().unwrap_or_default();
    let source_or_path = audio["source_path"].as_str().unwrap_or(path);
    let file_size = file_size_for_identity(source_or_path);
    let file_name = Path::new(source_or_path)
        .file_name()
        .map(|value| value.to_string_lossy().to_string())
        .unwrap_or_default();

    build_audio_identity_key(
        audio["title"].as_str().unwrap_or_default(),
        audio["artist"].as_str().unwrap_or_default(),
        audio["album"].as_str().unwrap_or_default(),
        audio["disc"].as_u64().unwrap_or(0) as u32,
        audio["track"].as_u64().unwrap_or(0) as u32,
        audio["duration"].as_u64().unwrap_or(0),
        audio["bitrate"].as_u64().unwrap_or(0) as u32,
        audio["sample_rate"].as_u64().unwrap_or(0) as u32,
        audio["cue_start_ms"].as_u64().unwrap_or(0),
        audio["cue_end_ms"].as_u64().unwrap_or(0),
        file_size,
        &file_name,
    )
}

fn is_unknown_text(value: &str) -> bool {
    value.trim().is_empty() || value.trim() == "UNKNOWN"
}

fn sanitize_metadata_text(value: &str, fallback: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() || trimmed == "UNKNOWN" {
        return fallback.to_string();
    }

    let has_garbled = trimmed.contains('\u{FFFD}') || trimmed.contains("锟斤拷");
    let mut cleaned = trimmed
        .chars()
        .filter(|ch| *ch != '\u{FFFD}' && *ch != '\u{FEFF}' && !ch.is_control())
        .collect::<String>();
    if has_garbled {
        cleaned = cleaned.replace("锟斤拷", "");
    }
    let cleaned = cleaned.trim();
    if cleaned.is_empty() {
        fallback.to_string()
    } else {
        cleaned.to_string()
    }
}

fn is_cue_path(path: impl AsRef<Path>) -> bool {
    let ext = path
        .as_ref()
        .extension()
        .map(|value| value.to_ascii_lowercase().to_string_lossy().to_string());
    matches!(ext.as_deref(), Some("cue"))
}

#[derive(Debug, Clone)]
struct Audio {
    title: String,
    artist: String,
    album: String,
    disc: Option<u32>,
    track: Option<u32>,
    /// in secs
    duration: u64,
    /// kbps
    bitrate: Option<u32>,
    sample_rate: Option<u32>,
    replay_gain_db: Option<f64>,
    source_path: Option<String>,
    cue_start_ms: Option<u64>,
    cue_end_ms: Option<u64>,
    /// absolute path
    path: String,
    /// secs since UNIX_EPOCH
    modified: u64,
    /// secs since UNIX_EPOCH
    created: u64,
    /// 标签获取方式
    by: Option<String>,
}

impl Audio {
    fn new_with_path(path: impl AsRef<Path>, by: Option<String>) -> Option<Self> {
        let path = path.as_ref();
        Some(Audio {
            title: path.file_name()?.to_string_lossy().to_string(),
            artist: "UNKNOWN".to_string(),
            album: "UNKNOWN".to_string(),
            disc: None,
            track: None,
            duration: 0,
            bitrate: None,
            sample_rate: None,
            replay_gain_db: None,
            source_path: None,
            cue_start_ms: None,
            cue_end_ms: None,
            path: path.to_string_lossy().to_string(),
            modified: 0,
            created: 0,
            by,
        })
    }

    fn to_json_value(&self) -> serde_json::Value {
        serde_json::json!({
            "title": self.title,
            "artist": self.artist,
            "album": self.album,
            "disc": self.disc,
            "track": self.track,
            "duration": self.duration,
            "bitrate": self.bitrate,
            "sample_rate": self.sample_rate,
            "replay_gain_db": self.replay_gain_db,
            "source_path": self.source_path,
            "cue_start_ms": self.cue_start_ms,
            "cue_end_ms": self.cue_end_ms,
            "path": self.path,
            "modified": self.modified,
            "created": self.created,
            "by": self.by
        })
    }

    fn merge_missing_fields(mut primary: Self, fallback: Self) -> Self {
        if is_unknown_text(&primary.title) && !is_unknown_text(&fallback.title) {
            primary.title = fallback.title;
        }
        if is_unknown_text(&primary.artist) && !is_unknown_text(&fallback.artist) {
            primary.artist = fallback.artist;
        }
        if is_unknown_text(&primary.album) && !is_unknown_text(&fallback.album) {
            primary.album = fallback.album;
        }
        if primary.disc.unwrap_or(0) == 0 && fallback.disc.unwrap_or(0) > 0 {
            primary.disc = fallback.disc;
        }
        if primary.track.unwrap_or(0) == 0 && fallback.track.unwrap_or(0) > 0 {
            primary.track = fallback.track;
        }
        if primary.duration == 0 && fallback.duration > 0 {
            primary.duration = fallback.duration;
        }
        if primary.bitrate.unwrap_or(0) == 0 && fallback.bitrate.unwrap_or(0) > 0 {
            primary.bitrate = fallback.bitrate;
        }
        if primary.sample_rate.unwrap_or(0) == 0 && fallback.sample_rate.unwrap_or(0) > 0 {
            primary.sample_rate = fallback.sample_rate;
        }
        if primary.replay_gain_db.is_none() && fallback.replay_gain_db.is_some() {
            primary.replay_gain_db = fallback.replay_gain_db;
        }
        if primary.source_path.is_none() && fallback.source_path.is_some() {
            primary.source_path = fallback.source_path;
        }
        if primary.cue_start_ms.is_none() && fallback.cue_start_ms.is_some() {
            primary.cue_start_ms = fallback.cue_start_ms;
        }
        if primary.cue_end_ms.is_none() && fallback.cue_end_ms.is_some() {
            primary.cue_end_ms = fallback.cue_end_ms;
        }

        match (primary.by.as_deref(), fallback.by.as_deref()) {
            (Some(a), Some(b)) if a != b => {
                primary.by = Some(format!("{}+{}", a, b));
            }
            (None, Some(b)) => {
                primary.by = Some(b.to_string());
            }
            _ => {}
        }

        primary
    }

    fn parse_replay_gain_db(value: &str) -> Option<f64> {
        let mut number = String::new();
        let mut started = false;
        for ch in value.chars() {
            if ch.is_ascii_digit() || ch == '.' || ch == '-' || ch == '+' {
                number.push(ch);
                started = true;
            } else if started {
                break;
            }
        }
        if number.is_empty() {
            return None;
        }

        number.parse::<f64>().ok()
    }

    fn parse_cue_value(line: &str, key: &str) -> Option<String> {
        let rest = line.strip_prefix(key)?.trim();
        if rest.is_empty() {
            return None;
        }
        if let Some(start) = rest.find('"') {
            let right = &rest[start + 1..];
            if let Some(end) = right.find('"') {
                return Some(right[..end].to_string());
            }
        }
        Some(rest.to_string())
    }

    fn parse_cue_timestamp_to_frames(value: &str) -> Option<u64> {
        let mut parts = value.trim().split(':');
        let minute = parts.next()?.trim().parse::<u64>().ok()?;
        let second = parts.next()?.trim().parse::<u64>().ok()?;
        let frame = parts.next()?.trim().parse::<u64>().ok()?;
        Some((minute * 60 + second) * 75 + frame)
    }

    fn read_from_cue_path(cue_path: impl AsRef<Path>) -> Vec<Self> {
        let cue_path = cue_path.as_ref();
        let cue_text = match fs::read_to_string(cue_path) {
            Ok(value) => value,
            Err(err) => {
                log_to_dart(format!("{:?}: {}", cue_path, err));
                return vec![];
            }
        };

        #[derive(Clone)]
        struct CueTrack {
            file_path: PathBuf,
            track: u32,
            title: Option<String>,
            performer: Option<String>,
            start_frames: u64,
        }

        let parent = cue_path.parent().unwrap_or(Path::new(""));
        let mut album_title: Option<String> = None;
        let mut album_performer: Option<String> = None;
        let mut current_file_path: Option<PathBuf> = None;
        let mut current_track_no: Option<u32> = None;
        let mut current_track_title: Option<String> = None;
        let mut current_track_performer: Option<String> = None;
        let mut current_track_start_frames: Option<u64> = None;
        let mut tracks: Vec<CueTrack> = vec![];

        fn push_current_track(
            tracks: &mut Vec<CueTrack>,
            current_file_path: &Option<PathBuf>,
            current_track_no: Option<u32>,
            current_track_title: &Option<String>,
            current_track_performer: &Option<String>,
            current_track_start_frames: Option<u64>,
        ) {
            if let (Some(file_path), Some(track_no), Some(start_frames)) = (
                current_file_path.clone(),
                current_track_no,
                current_track_start_frames,
            ) {
                tracks.push(CueTrack {
                    file_path,
                    track: track_no,
                    title: current_track_title.clone(),
                    performer: current_track_performer.clone(),
                    start_frames,
                });
            }
        }

        for raw_line in cue_text.lines() {
            let line = raw_line.trim();
            if line.is_empty() {
                continue;
            }

            if let Some(file_value) = Self::parse_cue_value(line, "FILE") {
                push_current_track(
                    &mut tracks,
                    &current_file_path,
                    current_track_no,
                    &current_track_title,
                    &current_track_performer,
                    current_track_start_frames,
                );
                current_track_no = None;
                current_track_title = None;
                current_track_performer = None;
                current_track_start_frames = None;

                let file_path = if Path::new(&file_value).is_absolute() {
                    PathBuf::from(file_value)
                } else {
                    parent.join(file_value)
                };
                current_file_path = Some(file_path);
                continue;
            }

            if line.starts_with("TRACK ") {
                push_current_track(
                    &mut tracks,
                    &current_file_path,
                    current_track_no,
                    &current_track_title,
                    &current_track_performer,
                    current_track_start_frames,
                );
                current_track_title = None;
                current_track_performer = None;
                current_track_start_frames = None;

                let segment = line.trim_start_matches("TRACK ").trim();
                let track_no = segment
                    .split_whitespace()
                    .next()
                    .and_then(|value| value.parse::<u32>().ok());
                current_track_no = track_no;
                continue;
            }

            if let Some(index_segment) = line.strip_prefix("INDEX 01 ") {
                current_track_start_frames = Self::parse_cue_timestamp_to_frames(index_segment);
                continue;
            }

            if let Some(title) = Self::parse_cue_value(line, "TITLE") {
                if current_track_no.is_some() {
                    current_track_title = Some(title);
                } else {
                    album_title = Some(title);
                }
                continue;
            }

            if let Some(performer) = Self::parse_cue_value(line, "PERFORMER") {
                if current_track_no.is_some() {
                    current_track_performer = Some(performer);
                } else {
                    album_performer = Some(performer);
                }
                continue;
            }
        }
        push_current_track(
            &mut tracks,
            &current_file_path,
            current_track_no,
            &current_track_title,
            &current_track_performer,
            current_track_start_frames,
        );

        if tracks.is_empty() {
            return vec![];
        }

        let mut source_cache: HashMap<String, Audio> = HashMap::new();
        let mut result: Vec<Audio> = vec![];
        for (i, track) in tracks.iter().enumerate() {
            let source_key = normalize_path_for_key(&track.file_path);
            let source_audio = if let Some(cached) = source_cache.get(&source_key) {
                cached.clone()
            } else {
                let Some(value) = Self::read_from_path(&track.file_path) else {
                    continue;
                };
                source_cache.insert(source_key.clone(), value.clone());
                value
            };

            let source_total_frames = source_audio.duration.saturating_mul(75);
            if source_total_frames == 0 {
                continue;
            }

            let start_frames = track
                .start_frames
                .min(source_total_frames.saturating_sub(1));
            let next_same_file_start = tracks
                .iter()
                .skip(i + 1)
                .find(|next| normalize_path_for_key(&next.file_path) == source_key)
                .map(|next| next.start_frames);
            let mut end_frames = next_same_file_start.unwrap_or(source_total_frames);
            if end_frames > source_total_frames {
                end_frames = source_total_frames;
            }
            if end_frames <= start_frames {
                continue;
            }

            let cue_start_ms = start_frames.saturating_mul(1000) / 75;
            let cue_end_ms = end_frames.saturating_mul(1000) / 75;
            let mut duration = (cue_end_ms.saturating_sub(cue_start_ms)) / 1000;
            if duration == 0 {
                duration = 1;
            }

            let title = track
                .title
                .clone()
                .unwrap_or_else(|| format!("Track {:02}", track.track));
            let artist = track
                .performer
                .clone()
                .or_else(|| album_performer.clone())
                .unwrap_or_else(|| source_audio.artist.clone());
            let album = album_title
                .clone()
                .unwrap_or_else(|| source_audio.album.clone());

            result.push(Audio {
                title,
                artist,
                album,
                disc: source_audio.disc,
                track: Some(track.track),
                duration,
                bitrate: source_audio.bitrate,
                sample_rate: source_audio.sample_rate,
                replay_gain_db: source_audio.replay_gain_db,
                source_path: Some(source_audio.path.clone()),
                cue_start_ms: Some(cue_start_ms),
                cue_end_ms: Some(cue_end_ms),
                path: format!("{}#CUE:{}:{}", source_audio.path, track.track, start_frames),
                modified: source_audio.modified,
                created: source_audio.created,
                by: Some("CUE".to_string()),
            });
        }

        result
    }

    /// 不支持：None  
    /// Lofty 能获取到信息：read_by_lofty  
    /// 不能的话：read_by_win_music_properties  
    /// 再不能的话：title: filename 代替
    fn read_from_path(path: impl AsRef<Path>) -> Option<Self> {
        let path = path.as_ref();
        let extension = path
            .extension()?
            .to_ascii_lowercase()
            .to_string_lossy()
            .to_string();
        let lofty_support: bool = *SUPPORT_FORMAT.get(extension.as_str())?;

        let file_metadata = match fs::metadata(path) {
            Ok(val) => val,
            Err(err) => {
                log_to_dart(err.to_string());
                return None;
            }
        };
        let modified = file_metadata
            .modified()
            .unwrap_or(UNIX_EPOCH)
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs();
        let created = file_metadata
            .created()
            .unwrap_or(UNIX_EPOCH)
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs();

        let win_audio = Self::read_by_win_music_properties(path, modified, created).ok();

        // WAV/WAVE 优先使用 Windows 系统属性读取标签，Lofty 仅用于补全缺失字段。
        if extension == "wav" || extension == "wave" {
            if let Some(win) = win_audio.clone() {
                if let Some(lofty) = Self::read_by_lofty(path, modified, created) {
                    return Some(Self::merge_missing_fields(win, lofty));
                }
                return Some(win);
            }

            if let Some(lofty) = Self::read_by_lofty(path, modified, created) {
                return Some(lofty);
            }

            return Self::new_with_path(path, None);
        }

        if lofty_support {
            if let Some(lofty) = Self::read_by_lofty(path, modified, created) {
                if let Some(win) = win_audio {
                    return Some(Self::merge_missing_fields(lofty, win));
                }
                return Some(lofty);
            }

            if let Some(win) = win_audio {
                return Some(win);
            }

            return Self::new_with_path(path, None);
        } else {
            if let Some(win) = win_audio {
                return Some(win);
            }

            return Self::new_with_path(path, None);
        }
    }

    /// 使用 lofty 获取音乐标签。只在文件名不正确、没有标签或包含不支持的编码时返回 None
    fn read_by_lofty(path: impl AsRef<Path>, modified: u64, created: u64) -> Option<Self> {
        let path = path.as_ref();
        let fallback_title = path
            .file_stem()
            .or_else(|| path.file_name())
            .map(|value| value.to_string_lossy().to_string())
            .unwrap_or_else(|| "UNKNOWN".to_string());
        let tagged_file = match lofty::read_from_path(path) {
            Ok(val) => val,
            Err(err) => {
                log_to_dart(format!("{:?}: {}", path, err));
                return None;
            }
        };

        let properties = tagged_file.properties();

        if let Some(tag) = tagged_file
            .primary_tag()
            .or_else(|| tagged_file.first_tag())
        {
            let artist_strs: Vec<_> = tag.get_strings(&ItemKey::TrackArtist).collect();
            let artist = if artist_strs.is_empty() {
                "UNKNOWN".to_string()
            } else {
                artist_strs.join("/")
            };
            let artist = sanitize_metadata_text(&artist, "UNKNOWN");
            let replay_gain_db = tag
                .get_strings(&ItemKey::ReplayGainTrackGain)
                .find_map(Self::parse_replay_gain_db);

            let title_raw = tag
                .title()
                .map(|value| value.to_string())
                .unwrap_or_else(|| fallback_title.clone());
            let album_raw = tag
                .album()
                .map(|value| value.to_string())
                .unwrap_or_else(|| "UNKNOWN".to_string());

            return Some(Audio {
                title: sanitize_metadata_text(&title_raw, &fallback_title),
                artist,
                album: sanitize_metadata_text(&album_raw, "UNKNOWN"),
                disc: tag.disk(),
                track: tag.track(),
                duration: properties.duration().as_secs(),
                bitrate: properties.audio_bitrate(),
                sample_rate: properties.sample_rate(),
                replay_gain_db,
                source_path: None,
                cue_start_ms: None,
                cue_end_ms: None,
                path: path.to_string_lossy().to_string(),
                modified,
                created,
                by: Some("Lofty".to_string()),
            });
        }

        return Some(Audio {
            title: path.file_name()?.to_string_lossy().to_string(),
            artist: std::borrow::Cow::Borrowed("UNKNOWN").to_string(),
            album: std::borrow::Cow::Borrowed("UNKNOWN").to_string(),
            disc: None,
            track: None,
            duration: properties.duration().as_secs(),
            bitrate: properties.audio_bitrate(),
            sample_rate: properties.sample_rate(),
            replay_gain_db: None,
            source_path: None,
            cue_start_ms: None,
            cue_end_ms: None,
            path: path.to_string_lossy().to_string(),
            modified,
            created,
            by: Some("Lofty".to_string()),
        });
    }

    /// 使用 Windows Api 获取音乐标签。会因为各种原因返回 Err
    fn read_by_win_music_properties(
        path: impl AsRef<Path>,
        modified: u64,
        created: u64,
    ) -> Result<Self, windows::core::Error> {
        let path = path.as_ref();
        let storage_file = StorageFile::GetFileFromPathAsync(&HSTRING::from(path))?.get()?;
        let music_properties = storage_file
            .Properties()?
            .GetMusicPropertiesAsync()?
            .get()?;

        let duration: Duration = music_properties.Duration()?.into();

        let mut title = music_properties
            .Title()
            .or_else(|_| storage_file.Name())?
            .to_string();
        if title.is_empty() {
            title = storage_file.Name()?.to_string();
        }
        let fallback_title = storage_file.Name()?.to_string();
        title = sanitize_metadata_text(&title, &fallback_title);

        let mut artist = music_properties
            .Artist()
            .unwrap_or(HSTRING::from("UNKNOWN"))
            .to_string();
        if artist.is_empty() {
            artist = "UNKNOWN".to_string();
        }
        artist = sanitize_metadata_text(&artist, "UNKNOWN");

        let mut album = music_properties
            .Album()
            .unwrap_or(HSTRING::from("UNKNOWN"))
            .to_string();
        if album.is_empty() {
            album = "UNKNOWN".to_string();
        }
        album = sanitize_metadata_text(&album, "UNKNOWN");

        Ok(Audio {
            title,
            artist,
            album,
            disc: None,
            track: Some(music_properties.TrackNumber()?),
            duration: duration.as_secs(),
            bitrate: Some(music_properties.Bitrate()? / 1000),
            sample_rate: None,
            replay_gain_db: None,
            source_path: None,
            cue_start_ms: None,
            cue_end_ms: None,
            path: path.to_string_lossy().to_string(),
            modified,
            created,
            by: Some("Windows".to_string()),
        })
    }
}

#[derive(Debug)]
struct AudioFolder {
    path: String,
    /// secs since UNIX_EPOCH
    modified: u64,
    /// biggest created in audios. secs since UNIX_EPOCH
    latest: u64,
    audios: Vec<Audio>,
}

impl AudioFolder {
    fn to_json_value(&self) -> serde_json::Value {
        let mut audios_json: Vec<serde_json::Value> = vec![];
        for audio in &self.audios {
            audios_json.push(audio.to_json_value());
        }

        serde_json::json!({
            "path": self.path,
            "modified": self.modified,
            "latest": self.latest,
            "audios": audios_json,
        })
    }

    /// 扫描路径为 path 的文件夹
    fn read_from_folder(path: impl AsRef<Path>) -> Result<AudioFolder, io::Error> {
        let path = path.as_ref();

        let dir = match fs::read_dir(path) {
            Ok(val) => val,
            Err(err) => {
                log_to_dart(format!("{:?}: {}", path, err));
                return Err(err);
            }
        };

        let mut audios: Vec<Audio> = vec![];
        let mut latest: u64 = 0;
        let entries: Vec<_> = dir.filter_map(|item| item.ok()).collect();
        let mut cue_source_paths: HashSet<String> = HashSet::new();
        for entry in &entries {
            let file_type = match entry.file_type() {
                Ok(value) => value,
                Err(_) => continue,
            };
            if !file_type.is_file() {
                continue;
            }
            if !is_cue_path(entry.path()) {
                continue;
            }

            let cue_tracks = Audio::read_from_cue_path(entry.path());
            for cue_track in cue_tracks {
                if let Some(source_path) = &cue_track.source_path {
                    cue_source_paths.insert(normalize_path_for_key(source_path));
                }
                if cue_track.created > latest {
                    latest = cue_track.created;
                }
                audios.push(cue_track);
            }
        }

        for entry in entries {
            let file_type = match entry.file_type() {
                Ok(value) => value,
                Err(_) => continue,
            };
            if !file_type.is_file() {
                continue;
            }
            if is_cue_path(entry.path()) {
                continue;
            }
            if cue_source_paths.contains(&normalize_path_for_key(entry.path())) {
                continue;
            }

            if let Some(audio_item) = Audio::read_from_path(entry.path()) {
                if audio_item.created > latest {
                    latest = audio_item.created;
                }
                audios.push(audio_item);
            }
        }

        if !audios.is_empty() {
            return Ok(AudioFolder {
                path: path.to_string_lossy().to_string(),
                modified: fs::metadata(path)?
                    .modified()?
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or(Duration::ZERO)
                    .as_secs(),
                latest,
                audios,
            });
        }

        Err(io::Error::new(
            io::ErrorKind::NotFound,
            path.to_string_lossy() + " has no music.",
        ))
    }

    /// 扫描路径为 path 的文件夹及其所有子文件夹。
    fn read_from_folder_recursively(
        folder: impl AsRef<Path>,
        result: &mut Vec<Self>,
        scaned_count: &mut u64,
        total_count: &mut u64,
        scaned_folders: &mut HashSet<String>,
        sink: &StreamSink<IndexActionState>,
    ) -> Result<(), io::Error> {
        let folder = folder.as_ref();
        if scaned_folders.contains(&folder.to_string_lossy().to_string()) {
            return Ok(());
        }

        let dir = match fs::read_dir(folder) {
            Ok(val) => val,
            Err(err) => {
                log_to_dart(format!("{:?}: {}", folder, err));
                return Ok(());
            }
        };

        let _ = sink.add(IndexActionState {
            progress: *scaned_count as f64 / *total_count as f64,
            message: String::from("正在扫描 ") + &folder.to_string_lossy(),
        });

        scaned_folders.insert(folder.to_string_lossy().to_string());
        let mut audios: Vec<Audio> = vec![];
        let mut latest: u64 = 0;

        let entries: Vec<_> = dir.filter_map(|item| item.ok()).collect();
        let mut file_entries = vec![];
        for entry in &entries {
            let file_type = match entry.file_type() {
                Ok(value) => value,
                Err(err) => {
                    log_to_dart(err.to_string());
                    continue;
                }
            };

            if file_type.is_dir() {
                *total_count += 1;
                let _ = Self::read_from_folder_recursively(
                    entry.path(),
                    result,
                    scaned_count,
                    total_count,
                    scaned_folders,
                    sink,
                );
            } else if file_type.is_file() {
                file_entries.push(entry.path());
            }
        }

        let mut cue_source_paths: HashSet<String> = HashSet::new();
        for file_path in &file_entries {
            if !is_cue_path(file_path) {
                continue;
            }

            for cue_track in Audio::read_from_cue_path(file_path) {
                if let Some(source_path) = &cue_track.source_path {
                    cue_source_paths.insert(normalize_path_for_key(source_path));
                }
                if cue_track.created > latest {
                    latest = cue_track.created;
                }
                audios.push(cue_track);
            }
        }

        for file_path in file_entries {
            if is_cue_path(&file_path) {
                continue;
            }
            if cue_source_paths.contains(&normalize_path_for_key(&file_path)) {
                continue;
            }

            if let Some(metadata) = Audio::read_from_path(&file_path) {
                if metadata.created > latest {
                    latest = metadata.created;
                }
                audios.push(metadata);
            }
        }

        if !audios.is_empty() {
            if let Ok(metadata) = fs::metadata(folder) {
                if let Ok(modified) = metadata.modified() {
                    result.push(AudioFolder {
                        path: folder.to_string_lossy().to_string(),
                        modified: modified
                            .duration_since(UNIX_EPOCH)
                            .unwrap_or(Duration::ZERO)
                            .as_secs(),
                        latest,
                        audios,
                    });
                }
            }
        }

        *scaned_count += 1;
        let _ = sink.add(IndexActionState {
            progress: *scaned_count as f64 / *total_count as f64,
            message: String::new(),
        });

        Ok(())
    }
}

fn dedup_audio_folders_by_path(audio_folders: &mut Vec<AudioFolder>) {
    let mut seen_audio_paths: HashSet<String> = HashSet::new();
    let mut seen_audio_identities: HashSet<String> = HashSet::new();
    for folder in audio_folders.iter_mut() {
        folder.audios.retain(|audio| {
            let path_key = normalize_path_for_key(&audio.path);
            let identity_key = audio_identity_key_from_audio(audio);
            if seen_audio_paths.contains(&path_key) || seen_audio_identities.contains(&identity_key)
            {
                return false;
            }
            seen_audio_paths.insert(path_key);
            seen_audio_identities.insert(identity_key);
            true
        });

        folder.latest = folder
            .audios
            .iter()
            .map(|audio| audio.created)
            .max()
            .unwrap_or(0);
    }

    audio_folders.retain(|folder| !folder.audios.is_empty());
}

fn dedup_index_folders_json_by_path(folders: &mut Vec<serde_json::Value>) {
    let mut seen_audio_paths: HashSet<String> = HashSet::new();
    let mut seen_audio_identities: HashSet<String> = HashSet::new();
    for folder in folders.iter_mut() {
        let audios = match folder["audios"].as_array_mut() {
            Some(value) => value,
            None => continue,
        };

        audios.retain(|audio| {
            let path = audio["path"].as_str().unwrap_or_default();
            let path_key = normalize_path_for_key(path);
            let identity_key = audio_identity_key_from_json(audio);
            if seen_audio_paths.contains(&path_key) || seen_audio_identities.contains(&identity_key)
            {
                return false;
            }
            seen_audio_paths.insert(path_key);
            seen_audio_identities.insert(identity_key);
            true
        });

        let latest = audios
            .iter()
            .filter_map(|audio| audio["created"].as_u64())
            .max()
            .unwrap_or(0);
        folder["latest"] = serde_json::json!(latest);
    }

    folders.retain(|folder| {
        folder["audios"]
            .as_array()
            .map(|audios| !audios.is_empty())
            .unwrap_or(false)
    });
}

fn _get_picture_by_windows(path: &String) -> Result<Vec<u8>, windows::core::Error> {
    let file = StorageFile::GetFileFromPathAsync(&HSTRING::from(path))?.get()?;
    let thumbnail = file
        .GetThumbnailAsyncOverloadDefaultSizeDefaultOptions(ThumbnailMode::MusicView)?
        .get()?;

    let size = thumbnail.Size()? as u32;
    let stream: IInputStream = thumbnail.cast()?;

    let mut buffer = vec![0u8; size as usize];
    let data_reader = DataReader::CreateDataReader(&stream)?;
    data_reader.LoadAsync(size)?.get()?;
    data_reader.ReadBytes(&mut buffer)?;

    data_reader.Close()?;
    stream.Close()?;

    Ok(buffer)
}

fn _get_picture_by_lofty(path: &String) -> Option<Vec<u8>> {
    if let Ok(tagged_file) = lofty::read_from_path(&path) {
        let tag = tagged_file
            .primary_tag()
            .or_else(|| tagged_file.first_tag())?;

        return Some(tag.pictures().first()?.data().to_vec());
    }

    None
}

/// for Flutter  
/// 如果无法通过 Lofty 获取则通过 Windows 获取
pub fn get_picture_from_path(path: String, width: u32, height: u32) -> Option<Vec<u8>> {
    let pic_option =
        _get_picture_by_lofty(&path).or_else(|| match _get_picture_by_windows(&path) {
            Ok(val) => Some(val),
            Err(err) => {
                log_to_dart(format!("fail to get pic: {}", err));
                None
            }
        });

    if let Some(pic) = &pic_option {
        if let Ok(loaded_pic) = image::load_from_memory(pic) {
            // 计算新的宽高，保持原比例
            let pic_ratio = loaded_pic.width() as f32 / loaded_pic.height() as f32;

            let (result_width, result_height) = if pic_ratio > 1.0 {
                (width, (width as f32 / pic_ratio).round() as u32)
            } else {
                ((height as f32 * pic_ratio).round() as u32, height)
            };

            let resized_img = imageops::resize(
                &loaded_pic,
                result_width,
                result_height,
                imageops::FilterType::Triangle,
            );

            let mut output = Cursor::new(Vec::new());
            if let Ok(_) = resized_img.write_to(&mut output, image::ImageFormat::Png) {
                return Some(output.into_inner());
            }
        }
    }

    pic_option
}

fn _get_lyric_from_lofty(path: &String) -> Option<String> {
    if let Ok(tagged_file) = lofty::read_from_path(&path) {
        let tag = tagged_file
            .primary_tag()
            .or_else(|| tagged_file.first_tag())?;
        let lyric_tag = tag.get(&ItemKey::Lyrics)?;
        let lyric = lyric_tag.value().text()?;

        return Some(lyric.to_string());
    }

    None
}

fn _get_lyric_from_lrc_file(path: &String) -> anyhow::Result<String> {
    let mut lrc_file_path = PathBuf::from(path);
    lrc_file_path.set_extension("lrc");

    let lrc_bytes = fs::read(lrc_file_path)?;

    let is_le = lrc_bytes.starts_with(&[0xFF, 0xFE]);
    let is_utf16 = (is_le || lrc_bytes.starts_with(&[0xFE, 0xFF])) && lrc_bytes.len() % 2 == 0;

    if is_utf16 {
        let convert_fn = match is_le {
            true => u16::from_le_bytes,
            false => u16::from_be_bytes,
        };

        let mut u16_bytes: Vec<u16> = vec![];
        let mut chunk_iter = lrc_bytes.chunks_exact(2);
        chunk_iter.next();

        for chunk in chunk_iter {
            u16_bytes.push(convert_fn([chunk[0], chunk[1]]));
        }
        return Ok(String::from_utf16(&u16_bytes)?);
    }

    return Ok(String::from_utf8(lrc_bytes)?);
}

/// for Flutter   
/// 只支持读取 ID3V2, VorbisComment, Mp4Ilst 存储的内嵌歌词
/// 以及相同目录相同文件名的 .lrc 外挂歌词（utf-8 or utf-16）
pub fn get_lyric_from_path(path: String) -> Option<String> {
    return _get_lyric_from_lofty(&path).or_else(|| match _get_lyric_from_lrc_file(&path) {
        Ok(val) => Some(val),
        Err(err) => {
            log_to_dart(format!("fail to get lrc: {}", err.to_string()));
            None
        }
    });
}

/// for Flutter  
/// 扫描给定路径下所有子文件夹（包括自己）的音乐文件并把索引保存在 index_path/index.json。
pub fn build_index_from_folders_recursively(
    folders: Vec<String>,
    index_path: String,
    sink: StreamSink<IndexActionState>,
) -> Result<(), io::Error> {
    let mut audio_folders: Vec<AudioFolder> = vec![];
    let mut scaned: u64 = 0;
    let mut total: u64 = folders.len() as u64;
    let mut scaned_folders: HashSet<String> = HashSet::new();

    for item in &folders {
        let _ = AudioFolder::read_from_folder_recursively(
            Path::new(item),
            &mut audio_folders,
            &mut scaned,
            &mut total,
            &mut scaned_folders,
            &sink,
        );
    }

    dedup_audio_folders_by_path(&mut audio_folders);

    let mut audio_folders_json: Vec<serde_json::Value> = vec![];
    for item in &audio_folders {
        audio_folders_json.push(item.to_json_value());
    }
    let json_value = serde_json::json!({
        "version": CURRENT_INDEX_VERSION,
        "folders": audio_folders_json,
    });

    let mut index_path = PathBuf::from(index_path);
    index_path.push("index.json");
    fs::File::create(index_path)?.write_all(json_value.to_string().as_bytes())?;

    Ok(())
}

fn _update_index_below_1_1_0(
    index: &serde_json::Value,
    index_path: &PathBuf,
    sink: &StreamSink<IndexActionState>,
) -> Result<(), io::Error> {
    let mut audio_folders_json: Vec<serde_json::Value> = vec![];
    let folders = index.as_array().unwrap();
    for item in folders {
        let path = item["path"].as_str().unwrap();
        let _ = sink.add(IndexActionState {
            progress: audio_folders_json.len() as f64 / folders.len() as f64,
            message: String::from("正在扫描 ") + path,
        });
        let folder_path = Path::new(path);
        if let Ok(audio_folder) = AudioFolder::read_from_folder(folder_path) {
            audio_folders_json.push(audio_folder.to_json_value());
            let _ = sink.add(IndexActionState {
                progress: audio_folders_json.len() as f64 / folders.len() as f64,
                message: String::new(),
            });
        }
    }
    fs::File::create(index_path)?.write_all(
        serde_json::json!({
            "version": CURRENT_INDEX_VERSION,
            "folders": audio_folders_json,
        })
        .to_string()
        .as_bytes(),
    )?;

    Ok(())
}

/// for Flutter   
/// 读取 index_path/index.json，检查更新。不可能重新读取被修改的文件夹下所有的音乐标签，这样太耗时。  
///
/// [LOWEST_VERSION] 指定可以继承的 index 的最低版本。
/// 如果 index version < [LOWEST_VERSION] 或者是 index 根本没有 version 再或者格式不符合要求，就转到
/// [_update_index_below_1_1_0] 更新 index；
/// 如果 index version >= [LOWEST_VERSION] 则进行更新。
///
/// 如果文件夹不存在，删除记录。  
/// 如果文件夹被修改（再次读取到的 modified > 记录的 modified），就更新它。没有则跳过它
/// 1. 遍历该文件夹索引，判断文件是否存在，不存在则删除记录
/// 2. 遍历该文件夹索引，如果文件被修改（再次读取到的 modified > 记录的 modified），重新读取标签；没有则跳过它
/// 3. 遍历该文件夹，添加新增（读取到的 created > 记录的 latest）的音乐文件
pub fn update_index(index_path: String, sink: StreamSink<IndexActionState>) -> anyhow::Result<()> {
    let mut index_path = PathBuf::from(index_path);
    index_path.push("index.json");
    let index = fs::read(&index_path)?;
    let mut index: serde_json::Value = serde_json::from_slice(&index)?;

    let version = index["version"].as_u64();
    if version.is_none() {
        return Ok(_update_index_below_1_1_0(&index, &index_path, &sink)?);
    }

    let force_refresh_all = version.unwrap_or(0) < CURRENT_INDEX_VERSION;
    let folders = index["folders"].as_array_mut().unwrap();

    // 删除访问不到的文件夹记录
    folders.retain(|item| {
        let path = item["path"].as_str().unwrap_or_default();
        Path::new(path).exists()
    });

    let total = if folders.is_empty() { 1 } else { folders.len() };
    let mut updated = 0usize;
    for folder_item in folders.iter_mut() {
        let folder_path = folder_item["path"].as_str().unwrap_or_default().to_string();
        if folder_path.is_empty() {
            updated += 1;
            continue;
        }

        let old_folder_modified = folder_item["modified"].as_u64().unwrap_or(0);
        let new_folder_modified = fs::metadata(&folder_path)
            .ok()
            .and_then(|metadata| metadata.modified().ok())
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
            .map(|duration| duration.as_secs())
            .unwrap_or(0);
        let need_refresh = force_refresh_all || new_folder_modified > old_folder_modified;

        if !need_refresh {
            updated += 1;
            continue;
        }

        let _ = sink.add(IndexActionState {
            progress: updated as f64 / total as f64,
            message: String::from("正在更新 ") + &folder_path,
        });

        match AudioFolder::read_from_folder(&folder_path) {
            Ok(refreshed_folder) => {
                *folder_item = refreshed_folder.to_json_value();
            }
            Err(_) => {
                folder_item["modified"] = serde_json::json!(new_folder_modified);
                folder_item["latest"] = serde_json::json!(0);
                folder_item["audios"] = serde_json::json!([]);
            }
        }

        updated += 1;
        let _ = sink.add(IndexActionState {
            progress: updated as f64 / total as f64,
            message: String::new(),
        });
    }

    dedup_index_folders_json_by_path(folders);
    index["version"] = serde_json::json!(CURRENT_INDEX_VERSION);

    fs::File::create(index_path)?.write_all(index.to_string().as_bytes())?;
    Ok(())
}
