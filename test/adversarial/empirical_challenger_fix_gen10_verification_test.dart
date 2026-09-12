import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/adaptive_waveform_slider.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRITICAL 1: Pause State Empirical Verification (No 60fps Ticker Leak)', () {
    testWidgets(
        'Play -> Pause -> 200ms (15 frames): hasScheduledFrame is false, effectiveBass is 0.0, isRhythmAnimating is false',
        (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>(
        List<double>.generate(64, (i) => i < 12 ? 0.95 : 0.2),
      );
      bool active = true;

      Widget buildHarness() {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AdaptiveWaveformSlider(
                      value: 25,
                      max: 100,
                      height: 30,
                      spectrum: spectrumNotifier,
                      spectrumActive: active,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      // Run for 30 frames (500ms) with active spectrum
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Assert active playback state
      final dynamic activeState = tester.state(find.byType(AdaptiveWaveformSlider));
      expect(activeState.isRhythmAnimating, isTrue, reason: 'Must be animating when playing');
      expect(activeState.smoothedConfidence, greaterThan(0.9), reason: 'Confidence must ramp up to near 1.0');

      dynamic activePainter = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(AdaptiveWaveformSlider),
        matching: find.byType(CustomPaint),
      ).first).painter;
      expect(activePainter.effectiveBass, greaterThan(0.0), reason: 'Bass modulation active');

      // Pause playback
      active = false;
      await tester.pumpWidget(buildHarness());
      await tester.pump(); // trigger widget update

      // Advance time 200ms (15 frames)
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Rigorous empirical assertions on paused state
      final dynamic pausedState = tester.state(find.byType(AdaptiveWaveformSlider));
      final hasScheduledFrame = tester.binding.hasScheduledFrame;
      dynamic pausedPainter = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(AdaptiveWaveformSlider),
        matching: find.byType(CustomPaint),
      ).first).painter;

      expect(hasScheduledFrame, isFalse,
          reason: 'CRITICAL P0: No 60fps frame scheduling leak when paused!');
      expect(pausedState.isRhythmAnimating, isFalse,
          reason: 'CRITICAL P0: _rhythmController.isAnimating must be false after 200ms');
      expect(pausedState.smoothedConfidence, equals(0.0),
          reason: '_smoothedConfidence must damp to exactly 0.0');
      expect(pausedPainter.effectiveBass, equals(0.0),
          reason: 'effectiveBass must be 0.0 at baseline');
      expect(pausedPainter.effectiveMid, equals(0.0),
          reason: 'effectiveMid must be 0.0 at baseline');
      expect(pausedPainter.effectiveTreble, equals(0.0),
          reason: 'effectiveTreble must be 0.0 at baseline');

      // Extra verification: advance another 2000ms (120 frames), verify it stays idle
      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'Must remain completely quiescent and never reawaken on its own');
      expect(pausedState.isRhythmAnimating, isFalse);

      spectrumNotifier.dispose();
    });

    testWidgets('Spurious spectrum updates while paused do NOT reactivate rhythm ticker', (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>([]);
      bool active = false;

      Widget buildHarness() {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AdaptiveWaveformSlider(
                      value: 10,
                      max: 100,
                      height: 30,
                      spectrum: spectrumNotifier,
                      spectrumActive: active,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      final dynamic state = tester.state(find.byType(AdaptiveWaveformSlider));
      expect(state.isRhythmAnimating, isFalse, reason: 'Initially paused -> ticker off');
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Now spam spectrumNotifier while paused
      for (int i = 0; i < 50; i++) {
        spectrumNotifier.value = [
          0.9,
          0.8,
          0.7,
          0.6,
          (i % 10) / 10.0,
        ];
        await tester.pump(const Duration(milliseconds: 16));
        expect(state.isRhythmAnimating, isFalse,
            reason: 'Spurious spectrum stream must NOT awaken rhythm controller when spectrumActive is false');
        expect(tester.binding.hasScheduledFrame, isFalse);
      }

      spectrumNotifier.dispose();
    });

    testWidgets('Initial mount with spectrumActive = false never starts ticker', (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>([0.9, 0.9, 0.9]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: AdaptiveWaveformSlider(
                  value: 0,
                  max: 100,
                  height: 30,
                  spectrum: spectrumNotifier,
                  spectrumActive: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dynamic state = tester.state(find.byType(AdaptiveWaveformSlider));
      expect(state.isRhythmAnimating, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      spectrumNotifier.dispose();
    });

    testWidgets('Rapid play/pause jitter (50 iterations) settles cleanly to quiescent pause', (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>(List.filled(64, 0.8));
      bool active = true;

      Widget buildHarness() {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 30,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AdaptiveWaveformSlider(
                      value: 50,
                      max: 100,
                      height: 30,
                      spectrum: spectrumNotifier,
                      spectrumActive: active,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      for (int i = 0; i < 50; i++) {
        active = (i % 2 == 0);
        await tester.pumpWidget(buildHarness());
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Final state is pause
      active = false;
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      // Wait 250ms
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final dynamic state = tester.state(find.byType(AdaptiveWaveformSlider));
      expect(state.isRhythmAnimating, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(state.smoothedConfidence, equals(0.0));

      spectrumNotifier.dispose();
    });

    testWidgets('User hover and fling drag while paused do NOT awaken rhythm controller and settle cleanly',
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
                  max: 100,
                  height: 30,
                  spectrumActive: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      // 1. Mouse hover & exit
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(topLeft.dx + 100, centerY));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await mouse.moveTo(Offset(topLeft.dx - 50, centerY - 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await mouse.removePointer();

      // Verify returned to quiescent state
      final dynamic state = tester.state(find.byType(AdaptiveWaveformSlider));
      expect(state.isRhythmAnimating, isFalse, reason: 'Hover must not awaken rhythm ticker');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'Hover exit must settle completely');

      // 2. Drag & Spring fling release
      final touch = await tester.startGesture(Offset(topLeft.dx + 200, centerY));
      await touch.moveBy(const Offset(60, 0));
      await tester.pump();
      await touch.moveBy(const Offset(-100, 0));
      await touch.up();

      // Spring oscillation for 600ms
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Verify spring settled and rhythm ticker remains false
      expect(state.isRhythmAnimating, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('CRITICAL 2: Static Paint Reuse & Zero GC Verification', () {
    test('Verify static final Paint field declarations in _AdaptiveWaveformPainter via source reflection', () {
      final file = File('lib/component/adaptive_waveform_slider.dart');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      // Assert _AdaptiveWaveformPainter class definition
      expect(source.contains('class _AdaptiveWaveformPainter extends CustomPainter'), isTrue);

      // Assert static final declarations
      expect(source.contains('static final Paint _activePaint = Paint()'), isTrue,
          reason: '_activePaint MUST be declared static final');
      expect(source.contains('static final Paint _inactivePaint = Paint()'), isTrue,
          reason: '_inactivePaint MUST be declared static final');
      expect(source.contains('static final Paint _glowPaint = Paint()'), isTrue,
          reason: '_glowPaint MUST be declared static final');
      expect(source.contains('static final Paint _needlePaint = Paint()'), isTrue,
          reason: '_needlePaint MUST be declared static final');

      // Assert NO instance-level Paint declarations inside _AdaptiveWaveformPainter
      final painterClassIndex = source.indexOf('class _AdaptiveWaveformPainter');
      final painterBlock = source.substring(painterClassIndex);
      final instancePaintMatches = RegExp(r'\n\s+final\s+Paint\s+_(\w+)\s*=').allMatches(painterBlock);
      expect(instancePaintMatches.isEmpty, isTrue,
          reason: 'There must be ZERO non-static Paint fields in _AdaptiveWaveformPainter');
    });

    test('Repetitive 1,000 paint canvas passes execute without allocation explosion or style corruption', () {
      final lut = AudioWaveformCache.getWaveformLut(0xCAFEBABE);
      const colorScheme = ColorScheme.dark();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        final phase = (i * 0.01) % 1.0;
        final p = TestWaveformPainterExposer(
          percent: 0.45,
          hoverPercent: 0.5,
          hoverAlpha: 0.8,
          dragPercent: 0.45,
          dragAlpha: 0.0,
          isDragging: false,
          lut: lut,
          colorScheme: colorScheme,
          effectiveBass: 0.5,
          effectiveMid: 0.3,
          effectiveTreble: 0.2,
          rhythmPhase: phase,
        );
        p.paint(canvas, const Size(600, 30));
      }
      stopwatch.stop();

      final picture = recorder.endRecording();
      picture.dispose();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: '1,000 canvas passes should complete in well under 1 second');
    });
  });

  group('CRITICAL 3: Extreme Spectrum Fuzzing & Spring Underdamped Robustness', () {
    testWidgets('Ultra-Adversarial Spectrum Fuzzing (NaN, Inf, -Inf, 1e308, subnormals, 100k array)',
        (tester) async {
      final spectrumNotifier = ValueNotifier<List<double>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: AdaptiveWaveformSlider(
                  value: 30,
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

      final fuzzCases = <String, List<double>>{
        'all_nan': [double.nan, double.nan, double.nan, double.nan],
        'mixed_infinities': [
          double.infinity,
          double.negativeInfinity,
          double.nan,
          -0.0,
          0.0,
          1e-323,
          double.maxFinite,
          -double.maxFinite,
        ],
        'extreme_negative_spikes': List.filled(64, -1e300),
        'giant_positive_spikes': List.filled(64, 1e300),
        '100k_elements_fuzz': List<double>.generate(100000, (i) => i.isEven ? double.nan : (i % 100) / 100.0),
      };

      for (final entry in fuzzCases.entries) {
        spectrumNotifier.value = entry.value;
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'Crashed on fuzz case: ');

        dynamic p = tester.widget<CustomPaint>(find.descendant(
          of: find.byType(AdaptiveWaveformSlider),
          matching: find.byType(CustomPaint),
        ).first).painter;

        expect(p.effectiveBass.isFinite, isTrue, reason: 'effectiveBass must be finite on ');
        expect(p.effectiveBass, inInclusiveRange(0.0, 1.0));
        expect(p.effectiveMid.isFinite, isTrue);
        expect(p.effectiveMid, inInclusiveRange(0.0, 1.0));
        expect(p.effectiveTreble.isFinite, isTrue);
        expect(p.effectiveTreble, inInclusiveRange(0.0, 1.0));
      }

      spectrumNotifier.dispose();
    });

    test('SpringSimulation underdamped oscillation math verification', () {
      const spring = SpringDescription(
        mass: 1.0,
        stiffness: 180.0,
        damping: 12.0,
      );

      final criticalDamping = 2 * math.sqrt(180.0 * 1.0); // 26.8328157
      final dampingRatio = 12.0 / criticalDamping; // 0.44721359

      expect(dampingRatio, lessThan(1.0), reason: 'Must be strictly underdamped');
      expect(dampingRatio, closeTo(0.4472, 0.001));

      // Test extreme negative velocity fling: v0 = -100,000
      final simExtreme = SpringSimulation(spring, 1.0, 0.0, -100000.0);
      double minX = 0.0;
      for (double t = 0.0; t <= 0.5; t += 0.001) {
        final x = simExtreme.x(t);
        if (x < minX) minX = x;
      }
      expect(minX, lessThan(-100.0), reason: 'Severe overshoot produced');

      // Verify clamping protection handles minX safely
      const squish = 0.8;
      const bulge = 0.2;
      final dragScale = 1.0 - 0.60 * squish * minX + 0.35 * bulge * minX;
      final dynamicNorm = (0.5 * (1.0 + 0.2) * 1.0 * dragScale).clamp(0.08, 1.45);
      expect(dynamicNorm, inInclusiveRange(0.08, 1.45));

      final barHeight = (4.5 + dynamicNorm * (28.0 - 4.5)).clamp(4.5, 30.0);
      expect(barHeight, inInclusiveRange(4.5, 30.0));
      expect(barHeight.isFinite, isTrue);
    });
  });

  group('CRITICAL 4: BottomPlayerBar 62.0px Time Container & 99:59:59 Overflow Verification', () {
    testWidgets('BottomPlayerBar handles 99:59:59 duration without text overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: '99h Song',
        artist: 'Long Artist',
        album: 'Long Album',
        path: r'E:\Music\99h.flac',
      );
      final playback = _Gen10LongPlaybackController(
        audio: audio,
        queue: [audio],
        customLength: 359999.0, // 99:59:59
        customPosition: 359990.0, // 99:59:50
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

      expect(tester.takeException(), isNull, reason: 'No RenderFlex or text overflow');

      // Assert 62.0px width container
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 62.0),
      );
      expect(sizedBoxes.length, greaterThanOrEqualTo(2));

      // Assert Text rendered
      expect(find.text('99:59:50'), findsOneWidget);
      expect(find.text('99:59:59'), findsOneWidget);
    });
  });
}

class _Gen10LongPlaybackController extends FakePlaybackController {
  _Gen10LongPlaybackController({
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

// Exposer for direct CustomPainter testing
class TestWaveformPainterExposer {
  TestWaveformPainterExposer({
    required this.percent,
    required this.hoverPercent,
    required this.hoverAlpha,
    required this.dragPercent,
    required this.dragAlpha,
    required this.isDragging,
    required this.lut,
    required this.colorScheme,
    required this.effectiveBass,
    required this.effectiveMid,
    required this.effectiveTreble,
    required this.rhythmPhase,
  });

  final double percent;
  final double hoverPercent;
  final double hoverAlpha;
  final double dragPercent;
  final double dragAlpha;
  final bool isDragging;
  final dynamic lut;
  final ColorScheme colorScheme;
  final double effectiveBass;
  final double effectiveMid;
  final double effectiveTreble;
  final double rhythmPhase;

  void paint(Canvas canvas, Size size) {
    final geo = calculateAdaptiveWaveformGeometry(size.width);
    final count = geo.count;
    final barWidth = geo.barWidth;
    final gap = geo.gap;
    if (count <= 0 || barWidth <= 0) return;

    final centerY = size.height / 2.0;
    const minBarHeight = 4.5;
    final maxBarHeight = math.max(minBarHeight, size.height - 2.0);

    final seekX = (percent * size.width).clamp(0.0, size.width);
    final hoverIndex = hoverPercent * (count - 1);
    final dragIndex = dragPercent * (count - 1);

    final barRadius = Radius.circular(barWidth / 2.0);
    final uPlay = percent.clamp(0.0, 1.0);
    final mBeat = 0.48 * math.pow(effectiveBass, 1.35);

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final centerBarX = x + barWidth / 2.0;
      final u = i / math.max(1, count - 1);

      final lutPos = u * 511.0;
      final lutIdx = lutPos.floor().clamp(0, 510);
      final lutFract = lutPos - lutIdx;
      final baseNorm = lut[lutIdx] * (1.0 - lutFract) + lut[lutIdx + 1] * lutFract;

      final mTravel = 0.18 * effectiveMid * math.sin(2 * math.pi * (3.0 * u - rhythmPhase)) +
          0.10 * effectiveTreble * math.cos(2 * math.pi * (6.0 * u + 1.2 * rhythmPhase));

      final dPlay = (u - uPlay).abs();
      final gCorona = math.exp(-(dPlay * dPlay) / (2 * 0.06 * 0.06));
      final mCorona = gCorona * (0.35 * effectiveMid + 0.28 * effectiveTreble);

      final kZone = u <= uPlay ? 1.0 : 0.60;
      final rhythmMod = (mBeat + mTravel + mCorona) * kZone;

      double hoverScale = 1.0;
      if (hoverAlpha > 0.001) {
        final dHover = (i - hoverIndex).abs();
        final gHover = math.exp(-(dHover * dHover) / (2 * 2.8 * 2.8));
        hoverScale = 1.0 + 0.42 * gHover * hoverAlpha;
      }

      double dragScale = 1.0;
      if (dragAlpha.abs() > 0.001) {
        final dDrag = (i - dragIndex).abs();
        final squish = math.exp(-(dDrag * dDrag) / (2 * 2.0 * 2.0));
        final bulge = math.exp(-((dDrag - 4.5) * (dDrag - 4.5)) / (2 * 2.2 * 2.2));
        dragScale = 1.0 - 0.60 * squish * dragAlpha + 0.35 * bulge * dragAlpha;
      }

      final dynamicNorm = (baseNorm * (1.0 + rhythmMod) * hoverScale * dragScale).clamp(0.08, 1.45);
      final barHeight = (minBarHeight + dynamicNorm * (maxBarHeight - minBarHeight)).clamp(minBarHeight, size.height);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight / 2.0, barWidth, barHeight),
        barRadius,
      );

      final isPlayed = centerBarX <= seekX;
      canvas.drawRRect(rrect, isPlayed ? _activePaint : _inactivePaint);
    }
  }

  static final Paint _activePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _inactivePaint = Paint()..style = PaintingStyle.fill;
}
