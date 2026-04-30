import 'dart:async';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart' show ResizeEdge;

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

  static WindowBackdropModeResult? get lastBackdropResult =>
      _lastBackdropResult;

  static Future<WindowBackdropModeResult> setWindowBackdropMode(
    WindowBackdropMode mode,
  ) async {
    try {
      final appliedMode = await _channel.invokeMapMethod<Object?, Object?>(
        "set_window_backdrop_mode",
        {"mode": mode.name},
      );
      final result = appliedMode == null
          ? WindowBackdropModeResult.fallback(
              mode,
              fallbackReason: 'empty_platform_response',
            )
          : WindowBackdropModeResult.fromMap(appliedMode, mode);
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

  static void init() {
    if (_initialized) return;
    _initialized = true;

    final playbackService = PlayService.instance.playbackService;
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
      }
    });
  }
}
