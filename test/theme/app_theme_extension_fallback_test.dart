import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

void main() {
  testWidgets('app theme tokens fall back under a plain MaterialApp', (
    tester,
  ) async {
    late List<Object> tokens;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: Builder(
          builder: (context) {
            tokens = [
              context.chrome,
              context.surfaces,
              context.accents,
              context.visuals,
              context.motion,
              context.playerTokens,
            ];
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tokens, hasLength(6));
    expect(tokens, everyElement(isNotNull));
  });
}
