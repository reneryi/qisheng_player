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
}
