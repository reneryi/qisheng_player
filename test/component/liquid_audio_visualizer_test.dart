import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/audio_visualizer/liquid_audio_visualizer.dart';
import 'package:qisheng_player/theme/app_theme.dart';

void main() {
  ThemeData themeFor(UiEffectsLevel effectsLevel) {
    return AppTheme.build(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      effectsLevel: effectsLevel,
    );
  }

  Finder spectrumPainter() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter is LiquidAudioVisualizerPainter,
    );
  }

  testWidgets('visual effects build a repaint-driven spectrum painter', (
    tester,
  ) async {
    final spectrum = ValueNotifier<List<double>>(
      List<double>.filled(64, 0.5),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: themeFor(UiEffectsLevel.visual),
        home: SizedBox(
          width: 480,
          height: 88,
          child: LiquidAudioVisualizer(spectrum: spectrum),
        ),
      ),
    );

    expect(spectrumPainter(), findsOneWidget);
    final paint = tester.widget<CustomPaint>(spectrumPainter());
    final painter = paint.painter! as LiquidAudioVisualizerPainter;
    expect(painter.spectrum, same(spectrum));
  });

  for (final level in [
    UiEffectsLevel.balanced,
    UiEffectsLevel.performance,
  ]) {
    testWidgets('$level does not subscribe a spectrum painter', (tester) async {
      final spectrum = ValueNotifier<List<double>>(const []);
      await tester.pumpWidget(
        MaterialApp(
          theme: themeFor(level),
          home: LiquidAudioVisualizer(spectrum: spectrum),
        ),
      );

      expect(spectrumPainter(), findsNothing);
    });
  }

  testWidgets('reduce motion disables continuous spectrum repainting', (
    tester,
  ) async {
    final spectrum = ValueNotifier<List<double>>(const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: themeFor(UiEffectsLevel.visual),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LiquidAudioVisualizer(spectrum: spectrum),
        ),
      ),
    );

    expect(spectrumPainter(), findsNothing);
  });

  testWidgets('the bottom-bar spectrum layer does not intercept commands', (
    tester,
  ) async {
    final spectrum = ValueNotifier<List<double>>(
      List<double>.filled(64, 0.5),
    );
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: themeFor(UiEffectsLevel.visual),
        home: SizedBox(
          width: 480,
          height: 88,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: LiquidAudioVisualizer(spectrum: spectrum),
              ),
              Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('play'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('play'));
    expect(taps, 1);
  });
}
