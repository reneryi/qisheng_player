import 'package:coriander_player/component/ui/expandable_search_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('ExpandableSearchAction stays stable on narrow width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
    );

    await tester.tap(find.byTooltip('搜索当前页面'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
