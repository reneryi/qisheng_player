import 'package:qisheng_player/page/now_playing_page/component/lyric_controls_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller stays visible across region and controls hover handoff', () {
    final controller = LyricControlsVisibilityController();
    addTearDown(controller.dispose);

    controller.setRegionHovered(true);
    expect(controller.visible, isTrue);

    controller.setControlsHovered(true);
    controller.setRegionHovered(false);
    expect(controller.visible, isTrue);

    controller.setControlsHovered(false);
    expect(controller.visible, isTrue);
  });

  test('controller keeps visible while menu is open and hides after delay',
      () async {
    final controller = LyricControlsVisibilityController();
    addTearDown(controller.dispose);

    controller.setMenuOpen(true);
    expect(controller.visible, isTrue);

    controller.setMenuOpen(false);
    expect(controller.visible, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 159));
    expect(controller.visible, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.visible, isFalse);
  });
}
