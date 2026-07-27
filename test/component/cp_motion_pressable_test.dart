import 'dart:ui';

import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHost({
    bool selected = false,
    bool selectedGlow = false,
  }) {
    return MaterialApp(
      theme: AppTheme.build(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8DFF),
        ),
      ),
      home: Scaffold(
        body: Center(
          child: CpMotionPressable(
            onTap: () {},
            selected: selected,
            selectedGlow: selectedGlow,
            hoverScale: 1.02,
            pressScale: 0.99,
            hoverShadow: true,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      ),
    );
  }

  Finder pressableScaleFinder() => find.descendant(
        of: find.byType(CpMotionPressable),
        matching: find.byType(AnimatedScale),
      );

  Finder pressableContainerFinder() => find.descendant(
        of: find.byType(CpMotionPressable),
        matching: find.byType(AnimatedContainer),
      );

  testWidgets('CpMotionPressable applies hover and press scale',
      (tester) async {
    await tester.pumpWidget(buildHost());

    expect(tester.widget<AnimatedScale>(pressableScaleFinder()).scale, 1);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(CpMotionPressable)));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(pressableScaleFinder()).scale, 1.02);

    await gesture.down(tester.getCenter(find.byType(CpMotionPressable)));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(pressableScaleFinder()).scale, 0.99);

    await gesture.up();
  });

  testWidgets('CpMotionPressable paints selected glow when enabled',
      (tester) async {
    await tester.pumpWidget(buildHost(selected: true, selectedGlow: true));

    final container =
        tester.widget<AnimatedContainer>(pressableContainerFinder());
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('immersive icon button has a transparent 48 pixel hit area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F8DFF),
          ),
        ),
        home: const Scaffold(
          body: Center(
            child: CpIconButton(
              variant: CpButtonVariant.immersive,
              tooltip: '沉浸式按钮',
              onPressed: _noop,
              icon: Icon(Icons.sort),
            ),
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.style?.fixedSize?.resolve({}), const Size.square(48));
    expect(button.style?.backgroundColor?.resolve({}), Colors.transparent);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(button.style?.side?.resolve({}), BorderSide.none);
  });

  testWidgets('immersive icon button follows light and dark theme colors', (
    tester,
  ) async {
    Future<Color?> pumpAndReadIconColor(Brightness brightness) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F8DFF),
        brightness: brightness,
      );
      final theme = AppTheme.build(colorScheme: colorScheme);
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: theme,
            child: const Scaffold(
              body: Center(
                child: CpIconButton(
                  variant: CpButtonVariant.immersive,
                  onPressed: _noop,
                  icon: Icon(Icons.sort),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return IconTheme.of(tester.element(find.byIcon(Icons.sort))).color;
    }

    final lightColor = await pumpAndReadIconColor(Brightness.light);
    final darkColor = await pumpAndReadIconColor(Brightness.dark);

    expect(lightColor, isNotNull);
    expect(darkColor, isNotNull);
    expect(lightColor!.computeLuminance(), lessThan(0.2));
    expect(darkColor!.computeLuminance(), greaterThan(0.7));
  });
}

void _noop() {}
