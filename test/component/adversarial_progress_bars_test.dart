import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/adaptive_waveform_slider.dart';
import 'package:qisheng_player/component/dual_layer_rhythm_slider.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 对抗测试 1: 极端视口与尺寸 (Extreme Viewport & Dimensions)
  // 宽度: 50px, 80px, 120px, 320px, 3840px
  // 高度: 14px (dense), 8px, 0px
  // =========================================================================
  group('Adversarial Viewport & Dimensions Test', () {
    final widths = [50.0, 80.0, 120.0, 320.0, 3840.0];
    final heights = [14.0, 8.0, 0.0];

    for (final w in widths) {
      for (final h in heights) {
        testWidgets(
            'FluidGlowProgressSlider renders cleanly at viewport W=${w}px, H=${h}px without overflow',
            (tester) async {
          tester.view.physicalSize = Size(math.max(w, 800.0), 600.0);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          double? changedVal;
          double? endVal;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: FluidGlowProgressSlider(
                      value: 25.0,
                      max: 100.0,
                      height: h,
                      onChanged: (v) => changedVal = v,
                      onChangeEnd: (v) => endVal = v,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          // If height > 0, test tap interaction at center
          if (h > 0) {
            final box = tester
                .renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
            final center = box.localToGlobal(Offset(w / 2.0, h / 2.0));
            await tester.tapAt(center);
            await tester.pump();
            expect(changedVal, isNotNull);
            expect(changedVal!, closeTo(50.0, 2.0));
            expect(endVal, isNotNull);
            expect(endVal!, closeTo(50.0, 2.0));
          }
        });

        testWidgets(
            'AdaptiveWaveformSlider renders cleanly at viewport W=${w}px, H=${h}px without overflow',
            (tester) async {
          tester.view.physicalSize = Size(math.max(w, 800.0), 600.0);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          double? changedVal;
          double? endVal;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: AdaptiveWaveformSlider(
                      value: 25.0,
                      max: 100.0,
                      height: h,
                      onChanged: (v) => changedVal = v,
                      onChangeEnd: (v) => endVal = v,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          if (h > 0) {
            final box = tester
                .renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
            final center = box.localToGlobal(Offset(w / 2.0, h / 2.0));
            await tester.tapAt(center);
            await tester.pump();
            expect(changedVal, isNotNull);
            expect(changedVal!, closeTo(50.0, 2.0));
            expect(endVal, isNotNull);
            expect(endVal!, closeTo(50.0, 2.0));
          }
        });

        testWidgets(
            'DualLayerRhythmSlider renders cleanly at viewport W=${w}px, H=${h}px without overflow',
            (tester) async {
          tester.view.physicalSize = Size(math.max(w, 800.0), 600.0);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          double? changedVal;
          double? endVal;

          final spectrum = ValueNotifier<List<double>>(
            List<double>.generate(64, (i) => 0.5),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: DualLayerRhythmSlider(
                      value: 25.0,
                      max: 100.0,
                      height: h,
                      spectrum: spectrum,
                      spectrumActive: true,
                      onChanged: (v) => changedVal = v,
                      onChangeEnd: (v) => endVal = v,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          if (h > 0) {
            final box = tester
                .renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
            final center = box.localToGlobal(Offset(w / 2.0, h / 2.0));
            await tester.tapAt(center);
            await tester.pump();
            expect(changedVal, isNotNull);
            expect(changedVal!, closeTo(50.0, 2.0));
            expect(endVal, isNotNull);
            expect(endVal!, closeTo(50.0, 2.0));
          }

          spectrum.dispose();
        });
      }
    }
  });

  // =========================================================================
  // 对抗测试 2: 极端时间与数值边界 (Extreme Numerical & Time Boundaries)
  // value < 0, value > max, max == 0, max < 0, NaN, Infinite
  // =========================================================================
  group('Adversarial Numerical & Time Boundary Test', () {
    final edgeCases = <String, ({double value, double max})>{
      'value < 0': (value: -50.0, max: 100.0),
      'value > max': (value: 250.0, max: 100.0),
      'max == 0': (value: 0.0, max: 0.0),
      'max == 0 with positive value': (value: 50.0, max: 0.0),
      'max < 0': (value: 10.0, max: -100.0),
      'value is NaN': (value: double.nan, max: 100.0),
      'max is NaN': (value: 50.0, max: double.nan),
      'both are NaN': (value: double.nan, max: double.nan),
      'value is +Infinity': (value: double.infinity, max: 100.0),
      'value is -Infinity': (value: double.negativeInfinity, max: 100.0),
      'max is +Infinity': (value: 50.0, max: double.infinity),
      'max is -Infinity': (value: 50.0, max: double.negativeInfinity),
    };

    edgeCases.forEach((name, tc) {
      testWidgets('FluidGlowProgressSlider safely handles $name without crash',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 20,
                  child: FluidGlowProgressSlider(
                    value: tc.value,
                    max: tc.max,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Failed rendering under $name');

        // Test hover interaction with this extreme value
        final box = tester
            .renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
        final center = box.localToGlobal(box.size.center(Offset.zero));
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset(center.dx - 100, center.dy));
        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'Failed hovering under $name');
        await gesture.removePointer();
      });

      testWidgets('AdaptiveWaveformSlider safely handles $name without crash',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 20,
                  child: AdaptiveWaveformSlider(
                    value: tc.value,
                    max: tc.max,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Failed rendering under $name');

        final box = tester
            .renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
        final center = box.localToGlobal(box.size.center(Offset.zero));
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset(center.dx - 100, center.dy));
        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'Failed hovering under $name');
        await gesture.removePointer();
      });

      testWidgets('DualLayerRhythmSlider safely handles $name without crash',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 20,
                  child: DualLayerRhythmSlider(
                    value: tc.value,
                    max: tc.max,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Failed rendering under $name');

        final box = tester
            .renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
        final center = box.localToGlobal(box.size.center(Offset.zero));
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset(center.dx - 100, center.dy));
        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'Failed hovering under $name');
        await gesture.removePointer();
      });
    });
  });

  // =========================================================================
  // 对抗测试 3: 密集滚轮高频轰炸 (Dense Wheel Scroll Bombardment)
  // 1ms 间隔连续注入数百个正向与反向 PointerScrollEvent，检验节流与边界截断
  // =========================================================================
  group('Adversarial Dense Wheel Scroll Bombardment Test', () {
    testWidgets(
        'FluidGlowProgressSlider throttles dense wheel flood and clamps at bounds',
        (tester) async {
      int endCallCount = 0;
      double? lastEndVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 20,
                child: FluidGlowProgressSlider(
                  value: 50.0,
                  max: 100.0,
                  onChangeEnd: (v) {
                    endCallCount++;
                    lastEndVal = v;
                  },
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

      // 1. Bombard with 200 scroll up events (delta.dy < 0) at 1ms interval
      for (int i = 0; i < 200; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -50),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      // During the flood, throttle timer should keep postponing, so 0 calls yet
      expect(endCallCount, equals(0));

      // Wait 50ms for throttle timer to fire
      await tester.pump(const Duration(milliseconds: 50));
      expect(endCallCount, equals(1));
      // Value should be clamped to max=100.0
      expect(lastEndVal, equals(100.0));

      // 2. Bombard with 200 scroll down events (delta.dy > 0) at 1ms interval
      for (int i = 0; i < 200; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, 50),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(endCallCount, equals(1));

      // Wait 50ms for throttle timer
      await tester.pump(const Duration(milliseconds: 50));
      expect(endCallCount, equals(2));
      // Value should be clamped to min=0.0
      expect(lastEndVal, equals(0.0));
    });

    testWidgets(
        'AdaptiveWaveformSlider throttles dense wheel flood and clamps at bounds',
        (tester) async {
      int endCallCount = 0;
      double? lastEndVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 20,
                child: AdaptiveWaveformSlider(
                  value: 40.0,
                  max: 80.0,
                  onChangeEnd: (v) {
                    endCallCount++;
                    lastEndVal = v;
                  },
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

      // 100 rapid upward scrolls
      for (int i = 0; i < 100; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -60),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(endCallCount, equals(0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(endCallCount, equals(1));
      expect(lastEndVal, equals(80.0));

      // 100 rapid downward scrolls
      for (int i = 0; i < 100; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, 60),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(endCallCount, equals(1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(endCallCount, equals(2));
      expect(lastEndVal, equals(0.0));
    });

    testWidgets(
        'DualLayerRhythmSlider throttles dense wheel flood and clamps at bounds',
        (tester) async {
      int endCallCount = 0;
      double? lastEndVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 20,
                child: DualLayerRhythmSlider(
                  value: 60.0,
                  max: 120.0,
                  onChangeEnd: (v) {
                    endCallCount++;
                    lastEndVal = v;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
      final center = box.localToGlobal(box.size.center(Offset.zero));

      // 150 rapid upward scrolls
      for (int i = 0; i < 150; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -100),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(endCallCount, equals(0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(endCallCount, equals(1));
      expect(lastEndVal, equals(120.0));

      // 150 rapid downward scrolls
      for (int i = 0; i < 150; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, 100),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(endCallCount, equals(1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(endCallCount, equals(2));
      expect(lastEndVal, equals(0.0));
    });

    testWidgets('FluidGlowProgressSlider ignores wheel scroll when max is NaN or <=0',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 20,
                child: FluidGlowProgressSlider(
                  value: 10.0,
                  max: double.nan,
                  onChangeEnd: (_) => callCount++,
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

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -50),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(callCount, equals(0), reason: 'Should not trigger seek when max is NaN');
    });

    testWidgets('AdaptiveWaveformSlider ignores wheel scroll when max is NaN or <=0',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 20,
                child: AdaptiveWaveformSlider(
                  value: 10.0,
                  max: double.nan,
                  onChangeEnd: (_) => callCount++,
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
          scrollDelta: const Offset(0, -50),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(callCount, equals(0), reason: 'Should not trigger seek when max is NaN');
    });

    testWidgets('DualLayerRhythmSlider ignores wheel scroll when max is NaN or <=0',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 20,
                child: DualLayerRhythmSlider(
                  value: 10.0,
                  max: double.nan,
                  onChangeEnd: (_) => callCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
      final center = box.localToGlobal(box.size.center(Offset.zero));

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -50),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(callCount, equals(0), reason: 'Should not trigger seek when max is NaN');
    });

    testWidgets('FluidGlowProgressSlider tap/drag with max=NaN emits no callback',
        (tester) async {
      double? changedVal;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 20,
                child: FluidGlowProgressSlider(
                  value: 10.0,
                  max: double.nan,
                  onChanged: (v) => changedVal = v,
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

      await tester.tapAt(center);
      await tester.pump();
      expect(changedVal, isNull, reason: 'Should not emit seek when max is NaN');
    });

    testWidgets('AdaptiveWaveformSlider tap/drag with max=NaN emits no callback',
        (tester) async {
      double? changedVal;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 20,
                child: AdaptiveWaveformSlider(
                  value: 10.0,
                  max: double.nan,
                  onChanged: (v) => changedVal = v,
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

      await tester.tapAt(center);
      await tester.pump();
      expect(changedVal, isNull, reason: 'Should not emit seek when max is NaN');
    });

    testWidgets('DualLayerRhythmSlider tap/drag with max=NaN emits no callback',
        (tester) async {
      double? changedVal;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 20,
                child: DualLayerRhythmSlider(
                  value: 10.0,
                  max: double.nan,
                  onChanged: (v) => changedVal = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
      final center = box.localToGlobal(box.size.center(Offset.zero));

      await tester.tapAt(center);
      await tester.pump();
      expect(changedVal, isNull, reason: 'Should not emit seek when max is NaN');
    });
  });

  // =========================================================================
  // 对抗测试 4: 死区对抗测试 (Dead-zone & Boundary Sub-pixel Click Test)
  // 在 x=0.01、x=W-0.01 边界像素点击，检验是否 100% 捕获交互并正确计算 seek 百分比
  // =========================================================================
  group('Adversarial Dead-Zone & Boundary Sub-pixel Click Test', () {
    final testWidths = [50.0, 120.0, 600.0, 3840.0];
    const duration = 200.0;

    for (final w in testWidths) {
      testWidgets(
          'FluidGlowProgressSlider captures sub-pixel boundary clicks at W=${w}px (zero dead zone)',
          (tester) async {
        tester.view.physicalSize = Size(math.max(w, 800.0), 600.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        double? tappedVal;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: w,
                  height: 20,
                  child: FluidGlowProgressSlider(
                    value: 50.0,
                    max: duration,
                    onChangeEnd: (v) => tappedVal = v,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester
            .renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
        final topLeft = box.localToGlobal(Offset.zero);
        final centerY = topLeft.dy + box.size.height / 2;

        // 1. Extreme left sub-pixel: x = 0.01
        await tester.tapAt(Offset(topLeft.dx + 0.01, centerY));
        await tester.pump();
        expect(tappedVal, isNotNull,
            reason: 'Left sub-pixel x=0.01 failed to register interaction');
        final expectedLeft = (0.01 / w) * duration;
        expect(tappedVal!, closeTo(expectedLeft, 0.01),
            reason: 'Left sub-pixel target value mismatch');

        // 2. Extreme right sub-pixel: x = W - 0.01
        await tester.tapAt(Offset(topLeft.dx + w - 0.01, centerY));
        await tester.pump();
        expect(tappedVal, isNotNull,
            reason: 'Right sub-pixel x=W-0.01 failed to register interaction');
        final expectedRight = ((w - 0.01) / w) * duration;
        expect(tappedVal!, closeTo(expectedRight, 0.01),
            reason: 'Right sub-pixel target value mismatch');
      });

      testWidgets(
          'AdaptiveWaveformSlider captures sub-pixel boundary clicks at W=${w}px (zero dead zone)',
          (tester) async {
        tester.view.physicalSize = Size(math.max(w, 800.0), 600.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        double? tappedVal;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: w,
                  height: 20,
                  child: AdaptiveWaveformSlider(
                    value: 50.0,
                    max: duration,
                    onChangeEnd: (v) => tappedVal = v,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester
            .renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
        final topLeft = box.localToGlobal(Offset.zero);
        final centerY = topLeft.dy + box.size.height / 2;

        // 1. Left sub-pixel x=0.01
        await tester.tapAt(Offset(topLeft.dx + 0.01, centerY));
        await tester.pump();
        expect(tappedVal, isNotNull);
        final expectedLeft = (0.01 / w) * duration;
        expect(tappedVal!, closeTo(expectedLeft, 0.01));

        // 2. Right sub-pixel x=W-0.01
        await tester.tapAt(Offset(topLeft.dx + w - 0.01, centerY));
        await tester.pump();
        expect(tappedVal, isNotNull);
        final expectedRight = ((w - 0.01) / w) * duration;
        expect(tappedVal!, closeTo(expectedRight, 0.01));
      });

      testWidgets(
          'DualLayerRhythmSlider captures sub-pixel boundary clicks at W=${w}px (zero dead zone)',
          (tester) async {
        tester.view.physicalSize = Size(math.max(w, 800.0), 600.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        double? tappedVal;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: w,
                  height: 20,
                  child: DualLayerRhythmSlider(
                    value: 50.0,
                    max: duration,
                    onChangeEnd: (v) => tappedVal = v,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester
            .renderObject<RenderBox>(find.byType(DualLayerRhythmSlider));
        final topLeft = box.localToGlobal(Offset.zero);
        final centerY = topLeft.dy + box.size.height / 2;

        // 1. Left sub-pixel x=0.01
        await tester.tapAt(Offset(topLeft.dx + 0.01, centerY));
        await tester.pump();
        expect(tappedVal, isNotNull);
        final expectedLeft = (0.01 / w) * duration;
        expect(tappedVal!, closeTo(expectedLeft, 0.01));

        // 2. Right sub-pixel x=W-0.01
        await tester.tapAt(Offset(topLeft.dx + w - 0.01, centerY));
        await tester.pump();
        expect(tappedVal, isNotNull);
        final expectedRight = ((w - 0.01) / w) * duration;
        expect(tappedVal!, closeTo(expectedRight, 0.01));
      });
    }
  });
}
