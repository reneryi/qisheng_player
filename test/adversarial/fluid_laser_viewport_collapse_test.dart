import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';

import '../test_helpers/media_test_harness.dart';

/// 记录 Canvas 所有绘制调用的测试替身，用于实证检验 Thumb 绘制与图元边界
class InspectingCanvas implements Canvas {
  final List<String> drawCalls = [];
  final List<Rect> drawnRects = [];
  final List<RRect> drawnRRects = [];
  final List<({Offset center, double radius})> drawnCircles = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    drawCalls.add('drawCircle(c=$c, r=$radius)');
    drawnCircles.add((center: c, radius: radius));
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    drawCalls.add('drawRect($rect)');
    drawnRects.add(rect);
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    drawCalls.add('drawRRect($rrect)');
    drawnRRects.add(rrect);
  }

  @override
  void clipRect(Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {
    drawCalls.add('clipRect($rect)');
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    drawCalls.add('clipRRect($rrect)');
  }

  @override
  void save() => drawCalls.add('save()');

  @override
  void restore() => drawCalls.add('restore()');

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

Future<void> _loadRealFont(String family, String fontPath) async {
  try {
    final file = File(fontPath);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final fontLoader = FontLoader(family);
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
  } catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadRealFont('SegoeUI', r'C:\Windows\Fonts\segoeui.ttf');
    await _loadRealFont('MiSansRegular', r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Regular.ttf');
    await _loadRealFont('MiSansMedium', r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Medium.ttf');
  });

  tearDown(() {
    AppSettings.instance.progressBarTypeNotifier.value = ProgressBarType.fluidGlow;
  });

  // =========================================================================
  // CHALLENGE 1: 视口极限压缩与膨胀 (Viewport Collapse & Expansion)
  // W = 5px, 10px, 30px, 3840px; H = 0px, 4px, 10px, 30px, 200px
  // =========================================================================
  group('CHALLENGE 1: 视口极限压缩与膨胀 (Viewport Collapse & Expansion)', () {
    const testWidths = [5.0, 10.0, 30.0, 3840.0];
    const testHeights = [0.0, 4.0, 10.0, 30.0, 200.0];

    for (final w in testWidths) {
      for (final h in testHeights) {
        testWidgets('FluidGlowProgressSlider survives W=${w}px, H=${h}px without crash', (tester) async {
          if (w > 800 || h > 600) {
            tester.view.physicalSize = Size(math.max(w, 800), math.max(h, 600));
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
          }
          double? observedVal;
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
                      onChanged: (v) => observedVal = v,
                      onChangeEnd: (v) => observedVal = v,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'Failed at W=$w, H=$h on initial pump');

          if (w > 0 && h > 0) {
            final sliderFinder = find.byType(FluidGlowProgressSlider);
            final box = tester.renderObject<RenderBox>(sliderFinder);
            final center = box.localToGlobal(Offset(w / 2.0, h / 2.0));

            await tester.tapAt(center);
            await tester.pump();
            expect(tester.takeException(), isNull, reason: 'Failed during tap at W=$w, H=$h');
            expect(observedVal, isNotNull);
          }
        });
      }
    }

    testWidgets('BottomPlayerBar survives extreme width collapse (W=300px) and ultra-expansion (W=3840px)', (tester) async {
      tester.view.physicalSize = const Size(3840, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\test.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      for (final w in [507.0, 600.0, 1200.0, 3840.0]) {
        await tester.pumpWidget(
          buildMediaHarness(
            playbackController: playback,
            lyricController: FakeLyricController(Lrc([], LrcSource.local)),
            desktopLyricController: FakeDesktopLyricController(),
            child: Center(
              child: SizedBox(
                width: w,
                child: const BottomPlayerBar(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'BottomPlayerBar crashed at width=$w');
      }
    });
  });

  // =========================================================================
  // CHALLENGE 2: 流体激光向左流光束边界裁剪与着色安全性
  // progressX = 0, 1e-6, width, < 0, > width
  // =========================================================================
  group('CHALLENGE 2: 流体激光向左流光束边界裁剪与着色安全性', () {
    testWidgets('Adversarial progressX via WidgetTree: 0, 1e-6, width, <0, >width', (tester) async {
      final edgeValues = <({String desc, double val, double max, double width})>[
        (desc: 'progressX = 0', val: 0.0, max: 100.0, width: 500.0),
        (desc: 'progressX = 1e-6', val: 0.0000005, max: 100.0, width: 500.0),
        (desc: 'progressX = width', val: 100.0, max: 100.0, width: 500.0),
        (desc: 'progressX < 0', val: -50.0, max: 100.0, width: 500.0),
        (desc: 'progressX > width', val: 200.0, max: 100.0, width: 500.0),
        (desc: 'micro width 5px at 100%', val: 100.0, max: 100.0, width: 5.0),
        (desc: 'micro width 5px at 0%', val: 0.0, max: 100.0, width: 5.0),
      ];

      for (final ev in edgeValues) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: ev.width,
                  height: 30,
                  child: FluidGlowProgressSlider(
                    value: ev.val,
                    max: ev.max,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Failed on edge value: ${ev.desc}');
      }
    });
  });

  // =========================================================================
  // CHALLENGE 3: 验证未悬停时无任何圆形 Thumb 突出轨道边界 (绝对平直)
  // =========================================================================
  group('CHALLENGE 3: 验证未悬停时无任何圆形 Thumb 突出轨道边界 (绝对平直)', () {
    testWidgets('Unhovered state has ZERO circular thumb drawings and flat track bounds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 50.0,
                  max: 100.0,
                  height: 30,
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
      ).first;
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter!;

      final canvas = InspectingCanvas();
      painter.paint(canvas, const Size(600, 30));

      expect(canvas.drawnCircles.length, equals(0),
          reason: 'Unhovered state must NOT draw any circle thumbs, found: ${canvas.drawnCircles}');

      // 常态轨道厚度必须精确为 5.5px，绝对平直
      expect(canvas.drawnRRects.first.height, equals(5.5),
          reason: 'Unhovered track height must be strictly 5.5px');

      for (final rrect in canvas.drawnRRects) {
        expect(rrect.top, greaterThanOrEqualTo(11.0), reason: 'RRect exceeds upper boundary: $rrect');
        expect(rrect.bottom, lessThanOrEqualTo(19.0), reason: 'RRect exceeds lower boundary: $rrect');
      }
    });

    testWidgets('Hovered state DOES draw circular thumb (contrast check)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 50.0,
                  max: 100.0,
                  height: 30,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
      final center = box.localToGlobal(const Offset(300, 15));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(center);
      await tester.pump();
      // 动画时长为 180ms，步进 180ms 展开至满状态
      await tester.pump(const Duration(milliseconds: 180));

      final customPaintFinder = find.descendant(
        of: find.byType(FluidGlowProgressSlider),
        matching: find.byType(CustomPaint),
      ).first;
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter!;

      final canvas = InspectingCanvas();
      painter.paint(canvas, const Size(600, 30));

      // 悬停 180ms 展开后轨道厚度精确膨胀至 7.5px
      expect(canvas.drawnRRects.first.height, equals(7.5),
          reason: 'Hovered track height must expand to strictly 7.5px after 180ms');

      expect(canvas.drawnCircles.length, greaterThanOrEqualTo(3),
          reason: 'Hovered state MUST reveal glowing circle thumb');

      await gesture.removePointer();
    });
  });

  // =========================================================================
  // CHALLENGE 4: 悬停时 72px 毛玻璃时间气泡在各种极端位置不发生 RenderFlex overflow
  // =========================================================================
  group('CHALLENGE 4: 悬停时 72px 毛玻璃时间气泡在各种极端位置不发生 RenderFlex overflow', () {
    testWidgets('Bubble at extreme left (x=0) does not overflow and clamps to 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 0.0,
                  max: 100.0,
                  height: 30,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
      final topLeft = box.localToGlobal(Offset.zero);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(topLeft.dx - 20, topLeft.dy + 15));
      await gesture.moveTo(Offset(topLeft.dx + 0.0, topLeft.dy + 15));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      final bubbleText = find.text('0:00:00');
      expect(bubbleText, findsOneWidget);

      final positionedFinder = find.ancestor(of: bubbleText, matching: find.byType(Positioned)).first;
      final positioned = tester.widget<Positioned>(positionedFinder);
      expect(positioned.left, equals(0.0));

      await gesture.removePointer();
    });

    testWidgets('Bubble at extreme right does not overflow and clamps to width - 72', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 30,
                child: FluidGlowProgressSlider(
                  value: 100.0,
                  max: 100.0,
                  height: 30,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
      final topLeft = box.localToGlobal(Offset.zero);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset(topLeft.dx + 650, topLeft.dy + 15));
      await gesture.moveTo(Offset(topLeft.dx + 590.0, topLeft.dy + 15));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      final textFinder = find.descendant(
        of: find.byType(FluidGlowProgressSlider),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final positionedFinder = find.ancestor(of: textFinder, matching: find.byType(Positioned)).first;
      final positioned = tester.widget<Positioned>(positionedFinder);
      expect(positioned.left, equals(600.0 - 72.0));

      await gesture.removePointer();
    });

    testWidgets('Bubble in extremely narrow window (width=30px, 10px, 5px) does not cause RenderFlex overflow', (tester) async {
      for (final w in [50.0, 30.0, 10.0, 5.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: w,
                  height: 30,
                  child: const FluidGlowProgressSlider(
                    value: 10.0,
                    max: 100.0,
                    height: 30,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final box = tester.renderObject<RenderBox>(find.byType(FluidGlowProgressSlider));
        final topLeft = box.localToGlobal(Offset.zero);

        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset(topLeft.dx - 10, topLeft.dy + 15));
        await gesture.moveTo(Offset(topLeft.dx + w / 2.0, topLeft.dy + 15));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Failed in narrow window w=$w');

        final bubbleText = find.byType(Text);
        expect(bubbleText, findsWidgets);

        await gesture.removePointer();
      }
    });
  });

  // =========================================================================
  // CHALLENGE 5: 超长音频 (99:59:59) 在 62px 时间标签容器下的排版与截断实证
  // =========================================================================
  group('CHALLENGE 5: 超长音频 (99:59:59) 在 62px 时间标签容器下的排版与截断实证', () {
    test('Duration 99:59:59 toStringHMMSS format check', () {
      const dur = Duration(hours: 99, minutes: 59, seconds: 59);
      expect(dur.toStringHMMSS(), equals('99:59:59'));
    });

    test('Empirical Typography Measurement: Segoe UI, MiSansRegular, MiSansMedium', () {
      final fonts = [
        (name: 'Default Test Font (Ahem)', family: null),
        (name: 'Windows Segoe UI', family: 'SegoeUI'),
        (name: 'MiSans Regular', family: 'MiSansRegular'),
        (name: 'MiSans Medium', family: 'MiSansMedium'),
      ];

      final sampleTexts = [
        '0:02:05', // 7 chars
        '1:02:05', // 7 chars
        '99:59:59', // 8 chars
        '100:00:00', // 9 chars
      ];

      for (final font in fonts) {
        for (final text in sampleTexts) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: font.family,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            textDirection: ui.TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: double.infinity);

          if (text == '99:59:59' && font.family != null) {
            expect(tp.width, lessThanOrEqualTo(62.0),
                reason: '${font.name} "99:59:59" must fit inside 62.0px container (measured: ${tp.width}px)');
          }
        }
      }
    });

    testWidgets('Live verification of 99:59:59 in SegoeUI and MiSans inside 62.0px container', (tester) async {
      for (final entry in [
        (font: 'SegoeUI', label: 'Windows Segoe UI'),
        (font: 'MiSansRegular', label: 'MiSans Regular'),
        (font: 'MiSansMedium', label: 'MiSans Medium'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: entry.font),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 62.0,
                  child: Text(
                    '99:59:59',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: entry.font,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final renderParagraph = tester.renderObject<RenderParagraph>(find.text('99:59:59'));
        expect(renderParagraph.didExceedMaxLines, isFalse,
            reason: '${entry.label} must not truncate "99:59:59" inside 62.0px container');
      }
    });

    testWidgets('Live verification of 99:59:59 in BottomPlayerBar with Segoe UI theme', (tester) async {
      final ultraAudio = TestAudio(
        title: 'Ultra Long Audio',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\ultra.flac',
      );
      final playback = _AdversarialPlaybackController(
        audio: ultraAudio,
        queue: [ultraAudio],
        customLength: 359999.0,
        customPosition: 359999.0,
      );

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ThemeProvider.instance),
            ChangeNotifierProvider<PlaybackController>.value(value: playback),
            ChangeNotifierProvider<LyricController>.value(
              value: FakeLyricController(Lrc([], LrcSource.local)),
            ),
            ChangeNotifierProvider<DesktopLyricController>.value(
              value: FakeDesktopLyricController(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: 'SegoeUI',
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF53A4FF), brightness: Brightness.dark),
            ),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 1200,
                  child: BottomPlayerBar(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final ultraTextFinder = find.text('99:59:59');
      expect(ultraTextFinder, findsNWidgets(2));

      final renderParagraphs = tester.renderObjectList<RenderParagraph>(ultraTextFinder);
      for (final rp in renderParagraphs) {
        expect(rp.didExceedMaxLines, isFalse,
            reason: 'BottomPlayerBar time labels for "99:59:59" under Segoe UI must not exceed maxLines in 62.0px container');
      }
    });

    testWidgets('Live verification of 99:59:59 in BottomPlayerBar with MiSans Medium theme', (tester) async {
      final ultraAudio = TestAudio(
        title: 'Ultra Long Audio',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\ultra.flac',
      );
      final playback = _AdversarialPlaybackController(
        audio: ultraAudio,
        queue: [ultraAudio],
        customLength: 359999.0,
        customPosition: 359999.0,
      );

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ThemeProvider.instance),
            ChangeNotifierProvider<PlaybackController>.value(value: playback),
            ChangeNotifierProvider<LyricController>.value(
              value: FakeLyricController(Lrc([], LrcSource.local)),
            ),
            ChangeNotifierProvider<DesktopLyricController>.value(
              value: FakeDesktopLyricController(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: 'MiSansMedium',
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF53A4FF), brightness: Brightness.dark),
            ),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 1200,
                  child: BottomPlayerBar(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final ultraTextFinder = find.text('99:59:59');
      expect(ultraTextFinder, findsNWidgets(2));

      final renderParagraphs = tester.renderObjectList<RenderParagraph>(ultraTextFinder);
      for (final rp in renderParagraphs) {
        expect(rp.didExceedMaxLines, isFalse,
            reason: 'BottomPlayerBar time labels for "99:59:59" under MiSans Medium must not exceed maxLines in 62.0px container');
      }
    });
  });
}

class _AdversarialPlaybackController extends FakePlaybackController {
  _AdversarialPlaybackController({
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
