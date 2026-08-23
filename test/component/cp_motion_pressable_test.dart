import 'dart:ui';

import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHost({
    bool selected = false,
    bool selectedGlow = false,
    VoidCallback? onTap,
    GestureTapDownCallback? onSecondaryTapDown,
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
            onTap: onTap ?? () {},
            onSecondaryTapDown: onSecondaryTapDown,
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

  testWidgets('keyboard Enter activates onTap (1.4)', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(buildHost(onTap: () => tapped++));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tapped, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(tapped, 2);
  });

  testWidgets('keyboard context menu key triggers secondary tap (1.4)', (
    tester,
  ) async {
    TapDownDetails? received;
    await tester.pumpWidget(
      buildHost(onSecondaryTapDown: (details) => received = details),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();
    expect(received, isNotNull);
  });

  testWidgets('focused pressable shows focus ring border (1.4)', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost());

    final containerFinder = pressableContainerFinder();
    BoxDecoration? decoration() =>
        tester.widget<AnimatedContainer>(containerFinder).decoration!
            as BoxDecoration?;

    // 未聚焦：边框为透明色（widget.border 默认 true 时始终有 border 对象）
    expect(decoration()?.border?.top.color, Colors.transparent);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    // 聚焦：出现品牌色描边（focus ring）
    final focusedBorder = decoration()?.border;
    expect(focusedBorder, isNotNull);
    expect(focusedBorder!.top.color, isNot(Colors.transparent));
  });

  testWidgets('non-interactive pressable cannot receive focus (1.4)', (
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
            child: CpMotionPressable(
              onTap: null,
              child: SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );

    // onTap 为 null 时内部 Focus 不可请求焦点
    final focus = tester.widget<Focus>(find.descendant(
      of: find.byType(CpMotionPressable),
      matching: find.byType(Focus),
    ));
    expect(focus.canRequestFocus, isFalse);
  });
}

void _noop() {}
