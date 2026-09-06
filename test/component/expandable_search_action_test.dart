import 'package:qisheng_player/component/ui/expandable_search_action.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('ExpandableSearchAction stays stable on narrow width',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: buildTestTheme(),
          home: Center(
            child: SizedBox(
              width: 74,
              child: ExpandableSearchAction(
                hintText: 'Search',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('搜索当前页面'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ExpandableSearchAction accepts space while typing',
      (tester) async {
    String latestValue = '';

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: ExpandableSearchAction(
                  hintText: 'Search',
                  onChanged: (value) => latestValue = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('搜索当前页面'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lofi mix');
    await tester.pump();

    expect(find.text('lofi mix'), findsOneWidget);
    expect(latestValue, 'lofi mix');
  });
}
