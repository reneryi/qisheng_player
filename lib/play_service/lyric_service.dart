// ignore_for_file: annotate_overrides

import 'dart:async';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:flutter/foundation.dart';

/// 歌词相关状态与行为接口，便于 UI 与测试注入。
abstract class LyricController extends ChangeNotifier {
  Future<Lyric?> get currLyricFuture;
  int get currentLyricLineIndex;
  Stream<int> get lyricLineStream;

  void findCurrLyricLine();
  void refreshCurrentLyricLine();
}

/// 只通知 lyric 变更
class LyricService extends LyricController {
  final PlaybackController _playbackService;
  final DesktopLyricController _desktopLyricService;
  final Future<Lyric?> Function(Audio audio, bool localFirst) _getDefaultLyric;
  final Future<Lyric?> Function(Audio audio) _getLocalLyric;
  final Future<Lyric?> Function(Audio audio) _getOnlineDefaultLyric;

  late StreamSubscription _positionStreamSubscription;
  int _lyricLoadVersion = 0;
  Future<void>? _closeFuture;
  bool _disposed = false;

  LyricService(PlayService playService)
      : _playbackService = playService.playbackService,
        _desktopLyricService = playService.desktopLyricService,
        _getDefaultLyric = _loadDefaultLyric,
        _getLocalLyric = Lrc.fromAudioPath,
        _getOnlineDefaultLyric = getMostMatchedLyric {
    _listenToPositionStream();
  }

  @visibleForTesting
  LyricService.forTest({
    required PlaybackController playbackService,
    required DesktopLyricController desktopLyricService,
    required Future<Lyric?> Function(Audio audio, bool localFirst)
        getDefaultLyric,
    Future<Lyric?> Function(Audio audio)? getLocalLyric,
    Future<Lyric?> Function(Audio audio)? getOnlineDefaultLyric,
  })  : _playbackService = playbackService,
        _desktopLyricService = desktopLyricService,
        _getDefaultLyric = getDefaultLyric,
        _getLocalLyric = getLocalLyric ?? Lrc.fromAudioPath,
        _getOnlineDefaultLyric = getOnlineDefaultLyric ?? getMostMatchedLyric {
    _listenToPositionStream();
  }

  void _listenToPositionStream() {
    _positionStreamSubscription = _playbackService.positionStream.listen((pos) {
      final lyric = _currentLyric;
      if (lyric == null || lyric.lines.isEmpty) return;
      final version = _lyricLoadVersion;

      // 播放位置可能因为托盘隐藏恢复、循环播放、设备恢复或底层跳变而
      // 回退/跳跃。这里不能只向前推进，否则到达最后一句后就无法纠正，
      // 会导致所有歌词视图长期停在旧行或最后一句。
      final nextLyricLine = _resolveNextLyricLine(lyric, pos);
      if (_nextLyricLine != nextLyricLine) {
        _nextLyricLine = nextLyricLine;
        _notifyCurrentLyricLine(lyric, version: version);
      }
    });
  }

  static Future<Lyric?> _loadDefaultLyric(
    Audio audio,
    bool localFirst,
  ) async {
    if (audio.isCueTrack) {
      return Lrc.fromAudioPath(audio);
    }

    if (localFirst) {
      return (await Lrc.fromAudioPath(audio)) ??
          (await getMostMatchedLyric(audio));
    }
    return (await getMostMatchedLyric(audio)) ??
        (await Lrc.fromAudioPath(audio));
  }

  Audio? _getNowPlaying() => _playbackService.nowPlaying;

  /// 同步持有的当前歌词对象引用，避免每 50ms 频繁挂载 microtask 堆积
  Lyric? _currentLyric;
  Lyric? get currentLyric => _currentLyric;

  /// 供 widget 使用
  Future<Lyric?> currLyricFuture = Future.value(null);

  /// 下一行歌词
  int _nextLyricLine = 0;

  int get currentLyricLineIndex {
    final current = _nextLyricLine - 1;
    return current < 0 ? 0 : current;
  }

  int _resolveNextLyricLine(Lyric lyric, double position) {
    final lines = lyric.lines;
    if (lines.isEmpty) return 0;

    final k = _nextLyricLine;
    final n = lines.length;

    // 1. O(1) 快路径：仍处于当前歌词行时间区间内（命中绝大多数 20Hz 播放帧）
    if (k == 0) {
      if (position < lines[0].start.inMilliseconds / 1000.0) return 0;
      if (n == 1 || position < lines[1].start.inMilliseconds / 1000.0) return 1;
    } else if (k < n) {
      final prevStart = lines[k - 1].start.inMilliseconds / 1000.0;
      final nextStart = lines[k].start.inMilliseconds / 1000.0;
      if (position >= prevStart && position < nextStart) {
        return k;
      }
      // 2. O(1) 快路径：正常播放单步推进到紧随其后的下一句
      if (position >= nextStart) {
        if (k + 1 == n ||
            position < lines[k + 1].start.inMilliseconds / 1000.0) {
          return k + 1;
        }
      }
    } else {
      // k == n，处于最后一行
      if (position >= lines[n - 1].start.inMilliseconds / 1000.0) {
        return n;
      }
    }

    // 3. O(log N) 二分回退：发生快进、倒带、进度拖拽或循环重播等跨越跳转时使用二分定位
    int low = 0;
    int high = n;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (lines[mid].start.inMilliseconds / 1000.0 > position) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  late final StreamController<int> _lyricLineStreamController =
      StreamController.broadcast(onListen: () {
    _lyricLineStreamController.add(currentLyricLineIndex);
  });

  Stream<int> get lyricLineStream => _lyricLineStreamController.stream;

  /// 重新计算歌词进行到第几行
  void findCurrLyricLine() {
    final version = _lyricLoadVersion;
    final lyric = _currentLyric;
    if (lyric != null) {
      _findAndNotifyCurrentLyricLine(lyric, version: version);
      return;
    }
    currLyricFuture.then((value) {
      if (version != _lyricLoadVersion) return;
      _findAndNotifyCurrentLyricLine(value, version: version);
    });
  }

  void _findAndNotifyCurrentLyricLine(
    Lyric? lyric, {
    required int version,
  }) {
    if (version != _lyricLoadVersion) return;
    _currentLyric = lyric;
    if (lyric == null) return;
    if (lyric.lines.isEmpty) return;

    _nextLyricLine = _resolveNextLyricLine(lyric, _playbackService.position);
    _notifyCurrentLyricLine(lyric, version: version);
  }

  void _notifyCurrentLyricLine(
    Lyric lyric, {
    required int version,
  }) {
    if (version != _lyricLoadVersion) return;
    if (lyric.lines.isEmpty) return;
    final currLineIndex =
        currentLyricLineIndex.clamp(0, lyric.lines.length - 1).toInt();
    _lyricLineStreamController.add(currLineIndex);

    _desktopLyricService.canSendMessage.then((canSend) {
      if (version != _lyricLoadVersion) return;
      if (!canSend) return;

      _desktopLyricService.sendLyricLineMessage(lyric.lines[currLineIndex]);
    });
  }

  void refreshCurrentLyricLine() {
    final version = _lyricLoadVersion;
    final lyric = _currentLyric;
    if (lyric != null) {
      _notifyCurrentLyricLine(lyric, version: version);
      return;
    }
    currLyricFuture.then((value) {
      if (version != _lyricLoadVersion) return;
      if (value == null) return;
      _notifyCurrentLyricLine(value, version: version);
    });
  }

  /// 根据默认歌词来源获取歌词：
  /// 1. 如果没有指定来源，按照现在的方式寻找歌词（本地优先或在线优先）
  /// 2. 如果指定来源，按照指定的来源获取
  void updateLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();
    final version = ++_lyricLoadVersion;
    _currentLyric = null;
    _nextLyricLine = 0;

    final lyricSource = LYRIC_SOURCES[nowPlaying.path];
    if (lyricSource != null) {
      if (lyricSource.source == LyricSourceType.local) {
        currLyricFuture = lyricSource.cachedText == null
            ? _getLocalLyric(nowPlaying)
            : Future.value(Lrc.fromLrcText(lyricSource.cachedText!, LrcSource.local));
      } else {
        currLyricFuture = getOnlineLyric(
          qqSongId: lyricSource.qqSongId,
          kugouSongHash: lyricSource.kugouSongHash,
          neteaseSongId: lyricSource.neteaseSongId,
        );
      }
    } else if (nowPlaying.isCueTrack) {
      currLyricFuture = _getLocalLyric(nowPlaying);
    } else {
      currLyricFuture =
          _getDefaultLyric(nowPlaying, AppSettings.instance.localLyricFirst);
    }

    currLyricFuture.then((value) {
      if (version != _lyricLoadVersion) return;
      _findAndNotifyCurrentLyricLine(value, version: version);
    });

    notifyListeners();
  }

  void useLocalLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();
    final version = ++_lyricLoadVersion;
    _currentLyric = null;
    _nextLyricLine = 0;

    currLyricFuture = _getLocalLyric(nowPlaying);
    currLyricFuture.then((value) {
      if (version != _lyricLoadVersion) return;
      _findAndNotifyCurrentLyricLine(value, version: version);
    });

    notifyListeners();
  }

  void useOnlineLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();
    final version = ++_lyricLoadVersion;
    _currentLyric = null;
    _nextLyricLine = 0;

    if (nowPlaying.isCueTrack) {
      currLyricFuture = _getLocalLyric(nowPlaying);
      currLyricFuture.then((value) {
        if (version != _lyricLoadVersion) return;
        _findAndNotifyCurrentLyricLine(value, version: version);
      });
      notifyListeners();
      return;
    }

    final lyricSource = LYRIC_SOURCES[nowPlaying.path];
    if (lyricSource != null && lyricSource.source != LyricSourceType.local) {
      currLyricFuture = getOnlineLyric(
        qqSongId: lyricSource.qqSongId,
        kugouSongHash: lyricSource.kugouSongHash,
        neteaseSongId: lyricSource.neteaseSongId,
      );
    } else {
      currLyricFuture = _getOnlineDefaultLyric(nowPlaying);
    }
    currLyricFuture.then((value) {
      if (version != _lyricLoadVersion) return;
      _findAndNotifyCurrentLyricLine(value, version: version);
    });

    notifyListeners();
  }

  void useSpecificLyric(Lyric lyric) {
    currLyricFuture.ignore();
    final version = ++_lyricLoadVersion;
    _currentLyric = lyric;
    _nextLyricLine = 0;

    currLyricFuture = Future.value(lyric);
    _findAndNotifyCurrentLyricLine(lyric, version: version);

    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lyricLoadVersion++;
    _closeFuture = Future.wait([
      _positionStreamSubscription.cancel(),
      _lyricLineStreamController.close(),
    ]);
    super.dispose();
  }

  Future<void> close() {
    dispose();
    return _closeFuture!;
  }
}
