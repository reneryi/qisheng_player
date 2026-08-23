import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/liquid_surface_background.dart';

void main() {
  test('palette falls back cleanly when colors are incomplete', () {
    const primary = Color(0xFF123456);
    final palette = LiquidSurfacePalette.fromColors(const [primary]);

    expect(palette.primary, primary);
    expect(palette.secondary, primary);
    expect(palette.accent, primary);
  });

  test('dye cores are darker and keep their source hue', () {
    const source = Color(0xFF7866D8);
    final core = resolveDyeCoreColor(source);

    expect(core.computeLuminance(), lessThan(source.computeLuminance()));
    expect(
      HSLColor.fromColor(core).hue,
      closeTo(HSLColor.fromColor(source).hue, 1),
    );
  });

  test('fallback blob contour is irregular and evolves continuously', () {
    final first = generateLiquidBlobPoints(
      center: const Offset(100, 80),
      radius: 60,
      seed: 2.4,
      time: 0,
    );
    final later = generateLiquidBlobPoints(
      center: const Offset(100, 80),
      radius: 60,
      seed: 2.4,
      time: 2,
    );
    final distances =
        first.map((point) => (point - const Offset(100, 80)).distance).toList();

    expect(distances.reduce(math.max) - distances.reduce(math.min),
        greaterThan(15));
    expect(first, isNot(equals(later)));
    expect(
      (first.first - later.first).distance,
      lessThan(8),
    );
  });

  testWidgets('liquid shader asset compiles and loads', (tester) async {
    final program = await tester.runAsync(
      () => ui.FragmentProgram.fromAsset(liquidSurfaceShaderAsset),
    );
    expect(program, isNotNull);
  });

  test('dark palette tone mapping caps each extreme artwork color', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );
    const palettes = [
      [Color(0xFFF7F7F2), Color(0xFFE9FFE8), Color(0xFFFFFFFF)],
      [Color(0xFF9B16FF), Color(0xFFFF3AE5), Color(0xFFB77CFF)],
      [Color(0xFFFFFF00), Color(0xFFB7C52A), Color(0xFF7A801B)],
      [Color(0xFFFF0000), Color(0xFF0000FF), Color(0xFF777777)],
    ];

    for (final colors in palettes) {
      final resolved =
          LiquidSurfacePalette.fromColors(colors).resolveForTheme(scheme);
      expect(
        [resolved.primary, resolved.secondary, resolved.accent]
            .map((color) => color.computeLuminance())
            .reduce(math.max),
        lessThanOrEqualTo(0.301),
      );
    }
  });

  test('bright colors no longer dim unrelated palette colors', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );
    const blue = Color(0xFF2255CC);
    const purple = Color(0xFF8E36D9);
    final mixed = LiquidSurfacePalette.fromColors(
      const [Color(0xFFFFFF00), blue, purple],
    ).resolveForTheme(scheme);
    final blueAlone = LiquidSurfacePalette.fromColors(
      const [blue],
    ).resolveForTheme(scheme);
    final purpleAlone = LiquidSurfacePalette.fromColors(
      const [purple],
    ).resolveForTheme(scheme);

    expect(mixed.secondary, blueAlone.primary);
    expect(mixed.accent, purpleAlone.primary);
  });

  test('light palette keeps the existing eighteen percent tint formula', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );
    const source = LiquidSurfacePalette(
      primary: Color(0xFF2255CC),
      secondary: Color(0xFFD94D7A),
      accent: Color(0xFF57A85A),
    );
    final resolved = source.resolveForTheme(scheme);

    expect(
      resolved.primary,
      Color.alphaBlend(
        source.primary.withValues(alpha: 0.18),
        scheme.surfaceContainer,
      ),
    );
    expect(
      resolved.secondary,
      Color.alphaBlend(
        source.secondary.withValues(alpha: 0.18),
        scheme.surfaceContainer,
      ),
    );
    expect(
      resolved.accent,
      Color.alphaBlend(
        source.accent.withValues(alpha: 0.18),
        scheme.surfaceContainer,
      ),
    );
  });

  test('highlight protection preserves chromatic hue relationships', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );
    const source = LiquidSurfacePalette(
      primary: Color(0xFF9B16FF),
      secondary: Color(0xFFFFE600),
      accent: Color(0xFF00AEEF),
    );
    final resolved = source.resolveForTheme(scheme);

    expect(
      HSLColor.fromColor(resolved.primary).hue,
      closeTo(HSLColor.fromColor(source.primary).hue, 3),
    );
    expect(
      HSLColor.fromColor(resolved.secondary).hue,
      closeTo(HSLColor.fromColor(source.secondary).hue, 3),
    );
    expect(
      HSLColor.fromColor(resolved.accent).hue,
      closeTo(HSLColor.fromColor(source.accent).hue, 3),
    );
  });

  test('random flow points cover the container without crowding', () {
    final random = math.Random(42);
    final samples = <List<Offset>>[
      for (var index = 0; index < 40; index++) generateLiquidFlowPoints(random),
    ];

    for (final points in samples) {
      expect(points, hasLength(3));
      expect(
        points.every(
          (point) =>
              point.dx >= 0.05 &&
              point.dx <= 0.95 &&
              point.dy >= 0.08 &&
              point.dy <= 0.92,
        ),
        isTrue,
      );
      expect((points[0] - points[1]).distance, greaterThanOrEqualTo(0.18));
      expect((points[0] - points[2]).distance, greaterThanOrEqualTo(0.18));
      expect((points[1] - points[2]).distance, greaterThanOrEqualTo(0.18));
    }

    final firstTrack = samples.map((points) => points.first).toList();
    expect(firstTrack.any((point) => point.dx < 0.35), isTrue);
    expect(firstTrack.any((point) => point.dx > 0.65), isTrue);
    expect(firstTrack.any((point) => point.dy < 0.35), isTrue);
    expect(firstTrack.any((point) => point.dy > 0.65), isTrue);
  });

  test('flow spline stays continuous across target advancement', () {
    const track = LiquidFlowTrack(
      previous: Offset(0.12, 0.18),
      current: Offset(0.28, 0.72),
      target: Offset(0.82, 0.31),
      next: Offset(0.46, 0.86),
    );
    final advanced = track.advance(const Offset(0.14, 0.48));

    expect((track.positionAt(1) - advanced.positionAt(0)).distance,
        lessThan(1e-9));
    expect(
      (track.positionAt(0.999) - advanced.positionAt(0.001)).distance,
      lessThan(0.01),
    );
  });

  testWidgets('performance mode paints a static surface', (tester) async {
    await tester.pumpWidget(
      _testSurface(effectsLevel: UiEffectsLevel.performance),
    );

    final first = _painter(tester);
    await tester.pump(const Duration(seconds: 1));
    final second = _painter(tester);

    expect(first.phase, 0);
    expect(second.phase, 0);
    expect(find.text('content'), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('rendered extreme palette contains no blown highlights',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const SizedBox(
              width: 240,
              height: 120,
              child: LiquidSurfaceBackground(
                paletteColors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFF00),
                  Color(0xFFFF36E4),
                ],
                effectsLevel: UiEffectsLevel.performance,
                borderRadius: BorderRadius.zero,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final metrics = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return null;

      var maxLuminance = 0.0;
      var blownPixels = 0;
      var minRed = 255;
      var maxRed = 0;
      var minGreen = 255;
      var maxGreen = 0;
      var minBlue = 255;
      var maxBlue = 0;
      for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        final blue = bytes.getUint8(offset + 2);
        final color = Color.fromARGB(
          bytes.getUint8(offset + 3),
          red,
          green,
          blue,
        );
        final luminance = color.computeLuminance();
        maxLuminance = math.max(maxLuminance, luminance);
        if (luminance > 0.8) blownPixels++;
        minRed = math.min(minRed, red);
        maxRed = math.max(maxRed, red);
        minGreen = math.min(minGreen, green);
        maxGreen = math.max(maxGreen, green);
        minBlue = math.min(minBlue, blue);
        maxBlue = math.max(maxBlue, blue);
      }
      return (
        maxLuminance: maxLuminance,
        blownPixels: blownPixels,
        maximumChannelRange: [
          maxRed - minRed,
          maxGreen - minGreen,
          maxBlue - minBlue,
        ].reduce(math.max),
      );
    });

    expect(metrics, isNotNull);
    expect(metrics!.maxLuminance, lessThanOrEqualTo(0.305));
    expect(metrics.blownPixels, 0);
    expect(metrics.maximumChannelRange, greaterThan(30));
  });

  testWidgets('visual mode advances the fluid phase', (tester) async {
    await tester.pumpWidget(
      _testSurface(effectsLevel: UiEffectsLevel.visual),
    );

    final before = _painter(tester);
    await tester.pump(const Duration(seconds: 1));
    final painter = _painter(tester);

    expect(painter.phase, greaterThan(0));
    expect(painter.positions, isNot(equals(before.positions)));
    expect(
      painter.positions
          .asMap()
          .entries
          .any((entry) => entry.value.dx != before.positions[entry.key].dx),
      isTrue,
    );
    expect(
      painter.positions
          .asMap()
          .entries
          .any((entry) => entry.value.dy != before.positions[entry.key].dy),
      isTrue,
    );
  });

  testWidgets('hidden lifecycle pauses and resumes the fluid ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testSurface(effectsLevel: UiEffectsLevel.visual),
    );
    await tester.pump(const Duration(milliseconds: 200));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = _painter(tester);
    await tester.pump(const Duration(seconds: 1));
    final stillPaused = _painter(tester);
    expect(stillPaused.phase, paused.phase);
    expect(stillPaused.positions, paused.positions);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).phase, greaterThan(stillPaused.phase));
  });
}

Widget _testSurface({required UiEffectsLevel effectsLevel}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 400,
        height: 240,
        child: LiquidSurfaceBackground(
          paletteColors: const [
            Color(0xFF225577),
            Color(0xFF772255),
            Color(0xFF557722),
          ],
          effectsLevel: effectsLevel,
          borderRadius: BorderRadius.circular(24),
          child: const Text('content'),
        ),
      ),
    ),
  );
}

LiquidSurfacePainter _painter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  return paints
      .map((paint) => paint.painter)
      .whereType<LiquidSurfacePainter>()
      .single;
}
