// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:math' as math;

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/play_service/audio_spectrum.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_session_store.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/smtc_flutter.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/foundation.dart';

enum PlayMode {
  /// 椤哄簭鎾斁鍒版挱鏀惧垪琛ㄧ粨灏?
  forward,

  /// 循环整个播放列表
  loop,

  /// 循环播放单曲
  singleLoop;

  static PlayMode? fromString(String playMode) {
    for (var value in PlayMode.values) {
      if (value.name == playMode) return value;
    }
    return null;
  }
}

final ValueListenable<List<double>> _emptyAudioSpectrum =
    ValueNotifier<List<double>>(const <double>[]);
final ValueListenable<bool> _defaultWasapiExclusive =
    ValueNotifier<bool>(false);

@visibleForTesting
List<Audio> rebindAudiosToLibrary(
  Iterable<Audio> audios,
  Iterable<Audio> libraryAudios,
) {
  final canonicalByPath = <String, Audio>{
    for (final audio in libraryAudios) audio.path: audio,
  };
  return audios
      .map((audio) => canonicalByPath[audio.path] ?? audio)
      .toList(growable: false);
}

@visibleForTesting
double calculateCueDisplayPosition({
  required Audio? audio,
  required double rawPosition,
  double? playerLength,
}) {
  if (audio == null || !audio.isCueTrack) return rawPosition;
  final startSec = (audio.cueStartMs ?? 0) / 1000.0;
  final localPosition = rawPosition - startSec;
  final trackLength = resolveCueTrackLength(
    audio: audio,
    playerLength: playerLength,
  );
  return localPosition.clamp(0.0, trackLength);
}

@visibleForTesting
double resolveCueTrackLength({
  required Audio? audio,
  double? playerLength,
}) {
  if (audio == null || !audio.isCueTrack) return playerLength ?? 0.0;
  final startSec = (audio.cueStartMs ?? 0) / 1000.0;
  final endSec = (audio.cueEndMs ?? 0) / 1000.0;
  final segmentLength = (endSec - startSec).clamp(0.0, double.infinity);
  if (segmentLength > 0) return segmentLength;
  if (audio.duration > 0) return audio.duration.toDouble();
  return playerLength ?? 0.0;
}

/// 鎾斁鐩稿叧鐘舵€佷笌鎺у埗鎺ュ彛锛屼究浜庢闈?UI 鍜屾祴璇曞叡鐢ㄣ€?
/// Playback state and controls shared by UI and tests.
abstract class PlaybackController extends ChangeNotifier {
  Audio? get nowPlaying;
  int get playlistIndex;
  ValueListenable<List<Audio>> get playlist;
  Stream<double> get positionStream;
  double get length;
  double get position;
  Stream<PlayerState> get playerStateStream;
  PlayerState get playerState;
  bool get isPlaying => playerState == PlayerState.playing;
  ValueNotifier<double> get volumeDspNotifier;
  double get volumeDsp;
  ValueNotifier<PlayMode> get playMode;
  ValueNotifier<bool> get shuffle;
  ValueListenable<List<double>> get audioSpectrum => _emptyAudioSpectrum;
  ValueListenable<bool> get wasapiExclusive => _defaultWasapiExclusive;

  void useExclusiveMode(bool exclusive) {}
  void setPlayMode(PlayMode playMode);
  void useShuffle(bool flag);
  void setVolumeDsp(double volume);
  void seek(double position);
  void start();
  void pause();
  void playAgain();
  void lastAudio();
  void nextAudio();
  void playIndexOfPlaylist(int audioIndex);
  void reorderPlaylist(int oldIndex, int newIndex);
  void removeAudioFromPlaylistByPath(String path);
}

/// 鍙€氱煡 now playing 鍙樻洿
class PlaybackService extends PlaybackController {
  final PlayService playService;
  late StreamSubscription _playerStateStreamSub;
  late StreamSubscription _smtcEventStreamSub;
  late StreamSubscription<double> _rawPositionStreamSub;
  final BassPlayer _player;
  final SmtcFlutter _smtc;
  final PlaybackPreference? _preferenceOverride;
  PlaybackPreference get _pref =>
      _preferenceOverride ?? AppPreference.instance.playbackPref;

  PlaybackService(
    this.playService, {
    BassPlayer? player,
    SmtcFlutter? smtc,
    PlaybackPreference? preferenceOverride,
  })  : _player = player ?? BassPlayer(),
        _smtc = smtc ?? SmtcFlutter(),
        _preferenceOverride = preferenceOverride {
    _playerStateStreamSub = playerStateStream.listen((event) {
      if (event == PlayerState.completed) {
        _autoNextAudio();
      }
    });

    _smtcEventStreamSub = _smtc.subscribeToControlEvents().listen((event) {
      switch (event) {
        case SMTCControlEvent.play:
          start();
          break;
        case SMTCControlEvent.pause:
          pause();
          break;
        case SMTCControlEvent.previous:
          lastAudio();
          break;
        case SMTCControlEvent.next:
          nextAudio();
          break;
        case SMTCControlEvent.unknown:
      }
    });

    _rawPositionStreamSub = _player.positionStream.listen(_handleRawPosition);
  }
  final _positionStreamController = StreamController<double>.broadcast();
  late final AudioSpectrumNotifier _audioSpectrum = AudioSpectrumNotifier(
    sample: _sampleAudioSpectrum,
  );
  bool _cueAutoNextTriggered = false;
  DateTime _lastSessionSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSmtcProgressMs = -1;
  DateTime _lastSmtcProgressUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _closeFuture;

  late final _wasapiExclusive = ValueNotifier(_player.wasapiExclusive);
  ValueNotifier<bool> get wasapiExclusive => _wasapiExclusive;

  late final _enableVolumeLeveling = ValueNotifier(_pref.enableVolumeLeveling);
  ValueNotifier<bool> get enableVolumeLeveling => _enableVolumeLeveling;

  late final _volumeLevelingPreampDb =
      ValueNotifier(_pref.volumeLevelingPreampDb);
  ValueNotifier<double> get volumeLevelingPreampDb => _volumeLevelingPreampDb;

  late final _volumeDsp = ValueNotifier(_pref.volumeDsp);
  ValueNotifier<double> get volumeDspNotifier => _volumeDsp;

  @override
  ValueListenable<List<double>> get audioSpectrum => _audioSpectrum;

  List<double> _sampleAudioSpectrum() {
    if (nowPlaying == null || playerState != PlayerState.playing) {
      return const <double>[];
    }
    return _player.sampleFft(bins: audioSpectrumBinCount);
  }

  /// 独占模式
  void useExclusiveMode(bool exclusive) {
    if (_player.useExclusiveMode(exclusive)) {
      _wasapiExclusive.value = exclusive;
      if (exclusive) _audioSpectrum.decayToSilence();
      _applyOutputVolume(nowPlaying);
    }
  }

  Audio? nowPlaying;

  int? _playlistIndex;
  int get playlistIndex => _playlistIndex ?? 0;

  final ValueNotifier<List<Audio>> playlist = ValueNotifier([]);
  List<Audio> _playlistBackup = [];
  int? _lastManualRandomSourceIndex;
  final List<int> _playbackHistory = [];
  bool _isNavigatingHistory = false;

  late final _playMode = ValueNotifier(_pref.playMode);
  ValueNotifier<PlayMode> get playMode => _playMode;

  void setPlayMode(PlayMode playMode) {
    if (this.playMode.value == playMode) return;
    this.playMode.value = playMode;
    _pref.playMode = playMode;
    _rememberPlaybackSession(save: true);
  }

  late final _shuffle = ValueNotifier(_pref.shuffle);
  ValueNotifier<bool> get shuffle => _shuffle;

  void _applyShuffleState(bool flag) {
    if (flag == shuffle.value) return;

    if (nowPlaying != null) {
      if (flag) {
        if (_playlistBackup.isEmpty) {
          _playlistBackup = List<Audio>.from(playlist.value);
        }
        final currentAudio = nowPlaying!;
        final remaining = List<Audio>.from(playlist.value)
          ..remove(currentAudio);
        remaining.shuffle();
        playlist.value = [currentAudio, ...remaining];
        _playlistIndex = 0;
      } else {
        final restored = _playlistBackup.isEmpty
            ? List<Audio>.from(playlist.value)
            : List<Audio>.from(_playlistBackup);
        playlist.value = restored;
        _playlistIndex = playlist.value.indexOf(nowPlaying!);
      }
    }

    shuffle.value = flag;
  }

  double _resolveNowPlayingLength() => resolveCueTrackLength(
        audio: nowPlaying,
        playerLength: _player.length,
      );

  double _toDisplayPosition(double rawPosition) => calculateCueDisplayPosition(
        audio: nowPlaying,
        rawPosition: rawPosition,
        playerLength: _player.length,
      );

  bool _shouldAutoNextCue(double rawPosition) {
    final audio = nowPlaying;
    if (audio == null || !audio.isCueTrack) return false;
    final cueEndMs = audio.cueEndMs;
    if (cueEndMs == null) return false;
    return rawPosition >= (cueEndMs / 1000.0) - 0.02;
  }

  void _handleCueSegmentCompleted() {
    final isForward = playMode.value == PlayMode.forward;
    final isLast = _playlistIndex != null &&
        playlist.value.isNotEmpty &&
        _playlistIndex! >= playlist.value.length - 1;
    if (isForward && isLast) {
      final cueEndSec = (nowPlaying?.cueEndMs ?? 0) / 1000.0;
      if (cueEndSec > 0) {
        _player.seek(cueEndSec);
      }
      pause();
      notifyListeners();
      return;
    }
    _autoNextAudio();
  }

  void _handleRawPosition(double rawPosition) {
    if (_metadataSuspended) return;
    if (_shouldAutoNextCue(rawPosition)) {
      if (!_cueAutoNextTriggered) {
        _cueAutoNextTriggered = true;
        _handleCueSegmentCompleted();
      }
      return;
    }

    _cueAutoNextTriggered = false;
    final displayPosition = _toDisplayPosition(rawPosition);
    _positionStreamController.add(displayPosition);
    _updateSmtcTimePropertiesThrottled((displayPosition * 1000).floor());
    _rememberPlaybackSessionThrottled();
  }

  void _updateSmtcTimePropertiesThrottled(int progressMs,
      {bool force = false}) {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastSmtcProgressUpdateAt).inMilliseconds;
    final diffMs = (progressMs - _lastSmtcProgressMs).abs();

    if (force || diffMs >= 1000 || (elapsedMs >= 250 && diffMs >= 200)) {
      _lastSmtcProgressMs = progressMs;
      _lastSmtcProgressUpdateAt = now;
      _smtc.updateTimeProperties(progress: progressMs);
    }
  }

  /// 在窗口从托盘/最小化状态恢复后补发一次播放与歌词快照。
  ///
  /// 该方法用于修正隐藏窗口期间可能错过的进度事件、歌词行事件和播放状态，
  /// 让顶部歌词、右侧歌词预览、详情页歌词滚动在恢复窗口后立即对齐当前播放
  /// 位置，而不是等待下一次自然歌词行变化。
  void resyncPlaybackSnapshot() {
    try {
      _player.resyncPlaybackSnapshot();
      _handleRawPosition(_player.position);
      _updateSmtcTimePropertiesThrottled(
        (_toDisplayPosition(_player.position) * 1000).floor(),
        force: true,
      );
      playService.lyricService.findCurrLyricLine();
      unawaited(_smtc.updateState(
        state: playerState == PlayerState.playing
            ? SMTCState.playing
            : SMTCState.paused,
      ));
    } catch (err) {
      LOGGER.e("[resync playback snapshot] $err");
    }
  }

  double get length => _resolveNowPlayingLength();

  double get position => _toDisplayPosition(_player.position);

  PlayerState get playerState => _player.playerState;

  double get volumeDsp => _pref.volumeDsp;

  double _resolveOutputVolumeDsp(Audio? audio) {
    final baseVolume = _pref.volumeDsp;
    if (!_pref.enableVolumeLeveling) return baseVolume;

    final gainDb = audio?.replayGainDb;
    if (gainDb == null) return baseVolume;

    final compensationDb = (-gainDb) + _pref.volumeLevelingPreampDb;
    final scale = math.pow(10.0, compensationDb / 20.0).toDouble();
    return (baseVolume * scale).clamp(0.05, 3.0);
  }

  void _applyOutputVolume(Audio? audio) {
    _player.setVolumeDsp(_resolveOutputVolumeDsp(audio));
  }

  Timer? _volumeSaveDebounce;

  void _scheduleVolumeSave() {
    _volumeSaveDebounce?.cancel();
    _volumeSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(AppPreference.instance.save());
    });
  }

  /// 修改解码时的音量（不影响 Windows 系统音量）
  void setVolumeDsp(double volume) {
    _pref.volumeDsp = volume;
    _volumeDsp.value = volume;
    _applyOutputVolume(nowPlaying);
    _scheduleVolumeSave();
  }

  void setEnableVolumeLeveling(bool enabled) {
    if (_pref.enableVolumeLeveling == enabled) return;
    _pref.enableVolumeLeveling = enabled;
    _enableVolumeLeveling.value = enabled;
    _applyOutputVolume(nowPlaying);
    _scheduleVolumeSave();
  }

  void setVolumeLevelingPreampDb(double preampDb) {
    final clipped = preampDb.clamp(-12.0, 12.0);
    _pref.volumeLevelingPreampDb = clipped;
    _volumeLevelingPreampDb.value = clipped;
    _applyOutputVolume(nowPlaying);
    _scheduleVolumeSave();
  }

  Stream<double> get positionStream => _positionStreamController.stream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// 两阶段提交播放事务（2-Phase Commit）：
  /// 1. 验证目标文件并初始化底层音频流（_player.setSource & _player.start）
  /// 2. 成功后正式提交 [_playlistIndex] 与 [nowPlaying] 状态并通知 UI
  /// 3. 失败时进行安全回滚或自动向后跳过，杜绝虚假播放
  void _loadAndPlay(
    int audioIndex,
    List<Audio> playlist, {
    bool isAutoNext = false,
    Set<int>? failedIndices,
  }) {
    _metadataPlaybackEpoch++;
    _metadataSuspended = false;
    if (audioIndex < 0 || audioIndex >= playlist.length) {
      return;
    }
    final targetAudio = playlist[audioIndex];
    final prevIndex = _playlistIndex;
    final prevNowPlaying = nowPlaying;
    if (!_isNavigatingHistory && prevIndex != null && prevIndex != audioIndex) {
      _playbackHistory.add(prevIndex);
      if (_playbackHistory.length > 50) {
        _playbackHistory.removeAt(0);
      }
    }

    try {
      _audioSpectrum.decayToSilence();
      _player.setSource(targetAudio.mediaPath);
      if (!_player.hasSource) {
        throw const FormatException("Source initialization failed");
      }

      // FLOW-04: 阶段 2 提前提交状态：确保在 seek 和 start 之前已挂载正确的当前分轨元数据与 cueEndMs，
      // 防止底层流启动后 33ms 进度轮询器误用旧分轨 cue 边界触发第 0 秒连环跳首。
      _playlistIndex = audioIndex;
      nowPlaying = targetAudio;
      _cueAutoNextTriggered = false;
      unawaited(targetAudio.cover);

      if (targetAudio.isCueTrack) {
        _player.seek((targetAudio.cueStartMs ?? 0) / 1000.0);
      }
      _applyOutputVolume(targetAudio);

      _player.start();
      if (!_player.hasSource) {
        throw const FormatException("Stream start failed");
      }

      try {
        playService.lyricService.updateLyric();
      } catch (lyricErr) {
        LOGGER.w("[load and play] lyric update failed: $lyricErr");
      }

      try {
        unawaited(PlayCountStore.instance.increase(nowPlaying!));
      } catch (_) {}

      notifyListeners();

      try {
        ThemeProvider.instance.applyThemeFromAudio(nowPlaying!);
      } catch (_) {}

      _smtc.updateState(state: SMTCState.playing);
      _smtc.updateDisplay(
        title: nowPlaying!.displayTitle,
        artist: nowPlaying!.displayArtist,
        album: nowPlaying!.displayAlbum,
        duration: (length * 1000).floor(),
        path: nowPlaying!.mediaPath,
      );
      _updateSmtcTimePropertiesThrottled(0, force: true);
      _rememberPlaybackSession(save: true);

      final loadedAudio = nowPlaying!;
      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;
        if (nowPlaying?.path != loadedAudio.path) return;

        playService.desktopLyricService
            .sendPlayerStateMessage(playerState == PlayerState.playing);
        playService.desktopLyricService.sendNowPlayingMessage(loadedAudio);
        playService.lyricService.refreshCurrentLyricLine();
      });
    } catch (err) {
      LOGGER.e("[load and play] $err");
      if (isAutoNext) {
        final failed = failedIndices ?? <int>{};
        failed.add(audioIndex);
        showTextOnSnackBar('无法播放 "${targetAudio.displayTitle}"，正在跳过...');
        _autoNextAudio(failedIndices: failed);
        return;
      }

      // 手动触发播放失败时保护现有状态不被污染；若底层流已破坏则安全复位为停止
      if (!_player.hasSource) {
        _playlistIndex = prevIndex;
        nowPlaying = prevNowPlaying;
        _cueAutoNextTriggered = false;
        _audioSpectrum.decayToSilence();
        _smtc.updateState(state: SMTCState.paused);
        unawaited(
          playService.desktopLyricService.canSendMessage.then((canSend) {
            if (!canSend) return;
            playService.desktopLyricService.sendPlayerStateMessage(false);
          }),
        );
      }
      showTextOnSnackBar(
        '无法播放 "${targetAudio.displayTitle}": 文件不存在或格式不支持',
      );
      notifyListeners();
    }
  }

  /// 鎾斁褰撳墠鎾斁鍒楄〃鐨勭鍑犻」锛屽彧鑳界敤鍦ㄦ挱鏀惧垪琛ㄧ晫闈?
  void playIndexOfPlaylist(int audioIndex) {
    _loadAndPlay(audioIndex, playlist.value);
  }

  /// 播放playlist[audioIndex]并设置播放列表为playlist
  void play(int audioIndex, List<Audio> playlist) {
    _playbackHistory.clear();
    if (shuffle.value) {
      this.playlist.value = List.from(playlist);
      final willPlay = this.playlist.value.removeAt(audioIndex);
      this.playlist.value.shuffle();
      this.playlist.value.insert(0, willPlay);
      _playlistBackup = List.from(playlist);
      _loadAndPlay(0, this.playlist.value);
    } else {
      this.playlist.value = List.from(playlist);
      _playlistBackup = List.from(playlist);
      _loadAndPlay(audioIndex, this.playlist.value);
    }
  }

  void shuffleAndPlay(List<Audio> audios) {
    _playbackHistory.clear();
    playlist.value = List.from(audios);
    playlist.value.shuffle();
    _playlistBackup = List.from(audios);

    _playMode.value = PlayMode.forward;
    _pref.playMode = PlayMode.forward;
    _pref.shuffle = true;
    shuffle.value = true;

    _loadAndPlay(0, playlist.value);
  }

  /// 下一首播放
  void addToNext(Audio audio) {
    if (_playlistIndex != null) {
      final updated = List<Audio>.from(playlist.value)
        ..insert(_playlistIndex! + 1, audio);
      playlist.value = updated;
      if (!shuffle.value) {
        _playlistBackup = List.from(updated);
      } else {
        final backup = List<Audio>.from(_playlistBackup);
        final backupIndex =
            nowPlaying != null ? backup.indexOf(nowPlaying!) : -1;
        if (backupIndex != -1) {
          backup.insert(backupIndex + 1, audio);
        } else {
          backup.add(audio);
        }
        _playlistBackup = backup;
      }
      _rememberPlaybackSession(save: true);
    }
  }

  /// 将歌曲追加到播放队列末尾；当前无播放内容时直接播放该歌曲。
  void addToQueue(Audio audio) {
    if (_playlistIndex == null) {
      play(0, [audio]);
      return;
    }
    final updated = List<Audio>.from(playlist.value)..add(audio);
    playlist.value = updated;
    if (!shuffle.value) {
      _playlistBackup = List<Audio>.from(updated);
    } else {
      _playlistBackup = List<Audio>.from(_playlistBackup)..add(audio);
    }
    _rememberPlaybackSession(save: true);
  }

  void useShuffle(bool flag) {
    if (flag == shuffle.value) return;

    _applyShuffleState(flag);
    _pref.shuffle = flag;
    _rememberPlaybackSession(save: true);
  }

  void _nextAudio_forward({Set<int>? failedIndices}) {
    final currentPlaylist = playlist.value;
    if (currentPlaylist.isEmpty) return;
    final failed = failedIndices ?? <int>{};

    int candidate = (_playlistIndex ?? -1) + 1;
    while (candidate < currentPlaylist.length && failed.contains(candidate)) {
      candidate++;
    }

    if (candidate < currentPlaylist.length) {
      _loadAndPlay(
        candidate,
        currentPlaylist,
        isAutoNext: true,
        failedIndices: failed,
      );
    } else {
      pause();
      if (failed.length >= currentPlaylist.length) {
        showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      }
      notifyListeners();
    }
  }

  void _nextAudio_loop({Set<int>? failedIndices}) {
    final currentPlaylist = playlist.value;
    if (currentPlaylist.isEmpty) return;
    final failed = failedIndices ?? <int>{};

    if (failed.length >= currentPlaylist.length) {
      pause();
      showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      notifyListeners();
      return;
    }

    int startIndex = _playlistIndex ?? -1;
    int newIndex = (startIndex + 1) % currentPlaylist.length;
    int attempts = 0;
    while (failed.contains(newIndex) && attempts < currentPlaylist.length) {
      newIndex = (newIndex + 1) % currentPlaylist.length;
      attempts++;
    }

    if (failed.contains(newIndex) || attempts >= currentPlaylist.length) {
      pause();
      showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      notifyListeners();
      return;
    }

    _loadAndPlay(
      newIndex,
      currentPlaylist,
      isAutoNext: failedIndices != null,
      failedIndices: failed,
    );
  }

  void _nextAudio_singleLoop({Set<int>? failedIndices}) {
    final currentPlaylist = playlist.value;
    if (currentPlaylist.isEmpty) return;
    final failed = failedIndices ?? <int>{};

    if (failed.length >= currentPlaylist.length) {
      pause();
      showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      notifyListeners();
      return;
    }

    final currentIndex = _playlistIndex ?? 0;
    if (failed.contains(currentIndex)) {
      int nextIndex = (currentIndex + 1) % currentPlaylist.length;
      int attempts = 0;
      while (failed.contains(nextIndex) && attempts < currentPlaylist.length) {
        nextIndex = (nextIndex + 1) % currentPlaylist.length;
        attempts++;
      }
      if (failed.contains(nextIndex) || attempts >= currentPlaylist.length) {
        pause();
        showTextOnSnackBar("播放列表中的所有曲目均无法播放");
        notifyListeners();
        return;
      }
      _loadAndPlay(
        nextIndex,
        currentPlaylist,
        isAutoNext: true,
        failedIndices: failed,
      );
      return;
    }

    _loadAndPlay(
      currentIndex,
      currentPlaylist,
      isAutoNext: failedIndices != null,
      failedIndices: failed,
    );
  }

  void _autoNextAudio({Set<int>? failedIndices}) {
    final currentPlaylist = playlist.value;
    final failed = failedIndices ?? <int>{};
    if (currentPlaylist.isEmpty || failed.length >= currentPlaylist.length) {
      pause();
      showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      notifyListeners();
      return;
    }

    if (playMode.value == PlayMode.singleLoop) {
      _nextAudio_singleLoop(failedIndices: failed);
      return;
    }

    if (shuffle.value) {
      _nextAudio_shuffleRandom(failedIndices: failed);
      return;
    }

    switch (playMode.value) {
      case PlayMode.forward:
        _nextAudio_forward(failedIndices: failed);
        break;
      case PlayMode.loop:
        _nextAudio_loop(failedIndices: failed);
        break;
      case PlayMode.singleLoop:
        _nextAudio_singleLoop(failedIndices: failed);
        break;
    }
  }

  @visibleForTesting
  void autoNextAudio({Set<int>? failedIndices}) =>
      _autoNextAudio(failedIndices: failedIndices);

  void _nextAudio_shuffleRandom({Set<int>? failedIndices}) {
    final currentPlaylist = playlist.value;
    if (currentPlaylist.isEmpty) return;
    final failed = failedIndices ?? <int>{};

    if (failed.length >= currentPlaylist.length) {
      pause();
      showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      notifyListeners();
      return;
    }

    final currentIndex = _playlistIndex;
    final allIndexes = List<int>.generate(currentPlaylist.length, (i) => i);

    final blocked = <int>{
      ...failed,
      if (currentIndex != null) currentIndex,
    };
    if (currentPlaylist.length > 2 && _lastManualRandomSourceIndex != null) {
      blocked.add(_lastManualRandomSourceIndex!);
    }

    var candidates = allIndexes.where((i) => !blocked.contains(i)).toList();
    if (candidates.isEmpty && currentPlaylist.length > 1) {
      candidates = allIndexes
          .where((i) => !failed.contains(i) && i != currentIndex)
          .toList();
    }
    if (candidates.isEmpty) {
      candidates = allIndexes.where((i) => !failed.contains(i)).toList();
    }
    if (candidates.isEmpty) {
      pause();
      showTextOnSnackBar("播放列表中的所有曲目均无法播放");
      notifyListeners();
      return;
    }

    final randomIndex = candidates[math.Random().nextInt(candidates.length)];
    if (currentIndex != null) {
      _lastManualRandomSourceIndex = currentIndex;
    }
    _loadAndPlay(
      randomIndex,
      currentPlaylist,
      isAutoNext: failedIndices != null,
      failedIndices: failed,
    );
  }

  /// 手动下一曲时默认循环播放列表
  void nextAudio() {
    if (shuffle.value) {
      _nextAudio_shuffleRandom();
      return;
    }
    _lastManualRandomSourceIndex = null;
    _nextAudio_loop();
  }

  /// 手动上一曲时默认循环播放列表
  void lastAudio() {
    if (shuffle.value) {
      while (_playbackHistory.isNotEmpty) {
        final prevIndex = _playbackHistory.removeLast();
        if (prevIndex >= 0 &&
            prevIndex < playlist.value.length &&
            prevIndex != _playlistIndex) {
          _isNavigatingHistory = true;
          try {
            _loadAndPlay(prevIndex, playlist.value);
          } finally {
            _isNavigatingHistory = false;
          }
          return;
        }
      }
      _nextAudio_shuffleRandom();
      return;
    }
    _lastManualRandomSourceIndex = null;
    if (_playlistIndex == null) return;

    int newIndex = _playlistIndex! - 1;
    if (newIndex < 0) {
      newIndex = playlist.value.length - 1;
    }

    _loadAndPlay(newIndex, playlist.value);
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    if (playlist.value.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= playlist.value.length) return;
    if (newIndex < 0 || newIndex >= playlist.value.length) return;
    if (oldIndex == newIndex) return;

    final updated = List<Audio>.from(playlist.value);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    playlist.value = updated;

    if (!shuffle.value) {
      _playlistBackup = List.from(updated);
    }

    if (nowPlaying != null) {
      _playlistIndex =
          updated.indexWhere((audio) => audio.path == nowPlaying!.path);
    }

    _rememberPlaybackSession(save: true);
    notifyListeners();
  }

  void removeAudioFromPlaylistByPath(String path) {
    if (playlist.value.isEmpty) return;
    final updated = playlist.value
        .where((audio) => audio.path != path)
        .toList(growable: false);
    if (updated.length == playlist.value.length) return;

    final removedCurrent = nowPlaying?.path == path;
    final oldCurrentPath = nowPlaying?.path;

    playlist.value = updated;
    if (!shuffle.value) {
      _playlistBackup = List.from(updated);
    } else {
      _playlistBackup.removeWhere((audio) => audio.path == path);
    }

    if (updated.isEmpty) {
      _metadataPlaybackEpoch++;
      _metadataSuspended = false;
      nowPlaying = null;
      _playlistIndex = null;
      _cueAutoNextTriggered = false;
      _rememberPlaybackSession(save: true);
      pause();
      notifyListeners();
      return;
    }

    if (!removedCurrent) {
      final index = updated.indexWhere((audio) => audio.path == oldCurrentPath);
      _playlistIndex = index < 0 ? 0 : index;
      _rememberPlaybackSession(save: true);
      notifyListeners();
      return;
    }

    int targetIndex = playlistIndex;
    if (targetIndex >= updated.length) {
      targetIndex = updated.length - 1;
    }
    _loadAndPlay(targetIndex, updated);
  }

  /// 暂停
  void pause() {
    if (_metadataSuspended) {
      _metadataResumePlaying = false;
      return;
    }
    try {
      if (playerState == PlayerState.playing) {
        _player.pause();
      }
      _smtc.updateState(state: SMTCState.paused);
      _updateSmtcTimePropertiesThrottled(
        (position * 1000).floor(),
        force: true,
      );
      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;

        playService.desktopLyricService.sendPlayerStateMessage(false);
      });
      _rememberPlaybackSession(save: true);
    } catch (err) {
      LOGGER.e("[pause] $err");
      showTextOnSnackBar(err.toString());
    }
  }

  /// 恢复播放
  void start() {
    if (_metadataSuspended) {
      _metadataResumePlaying = true;
      return;
    }
    try {
      if (nowPlaying == null) {
        final audios = AudioLibrary.instance.audioCollection;
        if (audios.isEmpty) return;
        play(0, audios);
        return;
      }

      if (!_player.hasSource) {
        try {
          _player.setSource(nowPlaying!.mediaPath);
          final restorePosition =
              _pref.lastPosition.clamp(0.0, length).toDouble();
          if (nowPlaying!.isCueTrack) {
            final cueStartSec = (nowPlaying!.cueStartMs ?? 0) / 1000.0;
            _player.seek(cueStartSec + restorePosition);
          } else {
            _player.seek(restorePosition);
          }
          _applyOutputVolume(nowPlaying);
        } catch (reloadErr) {
          LOGGER.e("[start reload source]: $reloadErr");
          showTextOnSnackBar(
            '无法播放 "${nowPlaying!.displayTitle}": 文件不存在或格式不支持',
          );
          notifyListeners();
          return;
        }
      }

      if (!_player.hasSource) {
        return;
      }

      _player.start();
      if (!_player.hasSource) {
        return;
      }

      _smtc.updateState(state: SMTCState.playing);
      _updateSmtcTimePropertiesThrottled(
        (position * 1000).floor(),
        force: true,
      );
      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;

        playService.desktopLyricService.sendPlayerStateMessage(true);
      });
      _rememberPlaybackSession(save: true);
    } catch (err) {
      LOGGER.e("[start]: $err");
      showTextOnSnackBar(err.toString());
    }
  }

  /// 鍐嶆鎾斁銆傚湪椤哄簭鎾斁瀹屾渶鍚庝竴鏇叉椂鍐嶆鎸夋挱鏀炬椂浣跨敤銆?
  /// 涓?[start] 鐨勫樊鍒湪浜庡畠浼氶€氱煡閲嶇粯缁勪欢
  void playAgain() => _nextAudio_singleLoop();

  int nowPlayingRevision = 0;

  /// 外部修改了当前播放歌曲的标签/封面后调用，通知 UI 刷新
  void refreshNowPlaying({bool forceNewInstance = true}) {
    final original = nowPlaying;
    if (original != null) {
      final Audio audio =
          forceNewInstance ? Audio.fromMap(original.toMap()) : original;
      nowPlaying = audio;
      nowPlayingRevision++;
      _smtc.updateDisplay(
        title: audio.displayTitle,
        artist: audio.displayArtist,
        album: audio.displayAlbum,
        duration: (length * 1000).floor(),
        path: audio.mediaPath,
      );
      ThemeProvider.instance.applyThemeFromAudio(audio);
      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;
        if (nowPlaying?.path != audio.path) return;
        playService.desktopLyricService.sendNowPlayingMessage(audio);
      });
    }
    notifyListeners();
  }

  int _metadataPlaybackEpoch = 0;
  bool _metadataSuspended = false;
  bool _metadataResumePlaying = false;

  /// Release only the matching physical file during the short replacement step.
  /// Restoration bypasses _loadAndPlay so editing never counts as a new play.
  Future<T> withMetadataFileReleased<T>(
    Audio target,
    Future<T> Function() commit, {
    required void Function(Object error) onRestoreError,
  }) async {
    final current = nowPlaying;
    if (current == null ||
        current.mediaPath.toLowerCase() != target.mediaPath.toLowerCase()) {
      return commit();
    }
    final epoch = ++_metadataPlaybackEpoch;
    final rawPosition = _player.position;
    _metadataResumePlaying = playerState == PlayerState.playing;
    _metadataSuspended = true;
    try {
      _player.freeFStream();
      return await commit();
    } finally {
      if (epoch == _metadataPlaybackEpoch && nowPlaying?.path == current.path) {
        _metadataSuspended = false;
        try {
          _player.setSource(current.mediaPath);
          _player.seek(rawPosition);
          _applyOutputVolume(current);
          if (_metadataResumePlaying) _player.start();
          _smtc.updateState(
              state: _metadataResumePlaying
                  ? SMTCState.playing
                  : SMTCState.paused);
          _rememberPlaybackSession(save: true);
          notifyListeners();
        } catch (error) {
          onRestoreError(error);
        }
      }
    }
  }

  void reconcileLibraryReferences() {
    final libraryAudios = AudioLibrary.instance.audioCollection;
    final canonicalByPath = <String, Audio>{
      for (final audio in libraryAudios) audio.path: audio,
    };
    final currentPath = nowPlaying?.path;

    playlist.value = rebindAudiosToLibrary(playlist.value, libraryAudios);
    _playlistBackup = rebindAudiosToLibrary(_playlistBackup, libraryAudios);
    if (currentPath != null) {
      nowPlaying = canonicalByPath[currentPath] ?? nowPlaying;
      final reboundIndex =
          playlist.value.indexWhere((audio) => audio.path == currentPath);
      if (reboundIndex >= 0) _playlistIndex = reboundIndex;
    }

    _rememberPlaybackSession(save: true);
    refreshNowPlaying();
  }

  void seek(double position) {
    if (_metadataSuspended) return;
    final audio = nowPlaying;
    if (audio != null && audio.isCueTrack) {
      final cueStartSec = (audio.cueStartMs ?? 0) / 1000.0;
      _cueAutoNextTriggered = false;
      _player.seek(cueStartSec + position.clamp(0.0, length));
    } else {
      _player.seek(position);
    }
    playService.lyricService.findCurrLyricLine();
    _rememberPlaybackSession(save: true);
    _updateSmtcTimePropertiesThrottled(
      (this.position * 1000).floor(),
      force: true,
    );
  }

  void rememberPlaybackSession(
      {bool save = false, bool updatePlaylist = true}) {
    _rememberPlaybackSession(save: save, updatePlaylist: updatePlaylist);
  }

  void _rememberPlaybackSession({
    bool save = false,
    bool updatePlaylist = true,
  }) {
    final audio = nowPlaying;
    final curPos = audio == null ? 0.0 : position.clamp(0.0, length).toDouble();
    final curIndex = _playlistIndex ?? 0;

    _pref
      ..lastAudioPath = audio?.path
      ..lastPlaylistIndex = curIndex
      ..lastPosition = curPos
      ..shuffle = shuffle.value;

    if (updatePlaylist || save) {
      _pref.lastPlaylistPaths =
          playlist.value.map((audio) => audio.path).toList(growable: false);
    }

    if (save) {
      unawaited(AppPreference.instance.save());
      unawaited(PlaybackSessionStore.saveSnapshot(
        audioPath: audio?.path,
        playlistIndex: curIndex,
        position: curPos,
      ));
    }
  }

  void _rememberPlaybackSessionThrottled() {
    if (nowPlaying == null) return;
    _rememberPlaybackSession(updatePlaylist: false);
    final now = DateTime.now();
    if (now.difference(_lastSessionSaveAt).inSeconds < 5) return;
    _lastSessionSaveAt = now;

    // 关键优化：仅保存轻量级进度快照 (< 100 字节)，彻底解耦全量偏好序列化与落盘
    unawaited(PlaybackSessionStore.saveSnapshot(
      audioPath: nowPlaying?.path,
      playlistIndex: _playlistIndex ?? 0,
      position: position.clamp(0.0, length).toDouble(),
    ));
  }

  Future<void> restoreLastSession() async {
    final snapshot = await PlaybackSessionStore.readSnapshot();
    final lastAudioPath = snapshot?.audioPath ?? _pref.lastAudioPath;
    if (lastAudioPath == null || lastAudioPath.isEmpty) return;

    final allAudios = AudioLibrary.instance.audioCollection;
    if (allAudios.isEmpty) return;

    final byPath = <String, Audio>{
      for (final audio in allAudios) audio.path: audio,
    };
    final restoredPlaylist = _pref.lastPlaylistPaths
        .map((path) => byPath[path])
        .whereType<Audio>()
        .toList();

    if (restoredPlaylist.isEmpty) {
      restoredPlaylist.addAll(allAudios);
    }

    var index =
        restoredPlaylist.indexWhere((audio) => audio.path == lastAudioPath);
    if (index < 0) {
      final fallbackAudio = byPath[lastAudioPath];
      if (fallbackAudio == null) return;
      restoredPlaylist.insert(0, fallbackAudio);
      index = 0;
    }

    final targetAudio = restoredPlaylist[index];
    try {
      playlist.value = List<Audio>.from(restoredPlaylist);
      _playlistBackup = List<Audio>.from(restoredPlaylist);

      _player.setSource(targetAudio.mediaPath);
      if (!_player.hasSource) {
        throw const FormatException("Source initialization failed");
      }

      _playlistIndex = index;
      nowPlaying = targetAudio;
      _cueAutoNextTriggered = false;

      final sessionPosition = snapshot?.position ?? _pref.lastPosition;
      final restorePosition = sessionPosition.clamp(0.0, length).toDouble();
      if (nowPlaying!.isCueTrack) {
        final cueStartSec = (nowPlaying!.cueStartMs ?? 0) / 1000.0;
        _player.seek(cueStartSec + restorePosition);
      } else {
        _player.seek(restorePosition);
      }
      _applyOutputVolume(nowPlaying);
      try {
        playService.lyricService.updateLyric();
      } catch (lyricErr) {
        LOGGER.w("[restore playback session] lyric update failed: $lyricErr");
      }
      notifyListeners();
      try {
        ThemeProvider.instance.applyThemeFromAudio(nowPlaying!);
      } catch (_) {}

      _smtc.updateState(state: SMTCState.paused);
      _smtc.updateDisplay(
        title: nowPlaying!.displayTitle,
        artist: nowPlaying!.displayArtist,
        album: nowPlaying!.displayAlbum,
        duration: (length * 1000).floor(),
        path: nowPlaying!.mediaPath,
      );
      _updateSmtcTimePropertiesThrottled(
        (position * 1000).floor(),
        force: true,
      );
    } catch (err, trace) {
      LOGGER.e("[restore playback session] $err", stackTrace: trace);
      _playlistIndex = null;
      _metadataPlaybackEpoch++;
      _metadataSuspended = false;
      nowPlaying = null;
      _cueAutoNextTriggered = false;
      notifyListeners();
    }
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _volumeSaveDebounce?.cancel();
    _rememberPlaybackSession(save: true);
    _audioSpectrum.dispose();
    _wasapiExclusive.dispose();
    _enableVolumeLeveling.dispose();
    _volumeLevelingPreampDb.dispose();
    _volumeDsp.dispose();
    playlist.dispose();
    _playMode.dispose();
    _shuffle.dispose();
    await Future.wait([
      _playerStateStreamSub.cancel(),
      _smtcEventStreamSub.cancel(),
      _rawPositionStreamSub.cancel(),
    ]);
    await _positionStreamController.close();
    try {
      _player.free();
    } catch (err, trace) {
      LOGGER.e('[shutdown] BASS 资源释放失败: $err', stackTrace: trace);
    }
    await _smtc.close();
    super.dispose();
  }
}
