import 'package:qisheng_player/component/window_resize_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  Future<void> pumpResizeFrame(
    WidgetTester tester, {
    required WindowResizeStartCallback onStartResizing,
    double dragThreshold = 5,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 120,
            child: WindowResizeFrame(
              dragThreshold: dragThreshold,
              onStartResizing: onStartResizing,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  Offset topEdgeCenter(WidgetTester tester) {
    final rect = tester.getRect(find.byType(WindowResizeFrame));
    return rect.topCenter + const Offset(0, 4);
  }

  testWidgets('WindowResizeFrame ignores single edge clicks', (tester) async {
    var resizeStartCount = 0;

    await pumpResizeFrame(
      tester,
      onStartResizing: (_) async {
        resizeStartCount += 1;
        return true;
      },
    );

    final gesture = await tester.startGesture(
      topEdgeCenter(tester),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();

    expect(resizeStartCount, 0);
  });

  testWidgets('WindowResizeFrame edge clicks do not reach child', (
    tester,
  ) async {
    var childTapCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 120,
            child: WindowResizeFrame(
              onStartResizing: (_) async => true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => childTapCount += 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      topEdgeCenter(tester),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();

    expect(childTapCount, 0);
  });

  testWidgets('WindowResizeFrame ignores movement below threshold', (
    tester,
  ) async {
    var resizeStartCount = 0;

    await pumpResizeFrame(
      tester,
      onStartResizing: (_) async {
        resizeStartCount += 1;
        return true;
      },
    );

    final gesture = await tester.startGesture(
      topEdgeCenter(tester),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(3, 3));
    await tester.pump();
    await gesture.up();

    expect(resizeStartCount, 0);
  });

  testWidgets('WindowResizeFrame starts resizing after threshold once', (
    tester,
  ) async {
    var resizeStartCount = 0;
    ResizeEdge? resizeEdge;

    await pumpResizeFrame(
      tester,
      onStartResizing: (edge) async {
        resizeStartCount += 1;
        resizeEdge = edge;
        return true;
      },
    );

    final gesture = await tester.startGesture(
      topEdgeCenter(tester),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(6, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    await gesture.up();

    expect(resizeStartCount, 1);
    expect(resizeEdge, ResizeEdge.top);
  });
}
