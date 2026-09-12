import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/adaptive_waveform_slider.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/dual_layer_rhythm_slider.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';
import 'package:qisheng_player/lyric/lrc.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppSettings.instance.progressBarTypeNotifier.value =
        ProgressBarType.fluidGlow;
  });

  // =========================================================================
  // 1. FluidGlowProgressSlider (方案一：全宽流体微光交互轨)
  // =========================================================================
  group('FluidGlowProgressSlider', () {
    testWidgets('adapts to full available container width with zero dead zone',
        (tester) async {
      double? changedVal;
      double? endVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: FluidGlowProgressSlider(
                  value: 30,
                  max: 120,
                  onChanged: (v) => changedVal = v,
                  onChangeEnd: (v) => endVal = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
      expect(box.size.width, equals(600.0));
      expect(box.size.height, equals(20.0));

      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      // Tap near the very left edge (x=6px) - should register without dead zone
      await tester.tapAt(Offset(topLeft.dx + 6, centerY));
      await tester.pump();
      expect(changedVal, isNotNull);
      expect(changedVal!, closeTo(1.2, 0.5));
      expect(endVal, isNotNull);
      expect(endVal!, closeTo(1.2, 0.5));

      // Tap near the right edge (x=594px) - should register near end
      await tester.tapAt(Offset(topLeft.dx + 594, centerY));
      await tester.pump();
      expect(endVal!, closeTo(118.8, 0.5));
    });

    testWidgets('hover expands track and reveals time bubble tooltip',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                child: FluidGlowProgressSlider(
                  value: 45,
                  max: 180,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      // Initially no tooltip is visible
      expect(find.text('0:01:30'), findsNothing);

      // Hover mouse at x=250 (which corresponds to 50% = 90 seconds = 0:01:30)
      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(topLeft.dx - 50, centerY));
      await gesture.moveTo(Offset(topLeft.dx + 250, centerY));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tooltip should be visible with formatted time
      expect(find.text('0:01:30'), findsOneWidget);

      // Move mouse away
      await gesture.moveTo(Offset(topLeft.dx - 50, centerY - 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('0:01:30'), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('mouse wheel steps +/- 5 seconds with throttle',
        (tester) async {
      double? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: FluidGlowProgressSlider(
                  value: 60,
                  max: 120,
                  onChangeEnd: (v) => seekTarget = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
      final center = box.localToGlobal(box.size.center(Offset.zero));

      // Scroll up (negative scrollDelta) -> forward 5 seconds (60 -> 65)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(seekTarget, equals(65.0));

      // Scroll down (positive scrollDelta) -> rewind 5 seconds (60 -> 55)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(seekTarget, equals(55.0));
    });

    testWidgets('dense height (14.0) renders without layout overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 14.0,
                child: FluidGlowProgressSlider(
                  value: 10,
                  max: 60,
                  height: 14.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 2. AdaptiveWaveformSlider (方案二：自适应动态果冻声波轨)
  // =========================================================================
  group('AdaptiveWaveformSlider', () {
    test('calculateAdaptiveWaveformGeometry guarantees exact boundary alignment',
        () {
      for (final width in [120.0, 320.0, 500.0, 720.5, 1024.0, 1440.0]) {
        final geo = calculateAdaptiveWaveformGeometry(width);
        expect(geo.count, greaterThanOrEqualTo(24));
        expect(geo.count, lessThanOrEqualTo(240));

        final totalSpan = geo.count * geo.barWidth + (geo.count - 1) * geo.gap;
        expect(totalSpan, closeTo(width, 1e-6),
            reason: 'Width $width should be exactly covered by columns');
      }
    });

    test('generateAudioWaveformSeed produces deterministic and distinct hashes',
        () {
      final audio1 = TestAudio(
        title: 'Song Alpha',
        artist: 'Artist 1',
        album: 'Album 1',
        path: 'E:/Music/track1.flac',
      );

      final audio2 = TestAudio(
        title: 'Song Beta',
        artist: 'Artist 2',
        album: 'Album 2',
        path: 'E:/Music/track2.flac',
      );

      final seed1 = generateAudioWaveformSeed(audio1);
      final seed1Again = generateAudioWaveformSeed(audio1);
      final seed2 = generateAudioWaveformSeed(audio2);
      final seedNull = generateAudioWaveformSeed(null);

      expect(seed1, equals(seed1Again));
      expect(seed1, isNot(equals(seed2)));
      expect(seed1, isNot(equals(seedNull)));

      final lut1 = AudioWaveformCache.getWaveformLut(seed1);
      final lut2 = AudioWaveformCache.getWaveformLut(seed2);
      expect(lut1.length, equals(512));
      expect(lut2.length, equals(512));
      expect(lut1, isNot(equals(lut2)));
    });

    testWidgets(
        'drag gesture and SpringSimulation release execute smoothly without crash',
        (tester) async {
      double? changedVal;
      double? endVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                child: AdaptiveWaveformSlider(
                  value: 30,
                  max: 100,
                  onChanged: (v) => changedVal = v,
                  onChangeEnd: (v) => endVal = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      // Start drag at x=100 (20%) -> drag to x=300 (60%) -> release
      final gesture =
          await tester.startGesture(Offset(topLeft.dx + 100, centerY));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(Offset(topLeft.dx + 300, centerY));
      await tester.pump();
      expect(changedVal, isNotNull);
      expect(changedVal!, closeTo(60.0, 1.0));

      await gesture.up();
      await tester.pump();
      expect(endVal, isNotNull);
      expect(endVal!, closeTo(60.0, 1.0));

      // Advance physics spring simulation oscillation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('wheel scroll steps +/- 5 seconds on AdaptiveWaveformSlider',
        (tester) async {
      double? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: AdaptiveWaveformSlider(
                  value: 40,
                  max: 100,
                  onChangeEnd: (v) => seekTarget = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
      final center = box.localToGlobal(box.size.center(Offset.zero));

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(seekTarget, equals(45.0));
    });
  });

  // =========================================================================
  // 3. DualLayerRhythmSlider (方案三：双层灵动呼吸光轨)
  // =========================================================================
  group('DualLayerRhythmSlider', () {
    test('resolveSpectrumEnergy extracts bass, mid, treble accurately', () {
      // Null / empty safely resolves to zero
      expect(resolveSpectrumEnergy(null).hasRealFft, isFalse);
      expect(resolveSpectrumEnergy([]).hasRealFft, isFalse);

      // Pure low-frequency pulse (first 6 bins high)
      final lowBins = List<double>.filled(64, 0.0);
      for (int i = 0; i < 6; i++) {
        lowBins[i] = 0.9;
      }
      final lowEnergy = resolveSpectrumEnergy(lowBins);
      expect(lowEnergy.bass, greaterThan(0.3));
      expect(lowEnergy.mid, equals(0.0));
      expect(lowEnergy.treble, equals(0.0));
      expect(lowEnergy.hasRealFft, isTrue);

      // Pure mid-frequency pulse (bins 15..25 high)
      final midBins = List<double>.filled(64, 0.0);
      for (int i = 15; i < 25; i++) {
        midBins[i] = 0.8;
      }
      final midEnergy = resolveSpectrumEnergy(midBins);
      expect(midEnergy.bass, equals(0.0));
      expect(midEnergy.mid, greaterThan(0.2));
      expect(midEnergy.treble, equals(0.0));
    });

    testWidgets(
        'renders top timeline and bottom rhythm ambient without errors even with empty spectrum',
        (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                child: DualLayerRhythmSlider(
                  value: 30,
                  max: 150,
                  spectrum: spectrumNotifier,
                  spectrumActive: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Simulate incoming FFT data
      spectrumNotifier.value = List<double>.generate(64, (i) => (i % 8) * 0.1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Clean disposal
      spectrumNotifier.dispose();
    });

    testWidgets('handles boundary values (max=0, value=0) gracefully',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: DualLayerRhythmSlider(
                  value: 0,
                  max: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'smoothly calms down ribbons when paused and blooms ribbons when resumed',
        (tester) async {
      bool active = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: DualLayerRhythmSlider(
                      value: 50,
                      max: 100,
                      spectrumActive: active,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Now pause playback
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: DualLayerRhythmSlider(
                      value: 50,
                      max: 100,
                      spectrumActive: false,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      // Advance through 350ms calm-down damping animation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Resume playback
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: DualLayerRhythmSlider(
                      value: 50,
                      max: 100,
                      spectrumActive: true,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 4. BottomPlayerBar 集成联动与热插拔测试
  // =========================================================================
  group('BottomPlayerBar Dynamic Slider Integration', () {
    testWidgets('hot-switches seamlessly across all three styles in live player bar',
        (tester) async {
      final audio = TestAudio(
        title: 'Full Suite Song',
        artist: 'Suite Artist',
        album: 'Suite Album',
        path: r'E:\Music\suite.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Center(
            child: SizedBox(
              width: 960,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Initial default is FluidGlowProgressSlider
      expect(find.byType(FluidGlowProgressSlider), findsOneWidget);
      expect(find.byType(AdaptiveWaveformSlider), findsNothing);
      expect(find.byType(DualLayerRhythmSlider), findsNothing);

      // 2. Switch to AdaptiveWaveformSlider
      AppSettings.instance.progressBarType = ProgressBarType.adaptiveWaveform;
      await tester.pump();
      expect(find.byType(FluidGlowProgressSlider), findsNothing);
      expect(find.byType(AdaptiveWaveformSlider), findsOneWidget);
      expect(find.byType(DualLayerRhythmSlider), findsNothing);

      // 3. Switch to DualLayerRhythmSlider
      AppSettings.instance.progressBarType = ProgressBarType.dualLayerRhythm;
      await tester.pump();
      expect(find.byType(FluidGlowProgressSlider), findsNothing);
      expect(find.byType(AdaptiveWaveformSlider), findsNothing);
      expect(find.byType(DualLayerRhythmSlider), findsOneWidget);

      // 4. Switch back to FluidGlowProgressSlider
      AppSettings.instance.progressBarType = ProgressBarType.fluidGlow;
      await tester.pump();
      expect(find.byType(FluidGlowProgressSlider), findsOneWidget);
      expect(find.byType(AdaptiveWaveformSlider), findsNothing);
      expect(find.byType(DualLayerRhythmSlider), findsNothing);

      // Advance debounce timer
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
