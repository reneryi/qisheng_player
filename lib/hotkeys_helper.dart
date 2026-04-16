import 'dart:async';
import 'dart:io';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

enum HotkeyAction {
  playPause("播放/暂停", "playPause"),
  previous("上一首", "previous"),
  next("下一首", "next"),
  volumeUp("音量加", "volumeUp"),
  volumeDown("音量减", "volumeDown"),
  mute("静音", "mute"),
  toggleDesktopLyric("显示/隐藏桌面歌词", "toggleDesktopLyric"),
  toggleMainWindow("显示/隐藏主界面", "toggleMainWindow"),
  goBack("返回上一页", "goBack"),
  quit("退出程序", "quit");

  const HotkeyAction(this.label, this.prefKey);
  final String label;
  final String prefKey;
}

class HotkeysHelper {
  static const Set<HotkeyAction> _backgroundActions = {
    HotkeyAction.previous,
    HotkeyAction.next,
    HotkeyAction.volumeUp,
    HotkeyAction.volumeDown,
    HotkeyAction.mute,
    HotkeyAction.toggleMainWindow,
  };

  static final _windowListener = _HotkeyWindowListener();

  static bool _windowFocused = true;
  static bool _inputFocused = false;
  static bool _windowListenerBound = false;
  static _HotkeyRegisterMode? _currentMode;
  static double _lastNonZeroVolume = 0.2;

  static final Map<HotkeyAction, void Function(HotKey)> _handlers = {
    HotkeyAction.playPause: (_) {
      final playbackService = PlayService.instance.playbackService;
      final state = playbackService.playerState;
      if (state == PlayerState.playing) {
        playbackService.pause();
      } else if (state == PlayerState.completed) {
        playbackService.playAgain();
      } else {
        playbackService.start();
      }
    },
    HotkeyAction.previous: (_) {
      PlayService.instance.playbackService.lastAudio();
    },
    HotkeyAction.next: (_) {
      PlayService.instance.playbackService.nextAudio();
    },
    HotkeyAction.volumeUp: (_) {
      final playbackService = PlayService.instance.playbackService;
      _setVolume(playbackService, playbackService.volumeDsp + 0.01);
    },
    HotkeyAction.volumeDown: (_) {
      final playbackService = PlayService.instance.playbackService;
      _setVolume(playbackService, playbackService.volumeDsp - 0.01);
    },
    HotkeyAction.mute: (_) {
      _toggleMute();
    },
    HotkeyAction.toggleDesktopLyric: (_) async {
      final desktopLyricService = PlayService.instance.desktopLyricService;
      final process = await desktopLyricService.desktopLyric;
      if (process == null) {
        await desktopLyricService.startDesktopLyric();
      } else {
        desktopLyricService.killDesktopLyric();
      }
    },
    HotkeyAction.toggleMainWindow: (_) async {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    },
    HotkeyAction.goBack: (_) {
      final routerContext = ROUTER_KEY.currentContext;
      if (routerContext == null) return;

      final navigator = Navigator.maybeOf(routerContext);
      if (navigator?.canPop() == true) {
        navigator?.pop();
      } else if (ROUTER_KEY.currentContext?.canPop() == true) {
        ROUTER_KEY.currentContext?.pop();
      }
    },
    HotkeyAction.quit: (_) async {
      await Future.wait([
        AppSettings.instance.saveSettings(),
        AppPreference.instance.save(),
        savePlaylists(),
      ]);
      exit(0);
    },
  };

  static final Map<HotkeyAction, HotKey> _registeredHotKeys = {};

  static HotkeyBindingPreference getBinding(HotkeyAction action) =>
      AppPreference.instance.hotkeyPref.bindings[action.prefKey]!;

  static HotkeyBindingPreference getDefaultBinding(HotkeyAction action) =>
      HotkeyPreference.defaults().bindings[action.prefKey]!;

  static String describeBinding(HotkeyBindingPreference binding) {
    final key = PhysicalKeyboardKey.findKeyByCode(binding.keyId);
    if (key == null) return "未设置";
    final buffer = <String>[];
    for (final modifier in binding.modifiers) {
      switch (modifier) {
        case "control":
          buffer.add("Ctrl");
          break;
        case "shift":
          buffer.add("Shift");
          break;
        case "alt":
          buffer.add("Alt");
          break;
        case "meta":
          buffer.add("Meta");
          break;
      }
    }
    final label = key.debugName ?? key.keyLabel;
    buffer.add(
        (label == " ") ? "Space" : (label.isEmpty ? key.toString() : label));
    return buffer.join("+");
  }

  static List<HotKeyModifier> _parseModifiers(List<String> names) {
    final result = <HotKeyModifier>[];
    for (final name in names) {
      switch (name) {
        case "control":
          result.add(HotKeyModifier.control);
          break;
        case "shift":
          result.add(HotKeyModifier.shift);
          break;
        case "alt":
          result.add(HotKeyModifier.alt);
          break;
        case "meta":
          result.add(HotKeyModifier.meta);
          break;
      }
    }
    return result;
  }

  static HotKey? _toHotKey(HotkeyBindingPreference binding) {
    final key = PhysicalKeyboardKey.findKeyByCode(binding.keyId);
    if (key == null) return null;
    return HotKey(
      key: key,
      modifiers: _parseModifiers(binding.modifiers),
      scope: HotKeyScope.system,
    );
  }

  static Future<void> registerHotKeys({Set<HotkeyAction>? actions}) async {
    await unregisterAll();
    _registeredHotKeys.clear();
    final registerActions = actions ?? HotkeyAction.values.toSet();

    for (final action in HotkeyAction.values) {
      if (!registerActions.contains(action)) continue;
      final binding = getBinding(action);
      final hotkey = _toHotKey(binding);
      if (hotkey == null) continue;
      try {
        await hotKeyManager.register(
          hotkey,
          keyDownHandler: _handlers[action],
        );
        _registeredHotKeys[action] = hotkey;
      } catch (err, trace) {
        LOGGER.e(
          "注册快捷键失败: ${action.label}",
          error: err,
          stackTrace: trace,
        );
      }
    }
  }

  static Future<void> init() async {
    if (!_windowListenerBound) {
      windowManager.addListener(_windowListener);
      _windowListenerBound = true;
    }
    final currentVolume = _normalizeVolume(
      PlayService.instance.playbackService.volumeDsp,
    );
    if (currentVolume > 0.0001) {
      _lastNonZeroVolume = currentVolume;
    }
    _windowFocused = await windowManager.isFocused();
    _inputFocused = false;
    _currentMode = null;
    await _applyCurrentMode();
  }

  static double _normalizeVolume(double volume) =>
      volume.clamp(0.0, 1.0).toDouble();

  static void _setVolume(PlaybackService playbackService, double volume) {
    final normalized = _normalizeVolume(volume);
    if (normalized > 0.0001) {
      _lastNonZeroVolume = normalized;
    }
    playbackService.setVolumeDsp(normalized);
  }

  static void _toggleMute() {
    final playbackService = PlayService.instance.playbackService;
    final currentVolume = _normalizeVolume(playbackService.volumeDsp);
    if (currentVolume <= 0.0001) {
      final restored = _lastNonZeroVolume <= 0.0001 ? 0.2 : _lastNonZeroVolume;
      _setVolume(playbackService, restored);
      return;
    }
    _lastNonZeroVolume = currentVolume;
    playbackService.setVolumeDsp(0.0);
  }

  static Future<void> _applyCurrentMode() async {
    final targetMode = _inputFocused
        ? _HotkeyRegisterMode.none
        : (_windowFocused
            ? _HotkeyRegisterMode.foreground
            : _HotkeyRegisterMode.background);
    if (_currentMode == targetMode) return;

    switch (targetMode) {
      case _HotkeyRegisterMode.none:
        await unregisterAll();
        _registeredHotKeys.clear();
        break;
      case _HotkeyRegisterMode.foreground:
        await registerHotKeys(actions: HotkeyAction.values.toSet());
        break;
      case _HotkeyRegisterMode.background:
        await registerHotKeys(actions: _backgroundActions);
        break;
    }
    _currentMode = targetMode;
  }

  static Future<void> updateBinding(
    HotkeyAction action,
    HotkeyBindingPreference binding,
  ) async {
    AppPreference.instance.hotkeyPref.bindings[action.prefKey] = binding;
    await AppPreference.instance.save();
    _currentMode = null;
    await _applyCurrentMode();
  }

  static Future<void> resetToDefault(HotkeyAction action) async {
    await updateBinding(action, getDefaultBinding(action));
  }

  static Future<void> unregisterAll() => hotKeyManager.unregisterAll();

  static Future<void> onWindowFocusChanged(bool focused) async {
    _windowFocused = focused;
    await _applyCurrentMode();
  }

  static Future<void> onFocusChanges(bool focus) async {
    _inputFocused = focus;
    await _applyCurrentMode();
  }
}

enum _HotkeyRegisterMode {
  none,
  foreground,
  background,
}

class _HotkeyWindowListener with WindowListener {
  @override
  void onWindowFocus() {
    unawaited(HotkeysHelper.onWindowFocusChanged(true));
  }

  @override
  void onWindowBlur() {
    unawaited(HotkeysHelper.onWindowFocusChanged(false));
  }
}
