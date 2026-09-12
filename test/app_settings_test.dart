import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';

void main() {
  group('AppSettings.parseWindowSize', () {
    test('uses the full desktop layout as the default size', () {
      expect(AppSettings.defaultWindowSize, const Size(1461, 898));
    });

    test('accepts valid sizes including the supported minimum', () {
      expect(
        AppSettings.parseWindowSize('507.0,507.0'),
        AppSettings.minimumWindowSize,
      );
      expect(
        AppSettings.parseWindowSize(' 1280.5, 756.25 '),
        const Size(1280.5, 756.25),
      );
    });

    test('falls back for malformed or incomplete values', () {
      for (final value in <Object?>[
        null,
        123,
        '',
        'invalid',
        '800',
        '800,600,1',
        'width,600',
      ]) {
        expect(
          AppSettings.parseWindowSize(value),
          AppSettings.defaultWindowSize,
          reason: 'value: $value',
        );
      }
    });

    test('falls back for non-finite, negative, or undersized values', () {
      for (final value in <String>[
        'NaN,756',
        'Infinity,756',
        '1280,-1',
        '506.9,507',
        '507,506.9',
      ]) {
        expect(
          AppSettings.parseWindowSize(value),
          AppSettings.defaultWindowSize,
          reason: 'value: $value',
        );
      }
    });
  });

  group('AppSettings visual effects settings', () {
    test('defaults to visual effects level as the primary mode', () {
      final settings = AppSettings.instance;
      expect(settings.uiEffectsLevel, equals(UiEffectsLevel.visual));
    });

    test('contains pure visual effects settings without vinyl record options', () {
      final settings = AppSettings.instance;
      expect(settings.showSpectrumVisualizer, isTrue);
      expect(settings.showKaraokeAnimation, isTrue);
      expect(settings.coverBreathEffect, isTrue);
      expect(settings.autoHideControls, isFalse);
    });
  });

  group('AppSettings customTheme and useSystemTheme consistency', () {
    test('customTheme persists independently from useSystemTheme and defaultTheme', () {
      final settings = AppSettings.instance;
      const initialCustom = 0xFF336699;
      settings.customTheme = initialCustom;
      settings.useSystemTheme = false;
      settings.defaultTheme = initialCustom;

      // Turning on system theme changes defaultTheme but preserves customTheme
      settings.useSystemTheme = true;
      final sysTheme = AppSettings.getWindowsTheme();
      settings.defaultTheme = sysTheme;

      expect(settings.customTheme, equals(initialCustom));
      expect(settings.defaultTheme, equals(sysTheme));

      // Turning off system theme restores customTheme
      settings.useSystemTheme = false;
      settings.defaultTheme = settings.customTheme;

      expect(settings.defaultTheme, equals(initialCustom));
      expect(settings.customTheme, equals(initialCustom));
    });

    test('parseSettingsMap retains visual for UiEffectsLevel and parses UiVisualStyleMode', () {
      final settings = AppSettings.instance;
      AppSettings.parseSettingsMap({
        "Version": 2,
        "UiEffectsLevel": "performance",
        "UiVisualStyleMode": "liquidGlass",
      });

      expect(settings.uiEffectsLevel, equals(UiEffectsLevel.visual));
      expect(settings.uiVisualStyleMode, equals(UiVisualStyleMode.liquidGlass));

      // Reset back to defaults
      AppSettings.parseSettingsMap({
        "Version": 2,
        "UiVisualStyleMode": "borderless",
      });
      expect(settings.uiEffectsLevel, equals(UiEffectsLevel.visual));
      expect(settings.uiVisualStyleMode, equals(UiVisualStyleMode.borderless));
    });

    test('parseSettingsMap correctly loads lyric save preferences', () {
      final settings = AppSettings.instance;
      AppSettings.parseSettingsMap({
        "Version": 2,
        "LyricSaveWriteTag": false,
        "LyricSaveExportLrc": true,
        "LyricSaveApplyPlayer": false,
      });

      expect(settings.lyricSaveWriteTag, isFalse);
      expect(settings.lyricSaveExportLrc, isTrue);
      expect(settings.lyricSaveApplyPlayer, isFalse);

      // Restore defaults
      AppSettings.parseSettingsMap({
        "Version": 2,
        "LyricSaveWriteTag": true,
        "LyricSaveExportLrc": true,
        "LyricSaveApplyPlayer": true,
      });
      expect(settings.lyricSaveWriteTag, isTrue);
      expect(settings.lyricSaveExportLrc, isTrue);
      expect(settings.lyricSaveApplyPlayer, isTrue);
    });
  });

  group('ProgressBarType and AppSettings persistence', () {
    tearDown(() {
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.fluidGlow;
    });

    test('ProgressBarType.fromName supports aliases and case-insensitivity', () {
      expect(ProgressBarType.fromName('fluidGlow'), ProgressBarType.fluidGlow);
      expect(ProgressBarType.fromName('FLUID'), ProgressBarType.fluidGlow);
      expect(ProgressBarType.fromName('glow'), ProgressBarType.fluidGlow);
      expect(ProgressBarType.fromName('fluid-glow'), ProgressBarType.fluidGlow);

      expect(ProgressBarType.fromName('adaptiveWaveform'), ProgressBarType.adaptiveWaveform);
      expect(ProgressBarType.fromName('waveform'), ProgressBarType.adaptiveWaveform);
      expect(ProgressBarType.fromName('JELLY'), ProgressBarType.adaptiveWaveform);
      expect(ProgressBarType.fromName('adaptive_waveform'), ProgressBarType.adaptiveWaveform);

      expect(ProgressBarType.fromName('dualLayerRhythm'), ProgressBarType.dualLayerRhythm);
      expect(ProgressBarType.fromName('rhythm'), ProgressBarType.dualLayerRhythm);
      expect(ProgressBarType.fromName('ambient_rhythm'), ProgressBarType.dualLayerRhythm);
      expect(ProgressBarType.fromName('ambientrhythm'), ProgressBarType.dualLayerRhythm);

      expect(ProgressBarType.fromName(null), isNull);
      expect(ProgressBarType.fromName('unknown_value'), isNull);
    });

    test('ProgressBarType labels and descriptions are defined and non-empty', () {
      for (final type in ProgressBarType.values) {
        expect(type.label, isNotEmpty);
        expect(type.description, isNotEmpty);
      }
    });

    test('parseSettingsMap loads ProgressBarType and updates notifier', () {
      final settings = AppSettings.instance;

      AppSettings.parseSettingsMap({
        "Version": 2,
        "ProgressBarType": "adaptiveWaveform",
      });
      expect(settings.progressBarType, equals(ProgressBarType.adaptiveWaveform));
      expect(settings.progressBarTypeNotifier.value, equals(ProgressBarType.adaptiveWaveform));

      AppSettings.parseSettingsMap({
        "Version": 2,
        "ProgressBarType": "dualLayerRhythm",
      });
      expect(settings.progressBarType, equals(ProgressBarType.dualLayerRhythm));

      AppSettings.parseSettingsMap({
        "Version": 2,
        "ProgressBarType": "invalid",
      });
      expect(settings.progressBarType, equals(ProgressBarType.fluidGlow));
    });

    test('setting progressBarType updates notifier and notifies listeners', () {
      final settings = AppSettings.instance;
      settings.progressBarTypeNotifier.value = ProgressBarType.fluidGlow;

      final notifications = <ProgressBarType>[];
      void listener() {
        notifications.add(settings.progressBarType);
      }

      settings.progressBarTypeNotifier.addListener(listener);
      settings.progressBarType = ProgressBarType.adaptiveWaveform;
      settings.progressBarType = ProgressBarType.dualLayerRhythm;
      settings.progressBarTypeNotifier.removeListener(listener);

      expect(notifications, [
        ProgressBarType.adaptiveWaveform,
        ProgressBarType.dualLayerRhythm,
      ]);
    });
  });

  group('AppSettings uiScale persistence and parsing', () {
    tearDown(() {
      AppSettings.instance.uiScale = 1.0;
    });

    test('defaults to 1.0', () {
      final settings = AppSettings.instance;
      expect(settings.uiScale, equals(1.0));
    });

    test('parseSettingsMap loads and clamps uiScale correctly', () {
      final settings = AppSettings.instance;

      AppSettings.parseSettingsMap({
        "Version": 2,
        "UiScale": 1.25,
      });
      expect(settings.uiScale, equals(1.25));

      AppSettings.parseSettingsMap({
        "Version": 2,
        "UiScale": 0.5,
      });
      expect(settings.uiScale, equals(0.8));

      AppSettings.parseSettingsMap({
        "Version": 2,
        "UiScale": 3.0,
      });
      expect(settings.uiScale, equals(2.0));
    });
  });
}

