import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/lyric_line_motion.dart';
import 'package:qisheng_player/theme/app_theme.dart';

void main() {
  testWidgets('current line settles without elastic rebound', (
    tester,
  ) async {
    Widget app({required bool isCurrent, required int distance}) {
      return MaterialApp(
        theme: AppTheme.build(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          effectsLevel: UiEffectsLevel.visual,
        ),
        home: LyricLineMotion(
          isCurrent: isCurrent,
          distanceFromCurrent: distance,
          child: const Text('line'),
        ),
      );
    }

    await tester.pumpWidget(app(isCurrent: false, distance: 3));
    var slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    var scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(slide.curve, isNot(Curves.elasticOut));
    expect(slide.offset.dy, closeTo(0.024, 0.001));
    expect(scale.scale, closeTo(0.985, 0.001));

    await tester.pumpWidget(app(isCurrent: true, distance: 0));
    slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(slide.curve, isNot(Curves.elasticOut));
    expect(slide.offset, Offset.zero);
    expect(scale.scale, 1);
  });
}
