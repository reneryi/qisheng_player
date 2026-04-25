import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/main_layout_frame.dart';
import 'package:coriander_player/component/ui/liquid_gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveMainLayoutDockInset reserves dock space only when needed', () {
    expect(
      resolveMainLayoutDockInset(
        reserveDockSpace: true,
        hasOverlay: true,
        dockHeight: 90,
        shellGap: 24,
      ),
      138,
    );

    expect(
      resolveMainLayoutDockInset(
        reserveDockSpace: false,
        hasOverlay: true,
        dockHeight: 90,
        shellGap: 24,
      ),
      0,
    );

    expect(
      resolveMainLayoutDockInset(
        reserveDockSpace: true,
        hasOverlay: false,
        dockHeight: 90,
        shellGap: 24,
      ),
      0,
    );
  });

  test('resolveLiquidGradientProfile disables animation in performance mode',
      () {
    final performance = resolveLiquidGradientProfile(
      UiEffectsLevel.performance,
    );
    final balanced = resolveLiquidGradientProfile(UiEffectsLevel.balanced);
    final visual = resolveLiquidGradientProfile(UiEffectsLevel.visual);

    expect(performance.animated, isFalse);
    expect(balanced.animated, isTrue);
    expect(visual.animated, isTrue);
    expect(visual.bandOpacity, greaterThan(balanced.bandOpacity));
  });

  test('resolveLiquidGradientProfile lowers intensity for tint-only mode', () {
    final normal = resolveLiquidGradientProfile(UiEffectsLevel.visual);
    final tintOnly = resolveLiquidGradientProfile(
      UiEffectsLevel.visual,
      tintOnly: true,
    );

    expect(tintOnly.bandOpacity, lessThan(normal.bandOpacity));
    expect(tintOnly.mixStrength, lessThan(normal.mixStrength));
  });

  testWidgets('LiquidGradientBackground is repaint-boundary isolated',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 180,
          child: LiquidGradientBackground(
            backgroundColors: [
              Color(0xFF101820),
              Color(0xFF060A10),
              Color(0xFF010204),
            ],
            paletteColors: [
              Color(0xFFCF305C),
              Color(0xFF204C90),
              Color(0xFF56A3B8),
              Color(0xFF403A4F),
            ],
            effectsLevel: UiEffectsLevel.performance,
          ),
        ),
      ),
    );

    expect(find.byType(RepaintBoundary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
