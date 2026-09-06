import 'package:qisheng_player/component/window_drag_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WindowDragRegion ignores single clicks', (tester) async {
    var dragStartCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: WindowDragRegion(
                onStartDragging: () async {
                  dragStartCount += 1;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final region = find.byType(WindowDragRegion);
    final center = tester.getCenter(region);

    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();

    expect(dragStartCount, 0);
  });

  testWidgets('WindowDragRegion ignores movement below threshold', (
    tester,
  ) async {
    var dragStartCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: WindowDragRegion(
                dragThreshold: 5,
                onStartDragging: () async {
                  dragStartCount += 1;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final region = find.byType(WindowDragRegion);
    final center = tester.getCenter(region);

    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(3, 3));
    await tester.pump();
    await gesture.up();

    expect(dragStartCount, 0);
  });

  testWidgets('WindowDragRegion starts dragging after threshold once', (
    tester,
  ) async {
    var dragStartCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: WindowDragRegion(
                dragThreshold: 5,
                onStartDragging: () async {
                  dragStartCount += 1;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final region = find.byType(WindowDragRegion);
    final center = tester.getCenter(region);

    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(6, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    await gesture.up();

    expect(dragStartCount, 1);
  });

  testWidgets('WindowDragRegion ignores repeated clicks without dragging', (
    tester,
  ) async {
    var dragStartCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: WindowDragRegion(
                onStartDragging: () async {
                  dragStartCount += 1;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final region = find.byType(WindowDragRegion);
    final center = tester.getCenter(region);

    final firstGesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await firstGesture.up();
    final secondGesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await secondGesture.up();
    await tester.pump();

    expect(dragStartCount, 0);
  });

  testWidgets('WindowDragRegion invokes onDoubleTap when double clicked without dragging', (
    tester,
  ) async {
    var doubleTapCount = 0;
    var dragStartCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: WindowDragRegion(
                onDoubleTap: () {
                  doubleTapCount += 1;
                },
                onStartDragging: () async {
                  dragStartCount += 1;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final region = find.byType(WindowDragRegion);
    final center = tester.getCenter(region);

    final firstGesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await firstGesture.up();
    await tester.pump(const Duration(milliseconds: 50));

    final secondGesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await secondGesture.up();
    await tester.pump();

    expect(doubleTapCount, 1);
    expect(dragStartCount, 0);
  });
}
