import 'package:coriander_player/component/scroll_aware_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AlwaysDeferScrollPhysics extends ScrollPhysics {
  const _AlwaysDeferScrollPhysics({super.parent});

  @override
  _AlwaysDeferScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _AlwaysDeferScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) {
    return true;
  }
}

void main() {
  Widget buildHarness({
    required Object futureKey,
    required Future<int> Function() future,
    ScrollPhysics? physics,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          physics: physics,
          children: [
            ScrollAwareFutureBuilder<int>(
              futureKey: futureKey,
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('waiting');
                }
                return Text('value-${snapshot.data}');
              },
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('ignores scheduled deferred load after disposal', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      buildHarness(
        futureKey: 'a',
        physics: const _AlwaysDeferScrollPhysics(),
        future: () {
          calls++;
          return Future.value(1);
        },
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restarts the deferred future when futureKey changes',
      (tester) async {
    var value = 1;

    await tester.pumpWidget(
      buildHarness(
        futureKey: 'a',
        future: () => Future.value(value),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('value-1'), findsOneWidget);

    value = 2;
    await tester.pumpWidget(
      buildHarness(
        futureKey: 'b',
        future: () => Future.value(value),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('value-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
