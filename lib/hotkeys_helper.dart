import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_shutdown.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  goForward("前进", "goForward"),
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

  /// 鼠标侧键的 USB HID 用途 ID。
  static final int _browserBackKeyId =
      PhysicalKeyboardKey.browserBack.usbHidUsage;
  static final int _browserForwardKeyId =
      PhysicalKeyboardKey.browserForward.usbHidUsage;

  /// 判断绑定是否为鼠标侧键（无法通过系统级热键 API 注册）。
  static bool isMouseButtonBinding(HotkeyBindingPreference binding) {
    return binding.keyId == _browserBackKeyId ||
        binding.keyId == _browserForwardKeyId;
  }

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
      AppNavigationState.instance.navigateBack(routerContext, fallback: '');
    },
    HotkeyAction.goForward: (_) {
      final routerContext = ROUTER_KEY.currentContext;
      if (routerContext == null) return;
      AppNavigationState.instance.navigateForward(routerContext);
    },
    HotkeyAction.quit: (_) async {
      await appShutdownCoordinator.shutdown();
      exit(0);
    },
  };

  static final Map<HotkeyAction, HotKey> _registeredHotKeys = {};

  static HotkeyBindingPreference getBinding(HotkeyAction action) =>
      AppPreference.instance.hotkeyPref.bindings[action.prefKey]!;

  static HotkeyBindingPreference getDefaultBinding(HotkeyAction action) =>
      HotkeyPreference.defaults().bindings[action.prefKey]!;

  /// 鼠标侧键 USB HID ID ↀ友好显示名称映射
  static final Map<int, String> _mouseButtonLabels = {
    PhysicalKeyboardKey.browserBack.usbHidUsage: "鼠标侧键后退",
    PhysicalKeyboardKey.browserForward.usbHidUsage: "鼠标侧键前进",
  };

  static String describeBinding(HotkeyBindingPreference binding) {
    // 优先检查是否为鼠标侧键。
    final mouseLabel = _mouseButtonLabels[binding.keyId];
    if (mouseLabel != null && binding.modifiers.isEmpty) {
      return mouseLabel;
    }

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
    // 鼠标侧键带修饰符的情况也使用友好名称。
    final label = mouseLabel ?? key.debugName ?? key.keyLabel;
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
      // 鼠标侧键无法通过系统级热键 API 注册，跳过。
      if (isMouseButtonBinding(binding)) continue;
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
          "注册快捷键失败：${action.label}",
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
    final targetMode = _resolveRegisterMode(
      windowFocused: _windowFocused,
      inputFocused: _inputFocused,
    );
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

  /// 处理鼠标侧键事件（从 Listener widget 调用）
  static void handlePointerDown(PointerDownEvent event) {
    if (_inputFocused) return;
    // 榧犳爣渚ч敭鍚庨€€ = button 3, 鍓嶈繘 = button 4
    final int button = event.buttons;
    int? matchKeyId;
    if (button == kBackMouseButton) {
      matchKeyId = _browserBackKeyId;
    } else if (button == kForwardMouseButton) {
      matchKeyId = _browserForwardKeyId;
    }
    if (matchKeyId == null) return;

    // 閬嶅巻鎵€鏈夌粦瀹氾紝鎵惧埌鍖归厤鐨?action 骞舵墽琛?
    for (final action in HotkeyAction.values) {
      final binding = getBinding(action);
      if (binding.keyId == matchKeyId && binding.modifiers.isEmpty) {
        final handler = _handlers[action];
        if (handler != null) {
          handler(HotKey(
            key: PhysicalKeyboardKey.findKeyByCode(matchKeyId) ??
                PhysicalKeyboardKey.browserBack,
            scope: HotKeyScope.system,
          ));
        }
        return;
      }
    }
  }

  static Future<void> onFocusChanges(bool focus) async {
    _inputFocused = focus;
    await _applyCurrentMode();
  }

  static _HotkeyRegisterMode _resolveRegisterMode({
    required bool windowFocused,
    required bool inputFocused,
  }) {
    if (inputFocused) return _HotkeyRegisterMode.none;
    return windowFocused
        ? _HotkeyRegisterMode.foreground
        : _HotkeyRegisterMode.background;
  }

  @visibleForTesting
  static String resolveRegisterModeName({
    required bool windowFocused,
    required bool inputFocused,
  }) {
    return _resolveRegisterMode(
      windowFocused: windowFocused,
      inputFocused: inputFocused,
    ).name;
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
