import 'dart:async';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:flutter/services.dart';

class WindowControls {
  static const MethodChannel _channel =
      MethodChannel("coriander_player/window_controls");
  static bool _initialized = false;

  static Future<String> setWindowBackdropMode(
    WindowBackdropMode mode,
  ) async {
    try {
      final appliedMode = await _channel.invokeMethod<String>(
        "set_window_backdrop_mode",
        {"mode": mode.name},
      );
      return WindowBackdropMode.fromName(appliedMode)?.name ??
          WindowBackdropMode.none.name;
    } on PlatformException {
      return WindowBackdropMode.none.name;
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
