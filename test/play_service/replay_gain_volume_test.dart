import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/smtc_flutter.dart';

class FakeSmtcFlutter implements SmtcFlutter {
  final _controller = StreamController<SMTCControlEvent>.broadcast();
  SMTCState? lastState;
  String? lastTitle;
  int? lastProgress;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> close() async {
    await _controller.close();
  }

  @override
  Stream<SMTCControlEvent> subscribeToControlEvents() => _controller.stream;

  @override
  Future<void> updateDisplay({
    required String title,
    required String artist,
    required String album,
    required int duration,
    required String path,
  }) async {
    lastTitle = title;
  }

  @override
  Future<void> updateState({required SMTCState state}) async {
    lastState = state;
  }

  @override
  Future<void> updateTimeProperties({required int progress}) async {
    lastProgress = progress;
  }
}

Audio createTestAudio({
  required String title,
  double? replayGainDb,
  String path = 'C:\\dummy\\test.flac',
}) {
  return Audio(
    title,
    'TestArtist',
    'TestAlbum',
    null,
    null,
    1,
    1,
    180,
    320,
    44100,
    replayGainDb,
    null,
    null,
    null,
    path,
    1,
    1,
    'FLAC',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => '.',
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  group('R5: calculateReplayGainVolume Pure Function Tests', () {
    test('Negative dB (e.g. -6 dB) results in attenuation (~0.501)', () {
      final output = calculateReplayGainVolume(
        baseVolume: 1.0,
        enableVolumeLeveling: true,
        replayGainDb: -6.0,
        preampDb: 0.0,
      );
      // 10^(-6.0 / 20.0) = 10^(-0.3) ≈ 0.5011872
      final expectedScale = math.pow(10.0, -6.0 / 20.0).toDouble();
      expect(output, closeTo(expectedScale, 0.0001));
      expect(output, closeTo(0.5012, 0.001));
      expect(output, lessThan(1.0));
    });

    test('Positive dB (e.g. +3 dB) results in amplification (~1.413)', () {
      final output = calculateReplayGainVolume(
        baseVolume: 1.0,
        enableVolumeLeveling: true,
        replayGainDb: 3.0,
        preampDb: 0.0,
      );
      // 10^(3.0 / 20.0) = 10^(0.15) ≈ 1.4125375
      final expectedScale = math.pow(10.0, 3.0 / 20.0).toDouble();
      expect(output, closeTo(expectedScale, 0.0001));
      expect(output, closeTo(1.4125, 0.001));
      expect(output, greaterThan(1.0));
    });

    test('Zero base volume produces exactly 0.0 (no mute leakage)', () {
      // Test with positive gain, negative gain, and zero gain
      expect(
        calculateReplayGainVolume(
          baseVolume: 0.0,
          enableVolumeLeveling: true,
          replayGainDb: 6.0,
          preampDb: 0.0,
        ),
        equals(0.0),
      );

      expect(
        calculateReplayGainVolume(
          baseVolume: 0.0,
          enableVolumeLeveling: true,
          replayGainDb: -6.0,
          preampDb: 0.0,
        ),
        equals(0.0),
      );

      expect(
        calculateReplayGainVolume(
          baseVolume: 0.0,
          enableVolumeLeveling: true,
          replayGainDb: 0.0,
          preampDb: 4.0,
        ),
        equals(0.0),
      );

      // Negative base volume also returns 0.0
      expect(
        calculateReplayGainVolume(
          baseVolume: -0.05,
          enableVolumeLeveling: true,
          replayGainDb: 5.0,
          preampDb: 0.0,
        ),
        equals(0.0),
      );
    });

    test('Volume leveling disabled returns base volume unchanged', () {
      const baseVol = 0.85;
      expect(
        calculateReplayGainVolume(
          baseVolume: baseVol,
          enableVolumeLeveling: false,
          replayGainDb: -8.0,
          preampDb: 4.0,
        ),
        equals(baseVol),
      );

      expect(
        calculateReplayGainVolume(
          baseVolume: baseVol,
          enableVolumeLeveling: false,
          replayGainDb: 6.0,
          preampDb: -2.0,
        ),
        equals(baseVol),
      );
    });

    test('Null replayGainDb returns base volume unchanged', () {
      const baseVol = 0.7;
      expect(
        calculateReplayGainVolume(
          baseVolume: baseVol,
          enableVolumeLeveling: true,
          replayGainDb: null,
          preampDb: 3.0,
        ),
        equals(baseVol),
      );
    });

    test('Preamp dB works additively with track gain dB', () {
      // -6 dB gain + 6 dB preamp = 0 dB compensation -> scale = 1.0
      expect(
        calculateReplayGainVolume(
          baseVolume: 0.8,
          enableVolumeLeveling: true,
          replayGainDb: -6.0,
          preampDb: 6.0,
        ),
        closeTo(0.8, 0.0001),
      );

      // -4 dB gain + 1 dB preamp = -3 dB compensation
      final expected = 0.8 * math.pow(10.0, -3.0 / 20.0).toDouble();
      expect(
        calculateReplayGainVolume(
          baseVolume: 0.8,
          enableVolumeLeveling: true,
          replayGainDb: -4.0,
          preampDb: 1.0,
        ),
        closeTo(expected, 0.0001),
      );

      // +2 dB gain + (-2 dB) preamp = 0 dB compensation
      expect(
        calculateReplayGainVolume(
          baseVolume: 0.6,
          enableVolumeLeveling: true,
          replayGainDb: 2.0,
          preampDb: -2.0,
        ),
        closeTo(0.6, 0.0001),
      );
    });

    test('Clamping behavior: does not force lower bound to 0.05, caps at 3.0', () {
      // Small volume: baseVolume 0.01 with -20 dB gain (scale 0.1) -> 0.001 (should not jump to 0.05)
      final smallOutput = calculateReplayGainVolume(
        baseVolume: 0.01,
        enableVolumeLeveling: true,
        replayGainDb: -20.0,
        preampDb: 0.0,
      );
      expect(smallOutput, closeTo(0.001, 0.0001));
      expect(smallOutput, lessThan(0.05));

      // Large amplification: baseVolume 1.0 with +20 dB gain (scale 10.0) -> capped at 3.0
      final largeOutput = calculateReplayGainVolume(
        baseVolume: 1.0,
        enableVolumeLeveling: true,
        replayGainDb: 20.0,
        preampDb: 0.0,
      );
      expect(largeOutput, equals(3.0));
    });
  });

  group('R5: PlaybackService Integration Tests', () {
    late FakeSmtcFlutter fakeSmtc;
    late BassPlayer player;

    setUp(() {
      fakeSmtc = FakeSmtcFlutter();
      player = BassPlayer();
    });

    test('resolveOutputVolumeDsp integrates with preference and audio metadata', () {
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        true,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = PlaybackService(
        PlayService.instance,
        player: player,
        smtc: fakeSmtc,
        preferenceOverride: pref,
      );

      final loudAudio = createTestAudio(
        title: 'Loud Track',
        replayGainDb: -6.0,
      );

      final quietAudio = createTestAudio(
        title: 'Quiet Track',
        replayGainDb: 3.0,
      );

      final noGainAudio = createTestAudio(
        title: 'No Gain Track',
        replayGainDb: null,
      );

      // 1. Loud audio attenuated
      final loudVol = playback.resolveOutputVolumeDsp(loudAudio);
      expect(loudVol, closeTo(0.5012, 0.001));

      // 2. Quiet audio amplified
      final quietVol = playback.resolveOutputVolumeDsp(quietAudio);
      expect(quietVol, closeTo(1.4125, 0.001));

      // 3. No gain metadata returns base volume
      final noGainVol = playback.resolveOutputVolumeDsp(noGainAudio);
      expect(noGainVol, equals(1.0));

      // 4. Null audio returns base volume
      final nullAudioVol = playback.resolveOutputVolumeDsp(null);
      expect(nullAudioVol, equals(1.0));

      // 5. Mute setting returns 0.0
      playback.setVolumeDsp(0.0);
      expect(playback.resolveOutputVolumeDsp(loudAudio), equals(0.0));
      expect(playback.resolveOutputVolumeDsp(quietAudio), equals(0.0));
      expect(playback.resolveOutputVolumeDsp(noGainAudio), equals(0.0));

      // 6. Restore volume and test preamp
      playback.setVolumeDsp(1.0);
      playback.setVolumeLevelingPreampDb(6.0);
      // -6.0 dB + 6.0 dB preamp = 0.0 dB -> scale 1.0 -> output 1.0
      expect(playback.resolveOutputVolumeDsp(loudAudio), closeTo(1.0, 0.0001));

      // 7. Disable volume leveling returns baseVolume
      playback.setEnableVolumeLeveling(false);
      expect(playback.resolveOutputVolumeDsp(loudAudio), equals(1.0));
      expect(playback.resolveOutputVolumeDsp(quietAudio), equals(1.0));
    });
  });
}
