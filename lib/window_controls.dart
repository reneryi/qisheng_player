import 'dart:async';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:flutter/services.dart';
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

  static WindowBackdropModeResult fallback(
    WindowBackdropMode requestedMode, {
    WindowBackdropMode? appliedMode,
    bool nativeBackdropSupported = false,
    String? fallbackReason,
  }) {
    return WindowBackdropModeResult(
      requestedMode: requestedMode,
      appliedMode: appliedMode ?? WindowBackdropMode.none,
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
            WindowBackdropMode.none;
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

  static WindowBackdropModeResult? get lastBackdropResult =>
      _lastBackdropResult;

  static Future<WindowBackdropModeResult> setWindowBackdropMode(
    WindowBackdropMode mode,
  ) async {
    // 极光流体模式在原生窗口层不需要透明材质支持，因此在原生端使用 none 进行渲染
    final effectiveMode =
        mode == WindowBackdropMode.fluid ? WindowBackdropMode.none : mode;
    try {
      final appliedMode = await _channel.invokeMapMethod<Object?, Object?>(
        "set_window_backdrop_mode",
        {"mode": effectiveMode.name},
      );
      var result = appliedMode == null
          ? WindowBackdropModeResult.fallback(
              mode,
              fallbackReason: 'empty_platform_response',
            )
          : WindowBackdropModeResult.fromMap(appliedMode, mode);

      // 新增：如果原本请求的是极光流体，虽然我们为了关闭原生材质传给底层 none，
      // 但由于极光流体已成功在 Dart/Flutter 层生效，我们在这里把 appliedMode 纠正为 fluid，
      // 并判定为应用成功，从而避免触发回退 SnackBar 提示。
      if (mode == WindowBackdropMode.fluid) {
        result = const WindowBackdropModeResult(
          requestedMode: WindowBackdropMode.fluid,
          appliedMode: WindowBackdropMode.fluid,
          nativeBackdropSupported: true, // 软件渲染的流体材质是必定支持的
          nativeApplySucceeded: true, // 标记为成功应用状态
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

  static void init() {
    if (_initialized) return;
    _initialized = true;

    final playbackService = PlayService.instance.playbackService;
    unawaited(
      windowManager.ensureInitialized().then((_) {
        windowManager.addListener(_windowListener);
      }),
    );
    unawaited(
      setWindowBackdropMode(AppSettings.instance.windowBackdropMode),
    );
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
      }
    });
  }
}

class _PlaybackWindowListener with WindowListener {
  @override
  void onWindowResize() {
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  void onWindowFocus() {
    WindowControls.resyncPlaybackAfterWindowActivated(reason: 'window focus');
  }

  @override
  void onWindowRestore() {
    WindowControls.resyncPlaybackAfterWindowActivated(reason: 'window restore');
  }
}
