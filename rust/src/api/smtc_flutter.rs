use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::Duration;

use flutter_rust_bridge::frb;
use windows::{
    core::HSTRING,
    Foundation::{EventRegistrationToken, TimeSpan, TypedEventHandler},
    Media::{
        MediaPlaybackStatus, MediaPlaybackType, Playback::MediaPlayer,
        SystemMediaTransportControls, SystemMediaTransportControlsButton,
        SystemMediaTransportControlsButtonPressedEventArgs,
        SystemMediaTransportControlsTimelineProperties,
    },
    Storage::{
        FileProperties::ThumbnailMode,
        StorageFile,
        Streams::{DataWriter, InMemoryRandomAccessStream, RandomAccessStreamReference},
    },
};

use crate::frb_generated::StreamSink;

use super::{logger::log_to_dart, tag_reader};

#[frb(opaque)]
pub struct SMTCFlutter {
    _smtc: Option<SystemMediaTransportControls>,
    _player: Option<MediaPlayer>,
    _button_token: Mutex<Option<EventRegistrationToken>>,
    _generation: AtomicU64,
}

pub enum SMTCControlEvent {
    Play,
    Pause,
    Previous,
    Next,
    Unknown,
}

pub enum SMTCState {
    Paused,
    Playing,
}

/// Apis for Flutter
impl SMTCFlutter {
    #[frb(sync)]
    pub fn new() -> Self {
        match Self::_new() {
            Ok(smtc) => smtc,
            Err(err) => {
                log_to_dart(format!("Failed to initialize Windows SMTC: {}", err));
                Self {
                    _smtc: None,
                    _player: None,
                    _button_token: Mutex::new(None),
                    _generation: AtomicU64::new(0),
                }
            }
        }
    }

    pub fn subscribe_to_control_events(&self, sink: StreamSink<SMTCControlEvent>) {
        let Some(smtc) = &self._smtc else {
            return;
        };
        let res = smtc.ButtonPressed(&TypedEventHandler::<
            SystemMediaTransportControls,
            SystemMediaTransportControlsButtonPressedEventArgs,
        >::new(move |_, event| {
            let Some(event_args) = event.as_ref() else {
                return Ok(());
            };
            let button = match event_args.Button() {
                Ok(b) => b,
                Err(err) => {
                    log_to_dart(format!("SMTC get button error: {}", err));
                    return Ok(());
                }
            };
            let event = match button {
                SystemMediaTransportControlsButton::Play => SMTCControlEvent::Play,
                SystemMediaTransportControlsButton::Pause => SMTCControlEvent::Pause,
                SystemMediaTransportControlsButton::Next => SMTCControlEvent::Next,
                SystemMediaTransportControlsButton::Previous => SMTCControlEvent::Previous,
                _ => SMTCControlEvent::Unknown,
            };
            if let Err(err) = sink.add(event) {
                log_to_dart(format!("SMTC sink.add error: {}", err));
            }

            Ok(())
        }));
        match res {
            Ok(token) => {
                if let Ok(mut guard) = self._button_token.lock() {
                    if let Some(old_token) = guard.replace(token) {
                        let _ = smtc.RemoveButtonPressed(old_token);
                    }
                }
            }
            Err(err) => {
                log_to_dart(format!("Failed to register SMTC button listener: {}", err));
            }
        }
    }

    pub fn update_state(&self, state: SMTCState) {
        if self._smtc.is_none() {
            return;
        }
        if let Err(err) = self._update_state(state) {
            log_to_dart(format!("fail to update state: {}", err));
        }
    }

    /// progress, duration: ms
    pub fn update_time_properties(&self, progress: u32) {
        if self._smtc.is_none() {
            return;
        }
        if let Err(err) = self._update_time_properties(progress) {
            log_to_dart(format!("fail to update state: {}", err));
        }
    }

    pub fn update_display(
        &self,
        title: String,
        artist: String,
        album: String,
        duration: u32,
        path: String,
    ) {
        if self._smtc.is_none() {
            return;
        }
        let gen = self._generation.fetch_add(1, Ordering::SeqCst) + 1;
        if let Err(err) = self._update_display(
            gen,
            HSTRING::from(title),
            HSTRING::from(artist),
            HSTRING::from(album),
            duration,
            HSTRING::from(path),
        ) {
            log_to_dart(format!("fail to update display: {}", err));
        }
    }

    pub fn close(self) {
        if let Some(smtc) = &self._smtc {
            if let Ok(mut guard) = self._button_token.lock() {
                if let Some(token) = guard.take() {
                    let _ = smtc.RemoveButtonPressed(token);
                }
            }
        }
        if let Some(player) = self._player {
            let _ = player.Close();
        }
    }
}

impl SMTCFlutter {
    fn _init_controls(smtc: &SystemMediaTransportControls) -> Result<(), windows::core::Error> {
        // 下一首
        smtc.SetIsNextEnabled(true)?;
        // 暂停
        smtc.SetIsPauseEnabled(true)?;
        // 播放（恢复）
        smtc.SetIsPlayEnabled(true)?;
        // 上一首
        smtc.SetIsPreviousEnabled(true)?;

        Ok(())
    }

    fn _new() -> Result<Self, windows::core::Error> {
        let player = MediaPlayer::new()?;
        player.CommandManager()?.SetIsEnabled(false)?;

        let smtc = player.SystemMediaTransportControls()?;
        Self::_init_controls(&smtc)?;

        Ok(Self {
            _smtc: Some(smtc),
            _player: Some(player),
            _button_token: Mutex::new(None),
            _generation: AtomicU64::new(0),
        })
    }

    fn _update_state(&self, state: SMTCState) -> Result<(), windows::core::Error> {
        let Some(smtc) = &self._smtc else {
            return Ok(());
        };
        let state = match state {
            SMTCState::Playing => MediaPlaybackStatus::Playing,
            SMTCState::Paused => MediaPlaybackStatus::Paused,
        };
        smtc.SetPlaybackStatus(state)?;

        Ok(())
    }

    /// progress, duration: ms
    fn _update_time_properties(&self, progress: u32) -> Result<(), windows::core::Error> {
        let Some(smtc) = &self._smtc else {
            return Ok(());
        };
        let time_properties = SystemMediaTransportControlsTimelineProperties::new()?;
        time_properties.SetPosition(TimeSpan::from(Duration::from_millis(progress.into())))?;
        smtc.UpdateTimelineProperties(&time_properties)?;

        Ok(())
    }

    fn _ras_ref_from_pic_data(
        picture_data: &[u8],
    ) -> Result<RandomAccessStreamReference, windows::core::Error> {
        let stream = InMemoryRandomAccessStream::new()?;

        let writer = DataWriter::CreateDataWriter(&stream)?;
        writer.WriteBytes(picture_data)?;
        writer.StoreAsync()?.get()?;

        // 调用 DetachStream() 的意义在于“把流从 DataWriter 脱附”，
        // 这样可以安全地释放/关闭 DataWriter 而不影响流的生命周期。
        // stream 不会因为 writer drop 而被销毁
        writer.DetachStream()?;

        stream.Seek(0)?;

        RandomAccessStreamReference::CreateFromStream(&stream)
    }

    fn _load_thumbnail(path: &HSTRING) -> Option<RandomAccessStreamReference> {
        if let Some(pic_data) = tag_reader::get_picture_from_path(path.to_string(), 256, 256) {
            match Self::_ras_ref_from_pic_data(&pic_data) {
                Ok(stream_ref) => return Some(stream_ref),
                Err(err) => {
                    log_to_dart(format!("Failed to create stream from embedded picture: {}", err));
                }
            }
        } else {
            log_to_dart(format!("no embedded picture found for file: {}", path));
        }

        // Fallback to Windows Shell StorageFile thumbnail with local error isolation
        match (|| -> Result<RandomAccessStreamReference, windows::core::Error> {
            let file = StorageFile::GetFileFromPathAsync(path)?.get()?;
            let thumbnail = file
                .GetThumbnailAsyncOverloadDefaultSizeDefaultOptions(ThumbnailMode::MusicView)?
                .get()?;
            RandomAccessStreamReference::CreateFromStream(&thumbnail)
        })() {
            Ok(stream_ref) => Some(stream_ref),
            Err(err) => {
                log_to_dart(format!("Failed to load StorageFile thumbnail for {}: {}", path, err));
                None
            }
        }
    }

    fn _update_display(
        &self,
        gen: u64,
        title: HSTRING,
        artist: HSTRING,
        album: HSTRING,
        duration: u32,
        path: HSTRING,
    ) -> Result<(), windows::core::Error> {
        let Some(smtc) = &self._smtc else {
            return Ok(());
        };
        if self._generation.load(Ordering::SeqCst) != gen {
            return Ok(());
        }

        let updater = smtc.DisplayUpdater()?;
        updater.SetType(MediaPlaybackType::Music)?;

        let time_properties = SystemMediaTransportControlsTimelineProperties::new()?;
        time_properties.SetStartTime(TimeSpan { Duration: 0 })?;
        time_properties.SetEndTime(TimeSpan::from(Duration::from_millis(duration.into())))?;
        time_properties.SetMinSeekTime(TimeSpan { Duration: 0 })?;
        time_properties.SetMaxSeekTime(TimeSpan::from(Duration::from_millis(duration.into())))?;
        smtc.UpdateTimelineProperties(&time_properties)?;

        let music_properties = updater.MusicProperties()?;
        music_properties.SetTitle(&title)?;
        music_properties.SetArtist(&artist)?;
        music_properties.SetAlbumTitle(&album)?;

        if self._generation.load(Ordering::SeqCst) != gen {
            return Ok(());
        }

        if let Some(pic_stream_ref) = Self::_load_thumbnail(&path) {
            if self._generation.load(Ordering::SeqCst) != gen {
                return Ok(());
            }
            if let Err(err) = updater.SetThumbnail(&pic_stream_ref) {
                log_to_dart(format!("Failed to set SMTC thumbnail: {}", err));
            }
        }

        if self._generation.load(Ordering::SeqCst) != gen {
            return Ok(());
        }

        updater.Update()?;

        if !(smtc.IsEnabled()?) {
            smtc.SetIsEnabled(true)?;
        }

        Ok(())
    }
}
