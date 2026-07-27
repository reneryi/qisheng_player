import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/theme/app_theme.dart';

void main() {
  Widget buildHost({
    List<Color>? gradientColors,
    Widget Function(BuildContext)? backgroundBuilder,
  }) {
    return MaterialApp(
      theme: AppTheme.build(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8DFF),
        ),
      ),
      home: Scaffold(
        body: CpSurface(
          tone: CpSurfaceTone.panel,
          dynamicGradientColors: gradientColors,
          backgroundBuilder: backgroundBuilder,
          child: const SizedBox(width: 120, height: 48),
        ),
      ),
    );
  }

  testWidgets('main surface uses a horizontal dynamic gradient',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        gradientColors: const [Color(0xFFE06A32), Color(0xFF7C321E)],
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final gradient =
        (container.decoration! as BoxDecoration).gradient! as LinearGradient;

    expect(gradient.begin, Alignment.centerLeft);
    expect(gradient.end, Alignment.centerRight);
  });

  testWidgets('surface without dynamic colors keeps the default gradient',
      (tester) async {
    await tester.pumpWidget(buildHost());

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final gradient =
        (container.decoration! as BoxDecoration).gradient! as LinearGradient;

    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
  });

  testWidgets('custom background replaces the decoration gradient',
      (tester) async {
    await tester.pumpWidget(
      buildHost(
        gradientColors: const [Color(0xFFE06A32), Color(0xFF7C321E)],
        backgroundBuilder: (_) => const ColoredBox(
          key: Key('custom-surface-background'),
          color: Color(0xFF123456),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.gradient, isNull);
    expect(find.byKey(const Key('custom-surface-background')), findsOneWidget);
    expect(find.byType(ClipRRect), findsWidgets);
  });
}
