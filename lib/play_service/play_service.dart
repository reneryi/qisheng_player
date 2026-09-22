import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/utils.dart';

class PlayService {
  PlaybackService? _playbackService;
  LyricService? _lyricService;
  DesktopLyricService? _desktopLyricService;
  Future<void>? _closeFuture;

  PlaybackService get playbackService =>
      _playbackService ??= PlaybackService(this);
  PlaybackService? get existingPlaybackService => _playbackService;
  LyricService get lyricService => _lyricService ??= LyricService(this);
  DesktopLyricService get desktopLyricService =>
      _desktopLyricService ??= DesktopLyricService(this);
  DesktopLyricService? get existingDesktopLyricService => _desktopLyricService;

  PlayService._();

  static PlayService? _instance;
  static PlayService? get existingInstance => _instance;

  static PlayService get instance {
    _instance ??= PlayService._();
    return _instance!;
  }

  static void setPlaybackServiceForTesting(PlaybackService? service) {
    instance._playbackService = service;
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    // 1. 立即暂停播放并快照当前会话，确保彻底静音与会话保全
    try {
      _playbackService?.pause();
      _playbackService?.rememberPlaybackSession();
    } catch (err, trace) {
      LOGGER.e('[shutdown] 播放状态预存失败: $err', stackTrace: trace);
    }

    // 2. 并行释放播放器与各附属服务，消除串行超时等待
    await Future.wait([
      _closeSafely('播放器', () async => _playbackService?.close()),
      _closeSafely('歌词服务', () async => _lyricService?.close()),
      _closeSafely(
        '桌面歌词',
        () async => _desktopLyricService?.stopDesktopLyric(
          persistPreference: false,
        ),
      ),
    ]);
  }

  Future<void> _closeSafely(
    String label,
    Future<void>? Function() operation,
  ) async {
    try {
      final fut = operation();
      if (fut != null) {
        await fut.timeout(const Duration(milliseconds: 1500));
      }
    } catch (err, trace) {
      LOGGER.e('[shutdown] $label 释放失败: $err', stackTrace: trace);
    }
  }
}
