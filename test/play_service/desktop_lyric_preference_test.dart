import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_pref_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
  });

  tearDown(() async {
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

  group('DesktopLyricPreference Model Tests', () {
    test('default constructor initializes followPlayerFont to true and lyricFontFamily to null', () {
      final pref = DesktopLyricPreference(
        false,
        false,
        null,
        null,
        null,
        null,
        null,
      );

      expect(pref.followPlayerFont, isTrue);
      expect(pref.lyricFontFamily, isNull);
      expect(pref.enabled, isFalse);
      expect(pref.locked, isFalse);
      expect(pref.primary, isNull);
    });

    test('constructor with custom font preferences initializes correctly', () {
      final pref = DesktopLyricPreference(
        true,
        true,
        0xFF123456,
        0xFF654321,
        0xFFFFFFFF,
        120.0,
        240.0,
        lyricFontFamily: 'MiSans',
        followPlayerFont: false,
      );

      expect(pref.enabled, isTrue);
      expect(pref.locked, isTrue);
      expect(pref.primary, 0xFF123456);
      expect(pref.surfaceContainer, 0xFF654321);
      expect(pref.onSurface, 0xFFFFFFFF);
      expect(pref.windowLeft, 120.0);
      expect(pref.windowTop, 240.0);
      expect(pref.lyricFontFamily, 'MiSans');
      expect(pref.followPlayerFont, isFalse);
    });

    test('toMap serializes lyricFontFamily and followPlayerFont', () {
      final pref = DesktopLyricPreference(
        false,
        false,
        null,
        null,
        null,
        null,
        null,
        lyricFontFamily: 'HarmonyOS Sans',
        followPlayerFont: false,
      );

      final map = pref.toMap();

      expect(map['lyricFontFamily'], 'HarmonyOS Sans');
      expect(map['followPlayerFont'], isFalse);
      expect(map['primary'], isNull);
      expect(map['enabled'], isFalse);
    });

    test('fromMap parses lyricFontFamily and followPlayerFont', () {
      final map = {
        'enabled': true,
        'locked': false,
        'primary': 0xFF00F5D4,
        'surfaceContainer': 0xFF1E293B,
        'onSurface': 0xFFF8FAFC,
        'windowLeft': 150.5,
        'windowTop': 250.5,
        'lyricFontFamily': 'JetBrains Mono',
        'followPlayerFont': false,
      };

      final pref = DesktopLyricPreference.fromMap(map);

      expect(pref.enabled, isTrue);
      expect(pref.locked, isFalse);
      expect(pref.primary, 0xFF00F5D4);
      expect(pref.windowLeft, 150.5);
      expect(pref.windowTop, 250.5);
      expect(pref.lyricFontFamily, 'JetBrains Mono');
      expect(pref.followPlayerFont, isFalse);
    });

    test('fromMap backward compatibility: missing font fields default correctly', () {
      final legacyMap = {
        'enabled': true,
        'locked': true,
        'primary': 0xFFFFFFFF,
        'surfaceContainer': 0xFF000000,
        'onSurface': 0xFFFFFFFF,
        'windowLeft': 100.0,
        'windowTop': 100.0,
      };

      final pref = DesktopLyricPreference.fromMap(legacyMap);

      expect(pref.lyricFontFamily, isNull);
      expect(pref.followPlayerFont, isTrue);
      expect(pref.enabled, isTrue);
      expect(pref.locked, isTrue);
    });

    test('round-trip serialization toMap -> fromMap preserves all fields', () {
      final original = DesktopLyricPreference(
        true,
        false,
        null,
        0xFF112233,
        0xFFEEEEEE,
        300.0,
        400.0,
        lyricFontFamily: 'Segoe UI',
        followPlayerFont: true,
      );

      final restored = DesktopLyricPreference.fromMap(original.toMap());

      expect(restored.enabled, original.enabled);
      expect(restored.locked, original.locked);
      expect(restored.primary, isNull);
      expect(restored.surfaceContainer, original.surfaceContainer);
      expect(restored.onSurface, original.onSurface);
      expect(restored.windowLeft, original.windowLeft);
      expect(restored.windowTop, original.windowTop);
      expect(restored.lyricFontFamily, 'Segoe UI');
      expect(restored.followPlayerFont, isTrue);
    });
  });

  group('AppPreference Integration Tests for DesktopLyricPreference', () {
    test('AppPreference.read() populates desktopLyricPref with lyricFontFamily and followPlayerFont', () async {
      await AppPreference.instance.save();

      final appDataDir = Directory('${tempDir.path}\\qisheng_player');
      final prefFile = File('${appDataDir.path}\\app_preference.json');
      final currentMap = json.decode(await prefFile.readAsString()) as Map<String, dynamic>;
      currentMap['desktopLyricPref'] = {
        'enabled': true,
        'locked': false,
        'primary': null,
        'surfaceContainer': 0xFF222222,
        'onSurface': 0xFFCCCCCC,
        'windowLeft': 50.0,
        'windowTop': 60.0,
        'lyricFontFamily': 'CustomLyricFont',
        'followPlayerFont': false,
      };
      await prefFile.writeAsString(json.encode(currentMap));

      await AppPreference.read();

      expect(AppPreference.instance.desktopLyricPref.enabled, isTrue);
      expect(AppPreference.instance.desktopLyricPref.primary, isNull);
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, 'CustomLyricFont');
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);
    });

    test('AppPreference.save() and read() round-trip retains desktop lyric font preferences', () async {
      AppPreference.instance.desktopLyricPref
        ..enabled = true
        ..locked = true
        ..primary = 0xFFB388FF
        ..lyricFontFamily = 'Alibaba PuHuiTi'
        ..followPlayerFont = false;

      await AppPreference.instance.save();

      // Clear memory instance to verify read() restores from disk
      AppPreference.instance.desktopLyricPref
        ..enabled = false
        ..locked = false
        ..primary = null
        ..lyricFontFamily = null
        ..followPlayerFont = true;

      await AppPreference.read();

      expect(AppPreference.instance.desktopLyricPref.enabled, isTrue);
      expect(AppPreference.instance.desktopLyricPref.locked, isTrue);
      expect(AppPreference.instance.desktopLyricPref.primary, 0xFFB388FF);
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, 'Alibaba PuHuiTi');
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);
    });

    test('ThemeProvider.applyThemeMode while desktop lyric is closed updates desktop lyric surfaceContainer and onSurface', () async {
      // Simulate switching to dark mode while desktop lyric is closed
      ThemeProvider.instance.applyThemeMode(ThemeMode.dark);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final darkScheme = ThemeProvider.instance.currScheme;
      expect(AppPreference.instance.desktopLyricPref.surfaceContainer, darkScheme.surfaceContainer.toARGB32());
      expect(AppPreference.instance.desktopLyricPref.onSurface, darkScheme.onSurface.toARGB32());

      // Simulate switching to light mode while desktop lyric is closed
      ThemeProvider.instance.applyThemeMode(ThemeMode.light);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final lightScheme = ThemeProvider.instance.currScheme;
      expect(AppPreference.instance.desktopLyricPref.surfaceContainer, lightScheme.surfaceContainer.toARGB32());
      expect(AppPreference.instance.desktopLyricPref.onSurface, lightScheme.onSurface.toARGB32());
    });
  });
}
