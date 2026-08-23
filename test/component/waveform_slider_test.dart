import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/waveform_slider.dart';

void main() {
  test('waveform interaction width matches the painted bars', () {
    expect(waveformSliderPaintWidth(), closeTo(284, 0.001));
    expect(resolveWaveformInteractionWidth(320), closeTo(284, 0.001));
    expect(resolveWaveformInteractionWidth(180), 180);
    expect(resolveWaveformInteractionWidth(double.infinity), 0);
  });

  testWidgets('only the centered waveform area responds to taps', (
    tester,
  ) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: WaveformSlider(
              value: 42,
              max: 240,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.byType(WaveformSlider));
    final topLeft = box.localToGlobal(Offset.zero);
    final centerY = topLeft.dy + box.size.height / 2;
    await tester.tapAt(Offset(topLeft.dx + 2, centerY));
    expect(changes, isEmpty);

    await tester.tapAt(Offset(topLeft.dx + 160, centerY));
    expect(changes, isNotEmpty);
    expect(changes.last, closeTo(120, 2));
  });

  testWidgets('playback state does not start a synthetic waveform ticker', (
    tester,
  ) async {
    var isPlaying = false;
    late StateSetter updateState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateState = setState;
            return Center(
              child: SizedBox(
                width: 320,
                child: WaveformSlider(
                  value: 42,
                  max: 240,
                  isPlaying: isPlaying,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    updateState(() => isPlaying = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
