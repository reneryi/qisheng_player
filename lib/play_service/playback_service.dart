// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:math' as math;

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/play_service/audio_spectrum.dart';
import 'package:qisheng_player/play_service/play_service.dart';
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
  ValueListenable<List<double>> get audioSpectrum => _emptyAudioSpectrum;

  void setPlayMode(PlayMode playMode);
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

  PlaybackService(this.playService) {
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

  final _player = BassPlayer();
  final _smtc = SmtcFlutter();
  final _pref = AppPreference.instance.playbackPref;
  final _positionStreamController = StreamController<double>.broadcast();
  late final AudioSpectrumNotifier _audioSpectrum = AudioSpectrumNotifier(
    sample: _sampleAudioSpectrum,
  );
  bool _cueAutoNextTriggered = false;
  DateTime _lastSessionSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
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

  late final _playMode = ValueNotifier(_pref.playMode);
  ValueNotifier<PlayMode> get playMode => _playMode;

  void setPlayMode(PlayMode playMode) {
    if (this.playMode.value == playMode) return;
    final shouldShuffle = playMode == PlayMode.loop;
    if (shouldShuffle != shuffle.value) {
      _applyShuffleState(shouldShuffle);
    }
    this.playMode.value = playMode;
    _pref.playMode = playMode;
    _rememberPlaybackSession(save: true);
  }

  late final _shuffle = ValueNotifier(_pref.playMode == PlayMode.loop);
  ValueNotifier<bool> get shuffle => _shuffle;

  void _applyShuffleState(bool flag) {
    if (flag == shuffle.value) return;

    if (nowPlaying != null) {
      if (flag) {
        playlist.value = List<Audio>.from(playlist.value);
        playlist.value.remove(nowPlaying!);
        playlist.value.shuffle();
        playlist.value.insert(0, nowPlaying!);
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

  double _resolveNowPlayingLength() {
    final audio = nowPlaying;
    if (audio == null || !audio.isCueTrack) return _player.length;

    final startSec = (audio.cueStartMs ?? 0) / 1000.0;
    final endSec = (audio.cueEndMs ?? 0) / 1000.0;
    final segmentLength = (endSec - startSec).clamp(0.0, double.infinity);
    if (segmentLength > 0) return segmentLength;
    if (audio.duration > 0) return audio.duration.toDouble();
    return _player.length;
  }

  double _toDisplayPosition(double rawPosition) {
    final audio = nowPlaying;
    if (audio == null || !audio.isCueTrack) return rawPosition;

    final startSec = (audio.cueStartMs ?? 0) / 1000.0;
    final localPosition = rawPosition - startSec;
    return localPosition.clamp(0.0, _resolveNowPlayingLength());
  }

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
    _smtc.updateTimeProperties(progress: (displayPosition * 1000).floor());
    _rememberPlaybackSessionThrottled();
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

  /// 修改解码时的音量（不影响 Windows 绯荤粺闊抽噺锛?
  void setVolumeDsp(double volume) {
    _pref.volumeDsp = volume;
    _volumeDsp.value = volume;
    _applyOutputVolume(nowPlaying);
  }

  void setEnableVolumeLeveling(bool enabled) {
    if (_pref.enableVolumeLeveling == enabled) return;
    _pref.enableVolumeLeveling = enabled;
    _enableVolumeLeveling.value = enabled;
    _applyOutputVolume(nowPlaying);
  }

  void setVolumeLevelingPreampDb(double preampDb) {
    final clipped = preampDb.clamp(-12.0, 12.0);
    _pref.volumeLevelingPreampDb = clipped;
    _volumeLevelingPreampDb.value = clipped;
    _applyOutputVolume(nowPlaying);
  }

  Stream<double> get positionStream => _positionStreamController.stream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// 1. 更新 [_playlistIndex] 一[audioIndex]
  /// 2. 更新 [nowPlaying] 一playlist[_nowPlayingIndex]
  /// 3. _bassPlayer.setSource
  /// 4. 设置解码音量
  /// 4. 鑾峰彇姝岃瘝 **灏?[_nextLyricLine] 置为0**
  /// 5. 播放
  /// 6. 通知并更新主题色
  void _loadAndPlay(int audioIndex, List<Audio> playlist) {
    try {
      _playlistIndex = audioIndex;
      nowPlaying = playlist[audioIndex];
      _cueAutoNextTriggered = false;
      _audioSpectrum.decayToSilence();
      _player.setSource(nowPlaying!.mediaPath);
      if (nowPlaying!.isCueTrack) {
        _player.seek((nowPlaying!.cueStartMs ?? 0) / 1000.0);
      }
      _applyOutputVolume(nowPlaying);

      playService.lyricService.updateLyric();

      _player.start();
      unawaited(PlayCountStore.instance.increase(nowPlaying!));
      notifyListeners();
      ThemeProvider.instance.applyThemeFromAudio(nowPlaying!);

      _smtc.updateState(state: SMTCState.playing);
      _smtc.updateDisplay(
        title: nowPlaying!.displayTitle,
        artist: nowPlaying!.displayArtist,
        album: nowPlaying!.displayAlbum,
        duration: (length * 1000).floor(),
        path: nowPlaying!.mediaPath,
      );
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
      showTextOnSnackBar(err.toString());
    }
  }

  /// 鎾斁褰撳墠鎾斁鍒楄〃鐨勭鍑犻」锛屽彧鑳界敤鍦ㄦ挱鏀惧垪琛ㄧ晫闈?
  void playIndexOfPlaylist(int audioIndex) {
    _loadAndPlay(audioIndex, playlist.value);
  }

  /// 播放playlist[audioIndex]并设置播放列表为playlist
  void play(int audioIndex, List<Audio> playlist) {
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
    playlist.value = List.from(audios);
    playlist.value.shuffle();
    _playlistBackup = List.from(audios);

    shuffle.value = true;

    _loadAndPlay(0, playlist.value);
  }

  /// 下一首播放
  void addToNext(Audio audio) {
    if (_playlistIndex != null) {
      final updated = List<Audio>.from(playlist.value)
        ..insert(_playlistIndex! + 1, audio);
      playlist.value = updated;
      _playlistBackup = List.from(updated);
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
    _playlistBackup = List<Audio>.from(updated);
    _rememberPlaybackSession(save: true);
  }

  void useShuffle(bool flag) {
    if (nowPlaying == null) return;
    if (flag == shuffle.value) return;

    _applyShuffleState(flag);
    _playMode.value = flag ? PlayMode.loop : PlayMode.forward;
    _pref.playMode = _playMode.value;
    _rememberPlaybackSession(save: true);
  }

  void _nextAudio_forward() {
    if (_playlistIndex == null) return;

    if (_playlistIndex! < playlist.value.length - 1) {
      _loadAndPlay(_playlistIndex! + 1, playlist.value);
    }
  }

  void _nextAudio_loop() {
    if (_playlistIndex == null) return;

    int newIndex = _playlistIndex! + 1;
    if (newIndex >= playlist.value.length) {
      newIndex = 0;
    }

    _loadAndPlay(newIndex, playlist.value);
  }

  void _nextAudio_singleLoop() {
    if (_playlistIndex == null) return;

    _loadAndPlay(_playlistIndex!, playlist.value);
  }

  void _autoNextAudio() {
    switch (playMode.value) {
      case PlayMode.forward:
        _nextAudio_forward();
        break;
      case PlayMode.loop:
        _nextAudio_shuffleRandom();
        break;
      case PlayMode.singleLoop:
        _nextAudio_singleLoop();
        break;
    }
  }

  void _nextAudio_shuffleRandom() {
    if (_playlistIndex == null || playlist.value.isEmpty) return;

    final currentIndex = _playlistIndex!;
    final allIndexes = List<int>.generate(playlist.value.length, (i) => i);

    // 闅忔満鍒囨瓕鏃堕粯璁や笉閲嶅褰撳墠姝屾洸锛涘垪琛ㄨ緝闀挎椂鍐嶉澶栭伩鍏嶁€滅珛鍒诲洖鍒颁笂娆℃潵婧愨€濄€?
    final blocked = <int>{currentIndex};
    if (playlist.value.length > 2 && _lastManualRandomSourceIndex != null) {
      blocked.add(_lastManualRandomSourceIndex!);
    }

    var candidates = allIndexes.where((i) => !blocked.contains(i)).toList();
    if (candidates.isEmpty && playlist.value.length > 1) {
      candidates = allIndexes.where((i) => i != currentIndex).toList();
    }
    if (candidates.isEmpty) {
      _nextAudio_singleLoop();
      return;
    }

    final randomIndex = candidates[math.Random().nextInt(candidates.length)];
    _lastManualRandomSourceIndex = currentIndex;
    _loadAndPlay(randomIndex, playlist.value);
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
    try {
      _player.pause();
      _smtc.updateState(state: SMTCState.paused);
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
    try {
      if (nowPlaying == null) {
        final audios = AudioLibrary.instance.audioCollection;
        if (audios.isEmpty) return;
        play(0, audios);
        return;
      }
      _player.start();
      _smtc.updateState(state: SMTCState.playing);
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

  /// 外部修改了当前播放歌曲的标签/封面后调用，通知 UI 鍒锋柊
  void refreshNowPlaying() {
    final audio = nowPlaying;
    if (audio != null) {
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
  }

  void _rememberPlaybackSession({bool save = false}) {
    final audio = nowPlaying;
    _pref
      ..lastAudioPath = audio?.path
      ..lastPlaylistPaths =
          playlist.value.map((audio) => audio.path).toList(growable: false)
      ..lastPlaylistIndex = _playlistIndex ?? 0
      ..lastPosition =
          audio == null ? 0.0 : position.clamp(0.0, length).toDouble();

    if (save) {
      unawaited(AppPreference.instance.save());
    }
  }

  void _rememberPlaybackSessionThrottled() {
    if (nowPlaying == null) return;
    _rememberPlaybackSession();
    final now = DateTime.now();
    if (now.difference(_lastSessionSaveAt).inSeconds < 5) return;
    _lastSessionSaveAt = now;
    unawaited(AppPreference.instance.save());
  }

  Future<void> restoreLastSession() async {
    final lastAudioPath = _pref.lastAudioPath;
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

    try {
      playlist.value = List<Audio>.from(restoredPlaylist);
      _playlistBackup = List<Audio>.from(restoredPlaylist);
      _playlistIndex = index;
      nowPlaying = restoredPlaylist[index];
      _cueAutoNextTriggered = false;

      _player.setSource(nowPlaying!.mediaPath);
      final restorePosition = _pref.lastPosition.clamp(0.0, length).toDouble();
      if (nowPlaying!.isCueTrack) {
        final cueStartSec = (nowPlaying!.cueStartMs ?? 0) / 1000.0;
        _player.seek(cueStartSec + restorePosition);
      } else {
        _player.seek(restorePosition);
      }
      _applyOutputVolume(nowPlaying);
      playService.lyricService.updateLyric();
      notifyListeners();
      ThemeProvider.instance.applyThemeFromAudio(nowPlaying!);

      _smtc.updateState(state: SMTCState.paused);
      _smtc.updateDisplay(
        title: nowPlaying!.displayTitle,
        artist: nowPlaying!.displayArtist,
        album: nowPlaying!.displayAlbum,
        duration: (length * 1000).floor(),
        path: nowPlaying!.mediaPath,
      );
    } catch (err, trace) {
      LOGGER.e("[restore playback session] $err", stackTrace: trace);
    }
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _rememberPlaybackSession();
    _audioSpectrum.dispose();
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
