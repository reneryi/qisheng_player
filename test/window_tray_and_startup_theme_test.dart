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

  group('AppSettings isWindowMaximized persistence', () {
    test('parseSettingsMap loads IsWindowMaximized correctly', () {
      AppSettings.parseSettingsMap({
        'Version': 2,
        'IsWindowMaximized': true,
      });
      expect(AppSettings.instance.isWindowMaximized, isTrue);

      AppSettings.parseSettingsMap({
        'Version': 2,
        'IsWindowMaximized': false,
      });
      expect(AppSettings.instance.isWindowMaximized, isFalse);
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

    test('on_window_layout_changed synchronizes isWindowMaximized', () async {
      WindowControls.ensureMethodChannelHandler();
      const channel = MethodChannel('qisheng_player/window_controls');

      final maxByteData = channel.codec.encodeMethodCall(
        const MethodCall('on_window_layout_changed', {'mode': 'maximized'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', maxByteData, (_) {});
      expect(AppSettings.instance.isWindowMaximized, isTrue);

      final normalByteData = channel.codec.encodeMethodCall(
        const MethodCall('on_window_layout_changed', {'mode': 'normal'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('qisheng_player/window_controls', normalByteData, (_) {});
      expect(AppSettings.instance.isWindowMaximized, isFalse);
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
  });
}
