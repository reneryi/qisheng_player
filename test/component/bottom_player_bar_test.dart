import 'package:coriander_player/component/bottom_player_bar.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveBottomPlayerBarLayout applies compact and dense breakpoints',
      () {
    expect(
      resolveBottomPlayerBarLayout(1400),
      isA<BottomPlayerBarLayout>()
          .having((value) => value.compact, 'compact', isFalse)
          .having((value) => value.dense, 'dense', isFalse),
    );

    expect(
      resolveBottomPlayerBarLayout(1180),
      isA<BottomPlayerBarLayout>()
          .having((value) => value.compact, 'compact', isTrue)
          .having((value) => value.dense, 'dense', isFalse),
    );

    expect(
      resolveBottomPlayerBarLayout(920),
      isA<BottomPlayerBarLayout>()
          .having((value) => value.compact, 'compact', isTrue)
          .having((value) => value.dense, 'dense', isTrue),
    );
  });

  test('resolveSliderThumbRadius shows thumb only on hover or drag', () {
    expect(
      resolveSliderThumbRadius(hovering: false, dragging: false),
      0,
    );
    expect(
      resolveSliderThumbRadius(hovering: true, dragging: false),
      6,
    );
    expect(
      resolveSliderThumbRadius(
        hovering: false,
        dragging: true,
        visibleRadius: 5,
      ),
      5,
    );
  });

  test('canPaintSliderAtWidth guards tiny render widths', () {
    expect(canPaintSliderAtWidth(0), isFalse);
    expect(canPaintSliderAtWidth(7.99), isFalse);
    expect(canPaintSliderAtWidth(8), isTrue);
    expect(canPaintSliderAtWidth(double.nan), isFalse);
  });

  test('smoothAudioSpectrum blends active samples', () {
    final smoothed = smoothAudioSpectrum(
      previous: const [0.4, 0.2],
      next: const [1.0, 0.0],
      active: true,
      binCount: 2,
      rawWeight: 0.25,
    );

    expect(smoothed, hasLength(2));
    expect(smoothed[0], closeTo(0.55, 0.0001));
    expect(smoothed[1], closeTo(0.15, 0.0001));
  });

  test('smoothAudioSpectrum decays when inactive', () {
    final smoothed = smoothAudioSpectrum(
      previous: const [0.5, 0.25],
      next: const [],
      active: false,
      binCount: 2,
      decay: 0.5,
    );

    expect(smoothed[0], closeTo(0.25, 0.0001));
    expect(smoothed[1], closeTo(0.125, 0.0001));
  });

  test('smoothAudioSpectrum keeps empty input empty', () {
    expect(
      smoothAudioSpectrum(previous: const [], next: const [], active: false),
      isEmpty,
    );
  });
}
