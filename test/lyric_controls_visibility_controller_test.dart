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

  test('controller auto-hides after idle delay in region and wakes up on pointer move',
      () async {
    final controller = LyricControlsVisibilityController(
      idleHideDelay: const Duration(milliseconds: 100),
      hideDelay: const Duration(milliseconds: 50),
    );
    addTearDown(controller.dispose);

    controller.setRegionHovered(true);
    expect(controller.visible, isTrue);

    // After idle delay without mouse movement, it should stealthily hide
    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(controller.visible, isFalse);

    // Mouse movement in region wakes it up
    controller.onRegionPointerMove();
    expect(controller.visible, isTrue);

    // But if hovering controls, it should NOT auto-hide after idle delay
    controller.setControlsHovered(true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(controller.visible, isTrue);
  });
}
