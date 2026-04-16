import 'dart:async';
import 'dart:math';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/lyric/lyric_source.dart';
import 'package:coriander_player/music_matcher.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/foundation.dart';

/// 只通知 lyric 变更
class LyricService extends ChangeNotifier {
  final PlayService playService;

  late StreamSubscription _positionStreamSubscription;
  LyricService(this.playService) {
    _positionStreamSubscription =
        playService.playbackService.positionStream.listen((pos) {
      currLyricFuture.then((value) {
        if (value == null) return;
        if (_nextLyricLine >= value.lines.length) return;
        final posInMs = (pos * 1000).round();
        bool changed = false;
        while (_nextLyricLine < value.lines.length &&
            posInMs > value.lines[_nextLyricLine].start.inMilliseconds) {
          _nextLyricLine += 1;
          changed = true;
        }
        if (changed) {
          _notifyCurrentLyricLine(value);
        }
      });
    });
  }

  Audio? _getNowPlaying() => playService.playbackService.nowPlaying;

  /// 供 widget 使用
  Future<Lyric?> currLyricFuture = Future.value(null);

  /// 下一行歌词
  int _nextLyricLine = 0;

  int get currentLyricLineIndex => max(_nextLyricLine - 1, 0);

  late final StreamController<int> _lyricLineStreamController =
      StreamController.broadcast(onListen: () {
    _lyricLineStreamController.add(_nextLyricLine);
  });

  Stream<int> get lyricLineStream => _lyricLineStreamController.stream;

  /// 重新计算歌词进行到第几行
  void findCurrLyricLine() {
    currLyricFuture.then((value) {
      if (value == null) return;
      if (value.lines.isEmpty) return;

      final next = value.lines.indexWhere(
        (element) =>
            element.start.inMilliseconds / 1000 >
            playService.playbackService.position,
      );
      _nextLyricLine = next == -1 ? value.lines.length : next;
      _notifyCurrentLyricLine(value);
    });
  }

  void _notifyCurrentLyricLine(Lyric lyric) {
    if (lyric.lines.isEmpty) return;
    final currLineIndex =
        currentLyricLineIndex.clamp(0, lyric.lines.length - 1).toInt();
    _lyricLineStreamController.add(currLineIndex);

    playService.desktopLyricService.canSendMessage.then((canSend) {
      if (!canSend) return;

      playService.desktopLyricService
          .sendLyricLineMessage(lyric.lines[currLineIndex]);
    });
  }

  void refreshCurrentLyricLine() {
    currLyricFuture.then((value) {
      if (value == null) return;
      _notifyCurrentLyricLine(value);
    });
  }

  Future<Lyric?> _getLyricDefault(bool localFirst) async {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return Future.value(null);
    if (nowPlaying.isCueTrack) {
      return Lrc.fromAudioPath(nowPlaying);
    }

    if (localFirst) {
      return (await Lrc.fromAudioPath(nowPlaying)) ??
          (await getMostMatchedLyric(nowPlaying));
    }
    return (await getMostMatchedLyric(nowPlaying)) ??
        (await Lrc.fromAudioPath(nowPlaying));
  }

  /// 根据默认歌词来源获取歌词：
  /// 1. 如果没有指定来源，按照现在的方式寻找歌词（本地优先或在线优先）
  /// 2. 如果指定来源，按照指定的来源获取
  void updateLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();

    if (nowPlaying.isCueTrack) {
      currLyricFuture = Lrc.fromAudioPath(nowPlaying);
      currLyricFuture.then((value) {
        _nextLyricLine = 0;
        findCurrLyricLine();
      });
      notifyListeners();
      return;
    }

    final lyricSource = LYRIC_SOURCES[nowPlaying.path];
    if (lyricSource == null) {
      currLyricFuture = _getLyricDefault(AppSettings.instance.localLyricFirst);
    } else {
      if (lyricSource.source == LyricSourceType.local) {
        currLyricFuture = Lrc.fromAudioPath(nowPlaying);
      } else {
        currLyricFuture = getOnlineLyric(
          qqSongId: lyricSource.qqSongId,
          kugouSongHash: lyricSource.kugouSongHash,
          neteaseSongId: lyricSource.neteaseSongId,
        );
      }
    }

    currLyricFuture.then((value) {
      _nextLyricLine = 0;
      findCurrLyricLine();
    });

    notifyListeners();
  }

  void useLocalLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();

    currLyricFuture = Lrc.fromAudioPath(nowPlaying);
    currLyricFuture.then((value) {
      findCurrLyricLine();
    });

    notifyListeners();
  }

  void useOnlineLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();

    if (nowPlaying.isCueTrack) {
      currLyricFuture = Lrc.fromAudioPath(nowPlaying);
      currLyricFuture.then((value) {
        findCurrLyricLine();
      });
      notifyListeners();
      return;
    }

    currLyricFuture = getMostMatchedLyric(nowPlaying);
    currLyricFuture.then((value) {
      findCurrLyricLine();
    });

    notifyListeners();
  }

  void useSpecificLyric(Lyric lyric) {
    currLyricFuture.ignore();

    currLyricFuture = Future.value(lyric);
    currLyricFuture.then((value) {
      findCurrLyricLine();
    });

    notifyListeners();
  }

  @override
  void dispose() {
    _lyricLineStreamController.close();
    _positionStreamSubscription.cancel();
    super.dispose();
  }
}
