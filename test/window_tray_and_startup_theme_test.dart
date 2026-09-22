import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/window_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_swe6_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('AlbumPalette serialization and deserialization', () {
    test('roundtrip serialization produces identical values', () {
      const original = AlbumPalette(
        primary: Color(0xFF112233),
        secondary: Color(0xFF445566),
        accent: Color(0xFF778899),
        muted: Color(0xFFAABBCC),
        highlight: Color(0xFFDDEEFF),
      );

      final map = original.toMap();
      final restored = AlbumPalette.fromMap(map);

      expect(restored, isNotNull);
      expect(restored!.primary, original.primary);
      expect(restored.secondary, original.secondary);
      expect(restored.accent, original.accent);
      expect(restored.muted, original.muted);
      expect(restored.highlight, original.highlight);
    });

    test('fromMap returns null for null or empty input', () {
      expect(AlbumPalette.fromMap(null), isNull);
      expect(AlbumPalette.fromMap({}), isNull);
    });

    test('fromMap safely handles missing individual color fields', () {
      final restored = AlbumPalette.fromMap({
        'primary': 0xFF123456,
      });

      expect(restored, isNotNull);
      expect(restored!.primary, const Color(0xFF123456));
      expect(restored.secondary, const Color(0xFF123456));
      expect(restored.accent, const Color(0xFF123456));
      expect(restored.muted, const Color(0xFF123456));
      expect(restored.highlight, const Color(0xFF123456));
    });

    test('fromMap normalizes zero alpha to fully opaque', () {
      final restored = AlbumPalette.fromMap({
        'primary': 0x00123456, // zero alpha
        'secondary': 0x00654321,
      });

      expect(restored, isNotNull);
      expect(restored!.primary.a, 1.0);
      expect(restored.primary, const Color(0xFF123456));
      expect(restored.secondary.a, 1.0);
      expect(restored.secondary, const Color(0xFF654321));
    });

    test('fromMap correctly normalizes negative 32-bit signed integers', () {
      // 0xFF123456 in signed 32-bit int is -15584170
      final restored = AlbumPalette.fromMap({
        'primary': -15584170,
        'secondary': -1, // 0xFFFFFFFF
      });

      expect(restored, isNotNull);
      expect(restored!.primary, const Color(0xFF123456));
      expect(restored.secondary, const Color(0xFFFFFFFF));
    });

    test('fromMap supports string hex colors and capitalized keys', () {
      final restored = AlbumPalette.fromMap({
        'Primary': '#112233',
        'Secondary': '#FF445566',
        'Accent': '0x778899',
        'Muted': '0xFFAABBCC',
        'Highlight': '0xFFDDEEFF',
      });

      expect(restored, isNotNull);
      expect(restored!.primary, const Color(0xFF112233));
      expect(restored.secondary, const Color(0xFF445566));
      expect(restored.accent, const Color(0xFF778899));
      expect(restored.muted, const Color(0xFFAABBCC));
      expect(restored.highlight, const Color(0xFFDDEEFF));
    });

    test('fromMap returns null for invalid string colors', () {
      expect(AlbumPalette.fromMap({'primary': 'not_a_color'}), isNull);
      expect(AlbumPalette.fromMap({'primary': ''}), isNull);
    });
  });

  group('AppPreference dynamic album palette persistence', () {
    test('lastDynamicAlbumPalette field defaults to null and holds assigned palette', () {
      final preference = AppPreference();
      expect(preference.lastDynamicAlbumPalette, isNull);

      const palette = AlbumPalette(
        primary: Color(0xFF123456),
        secondary: Color(0xFF654321),
        accent: Color(0xFFABCDEF),
        muted: Color(0xFF1E1E1E),
        highlight: Color(0xFFFFFFFF),
      );

      preference.lastDynamicAlbumPalette = palette;
      expect(preference.lastDynamicAlbumPalette, equals(palette));
    });
  });

  group('WindowControls tray and close methods', () {
    test('minimizeToTray sends minimize_to_tray method call on Windows', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );

      await WindowControls.minimizeToTray();
      // On Windows environment this invokes minimize_to_tray
      expect(calls.any((c) => c.method == 'minimize_to_tray'), isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });

    test('close sends minimize_to_tray method call on Windows', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );

      await WindowControls.close();
      expect(calls.any((c) => c.method == 'minimize_to_tray'), isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });

    test('syncTrayMenuState invokes update_tray_menu_state without error', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );

      await WindowControls.syncTrayMenuState();
      expect(calls.any((c) => c.method == 'update_tray_menu_state'), isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });
  });

  group('AppSettings isWindowMaximized and isWindowFullScreen persistence', () {
    test('parseSettingsMap loads IsWindowMaximized and IsWindowFullScreen correctly', () {
      AppSettings.parseSettingsMap({
        'Version': 2,
        'IsWindowMaximized': true,
        'IsWindowFullScreen': false,
      });
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(AppSettings.instance.isWindowFullScreen, isFalse);

      AppSettings.parseSettingsMap({
        'Version': 2,
        'IsWindowMaximized': false,
        'IsWindowFullScreen': true,
      });
      expect(AppSettings.instance.isWindowMaximized, isFalse);
      expect(AppSettings.instance.isWindowFullScreen, isTrue);

      AppSettings.parseSettingsMap({
        'Version': 2,
        'IsWindowMaximized': false,
        'IsWindowFullScreen': false,
      });
      expect(AppSettings.instance.isWindowMaximized, isFalse);
      expect(AppSettings.instance.isWindowFullScreen, isFalse);
    });

    test('parseSettingsMap loads CloseAction correctly', () {
      AppSettings.parseSettingsMap({
        'Version': 2,
        'CloseAction': 'exitApp',
      });
      expect(AppSettings.instance.closeAction, CloseAction.exitApp);

      AppSettings.parseSettingsMap({
        'Version': 2,
        'CloseAction': 'minimizeToTray',
      });
      expect(AppSettings.instance.closeAction, CloseAction.minimizeToTray);
    });
  });

  group('ThemeProvider dynamic album palette restoration', () {
    test('restorePersistedAlbumPalette immediately restores dynamic colors and notifies listeners', () {
      const palette = AlbumPalette(
        primary: Color(0xFF334455),
        secondary: Color(0xFF556677),
        accent: Color(0xFF778899),
        muted: Color(0xFF99AABB),
        highlight: Color(0xFFBBDDFF),
      );

      bool notified = false;
      void listener() {
        notified = true;
      }

      ThemeProvider.instance.addListener(listener);
      ThemeProvider.instance.restorePersistedAlbumPalette(palette);
      ThemeProvider.instance.removeListener(listener);

      expect(notified, isTrue);
      expect(ThemeProvider.instance.meshFlowPalette.primary, const Color(0xFF334455));
      expect(AppPreference.instance.lastDynamicAlbumPalette, equals(palette));
    });
  });

  group('DesktopLyricService isRunning', () {
    test('isRunning defaults to false when no process is running', () {
      final service = DesktopLyricService.forTest();
      expect(service.isRunning, isFalse);
    });
  });

  group('WindowControls visibility and tray state synchronization', () {
    test('close and minimizeToTray update isWindowVisible to false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async => null,
      );

      WindowControls.isWindowVisible.value = true;
      await WindowControls.close();
      expect(WindowControls.isWindowVisible.value, isFalse);

      WindowControls.isWindowVisible.value = true;
      await WindowControls.minimizeToTray();
      expect(WindowControls.isWindowVisible.value, isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });

    test('window_minimized_to_tray and window_restored_from_tray update isWindowVisible', () async {
      WindowControls.ensureMethodChannelHandler();
      const channel = MethodChannel('qisheng_player/window_controls');
      
      // Simulate native calling window_minimized_to_tray
      final minByteData = channel.codec.encodeMethodCall(
        const MethodCall('window_minimized_to_tray'),
      );
      WindowControls.isWindowVisible.value = true;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', minByteData, (_) {});
      expect(WindowControls.isWindowVisible.value, isFalse);

      // Simulate native calling window_restored_from_tray
      final restoreByteData = channel.codec.encodeMethodCall(
        const MethodCall('window_restored_from_tray'),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', restoreByteData, (_) {});
      expect(WindowControls.isWindowVisible.value, isTrue);
    });

    test('on_window_layout_changed synchronizes isWindowMaximized and isWindowFullScreen', () async {
      WindowControls.ensureMethodChannelHandler();
      const channel = MethodChannel('qisheng_player/window_controls');

      final fullByteData = channel.codec.encodeMethodCall(
        const MethodCall('on_window_layout_changed', {'mode': 'fullscreen'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', fullByteData, (_) {});
      expect(AppSettings.instance.isWindowFullScreen, isTrue);
      expect(AppSettings.instance.isWindowMaximized, isFalse);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.fullscreen);

      final maxByteData = channel.codec.encodeMethodCall(
        const MethodCall('on_window_layout_changed', {'mode': 'maximized'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', maxByteData, (_) {});
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(AppSettings.instance.isWindowFullScreen, isFalse);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      final normalByteData = channel.codec.encodeMethodCall(
        const MethodCall('on_window_layout_changed', {'mode': 'normal'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', normalByteData, (_) {});
      expect(AppSettings.instance.isWindowMaximized, isFalse);
      expect(AppSettings.instance.isWindowFullScreen, isFalse);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.normal);
    });

    test('syncWindowLayoutMode synchronizes isWindowMaximized', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          if (call.method == 'get_window_layout_mode') {
            return 'maximized';
          }
          return null;
        },
      );

      AppSettings.instance.isWindowMaximized = false;
      await WindowControls.syncWindowLayoutMode();
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          if (call.method == 'get_window_layout_mode') {
            return 'normal';
          }
          return null;
        },
      );

      await WindowControls.syncWindowLayoutMode();
      expect(AppSettings.instance.isWindowMaximized, isFalse);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.normal);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });

    test('toggle_theme_mode toggles theme and syncs tray state', () async {
      WindowControls.ensureMethodChannelHandler();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call.method);
          return null;
        },
      );

      ThemeProvider.instance.applyThemeMode(ThemeMode.dark);
      await WindowControls.handleMethodCall(
        const MethodCall('toggle_theme_mode'),
      );
      expect(AppSettings.instance.themeMode, ThemeMode.light);
      expect(calls.contains('update_tray_menu_state'), isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });

    test('syncTrayMenuState trims whitespace from title and artist', () async {
      MethodCall? lastCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          if (call.method == 'update_tray_menu_state') {
            lastCall = call;
          }
          return null;
        },
      );

      await WindowControls.syncTrayMenuState();
      expect(lastCall, isNotNull);
      final args = lastCall!.arguments as Map;
      expect((args['title'] as String).trim(), equals(args['title']));
      expect((args['artist'] as String).trim(), equals(args['artist']));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
    });

    test('setInitialLayoutMode updates layoutMode accurately without delay', () {
      WindowControls.layoutMode.value = WindowLayoutMode.normal;
      WindowControls.setInitialLayoutMode(true);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.maximized));

      WindowControls.setInitialLayoutMode(false);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.normal));

      WindowControls.setInitialLayoutMode(false, isFullScreen: true);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.fullscreen));
    });

    test('showWindow sends show_window method call with maximize and fullscreen on Windows', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          return null;
        },
      );

      await WindowControls.showWindow(maximize: true);
      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(
        calls.any((c) =>
            c.method == 'show_window' &&
            c.arguments is Map &&
            (c.arguments as Map)['maximize'] == true &&
            (c.arguments as Map)['fullscreen'] == false),
        isTrue,
      );

      calls.clear();
      await WindowControls.showWindow(maximize: false, fullscreen: true);
      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(
        calls.any((c) =>
            c.method == 'show_window' &&
            c.arguments is Map &&
            (c.arguments as Map)['maximize'] == false &&
            (c.arguments as Map)['fullscreen'] == true),
        isTrue,
      );

      calls.clear();
      await WindowControls.showWindow(maximize: false, fullscreen: false);
      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(
        calls.any((c) =>
            c.method == 'show_window' &&
            c.arguments is Map &&
            (c.arguments as Map)['maximize'] == false &&
            (c.arguments as Map)['fullscreen'] == false),
        isTrue,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    test('Maximized state preserved when closed to tray and protected against spurious layout events', () async {
      WindowControls.ensureMethodChannelHandler();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          if (call.method == 'is_maximized') {
            return AppSettings.instance.isWindowMaximized;
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      // 1. 模拟窗口处于最大化且可见状态
      WindowControls.isWindowVisible.value = true;
      AppSettings.instance.isWindowMaximized = true;
      AppSettings.instance.isWindowFullScreen = false;
      WindowControls.setInitialLayoutMode(true, isFullScreen: false);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      // 2. 用户点击右上角关闭按钮最小化至托盘
      await WindowControls.close();
      expect(WindowControls.isWindowVisible.value, isFalse);
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      // 3. 模拟后台托盘隐藏期间，原生或 window_manager 派发偶发的 normal/unmaximize 消息
      final normalByteData = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('on_window_layout_changed', <String, dynamic>{'mode': 'normal'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', normalByteData, (_) {});

      // 验证保护机制：在托盘隐藏期间，严禁将最大化状态降级覆盖为普通窗口
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      // 4. 模拟重新启动初始化过程：WindowControls.init 必须向原生同步已持久化的最大化状态，且不被重置
      calls.clear();
      WindowControls.resetForTesting();
      await WindowControls.init();
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(
        calls.any((c) =>
            c.method == 'set_initial_window_state' &&
            c.arguments is Map &&
            (c.arguments as Map)['isMaximized'] == true &&
            (c.arguments as Map)['isFullScreen'] == false),
        isTrue,
      );

      // 5. 模拟启动首帧展示：showWindow 必须以 maximize: true 显示窗口
      calls.clear();
      await WindowControls.showWindow(
        maximize: AppSettings.instance.isWindowMaximized,
        fullscreen: AppSettings.instance.isWindowFullScreen,
      );
      expect(
        calls.any((c) =>
            c.method == 'show_window' &&
            c.arguments is Map &&
            (c.arguments as Map)['maximize'] == true),
        isTrue,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    test('Fullscreen state preserved when closed to tray and protected against spurious layout events', () async {
      WindowControls.ensureMethodChannelHandler();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          if (call.method == 'is_fullscreen') {
            return AppSettings.instance.isWindowFullScreen;
          }
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      // 1. 模拟全屏且可见
      WindowControls.isWindowVisible.value = true;
      AppSettings.instance.isWindowFullScreen = true;
      AppSettings.instance.isWindowMaximized = false;
      WindowControls.setInitialLayoutMode(false, isFullScreen: true);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.fullscreen);

      // 2. 关闭至托盘
      await WindowControls.close();
      expect(WindowControls.isWindowVisible.value, isFalse);
      expect(AppSettings.instance.isWindowFullScreen, isTrue);

      // 3. 模拟后台通知 normal
      final normalByteData = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('on_window_layout_changed', <String, dynamic>{'mode': 'normal'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', normalByteData, (_) {});
      expect(AppSettings.instance.isWindowFullScreen, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.fullscreen);

      // 4. 重新启动初始化
      calls.clear();
      WindowControls.resetForTesting();
      await WindowControls.init();
      expect(AppSettings.instance.isWindowFullScreen, isTrue);
      expect(
        calls.any((c) =>
            c.method == 'set_initial_window_state' &&
            c.arguments is Map &&
            (c.arguments as Map)['isFullScreen'] == true),
        isTrue,
      );

      // 5. 启动显示
      calls.clear();
      await WindowControls.showWindow(
        maximize: AppSettings.instance.isWindowMaximized,
        fullscreen: AppSettings.instance.isWindowFullScreen,
      );
      expect(
        calls.any((c) =>
            c.method == 'show_window' &&
            c.arguments is Map &&
            (c.arguments as Map)['fullscreen'] == true),
        isTrue,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    test('Cold start from maximized settings preserves maximized state even if spurious events fire before showWindow', () async {
      WindowControls.ensureMethodChannelHandler();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      // 1. 模拟全新冷启动环境：读取设置后窗口为最大化，但窗口原生层尚不可见
      WindowControls.resetForTesting();
      WindowControls.isWindowVisible.value = false;
      AppSettings.instance.isWindowMaximized = true;
      AppSettings.instance.isWindowFullScreen = false;
      WindowControls.setInitialLayoutMode(true, isFullScreen: false);
      expect(WindowControls.isWindowVisible.value, isFalse);
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      // 2. 模拟原生层在首帧渲染与 showWindow 之前可能派发的 normal 布局或 unmaximize 消息
      final normalByteData = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('on_window_layout_changed', <String, dynamic>{'mode': 'normal'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', normalByteData, (_) {});

      // 必须拦截并保持最大化状态不变
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      // 3. 执行 WindowControls.init
      await WindowControls.init();
      expect(
        calls.any((c) =>
            c.method == 'set_initial_window_state' &&
            c.arguments is Map &&
            (c.arguments as Map)['isMaximized'] == true),
        isTrue,
      );

      // 4. 首帧渲染完成，调用 showWindow 显示最大化窗口
      calls.clear();
      await WindowControls.showWindow(
        maximize: AppSettings.instance.isWindowMaximized,
        fullscreen: AppSettings.instance.isWindowFullScreen,
      );
      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(
        calls.any((c) =>
            c.method == 'show_window' &&
            c.arguments is Map &&
            (c.arguments as Map)['maximize'] == true),
        isTrue,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    test('close respects CloseAction and window_manager layout callbacks are ignored on Windows', () async {
      WindowControls.ensureMethodChannelHandler();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          calls.add(call);
          if (call.method == 'is_maximized') {
            return AppSettings.instance.isWindowMaximized;
          }
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      // 1. CloseAction.minimizeToTray 走最小化到托盘
      AppSettings.instance.closeAction = CloseAction.minimizeToTray;
      WindowControls.isWindowVisible.value = true;
      calls.clear();
      await WindowControls.close();
      expect(WindowControls.isWindowVisible.value, isFalse);
      expect(calls.any((c) => c.method == 'minimize_to_tray'), isTrue);

      // 2. 验证在 Windows 上 window_manager 派发的布局事件被完全屏蔽
      AppSettings.instance.isWindowMaximized = true;
      WindowControls.setInitialLayoutMode(true);
      expect(AppSettings.instance.isWindowMaximized, isTrue);

      // 模拟 window_manager 派发 onWindowUnmaximize
      WindowControls.windowListenerForTesting.onWindowUnmaximize();
      // 在 Windows 平台上必须直接 return，绝不能被篡改为 false
      expect(AppSettings.instance.isWindowMaximized, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

      // 模拟 window_manager 派发 onWindowMaximize
      AppSettings.instance.isWindowMaximized = false;
      WindowControls.setInitialLayoutMode(false);
      WindowControls.windowListenerForTesting.onWindowMaximize();
      expect(AppSettings.instance.isWindowMaximized, isFalse);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.normal);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });
  });
}
