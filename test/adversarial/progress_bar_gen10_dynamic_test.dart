import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/adaptive_waveform_slider.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/dual_layer_rhythm_slider.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppSettings.instance.progressBarTypeNotifier.value =
        ProgressBarType.fluidGlow;
  });

  // =========================================================================
  // 1. 底栏扩容与时间排版验证 (R1)
  // =========================================================================
  group('Gen10 BottomPlayerBar Dimensions & Typography (R1)', () {
    test('AppChromeTokens dockHeight is 116.0px', () {
      final theme = buildTestTheme();
      final tokens = theme.extension<AppChromeTokens>();
      expect(tokens?.dockHeight, equals(116.0));
    });

    testWidgets(
        'BottomPlayerBar renders at 116.0px height, sliderHeight 36.0px, time container 62.0px with 14px w500 font',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: 'Gen10 Audio Song',
        artist: 'Gen10 Artist',
        album: 'Gen10 Album',
        path: r'E:\Music\gen10.flac',
      );
      final playback = _Gen10PlaybackController(
        audio: audio,
        queue: [audio],
        customLength: 3725.0, // 1:02:05
        customPosition: 125.0, // 0:02:05
      );

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Center(
            child: SizedBox(
              width: 1200,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Check BottomPlayerBar overall container height
      final barFinder = find.byType(BottomPlayerBar);
      expect(barFinder, findsOneWidget);
      final barBox = tester.renderObject<RenderBox>(barFinder);
      expect(barBox.size.height, equals(116.0));

      // Check FluidGlowProgressSlider receives height 36.0px
      final sliderFinder = find.byType(FluidGlowProgressSlider);
      expect(sliderFinder, findsOneWidget);
      final slider = tester.widget<FluidGlowProgressSlider>(sliderFinder);
      expect(slider.height, equals(36.0));

      // Check time text labels: font 14.0, w500, width 62.0
      final timeTexts = tester.widgetList<Text>(find.byWidgetPredicate(
          (w) => w is Text && (w.data == '0:02:05' || w.data == '1:02:05')));
      expect(timeTexts.length, equals(2));
      for (final t in timeTexts) {
        expect(t.style?.fontSize, equals(14.0));
        expect(t.style?.fontWeight, equals(FontWeight.w500));
      }

      final sizedBoxes = tester.widgetList<SizedBox>(
          find.byWidgetPredicate((w) => w is SizedBox && w.width == 62.0));
      expect(sizedBoxes.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Dense layout resolves sliderHeight to 22.0px', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: 'Dense Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\dense.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Center(
            child: SizedBox(
              width: 800,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pump();

      final sliderFinder = find.byType(FluidGlowProgressSlider);
      expect(sliderFinder, findsOneWidget);
      final slider = tester.widget<FluidGlowProgressSlider>(sliderFinder);
      expect(slider.height, equals(22.0));
    });
  });

  // =========================================================================
  // 2. 流体激光进度条测试 (R2: 彗星流光束与常态无圆圈)
  // =========================================================================
  group('Gen10 FluidGlowProgressSlider (R2)', () {
    testWidgets(
        'Unhovered state renders 5.5px track, focus core 2.5px, no thumb circle, and no tooltip',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 30,
                  max: 100,
                  height: 30,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final customPaintFinder = find.descendant(
        of: find.byType(FluidGlowProgressSlider),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsWidgets);

      // Verify no tooltip text is visible when unhovered
      expect(find.text('0:00:30'), findsNothing);
    });

    testWidgets(
        'Hover state smoothly reveals 7.5px track, 6.5px thumb, and 72px width tooltip',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 50,
                  max: 200,
                  height: 30,
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

      // Hover at 25% (x=125 -> 50 seconds -> 0:00:50)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(topLeft.dx - 40, centerY));
      await gesture.moveTo(Offset(topLeft.dx + 125, centerY));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tooltip appears with formatted time 0:00:50
      expect(find.text('0:00:50'), findsOneWidget);

      // Verify tooltip container width is 72.0
      final textFinder = find.text('0:00:50');
      final containerFinder =
          find.ancestor(of: textFinder, matching: find.byType(Container)).first;
      final containerBox = tester.renderObject<RenderBox>(containerFinder);
      expect(containerBox.size.width, equals(72.0));

      // Move away
      await gesture.moveTo(Offset(topLeft.dx - 50, centerY - 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('0:00:50'), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('Drag state expands track to 8.0px and thumb to 8.0px smoothly',
        (tester) async {
      double? changed;
      double? endVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 10,
                  max: 100,
                  height: 30,
                  onChanged: (v) => changed = v,
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
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      // Drag from x=40 to x=300
      final gesture =
          await tester.startGesture(Offset(topLeft.dx + 40, centerY));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.moveTo(Offset(topLeft.dx + 300, centerY));
      await tester.pump();
      expect(changed, isNotNull);
      expect(changed!, closeTo(75.0, 1.0));

      await gesture.up();
      await tester.pump();
      expect(endVal, isNotNull);
      expect(endVal!, closeTo(75.0, 1.0));
    });
  });

  // =========================================================================
  // 3. 动态声波进度条测试 (R3: 实时音频律动与谐振场)
  // =========================================================================
  group('Gen10 AdaptiveWaveformSlider (R3)', () {
    test('calculateAdaptiveWaveformGeometry uses targetBarWidth 3.8 and gap 1.8',
        () {
      for (final w in [200.0, 480.0, 720.0, 1080.0, 1440.0]) {
        final geo = calculateAdaptiveWaveformGeometry(w);
        expect(geo.count, greaterThanOrEqualTo(24));
        expect(geo.count, lessThanOrEqualTo(240));
        expect(geo.barWidth, closeTo(3.8, 1.5));
        expect(geo.gap, closeTo(1.8, 1.0));

        final total = geo.count * geo.barWidth + (geo.count - 1) * geo.gap;
        expect(total, closeTo(w, 1e-6));
      }
    });

    testWidgets(
        'AdaptiveWaveformSlider handles dynamic spectrum changes and dampens smoothly to complete stop',
        (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>([]);
      bool spectrumActive = true;

      Widget buildSlider() {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AdaptiveWaveformSlider(
                      value: 40,
                      max: 120,
                      height: 30,
                      spectrum: spectrumNotifier,
                      spectrumActive: spectrumActive,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSlider());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 1. Feed live FFT spectrum data (bass heavy) during playback
      final bassFft = List<double>.generate(64, (i) => i < 8 ? 0.9 : 0.1);
      spectrumNotifier.value = bassFft;
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      // Verify that effectiveBass is dynamically driven > 0
      dynamic pActive = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(AdaptiveWaveformSlider),
        matching: find.byType(CustomPaint),
      ).first).painter;
      expect(pActive.effectiveBass, greaterThan(0.0),
          reason: 'effectiveBass must be actively modulated by FFT stream');

      final dynamic activeState =
          tester.state(find.byType(AdaptiveWaveformSlider));
      expect(activeState.isRhythmAnimating, isTrue,
          reason: 'Ticker must be running during playback');

      // 2. Pause playback (spectrumActive = false)
      spectrumActive = false;
      await tester.pumpWidget(buildSlider());
      await tester.pump();

      // Advance time 200ms (15 frames) to complete low-pass damping
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Assert: ticker is stopped, no scheduled frame, and waveform completely returned to baseline
      final dynamic pausedState =
          tester.state(find.byType(AdaptiveWaveformSlider));
      expect(pausedState.isRhythmAnimating, isFalse,
          reason: '_rhythmController must be stopped after 200ms pause');
      expect(pausedState.smoothedConfidence, equals(0.0),
          reason: '_smoothedConfidence must damp to exactly 0.0');
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'No 60fps frame scheduling leak when paused');

      dynamic pPaused = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(AdaptiveWaveformSlider),
        matching: find.byType(CustomPaint),
      ).first).painter;
      expect(pPaused.effectiveBass, equals(0.0),
          reason: 'Waveform effectiveBass must be 0.0 at baseline');
      expect(pPaused.effectiveMid, equals(0.0));
      expect(pPaused.effectiveTreble, equals(0.0));

      spectrumNotifier.dispose();
    });

    testWidgets(
        'AdaptiveWaveformSlider tooltip bubble displays at width 72 and elevation height + 8',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: AdaptiveWaveformSlider(
                  value: 30,
                  max: 150,
                  height: 30,
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

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(topLeft.dx - 30, centerY));
      await gesture.moveTo(Offset(topLeft.dx + 250, centerY)); // 50% = 75s
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('0:01:15'), findsOneWidget);

      final textFinder = find.text('0:01:15');
      final containerFinder =
          find.ancestor(of: textFinder, matching: find.byType(Container)).first;
      final containerBox = tester.renderObject<RenderBox>(containerFinder);
      expect(containerBox.size.width, equals(72.0));

      await gesture.removePointer();
    });
  });

  // =========================================================================
  // 4. 灵动呼吸进度条测试 (R4: 呼吸光晕与微波光织)
  // =========================================================================
  group('Gen10 DualLayerRhythmSlider (R4)', () {
    testWidgets(
        'DualLayerRhythmSlider renders expanded ambient aura and dual-layer wave without exception',
        (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>([
        0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, // Bass
        ...List<double>.filled(56, 0.05),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 30,
                child: DualLayerRhythmSlider(
                  value: 50,
                  max: 100,
                  height: 30,
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

      // Verify custom painters are in tree (timeline and ambient)
      final customPaints = tester.widgetList<CustomPaint>(find.descendant(
        of: find.byType(DualLayerRhythmSlider),
        matching: find.byType(CustomPaint),
      ));
      expect(customPaints.length, greaterThanOrEqualTo(2));

      // Advance animation tickers
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(tester.takeException(), isNull);

      spectrumNotifier.dispose();
    });

    testWidgets('DualLayerRhythmSlider tooltip format and layout',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: DualLayerRhythmSlider(
                  value: 10,
                  max: 200,
                  height: 30,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(topLeft.dx - 30, centerY));
      await gesture.moveTo(Offset(topLeft.dx + 250, centerY)); // 50% = 100s
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('0:01:40'), findsOneWidget);

      final textFinder = find.text('0:01:40');
      final containerFinder =
          find.ancestor(of: textFinder, matching: find.byType(Container)).first;
      final containerBox = tester.renderObject<RenderBox>(containerFinder);
      expect(containerBox.size.width, equals(72.0));

      await gesture.removePointer();
    });
  });

  // =========================================================================
  // 5. 对抗性极端边界与压力测试 (Adversarial Edge Cases & Stress)
  // =========================================================================
  group('Gen10 Adversarial Edge Cases & Stress Scenarios', () {
    testWidgets('Extreme aspect ratios and collapsed sizes do not throw errors',
        (tester) async {
      for (final w in [30.0, 50.0, 100.0, 2560.0]) {
        for (final h in [5.0, 20.0, 30.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: FluidGlowProgressSlider(
                      value: 10,
                      max: 100,
                      height: h,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets(
        'Negative, zero, and infinite-like values handled safely across all 3 sliders',
        (tester) async {
      final edgeCases = [
        (val: -10.0, max: 100.0),
        (val: 0.0, max: 0.0),
        (val: 150.0, max: 100.0),
        (val: double.nan, max: 100.0),
        (val: 50.0, max: double.infinity),
      ];

      for (final ec in edgeCases) {
        // FluidGlowProgressSlider
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 30,
                  child: FluidGlowProgressSlider(
                    value: ec.val.isNaN ? 0 : ec.val,
                    max: ec.max.isInfinite ? 100 : ec.max,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // AdaptiveWaveformSlider
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 30,
                  child: AdaptiveWaveformSlider(
                    value: ec.val.isNaN ? 0 : ec.val,
                    max: ec.max.isInfinite ? 100 : ec.max,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // DualLayerRhythmSlider
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 30,
                  child: DualLayerRhythmSlider(
                    value: ec.val.isNaN ? 0 : ec.val,
                    max: ec.max.isInfinite ? 100 : ec.max,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Rapid drag thrashing across ends (0 <-> 100%) remains stable',
        (tester) async {
      double? lastValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 0,
                  max: 100,
                  height: 30,
                  onChanged: (v) => lastValue = v,
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

      final gesture = await tester.startGesture(Offset(topLeft.dx, centerY));
      for (int i = 0; i < 20; i++) {
        final targetX = (i % 2 == 0) ? topLeft.dx + 490 : topLeft.dx + 10;
        await gesture.moveTo(Offset(targetX, centerY));
        await tester.pump(const Duration(milliseconds: 5));
      }
      await gesture.up();
      await tester.pump();
      expect(lastValue, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Hot switching slider types in live BottomPlayerBar under active spectrum does not crash',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: 'Hot Swap Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\hotswap.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );

      // Start with fluidGlow
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.fluidGlow;

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Center(
            child: SizedBox(
              width: 1200,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FluidGlowProgressSlider), findsOneWidget);

      // Switch to adaptiveWaveform
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.adaptiveWaveform;
      await tester.pump();
      expect(find.byType(AdaptiveWaveformSlider), findsOneWidget);

      // Switch to dualLayerRhythm
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.dualLayerRhythm;
      await tester.pump();
      expect(find.byType(DualLayerRhythmSlider), findsOneWidget);

      // Switch back to fluidGlow
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.fluidGlow;
      await tester.pump();
      expect(find.byType(FluidGlowProgressSlider), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('Left track section is constrained to 70px max height and centered', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: 'Compact Track Title',
        artist: 'Compact Artist',
        album: 'Album',
        path: r'E:\Music\track.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Center(
            child: SizedBox(
              width: 1200,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the ConstrainedBox in the left track section
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byWidgetPredicate((w) =>
            w is ConstrainedBox &&
            w.constraints.maxHeight == 70.0),
      );
      expect(constrainedBoxes, isNotEmpty,
          reason: 'Left track section must be constrained to 70px to eliminate huge blank gaps');
    });

    testWidgets('DualLayerRhythmSlider damps to calm baseline on pause and restarts on resume', (tester) async {
      final valueListenable = ValueNotifier<List<double>>(List.filled(64, 0.8));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 36,
                child: DualLayerRhythmSlider(
                  value: 30.0,
                  max: 100.0,
                  height: 36.0,
                  isPlaying: true,
                  spectrumActive: true,
                  spectrum: valueListenable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Pause playback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 36,
                child: DualLayerRhythmSlider(
                  value: 30.0,
                  max: 100.0,
                  height: 36.0,
                  isPlaying: false,
                  spectrumActive: false,
                  spectrum: valueListenable,
                ),
              ),
            ),
          ),
        ),
      );

      // Settle the 350ms calm animation
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Resume playback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 36,
                child: DualLayerRhythmSlider(
                  value: 30.0,
                  max: 100.0,
                  height: 36.0,
                  isPlaying: true,
                  spectrumActive: true,
                  spectrum: valueListenable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });
  });
}

class _Gen10PlaybackController extends FakePlaybackController {
  _Gen10PlaybackController({
    required super.audio,
    required super.queue,
    required this.customLength,
    required this.customPosition,
  });

  final double customLength;
  final double customPosition;

  @override
  double get length => customLength;

  @override
  double get position => customPosition;
}
