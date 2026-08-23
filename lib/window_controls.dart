import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_shutdown.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart'
    show ResizeEdge, WindowListener, windowManager;

class WindowBackdropModeResult {
  const WindowBackdropModeResult({
    required this.requestedMode,
    required this.appliedMode,
    required this.nativeBackdropSupported,
    required this.nativeApplySucceeded,
    this.fallbackReason,
  });

  final WindowBackdropMode requestedMode;
  final WindowBackdropMode appliedMode;
  final bool nativeBackdropSupported;
  final bool nativeApplySucceeded;
  final String? fallbackReason;

  bool get usesSimulatedBackdropOnly => !nativeApplySucceeded;

  /// The backdrop mode that Flutter can safely render against.
  ///
  /// A requested native material is only considered active after the platform
  /// confirms that it was applied. Until then, rendering falls back to
  /// `defaultGradient` so the desktop cannot leak through the window.
  WindowBackdropMode get effectiveRenderMode {
    if (requestedMode == WindowBackdropMode.meshFlow ||
        requestedMode == WindowBackdropMode.waterRipple ||
        requestedMode == WindowBackdropMode.prismaticGlass ||
        requestedMode == WindowBackdropMode.defaultGradient) {
      return requestedMode;
    }
    if (!nativeApplySucceeded) return WindowBackdropMode.defaultGradient;
    return switch (appliedMode) {
      WindowBackdropMode.micaAlt => WindowBackdropMode.micaAlt,
      WindowBackdropMode.acrylic => WindowBackdropMode.acrylic,
      _ => WindowBackdropMode.defaultGradient,
    };
  }

  static WindowBackdropModeResult fallback(
    WindowBackdropMode requestedMode, {
    WindowBackdropMode? appliedMode,
    bool nativeBackdropSupported = false,
    String? fallbackReason,
  }) {
    return WindowBackdropModeResult(
      requestedMode: requestedMode,
      appliedMode: appliedMode ?? WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: nativeBackdropSupported,
      nativeApplySucceeded: false,
      fallbackReason: fallbackReason,
    );
  }

  factory WindowBackdropModeResult.fromMap(
    Map<Object?, Object?> map,
    WindowBackdropMode requestedMode,
  ) {
    final requested =
        WindowBackdropMode.fromName(map['requestedMode'] as String?) ??
            requestedMode;
    final applied =
        WindowBackdropMode.fromName(map['appliedMode'] as String?) ??
            WindowBackdropMode.defaultGradient;
    final nativeBackdropSupported =
        (map['nativeBackdropSupported'] as bool?) ?? false;
    final nativeApplySucceeded =
        (map['nativeApplySucceeded'] as bool?) ?? false;
    final fallbackReason = map['fallbackReason'] as String?;

    return WindowBackdropModeResult(
      requestedMode: requested,
      appliedMode: applied,
      nativeBackdropSupported: nativeBackdropSupported,
      nativeApplySucceeded: nativeApplySucceeded,
      fallbackReason: fallbackReason?.isEmpty == true ? null : fallbackReason,
    );
  }
}

class WindowControls {
  static const MethodChannel _channel =
      MethodChannel("qisheng_player/window_controls");
  static bool _initialized = false;
  static WindowBackdropModeResult? _lastBackdropResult;
  static final _windowListener = _PlaybackWindowListener();
  static Timer? _resumeSyncTimer;
  static int _resumeSyncGeneration = 0;
  static final ValueNotifier<WindowLayoutMode> layoutMode =
      ValueNotifier(WindowLayoutMode.normal);

  static double get shellGap =>
      layoutMode.value == WindowLayoutMode.maximized ? 20 : 10;

  static Future<void> syncWindowLayoutMode() async {
    try {
      final fullscreen = await windowManager.isFullScreen();
      final maximized = await windowManager.isMaximized();
      final next = fullscreen
          ? WindowLayoutMode.fullscreen
          : maximized
              ? WindowLayoutMode.maximized
              : WindowLayoutMode.normal;
      if (layoutMode.value != next) layoutMode.value = next;
    } catch (_) {}
  }

  static WindowBackdropModeResult? get lastBackdropResult =>
      _lastBackdropResult;

  static Future<WindowBackdropModeResult> setWindowBackdropMode(
    WindowBackdropMode mode,
  ) async {
    // 软件渲染材质（默认对角渐变、弥散流彩、水波纹、琉璃透镜）在原生窗口层通知底层关闭 DWM 材质
    final bool isSoftwareMaterial =
        mode == WindowBackdropMode.defaultGradient ||
            mode == WindowBackdropMode.meshFlow ||
            mode == WindowBackdropMode.waterRipple ||
            mode == WindowBackdropMode.prismaticGlass;
    // 与 windows/runner/flutter_window.cpp 的 NormalizeBackdropMode /
    // BackdropTypeFromMode 保持一致的规范化字符串协议（小写）。
    final String nativeParam = switch (mode) {
      WindowBackdropMode.micaAlt => "micaalt",
      WindowBackdropMode.acrylic => "acrylic",
      _ => "none",
    };

    try {
      final appliedMode = await _channel.invokeMapMethod<Object?, Object?>(
        "set_window_backdrop_mode",
        {"mode": nativeParam},
      );
      var result = appliedMode == null
          ? WindowBackdropModeResult.fallback(
              mode,
              fallbackReason: 'empty_platform_response',
            )
          : WindowBackdropModeResult.fromMap(appliedMode, mode);

      if (isSoftwareMaterial) {
        result = WindowBackdropModeResult(
          requestedMode: mode,
          appliedMode: mode,
          nativeBackdropSupported: true,
          nativeApplySucceeded: true,
        );
      }

      _lastBackdropResult = result;
      return result;
    } on PlatformException {
      final result = WindowBackdropModeResult.fallback(
        mode,
        fallbackReason: 'platform_exception',
      );
      _lastBackdropResult = result;
      return result;
    }
  }

  static Future<Map<String, int>?> getDesktopLyricRect({int? pid}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        "get_desktop_lyric_rect",
        pid == null ? null : {"pid": pid},
      );
      if (result == null) return null;
      final left = (result["left"] as num?)?.round();
      final top = (result["top"] as num?)?.round();
      final width = (result["width"] as num?)?.round();
      final height = (result["height"] as num?)?.round();
      if (left == null || top == null || width == null || height == null) {
        return null;
      }
      return {
        "left": left,
        "top": top,
        "width": width,
        "height": height,
      };
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> setDesktopLyricPosition({
    int? pid,
    required int left,
    required int top,
  }) async {
    try {
      final payload = <String, Object>{
        "left": left,
        "top": top,
      };
      if (pid != null) {
        payload["pid"] = pid;
      }
      final moved = await _channel.invokeMethod<bool>(
        "set_desktop_lyric_position",
        payload,
      );
      return moved ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> setDesktopLyricProcess({
    int? pid,
    String? executablePath,
  }) async {
    try {
      final payload = <String, Object>{};
      if (pid != null) {
        payload['pid'] = pid;
      }
      if (executablePath != null && executablePath.isNotEmpty) {
        payload['executablePath'] = executablePath;
      }
      await _channel.invokeMethod<void>('set_desktop_lyric_process', payload);
    } on PlatformException {
      // Ignore cleanup/register failures during startup or shutdown.
    }
  }

  static Future<bool> startDragging() async {
    try {
      return await _channel.invokeMethod<bool>("start_dragging") ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> startResizing(ResizeEdge resizeEdge) async {
    try {
      return await _channel.invokeMethod<bool>(
            "start_resizing",
            {"resizeEdge": resizeEdge.name},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> _syncPlayingState(PlayerState state) async {
    final isPlaying = state == PlayerState.playing;
    try {
      await _channel.invokeMethod("set_playing", {"playing": isPlaying});
    } on PlatformException {
      // Ignore sync failures in early startup or during shutdown.
    }
  }

  static void resyncPlaybackAfterWindowActivated({String reason = 'window'}) {
    final generation = ++_resumeSyncGeneration;
    _resumeSyncTimer?.cancel();
    _resumeSyncTimer = Timer(const Duration(milliseconds: 80), () {
      _resyncPlaybackSnapshot(reason: reason);
      Timer(const Duration(milliseconds: 220), () {
        if (generation != _resumeSyncGeneration) return;
        _resyncPlaybackSnapshot(reason: '$reason delayed');
      });
    });
  }

  static void _resyncPlaybackSnapshot({required String reason}) {
    final playbackService = PlayService.instance.playbackService;
    playbackService.resyncPlaybackSnapshot();
    unawaited(_syncPlayingState(playbackService.playerState));
  }

  static bool _isExiting = false;

  /// 全局统一退出应用程序入口
  ///
  /// 执行完整的保存与释放流程，带有超时保护，并通过原生通道与窗口管理器彻底退出进程。
  static Future<void> exitApp() async {
    if (_isExiting) return;
    _isExiting = true;

    try {
      // 执行应用状态与播放器资源持久化与释放（限时 1.5 秒兜底）
      await appShutdownCoordinator
          .shutdown()
          .timeout(const Duration(milliseconds: 1500));
    } catch (err, trace) {
      LOGGER.e('[exitApp] 应用退出释放异常: $err', stackTrace: trace);
    }

    try {
      // 销毁窗口
      await windowManager.destroy();
    } catch (_) {}

    try {
      // 通知原生平台清理托盘图标并退出消息循环
      await _channel.invokeMethod("exit_app");
    } catch (_) {}

    // 保证 Dart 进程完全终止
    exit(0);
  }

  static Future<WindowBackdropModeResult> init() async {
    if (_initialized) {
      return _lastBackdropResult ??
          WindowBackdropModeResult.fallback(
            AppSettings.instance.windowBackdropMode,
            fallbackReason: 'initialization_pending',
          );
    }
    _initialized = true;

    final playbackService = PlayService.instance.playbackService;
    await windowManager.ensureInitialized();
    windowManager.addListener(_windowListener);
    await windowManager.setPreventClose(true);
    unawaited(syncWindowLayoutMode());
    final initialBackdropResult =
        await setWindowBackdropMode(AppSettings.instance.windowBackdropMode);
    unawaited(_syncPlayingState(playbackService.playerState));
    playbackService.playerStateStream.listen((state) {
      unawaited(_syncPlayingState(state));
    });

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "previous":
          playbackService.lastAudio();
          return;
        case "next":
          playbackService.nextAudio();
          return;
        case "play_pause":
          if (playbackService.playerState == PlayerState.playing) {
            playbackService.pause();
          } else if (playbackService.playerState == PlayerState.completed) {
            playbackService.playAgain();
          } else {
            playbackService.start();
          }
          return;
        case "window_restored_from_tray":
          resyncPlaybackAfterWindowActivated(reason: 'tray restore');
          return;
        case "exit_app":
          unawaited(exitApp());
          return;
      }
    });
    return initialBackdropResult;
  }
}

class _PlaybackWindowListener with WindowListener {
  @override
  void onWindowClose() {
    unawaited(WindowControls.exitApp());
  }

  @override
  void onWindowResize() {
    unawaited(WindowControls.syncWindowLayoutMode());
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  void onWindowFocus() {
    WindowControls.resyncPlaybackAfterWindowActivated(reason: 'window focus');
  }

  @override
  void onWindowRestore() {
    unawaited(WindowControls.syncWindowLayoutMode());
    WindowControls.resyncPlaybackAfterWindowActivated(reason: 'window restore');
  }

  @override
  void onWindowMaximize() => unawaited(WindowControls.syncWindowLayoutMode());

  @override
  void onWindowUnmaximize() => unawaited(WindowControls.syncWindowLayoutMode());

  @override
  void onWindowEnterFullScreen() =>
      unawaited(WindowControls.syncWindowLayoutMode());

  @override
  void onWindowLeaveFullScreen() =>
      unawaited(WindowControls.syncWindowLayoutMode());
}
