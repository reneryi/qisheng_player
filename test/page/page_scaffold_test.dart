import 'package:coriander_player/page/page_scaffold.dart';
import 'package:coriander_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _buildTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

void main() {
  testWidgets('PageScaffold wraps actions on narrower desktop widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(980, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: Scaffold(
          body: PageScaffold(
            title: '媒体库',
            subtitle: '测试头部布局',
            primaryAction: FilledButton(
              onPressed: () {},
              child: const Text('主操作'),
            ),
            secondaryActions: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('筛选'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('排序'),
              ),
            ],
            body: const Placeholder(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('主操作'), findsOneWidget);
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('排序'), findsOneWidget);
  });
}
