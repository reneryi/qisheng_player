import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:qisheng_player/play_service/audio_spectrum.dart';

void main() {
  group('shapeFftSpectrum', () {
    test('returns silence for missing or invalid FFT data', () {
      expect(shapeFftSpectrum(const []), isEmpty);
      expect(
        shapeFftSpectrum([
          for (var index = 0; index < 1024; index++)
            switch (index % 3) {
              0 => double.nan,
              1 => double.infinity,
              _ => -1,
            },
        ]),
        isEmpty,
      );
    });

    test('creates 64 finite normalized log-spaced bands', () {
      final fft = List<double>.filled(1024, 0);
      for (var index = 2; index < fft.length; index++) {
        fft[index] = index / fft.length;
      }

      final result = shapeFftSpectrum(fft);

      expect(result, hasLength(audioSpectrumBinCount));
      expect(result.every((value) => value.isFinite), isTrue);
      expect(result.every((value) => value >= 0 && value <= 1), isTrue);
      expect(result.last, greaterThan(result.first));
    });

    test('maps low and high FFT bins to ordered display bands', () {
      final lowFft = List<double>.filled(1024, 0)..[2] = 1;
      final highFft = List<double>.filled(1024, 0)..[900] = 1;

      final low = shapeFftSpectrum(lowFft);
      final high = shapeFftSpectrum(highFft);
      final lowBand = low.indexWhere((value) => value > 0);
      final highBand = high.indexWhere((value) => value > 0);

      expect(lowBand, greaterThanOrEqualTo(0));
      expect(highBand, greaterThan(lowBand));
    });
  });

  group('smoothAudioSpectrum', () {
    test('uses the configured fast attack', () {
      final result = smoothAudioSpectrum(
        previous: List<double>.filled(audioSpectrumBinCount, 0),
        next: List<double>.filled(audioSpectrumBinCount, 1),
        active: true,
      );

      expect(result, hasLength(audioSpectrumBinCount));
      expect(result.first, closeTo(0.45, 0.0001));
    });

    test('uses 0.86 release for falling and paused samples', () {
      final previous = List<double>.filled(audioSpectrumBinCount, 1);
      final falling = smoothAudioSpectrum(
        previous: previous,
        next: List<double>.filled(audioSpectrumBinCount, 0.1),
        active: true,
      );
      final paused = smoothAudioSpectrum(
        previous: previous,
        next: const [],
        active: false,
      );

      expect(falling.first, closeTo(0.86, 0.0001));
      expect(paused.first, closeTo(0.86, 0.0001));
    });

    test('paused values converge to the empty silence sentinel', () {
      List<double> current = List<double>.filled(audioSpectrumBinCount, 1);
      for (var frame = 0; frame < 64; frame++) {
        current = smoothAudioSpectrum(
          previous: current,
          next: const [],
          active: false,
        );
      }

      expect(current, isEmpty);
    });

    test('non-finite samples are normalized to silence', () {
      final result = smoothAudioSpectrum(
        previous: List<double>.filled(audioSpectrumBinCount, 0.5),
        next: [double.nan, double.infinity, double.negativeInfinity],
        active: true,
      );

      expect(result.every((value) => value.isFinite), isTrue);
      expect(result.first, closeTo(0.43, 0.0001));
    });
  });

  group('AudioSpectrumNotifier', () {
    testWidgets('samples lazily and stops after the last listener is removed',
        (tester) async {
      var samples = 0;
      final notifier = AudioSpectrumNotifier(
        sample: () {
          samples++;
          return List<double>.filled(audioSpectrumBinCount, 0.5);
        },
      );
      void listener() {}

      await tester.pump(const Duration(milliseconds: 100));
      expect(samples, 0);

      notifier.addListener(listener);
      await tester.pump(const Duration(milliseconds: 100));
      expect(samples, 3);
      expect(notifier.value, hasLength(audioSpectrumBinCount));

      notifier.removeListener(listener);
      final samplesAtRemoval = samples;
      await tester.pump(const Duration(milliseconds: 100));
      expect(samples, samplesAtRemoval);
      expect(notifier.value, isEmpty);
      notifier.dispose();
    });

    testWidgets('transition requests decay before sampling the new source',
        (tester) async {
      var samples = 0;
      final notifier = AudioSpectrumNotifier(
        sample: () {
          samples++;
          return List<double>.filled(audioSpectrumBinCount, 1);
        },
      );
      void listener() {}
      notifier.addListener(listener);
      await tester.pump(const Duration(milliseconds: 34));
      expect(notifier.value.first, closeTo(0.45, 0.0001));

      notifier.decayToSilence();
      final samplesBeforeDecay = samples;
      for (var frame = 0; frame < 64 && notifier.value.isNotEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(notifier.value, isEmpty);
      expect(samples, samplesBeforeDecay);

      await tester.pump(const Duration(milliseconds: 33));
      expect(samples, samplesBeforeDecay + 1);
      expect(notifier.value, isNotEmpty);
      notifier.dispose();
    });

    testWidgets('dispose cancels an active sampling timer', (tester) async {
      var samples = 0;
      final notifier = AudioSpectrumNotifier(
        sample: () {
          samples++;
          return const [];
        },
      );
      notifier.addListener(() {});
      await tester.pump(const Duration(milliseconds: 34));
      notifier.dispose();
      final samplesAtDispose = samples;

      await tester.pump(const Duration(seconds: 1));
      expect(samples, samplesAtDispose);
    });

    testWidgets('paused lifecycle stops sampling until resumed', (
      tester,
    ) async {
      var samples = 0;
      final notifier = AudioSpectrumNotifier(
        sample: () {
          samples++;
          return List<double>.filled(audioSpectrumBinCount, 0.5);
        },
      );
      notifier.addListener(() {});
      await tester.pump(const Duration(milliseconds: 34));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final samplesAtPause = samples;
      await tester.pump(const Duration(seconds: 1));
      expect(samples, samplesAtPause);
      expect(notifier.value, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 34));
      expect(samples, samplesAtPause + 1);
      notifier.dispose();
    });
  });
}
