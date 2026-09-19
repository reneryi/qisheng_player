import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/utils.dart';

class PlayService {
  PlaybackService? _playbackService;
  LyricService? _lyricService;
  DesktopLyricService? _desktopLyricService;
  Future<void>? _closeFuture;

  PlaybackService get playbackService =>
      _playbackService ??= PlaybackService(this);
  LyricService get lyricService => _lyricService ??= LyricService(this);
  DesktopLyricService get desktopLyricService =>
      _desktopLyricService ??= DesktopLyricService(this);

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
    // 退出前优先快照当前播放状态并落盘，防止后续硬件或子进程释放耗时导致最新状态丢失
    try {
      _playbackService?.rememberPlaybackSession();
      await AppPreference.instance.save();
    } catch (err, trace) {
      LOGGER.e('[shutdown] 播放状态预存失败: $err', stackTrace: trace);
    }

    await _closeSafely('歌词服务', () async => _lyricService?.close());
    await _closeSafely(
      '桌面歌词',
      () async => _desktopLyricService?.stopDesktopLyric(
        persistPreference: false,
      ),
    );
    await _closeSafely('播放器', () async => _playbackService?.close());
    await AppPreference.instance.save();
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
