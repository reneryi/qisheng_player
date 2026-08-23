import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/spectrum_progress_slider.dart';

void main() {
  test('spectrum progress width stays finite and centered', () {
    expect(resolveSpectrumProgressWidth(320), spectrumProgressMaxWidth);
    expect(resolveSpectrumProgressWidth(180), 180);
    expect(resolveSpectrumProgressWidth(double.infinity), 0);
  });

  testWidgets('spectrum progress slider seeks across its painted width', (
    tester,
  ) async {
    final spectrum = ValueNotifier<List<double>>(
      List<double>.filled(64, 0.5),
    );
    addTearDown(spectrum.dispose);
    final changes = <double>[];
    final commits = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: SpectrumProgressSlider(
              spectrum: spectrum,
              value: 42,
              max: 240,
              spectrumActive: true,
              onChanged: changes.add,
              onChangeEnd: commits.add,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byType(SpectrumProgressSlider)));
    expect(changes.last, closeTo(120, 2));
    expect(commits.last, closeTo(120, 2));
  });

  testWidgets('only the painter subscribes to realtime spectrum frames', (
    tester,
  ) async {
    final spectrum = ValueNotifier<List<double>>(
      List<double>.filled(64, 0.25),
    );
    addTearDown(spectrum.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SpectrumProgressSlider(
          spectrum: spectrum,
          value: 30,
          max: 120,
          spectrumActive: true,
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is SpectrumProgressPainter,
      ),
    );
    final painter = paint.painter! as SpectrumProgressPainter;
    expect(painter.spectrum, same(spectrum));
    expect(painter.spectrumActive, isTrue);

    spectrum.value = List<double>.filled(64, 0.75);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused spectrum falls back to a non-animated progress track', (
    tester,
  ) async {
    final spectrum = ValueNotifier<List<double>>(
      List<double>.filled(64, 0.75),
    );
    addTearDown(spectrum.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SpectrumProgressSlider(
          spectrum: spectrum,
          value: 30,
          max: 120,
          spectrumActive: false,
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is SpectrumProgressPainter,
      ),
    );
    expect(
      (paint.painter! as SpectrumProgressPainter).spectrumActive,
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
