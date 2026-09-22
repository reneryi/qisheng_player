import 'package:desktop_lyric/component/desktop_lyric_body.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const testTheme = ThemeChangedMessage(
    0xFF2196F3,
    0xFF1E1E1E,
    0xFFFFFFFF,
  );

  Widget buildSubject({
    ThemeChangedMessage theme = testTheme,
    bool isDarkMode = true,
  }) {
    DesktopLyricController.instance.isDarkMode.value = isDarkMode;
    return Provider<ThemeChangedMessage>.value(
      value: theme,
      child: MaterialApp(
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const SizedBox(
          width: 800,
          height: 180,
          child: DesktopLyricBody(),
        ),
      ),
    );
  }

  testWidgets('initial unhovered state has transparent material and easeOutCubic curve',
      (tester) async {
    await tester.pumpWidget(buildSubject(isDarkMode: true));

    final containerFinder = find.byType(AnimatedContainer);
    expect(containerFinder, findsOneWidget);

    final container = tester.widget<AnimatedContainer>(containerFinder);
    expect(container.duration, const Duration(milliseconds: 240));
    expect(container.curve, Curves.easeOutCubic);
    expect(
      container.margin,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.transparent);
    expect(decoration.gradient, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(18.0));
    expect(
      decoration.border,
      Border.all(color: Colors.transparent, width: 1.0),
    );
    expect(decoration.boxShadow == null || decoration.boxShadow!.isEmpty, isTrue);
  });

  testWidgets('hover state in dark mode renders frosted glass material with dual shadows',
      (tester) async {
    await tester.pumpWidget(buildSubject(isDarkMode: true));

    final bodyStateFinder = find.byType(DesktopLyricBody);
    final state = tester.state<DesktopLyricBodyState>(bodyStateFinder);

    // Simulate hover
    state.setHoveringForTest(true);
    await tester.pumpAndSettle();

    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration as BoxDecoration;

    // 1. Semi-transparent blended base color (alpha ~ 78%)
    final expectedDarkColor = Color.alphaBlend(
      const Color(0xFF2196F3).withValues(alpha: 0.10),
      const Color(0xFF141923).withValues(alpha: 0.78),
    );
    expect(decoration.color, equals(expectedDarkColor));

    // 2. Diagonal micro-glimmer refraction gradient
    final gradient = decoration.gradient as LinearGradient?;
    expect(gradient, isNotNull);
    expect(gradient!.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors, [
      Colors.white.withValues(alpha: 0.08),
      Colors.transparent,
    ]);

    // 3. 1px micro-highlight border
    expect(
      decoration.border,
      Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.0),
    );

    // 4. Modern capsule border radius
    expect(decoration.borderRadius, BorderRadius.circular(18.0));

    // 5. Dual-layer ambient and theme halo box shadows
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.length, 2);

    final shadow0 = decoration.boxShadow![0];
    expect(shadow0.color, Colors.black.withValues(alpha: 0.32));
    expect(shadow0.blurRadius, 20);
    expect(shadow0.offset, const Offset(0, 6));
    expect(shadow0.spreadRadius, -2);

    final shadow1 = decoration.boxShadow![1];
    expect(shadow1.color, const Color(0xFF2196F3).withValues(alpha: 0.20));
    expect(shadow1.blurRadius, 24);
    expect(shadow1.offset, const Offset(0, 2));
    expect(shadow1.spreadRadius, -4);
  });

  testWidgets('hover state in light mode renders bright frosted glass material',
      (tester) async {
    await tester.pumpWidget(buildSubject(isDarkMode: false));

    final bodyStateFinder = find.byType(DesktopLyricBody);
    final state = tester.state<DesktopLyricBodyState>(bodyStateFinder);

    state.setHoveringForTest(true);
    await tester.pumpAndSettle();

    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration as BoxDecoration;

    // 1. Semi-transparent blended base color (alpha ~ 82%)
    final expectedLightColor = Color.alphaBlend(
      const Color(0xFF2196F3).withValues(alpha: 0.05),
      Colors.white.withValues(alpha: 0.82),
    );
    expect(decoration.color, equals(expectedLightColor));

    // 2. Diagonal micro-glimmer gradient
    final gradient = decoration.gradient as LinearGradient?;
    expect(gradient, isNotNull);
    expect(gradient!.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors, [
      Colors.white.withValues(alpha: 0.70),
      Colors.transparent,
    ]);

    // 3. 1px micro-border in light mode
    expect(
      decoration.border,
      Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
    );

    // 4. Dual-layer box shadows in light mode
    expect(decoration.boxShadow!.length, 2);
    expect(decoration.boxShadow![0].color, Colors.black.withValues(alpha: 0.10));
    expect(decoration.boxShadow![0].blurRadius, 20);
    expect(decoration.boxShadow![0].offset, const Offset(0, 6));
    expect(decoration.boxShadow![0].spreadRadius, -2);

    expect(
      decoration.boxShadow![1].color,
      const Color(0xFF2196F3).withValues(alpha: 0.08),
    );
    expect(decoration.boxShadow![1].blurRadius, 24);
    expect(decoration.boxShadow![1].offset, const Offset(0, 2));
    expect(decoration.boxShadow![1].spreadRadius, -4);
  });

  testWidgets('mouse pointer enter and exit smoothly toggles hover state and material',
      (tester) async {
    await tester.pumpWidget(buildSubject(isDarkMode: true));

    final state = tester.state<DesktopLyricBodyState>(find.byType(DesktopLyricBody));
    expect(state.isHovering, isFalse);

    // Simulate mouse pointer moving into body
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(DesktopLyricBody)));
    await tester.pumpAndSettle();

    expect(state.isHovering, isTrue);
    var container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    var decoration = container.decoration as BoxDecoration;
    expect(decoration.color, isNot(Colors.transparent));
    expect(decoration.boxShadow, isNotEmpty);

    // Move mouse out of body
    await gesture.moveTo(const Offset(1000, 1000));
    await tester.pumpAndSettle();

    expect(state.isHovering, isFalse);
    container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.transparent);
    expect(decoration.boxShadow == null || decoration.boxShadow!.isEmpty, isTrue);

    await gesture.removePointer();
  });

  testWidgets('AnimatedSwitcher in DesktopLyricForeground uses Curves.easeOutCubic',
      (tester) async {
    await tester.pumpWidget(buildSubject(isDarkMode: true));

    final switcherFinder = find.byType(AnimatedSwitcher);
    expect(switcherFinder, findsOneWidget);

    final switcher = tester.widget<AnimatedSwitcher>(switcherFinder);
    expect(switcher.duration, const Duration(milliseconds: 150));
    expect(switcher.switchInCurve, Curves.easeOutCubic);
    expect(switcher.switchOutCurve, Curves.easeOutCubic);
  });

  testWidgets('ClipRRect encloses DesktopLyricForeground with 18px radius inside AnimatedContainer',
      (tester) async {
    await tester.pumpWidget(buildSubject(isDarkMode: true));

    final clipRRectFinder = find.descendant(
      of: find.byType(AnimatedContainer),
      matching: find.byType(ClipRRect),
    );
    expect(clipRRectFinder, findsOneWidget);

    final clipRRect = tester.widget<ClipRRect>(clipRRectFinder);
    expect(clipRRect.borderRadius, BorderRadius.circular(18.0));

    final foregroundFinder = find.descendant(
      of: clipRRectFinder,
      matching: find.byType(DesktopLyricForeground),
    );
    expect(foregroundFinder, findsOneWidget);
  });
}
