//! File-first metadata transactions. Preparing never mutates the source. The
//! durable journal survives process termination between replacement and indexing.
use super::tag_reader::{atomic_write_bytes, lock_index_writes, replace_file};
use anyhow::{bail, ensure, Context, Result};
use lofty::{
    config::WriteOptions,
    picture::{Picture, PictureType},
    prelude::*,
    tag::{Tag, TagType},
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{
    collections::HashMap,
    fs,
    io::Read,
    path::{Path, PathBuf},
    sync::{Mutex, OnceLock},
    time::{SystemTime, UNIX_EPOCH},
};

/// None keeps a field, an empty string clears it. Zero clears an ordinal.
#[derive(Clone, Default)]
pub struct AudioMetadataPatch {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub track: Option<u32>,
    pub disc: Option<u32>,
    pub lyrics: Option<String>,
    pub cover: Option<Vec<u8>>,
}

#[derive(Clone)]
pub struct AudioMetadataSnapshot {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_artist: String,
    pub track: u32,
    pub disc: u32,
    pub lyrics: String,
    pub modified: u64,
    pub size: u64,
    pub fingerprint: String,
}

#[derive(Clone)]
struct Transaction {
    path: PathBuf,
    temporary: PathBuf,
    backup: PathBuf,
    journal: PathBuf,
    before: String,
    after: String,
}
static TRANSACTIONS: OnceLock<Mutex<HashMap<String, Transaction>>> = OnceLock::new();
fn transactions() -> &'static Mutex<HashMap<String, Transaction>> {
    TRANSACTIONS.get_or_init(Default::default)
}

fn fingerprint(path: &Path) -> Result<String> {
    let mut file = fs::File::open(path)?;
    let mut hash = Sha256::new();
    let mut buffer = [0_u8; 65536];
    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hash.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hash.finalize()))
}

pub fn read_audio_metadata(path: String) -> Result<AudioMetadataSnapshot> {
    let file = lofty::read_from_path(&path)?;
    let tag = file.primary_tag().or_else(|| file.first_tag());
    let text = |key: ItemKey| {
        tag.and_then(|t| t.get_string(&key))
            .unwrap_or("")
            .to_string()
    };
    let meta = fs::metadata(&path)?;
    Ok(AudioMetadataSnapshot {
        title: text(ItemKey::TrackTitle),
        artist: text(ItemKey::TrackArtist),
        album: text(ItemKey::AlbumTitle),
        album_artist: text(ItemKey::AlbumArtist),
        track: tag.and_then(|t| t.track()).unwrap_or(0),
        disc: tag.and_then(|t| t.disk()).unwrap_or(0),
        lyrics: text(ItemKey::Lyrics),
        modified: meta.modified()?.duration_since(UNIX_EPOCH)?.as_secs(),
        size: meta.len(),
        fingerprint: fingerprint(Path::new(&path))?,
    })
}

fn fields(p: &AudioMetadataPatch) -> Vec<(ItemKey, Option<String>)> {
    vec![
        (ItemKey::TrackTitle, p.title.clone()),
        (ItemKey::TrackArtist, p.artist.clone()),
        (ItemKey::AlbumTitle, p.album.clone()),
        (ItemKey::AlbumArtist, p.album_artist.clone()),
        (
            ItemKey::TrackNumber,
            p.track
                .map(|v| if v == 0 { String::new() } else { v.to_string() }),
        ),
        (
            ItemKey::DiscNumber,
            p.disc
                .map(|v| if v == 0 { String::new() } else { v.to_string() }),
        ),
        (ItemKey::Lyrics, p.lyrics.clone()),
    ]
}

fn snapshot_json(s: &AudioMetadataSnapshot) -> Value {
    json!({"title":s.title,"artist":s.artist,"album":s.album,"album_artist":s.album_artist,
        "track":s.track,"disc":s.disc,"modified":s.modified,"size":s.size})
}

/// Returns an opaque token. A second prepare for the same physical file fails.
pub fn prepare_audio_metadata(
    path: String,
    support_path: String,
    expected_fingerprint: String,
    patch: AudioMetadataPatch,
) -> Result<String> {
    let path = fs::canonicalize(path)?;
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    ensure!(
        ["mp3", "flac", "m4a", "ogg", "opus", "aac"].contains(&ext.as_str()),
        "此格式尚未开放标签写入"
    );
    ensure!(
        !fs::metadata(&path)?.permissions().readonly(),
        "文件只读，无法保存"
    );
    let dir = Path::new(&support_path).join("metadata_transactions");
    fs::create_dir_all(&dir)?;
    for entry in fs::read_dir(&dir)? {
        let pending = entry?.path();
        if pending.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }
        let value: Value = serde_json::from_slice(&fs::read(&pending)?)?;
        if value["path"].as_str().map(Path::new) == Some(path.as_path()) {
            bail!("此文件有尚未完成的索引同步，请重启播放器恢复后再编辑");
        }
    }
    let before = fingerprint(&path)?;
    ensure!(
        expected_fingerprint.is_empty() || expected_fingerprint == before,
        "文件已被其他程序修改，请重新打开编辑器"
    );
    let token = format!(
        "{}-{}",
        std::process::id(),
        SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos()
    );
    let temporary = path.with_file_name(format!(".qisheng-edit-{token}.{ext}"));
    let backup = path.with_file_name(format!(".qisheng-backup-{token}.{ext}"));
    let journal = dir.join(format!("{token}.json"));
    {
        let mut active = transactions().lock().unwrap_or_else(|e| e.into_inner());
        ensure!(
            !active.values().any(|t| t.path == path),
            "此文件正在保存，请稍后重试"
        );
        active.insert(
            token.clone(),
            Transaction {
                path: path.clone(),
                temporary: temporary.clone(),
                backup: backup.clone(),
                journal: journal.clone(),
                before: before.clone(),
                after: String::new(),
            },
        );
    }
    let result = (|| -> Result<Transaction> {
        fs::copy(&path, &temporary)?;
        let original = lofty::read_from_path(&temporary)?;
        let tag_type = original.file_type().primary_tag_type();
        let mut tag = original
            .primary_tag()
            .cloned()
            .unwrap_or_else(|| Tag::new(tag_type));
        let edits = fields(&patch);
        for (key, value) in &edits {
            if let Some(value) = value {
                tag.remove_key(key);
                if !value.is_empty() {
                    tag.insert_text(key.clone(), value.clone());
                }
            }
        }
        if let Some(bytes) = &patch.cover {
            if tag_type == TagType::Mp4Ilst {
                ensure!(
                    tag.pictures().len() <= 1,
                    "M4A 文件包含多张图片，无法可靠识别主封面并保留其他图片，已取消"
                );
                while !tag.pictures().is_empty() {
                    tag.remove_picture(0);
                }
            } else {
                tag.remove_picture_type(PictureType::CoverFront);
            }
            if !bytes.is_empty() {
                ensure!(bytes.len() <= 12 * 1024 * 1024, "图片超过 12 MB");
                let dimensions = image::ImageReader::new(std::io::Cursor::new(bytes))
                    .with_guessed_format()
                    .context("图片格式无效")?
                    .into_dimensions()
                    .context("图片无法读取")?;
                ensure!(
                    dimensions.0 <= 8192
                        && dimensions.1 <= 8192
                        && u64::from(dimensions.0) * u64::from(dimensions.1) <= 32_000_000,
                    "图片像素尺寸过大"
                );
                image::load_from_memory(bytes).context("图片无法解码")?;
                let mut picture = Picture::from_reader(&mut std::io::Cursor::new(bytes))?;
                picture.set_pic_type(PictureType::CoverFront);
                tag.push_picture(picture);
            }
        }
        tag.save_to_path(&temporary, WriteOptions::default())?;
        let updated = lofty::read_from_path(&temporary)?;
        let actual = updated.primary_tag().context("无法回读写入标签")?;
        for (key, value) in &edits {
            if let Some(value) = value {
                if key == &ItemKey::TrackNumber {
                    let actual_track = actual.track().unwrap_or(0);
                    let expected_track = value.parse::<u32>().unwrap_or(0);
                    ensure!(
                        actual_track == expected_track,
                        "音轨号回读验证失败: 预期 {}, 实际 {}",
                        expected_track,
                        actual_track
                    );
                } else if key == &ItemKey::DiscNumber {
                    let actual_disc = actual.disk().unwrap_or(0);
                    let expected_disc = value.parse::<u32>().unwrap_or(0);
                    ensure!(
                        actual_disc == expected_disc,
                        "碟号回读验证失败: 预期 {}, 实际 {}",
                        expected_disc,
                        actual_disc
                    );
                } else {
                    ensure!(
                        actual.get_string(key).unwrap_or("") == value,
                        "字段回读验证失败: {:?}",
                        key
                    );
                }
            }
        }
        for old_tag in original.tags() {
            if old_tag.tag_type() == TagType::Id3v1 {
                continue;
            }
            let new_tag = match updated.tag(old_tag.tag_type()) {
                Some(t) => t,
                None => continue,
            };
            for item in old_tag.items() {
                let edited = old_tag.tag_type() == tag_type
                    && edits.iter().any(|(k, v)| v.is_some() && k == item.key());
                if !edited {
                    ensure!(
                        new_tag.items().any(|n| n == item),
                        "写入会改变未编辑标签 {:?}，已取消",
                        item.key()
                    );
                }
            }
            for pic in old_tag.pictures() {
                if !(old_tag.tag_type() == tag_type
                    && patch.cover.is_some()
                    && (pic.pic_type() == PictureType::CoverFront || tag_type == TagType::Mp4Ilst))
                {
                    ensure!(new_tag.pictures().contains(pic), "写入会丢失原图片，已取消");
                }
            }
        }
        if let Some(bytes) = &patch.cover {
            ensure!(
                if bytes.is_empty() {
                    !actual
                        .pictures()
                        .iter()
                        .any(|p| p.pic_type() == PictureType::CoverFront)
                } else {
                    actual.pictures().iter().any(|p| p.data() == bytes)
                },
                "封面回读验证失败"
            );
        }
        let a = original.properties();
        let b = updated.properties();
        ensure!(
            a.sample_rate() == b.sample_rate()
                && a.channels() == b.channels()
                && a.duration().abs_diff(b.duration()).as_millis() <= 500,
            "音频属性发生变化，已取消"
        );
        fs::OpenOptions::new()
            .write(true)
            .open(&temporary)?
            .sync_all()?;
        ensure!(fingerprint(&path)? == before, "源文件在保存期间发生变化");
        let after = fingerprint(&temporary)?;
        let tx = Transaction {
            path,
            temporary: temporary.clone(),
            backup,
            journal: journal.clone(),
            before,
            after,
        };
        atomic_write_bytes(
            &journal,
            &serde_json::to_vec(
                &json!({"path":tx.path,"temporary":tx.temporary,"backup":tx.backup,"before":tx.before,"after":tx.after}),
            )?,
        )?;
        Ok(tx)
    })();
    match result {
        Ok(tx) => {
            transactions()
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .insert(token.clone(), tx);
            Ok(token)
        }
        Err(e) => {
            transactions()
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner())
                .remove(&token);
            let _ = fs::remove_file(temporary);
            let _ = fs::remove_file(journal);
            Err(e)
        }
    }
}

/// Called while the playback handle is released. The journal is already durable.
pub fn commit_audio_metadata(token: String) -> Result<AudioMetadataSnapshot> {
    let active = transactions().lock().unwrap_or_else(|e| e.into_inner());
    let tx = active.get(&token).context("编辑事务已失效")?;
    ensure!(
        fingerprint(&tx.path)? == tx.before,
        "源文件在提交前发生变化，未覆盖"
    );
    fs::copy(&tx.path, &tx.backup)?;
    fs::OpenOptions::new()
        .write(true)
        .open(&tx.backup)?
        .sync_all()?;
    let mut verified = read_audio_metadata(tx.temporary.to_string_lossy().into_owned())?;
    replace_file(&tx.temporary, &tx.path)?;
    let metadata = fs::metadata(&tx.path)?;
    let committed_fingerprint = fingerprint(&tx.path)?;
    ensure!(
        committed_fingerprint == tx.after,
        "文件替换后的内容校验失败，保留恢复记录"
    );
    verified.modified = metadata.modified()?.duration_since(UNIX_EPOCH)?.as_secs();
    verified.size = metadata.len();
    verified.fingerprint = committed_fingerprint;
    Ok(verified)
}

fn synchronize(path: &Path, support: &Path) -> Result<AudioMetadataSnapshot> {
    let _guard = lock_index_writes();
    let s = read_audio_metadata(path.to_string_lossy().into_owned())?;
    let index_path = support.join("index.json");
    let mut index: Value = serde_json::from_slice(&fs::read(&index_path)?)?;
    let mut found = false;
    for folder in index["folders"].as_array_mut().context("曲库索引无效")? {
        if let Some(audios) = folder["audios"].as_array_mut() {
            for audio in audios {
                if audio["source_path"].is_string() {
                    continue;
                }
                let same = audio["path"]
                    .as_str()
                    .and_then(|p| fs::canonicalize(p).ok())
                    .as_deref()
                    == Some(path);
                if same {
                    for (k, v) in snapshot_json(&s).as_object().unwrap() {
                        audio[k] = v.clone();
                    }
                    found = true;
                }
            }
        }
    }
    ensure!(found, "文件已保存，但曲库中未找到该歌曲，需要重新扫描");
    atomic_write_bytes(&index_path, &serde_json::to_vec(&index)?)?;
    // Remove stale overrides only after the file is committed. Failure keeps the journal.
    let overrides_path = support.join("audio_override.json");
    if overrides_path.exists() {
        let mut overrides: Value = serde_json::from_slice(&fs::read(&overrides_path)?)?;
        if let Some(map) = overrides.as_object_mut() {
            map.retain(|k, _| fs::canonicalize(k).ok().as_deref() != Some(path));
        }
        atomic_write_bytes(&overrides_path, &serde_json::to_vec(&overrides)?)?;
    }
    Ok(s)
}

pub fn finish_audio_metadata(token: String, support_path: String) -> Result<AudioMetadataSnapshot> {
    let mut active = transactions().lock().unwrap_or_else(|e| e.into_inner());
    let tx = active.get(&token).context("编辑事务已失效")?.clone();
    let result = synchronize(&tx.path, Path::new(&support_path));
    // Release the in-process lock even on indexing failure; durable recovery remains.
    active.remove(&token);
    if result.is_ok() {
        cleanup(&tx)?;
    }
    result
}

fn cleanup(tx: &Transaction) -> Result<()> {
    for path in [&tx.temporary, &tx.backup, &tx.journal] {
        match fs::remove_file(path) {
            Ok(()) => {}
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(e.into()),
        }
    }
    Ok(())
}

pub fn cancel_audio_metadata(token: String) -> Result<()> {
    if let Some(tx) = transactions()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .remove(&token)
    {
        // Never erase recovery evidence for an already replaced file.
        if fingerprint(&tx.path)? == tx.before {
            cleanup(&tx)?;
        }
    }
    Ok(())
}

/// Invoked before loading the index on startup, before overrides are read.
pub fn recover_audio_metadata(support_path: String) -> Result<Vec<String>> {
    let _active = transactions().lock().unwrap_or_else(|e| e.into_inner());
    let root = Path::new(&support_path);
    let dir = root.join("metadata_transactions");
    if !dir.exists() {
        return Ok(vec![]);
    }
    let mut warnings = vec![];
    for entry in fs::read_dir(dir)? {
        let journal = entry?.path();
        if journal.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }
        let attempt = (|| -> Result<()> {
            let v: Value = serde_json::from_slice(&fs::read(&journal)?)?;
            let text = |k: &str| -> Result<String> {
                Ok(v[k].as_str().context("恢复记录无效")?.to_string())
            };
            let tx = Transaction {
                path: PathBuf::from(text("path")?),
                temporary: PathBuf::from(text("temporary")?),
                backup: PathBuf::from(text("backup")?),
                journal: journal.clone(),
                before: text("before")?,
                after: text("after")?,
            };
            if _active.values().any(|a| a.path == tx.path) {
                return Ok(());
            }
            let current = fingerprint(&tx.path)?;
            if current == tx.after {
                synchronize(&tx.path, root)?;
            } else if current != tx.before {
                bail!(
                    "源文件已再次修改，保留备份供人工恢复: {}",
                    tx.backup.display()
                );
            }
            cleanup(&tx)
        })();
        if let Err(e) = attempt {
            warnings.push(format!("{}: {e}", journal.display()));
        }
    }
    Ok(warnings)
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{DynamicImage, ImageFormat, RgbaImage};
    use std::{io::Cursor, process::Command};

    struct TestDir(PathBuf);
    impl Drop for TestDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn command_ok(mut command: Command) {
        let output = command.output().expect("failed to launch ffmpeg");
        assert!(
            output.status.success(),
            "ffmpeg failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    fn audio_md5(path: &Path) -> String {
        let output = Command::new("ffmpeg")
            .args(["-v", "error", "-i"])
            .arg(path)
            .args(["-map", "0:a:0", "-f", "md5", "-"])
            .output()
            .unwrap();
        assert!(output.status.success());
        String::from_utf8(output.stdout).unwrap()
    }

    #[test]
    fn combined_edit_is_transactional_and_preserves_audio_for_supported_formats() {
        let root = std::env::temp_dir().join(format!(
            "qisheng-metadata-test-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&root).unwrap();
        let _guard = TestDir(root.clone());
        let support = root.join("support");
        fs::create_dir_all(&support).unwrap();
        let formats = [
            ("mp3", "libmp3lame"),
            ("flac", "flac"),
            ("m4a", "aac"),
            ("ogg", "libvorbis"),
            ("opus", "libopus"),
        ];
        let mut replay_gain_samples = 0;
        for (ext, codec) in formats {
            let path = root.join(format!("sample.{ext}"));
            let mut command = Command::new("ffmpeg");
            command
                .args([
                    "-v",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    "sine=frequency=440:duration=0.4",
                    "-c:a",
                    codec,
                    "-metadata",
                    "title=Old title",
                    "-metadata",
                    "artist=Old artist",
                    "-metadata",
                    "album=Old album",
                    "-metadata",
                    "composer=Preserved composer",
                    "-metadata",
                    "REPLAYGAIN_TRACK_GAIN=-3.20 dB",
                    "-y",
                ])
                .arg(&path);
            command_ok(command);
            let mut back_cover = Vec::new();
            DynamicImage::ImageRgba8(RgbaImage::from_pixel(2, 2, image::Rgba([9, 8, 7, 255])))
                .write_to(&mut Cursor::new(&mut back_cover), ImageFormat::Png)
                .unwrap();
            if ext != "m4a" {
                let tagged = lofty::read_from_path(&path).unwrap();
                let tag_type = tagged.file_type().primary_tag_type();
                let mut tag = tagged
                    .primary_tag()
                    .cloned()
                    .unwrap_or_else(|| Tag::new(tag_type));
                let mut picture = Picture::from_reader(&mut Cursor::new(&back_cover)).unwrap();
                picture.set_pic_type(PictureType::CoverBack);
                tag.push_picture(picture);
                tag.save_to_path(&path, WriteOptions::default()).unwrap();
            }
            let initially_tagged = lofty::read_from_path(&path).unwrap();
            let initial_tag = initially_tagged
                .primary_tag()
                .or_else(|| initially_tagged.first_tag())
                .unwrap();
            let had_replay_gain = initial_tag
                .items()
                .any(|item| item.key() == &ItemKey::ReplayGainTrackGain);
            if had_replay_gain {
                replay_gain_samples += 1;
            }
            let before = read_audio_metadata(path.to_string_lossy().into_owned()).unwrap();
            let decoded_before = audio_md5(&path);
            let mut png = Vec::new();
            DynamicImage::ImageRgba8(RgbaImage::from_pixel(2, 2, image::Rgba([1, 2, 3, 255])))
                .write_to(&mut Cursor::new(&mut png), ImageFormat::Png)
                .unwrap();
            atomic_write_bytes(&support.join("index.json"), &serde_json::to_vec(&json!({"folders":[{"audios":[{
                "path":path,"title":"Old title","artist":"Old artist","album":"Old album","modified":0,"size":0
            }]}]})).unwrap()).unwrap();
            let token = prepare_audio_metadata(
                path.to_string_lossy().into_owned(),
                support.to_string_lossy().into_owned(),
                before.fingerprint.clone(),
                AudioMetadataPatch {
                    title: Some("New title".into()),
                    artist: Some("New artist".into()),
                    album: Some("New album".into()),
                    album_artist: Some("Album artist".into()),
                    track: Some(7),
                    disc: Some(2),
                    lyrics: Some("[00:00.00]verified".into()),
                    cover: Some(png),
                },
            )
            .unwrap_or_else(|error| panic!("prepare failed for {ext}: {error:#}"));
            assert_eq!(
                fingerprint(&path).unwrap(),
                before.fingerprint,
                "prepare changed {ext}"
            );
            let committed = commit_audio_metadata(token.clone()).unwrap();
            assert_eq!(committed.title, "New title");
            assert_eq!(committed.album_artist, "Album artist");
            assert_eq!(committed.track, 7);
            assert_eq!(committed.disc, 2);
            assert_eq!(
                audio_md5(&path),
                decoded_before,
                "audio payload changed for {ext}"
            );
            let tagged = lofty::read_from_path(&path).unwrap();
            let tag = tagged.primary_tag().or_else(|| tagged.first_tag()).unwrap();
            assert_eq!(
                tag.get_string(&ItemKey::Composer),
                Some("Preserved composer")
            );
            assert_eq!(
                tag.items()
                    .any(|item| item.key() == &ItemKey::ReplayGainTrackGain),
                had_replay_gain
            );
            if ext != "m4a" {
                assert!(
                    tag.pictures().iter().any(|picture| {
                        picture.pic_type() == PictureType::CoverBack && picture.data() == back_cover
                    }),
                    "back cover was not preserved for {ext}"
                );
            }
            finish_audio_metadata(token, support.to_string_lossy().into_owned()).unwrap();
        }
        assert!(
            replay_gain_samples > 0,
            "test inputs did not contain ReplayGain"
        );
    }

    #[test]
    fn unsupported_and_invalid_inputs_never_touch_the_source() {
        let root = std::env::temp_dir().join(format!(
            "qisheng-metadata-negative-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&root).unwrap();
        let _guard = TestDir(root.clone());
        let unsupported = root.join("sample.wav");
        fs::write(&unsupported, b"unchanged").unwrap();
        assert!(prepare_audio_metadata(
            unsupported.to_string_lossy().into_owned(),
            root.to_string_lossy().into_owned(),
            String::new(),
            AudioMetadataPatch::default()
        )
        .is_err());
        assert_eq!(fs::read(unsupported).unwrap(), b"unchanged");

        let path = root.join("valid.mp3");
        let mut command = Command::new("ffmpeg");
        command
            .args([
                "-v",
                "error",
                "-f",
                "lavfi",
                "-i",
                "sine=duration=0.1",
                "-c:a",
                "libmp3lame",
                "-y",
            ])
            .arg(&path);
        command_ok(command);
        let before = fingerprint(&path).unwrap();
        assert!(prepare_audio_metadata(
            path.to_string_lossy().into_owned(),
            root.to_string_lossy().into_owned(),
            "wrong fingerprint".into(),
            AudioMetadataPatch {
                title: Some("changed".into()),
                ..Default::default()
            }
        )
        .is_err());
        assert_eq!(fingerprint(&path).unwrap(), before);

        let snapshot = read_audio_metadata(path.to_string_lossy().into_owned()).unwrap();
        let token = prepare_audio_metadata(
            path.to_string_lossy().into_owned(),
            root.to_string_lossy().into_owned(),
            snapshot.fingerprint,
            AudioMetadataPatch {
                title: Some("prepared".into()),
                ..Default::default()
            },
        )
        .unwrap();
        assert!(prepare_audio_metadata(
            path.to_string_lossy().into_owned(),
            root.to_string_lossy().into_owned(),
            before.clone(),
            AudioMetadataPatch::default()
        )
        .is_err());
        cancel_audio_metadata(token).unwrap();
        assert_eq!(fingerprint(&path).unwrap(), before);

        let mut permissions = fs::metadata(&path).unwrap().permissions();
        permissions.set_readonly(true);
        fs::set_permissions(&path, permissions.clone()).unwrap();
        assert!(prepare_audio_metadata(
            path.to_string_lossy().into_owned(),
            root.to_string_lossy().into_owned(),
            before.clone(),
            AudioMetadataPatch::default()
        )
        .is_err());
        permissions.set_readonly(false);
        fs::set_permissions(&path, permissions).unwrap();
        assert_eq!(fingerprint(&path).unwrap(), before);
    }

    #[test]
    fn m4a_with_multiple_pictures_rejects_cover_replacement() {
        let root = std::env::temp_dir().join(format!(
            "qisheng-metadata-m4a-pictures-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&root).unwrap();
        let _guard = TestDir(root.clone());
        let path = root.join("multiple-pictures.m4a");
        let mut command = Command::new("ffmpeg");
        command
            .args([
                "-v",
                "error",
                "-f",
                "lavfi",
                "-i",
                "sine=duration=0.1",
                "-c:a",
                "aac",
                "-y",
            ])
            .arg(&path);
        command_ok(command);

        let tagged = lofty::read_from_path(&path).unwrap();
        let tag_type = tagged.file_type().primary_tag_type();
        let mut tag = Tag::new(tag_type);
        for color in [[1, 2, 3, 255], [4, 5, 6, 255]] {
            let mut bytes = Vec::new();
            DynamicImage::ImageRgba8(RgbaImage::from_pixel(2, 2, image::Rgba(color)))
                .write_to(&mut Cursor::new(&mut bytes), ImageFormat::Png)
                .unwrap();
            tag.push_picture(Picture::from_reader(&mut Cursor::new(bytes)).unwrap());
        }
        tag.save_to_path(&path, WriteOptions::default()).unwrap();
        assert_eq!(
            lofty::read_from_path(&path)
                .unwrap()
                .primary_tag()
                .unwrap()
                .pictures()
                .len(),
            2
        );

        let before = read_audio_metadata(path.to_string_lossy().into_owned()).unwrap();
        let replacement =
            DynamicImage::ImageRgba8(RgbaImage::from_pixel(2, 2, image::Rgba([7, 8, 9, 255])));
        let mut replacement_bytes = Vec::new();
        replacement
            .write_to(&mut Cursor::new(&mut replacement_bytes), ImageFormat::Png)
            .unwrap();
        let error = prepare_audio_metadata(
            path.to_string_lossy().into_owned(),
            root.to_string_lossy().into_owned(),
            before.fingerprint.clone(),
            AudioMetadataPatch {
                cover: Some(replacement_bytes),
                ..Default::default()
            },
        )
        .unwrap_err();
        assert!(error.to_string().contains("M4A 文件包含多张图片"));
        assert_eq!(fingerprint(&path).unwrap(), before.fingerprint);
    }
}
