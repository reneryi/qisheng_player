import 'package:coriander_player/component/bottom_player_bar.dart';
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
}
