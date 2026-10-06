import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/play_service/volume_curve.dart';

void main() {
  group('Perceptual Volume Curve Tests', () {
    test('Boundary values mapping correctly', () {
      expect(perceptualVolumeToAmplitude(0.0), equals(0.0));
      expect(perceptualVolumeToAmplitude(1.0), equals(1.0));
      expect(perceptualVolumeToAmplitude(-0.5), equals(0.0));
      expect(perceptualVolumeToAmplitude(1.5), equals(1.0));

      expect(amplitudeToPerceptualVolume(0.0), equals(0.0));
      expect(amplitudeToPerceptualVolume(1.0), equals(1.0));
      expect(amplitudeToPerceptualVolume(-0.2), equals(0.0));
      expect(amplitudeToPerceptualVolume(1.8), equals(1.0));
    });

    test('Key auditory reference points follow cubic scale (p^3)', () {
      // p = 0.10 -> a = 0.001 (-60 dB)
      expect(perceptualVolumeToAmplitude(0.1), closeTo(0.001, 1e-6));

      // p = 0.20 -> a = 0.008 (-41.9 dB) - typical comfortable headphone range
      expect(perceptualVolumeToAmplitude(0.2), closeTo(0.008, 1e-6));

      // p = 0.30 -> a = 0.027 (-31.4 dB)
      expect(perceptualVolumeToAmplitude(0.3), closeTo(0.027, 1e-6));

      // p = 0.50 -> a = 0.125 (-18.0 dB)
      expect(perceptualVolumeToAmplitude(0.5), closeTo(0.125, 1e-6));
    });

    test('Monotonicity and round-trip consistency across [0.0, 1.0]', () {
      double previousAmp = -1.0;
      for (int i = 0; i <= 100; i++) {
        final p = i / 100.0;
        final a = perceptualVolumeToAmplitude(p);
        expect(a, greaterThanOrEqualTo(previousAmp));
        previousAmp = a;

        final recoveredP = amplitudeToPerceptualVolume(a);
        expect(recoveredP, closeTo(p, 1e-5));
      }
    });

    test('Historical user migration: 1% linear amplitude (0.01) maps to ~21.5% perceived slider', () {
      // In historical versions, user had to set volumeDsp to 0.01 (-40 dB) on headphones.
      // After migration, amplitudeToPerceptualVolume(0.01) = (0.01)^(1/3) ≈ 0.21544
      final migratedPerceptual = amplitudeToPerceptualVolume(0.01);
      expect(migratedPerceptual, closeTo(0.2154, 0.001));

      // Verifying that output amplitude from migrated slider preserves the exact original loudness (-40 dB)
      final restoredAmp = perceptualVolumeToAmplitude(migratedPerceptual);
      expect(restoredAmp, closeTo(0.01, 1e-5));
      final db = 20.0 * (math.log(restoredAmp) / math.ln10);
      expect(db, closeTo(-40.0, 0.1));
    });
  });
}
