import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/utils.dart';

typedef ShutdownOperation = Future<void> Function();

class AppShutdownCoordinator {
  AppShutdownCoordinator({
    required ShutdownOperation closePlayer,
    required List<ShutdownOperation> persistState,
  })  : _closePlayer = closePlayer,
        _persistState = persistState;

  factory AppShutdownCoordinator.production() {
    return AppShutdownCoordinator(
      closePlayer: () async {
        final playService = PlayService.existingInstance;
        if (playService == null) {
          await AppPreference.instance.save();
          return;
        }
        await playService.close();
      },
      persistState: [
        AppSettings.instance.saveSettings,
        PlayCountStore.instance.save,
        savePlaylists,
      ],
    );
  }

  final ShutdownOperation _closePlayer;
  final List<ShutdownOperation> _persistState;
  Future<void>? _shutdownFuture;

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    await _runSafely('播放器资源', _closePlayer);
    await Future.wait([
      for (final operation in _persistState) _runSafely('应用状态', operation),
    ]);
  }

  Future<void> _runSafely(String label, ShutdownOperation operation) async {
    try {
      // 增加单项操作超时机制，防止某个服务释放或写入卡死导致整个应用无法退出
      await operation().timeout(const Duration(milliseconds: 1200));
    } catch (err, trace) {
      LOGGER.e('[shutdown] $label 保存或释放失败: $err', stackTrace: trace);
    }
  }
}

final appShutdownCoordinator = AppShutdownCoordinator.production();
