import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/ui/modern_tooltip.dart';

void main() {
  group('BubbleShapeBorder tests', () {
    test('computes correct dimensions according to arrow direction', () {
      const downBorder = BubbleShapeBorder(
        arrowDirection: BubbleArrowDirection.down,
        arrowHeight: 6.0,
      );
      expect(downBorder.dimensions, const EdgeInsets.only(bottom: 6.0));

      const upBorder = BubbleShapeBorder(
        arrowDirection: BubbleArrowDirection.up,
        arrowHeight: 6.0,
      );
      expect(upBorder.dimensions, const EdgeInsets.only(top: 6.0));

      const leftBorder = BubbleShapeBorder(
        arrowDirection: BubbleArrowDirection.left,
        arrowHeight: 8.0,
      );
      expect(leftBorder.dimensions, const EdgeInsets.only(left: 8.0));

      const rightBorder = BubbleShapeBorder(
        arrowDirection: BubbleArrowDirection.right,
        arrowHeight: 8.0,
      );
      expect(rightBorder.dimensions, const EdgeInsets.only(right: 8.0));

      const noneBorder = BubbleShapeBorder(
        arrowDirection: BubbleArrowDirection.none,
      );
      expect(noneBorder.dimensions, EdgeInsets.zero);
    });

    test('generates outer path without throw for all directions', () {
      const rect = Rect.fromLTWH(0, 0, 100, 40);
      for (final dir in BubbleArrowDirection.values) {
        final border = BubbleShapeBorder(arrowDirection: dir);
        final path = border.getOuterPath(rect);
        expect(path, isNotNull);
        expect(path.getBounds().isEmpty, isFalse);
      }

      // Empty / zero rect edge case
      for (final dir in BubbleArrowDirection.values) {
        final border = BubbleShapeBorder(arrowDirection: dir);
        final emptyPath = border.getOuterPath(Rect.zero);
        expect(emptyPath, isNotNull);
        expect(emptyPath.getBounds().isEmpty, isTrue);
      }
    });
  });

  group('ModernTooltip widget tests', () {
    testWidgets('renders child and reveals tooltip on hover', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ModernTooltip(
                message: '提示文本',
                direction: ModernTooltipDirection.left,
                child: Text('悬停目标'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('悬停目标'), findsOneWidget);
      expect(find.text('提示文本'), findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('悬停目标')));
      await tester.pump();

      // Wait for tooltip hover delay
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('提示文本'), findsOneWidget);

      // Verify tooltip is wrapped in IgnorePointer
      final ignorePointerFinder = find.ancestor(
        of: find.text('提示文本'),
        matching: find.byType(IgnorePointer),
      );
      expect(ignorePointerFinder, findsWidgets);

      // Move away
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('提示文本'), findsNothing);
    });

    testWidgets('sequential hover switches tooltips quickly without overlap',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModernTooltip(
                    message: '按钮一提示',
                    direction: ModernTooltipDirection.left,
                    child: Text('按钮一'),
                  ),
                  SizedBox(height: 16),
                  ModernTooltip(
                    message: '按钮二提示',
                    direction: ModernTooltipDirection.left,
                    child: Text('按钮二'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);

      // Hover Button 1
      await gesture.moveTo(tester.getCenter(find.text('按钮一')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('按钮一提示'), findsOneWidget);
      expect(find.text('按钮二提示'), findsNothing);

      // Move directly to Button 2
      await gesture.moveTo(tester.getCenter(find.text('按钮二')));
      await tester.pump();

      // Button 1 tooltip dismisses immediately and Button 2 tooltip reveals rapidly
      expect(find.text('按钮一提示'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('按钮二提示'), findsOneWidget);

      // Move away
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('按钮二提示'), findsNothing);
    });

    testWidgets('rapid re-entry into the same button interrupts exit smoothly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ModernTooltip(
                message: '再入测试提示',
                child: Text('再入测试目标'),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);

      // Hover
      await gesture.moveTo(tester.getCenter(find.text('再入测试目标')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('再入测试提示'), findsOneWidget);

      // Move away to start exit
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120)); // partial exit

      // Move back immediately during exit
      await gesture.moveTo(tester.getCenter(find.text('再入测试目标')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tooltip stays visible without throwing or unhandled errors
      expect(find.text('再入测试提示'), findsOneWidget);
    });
  });

  group('ModernTooltipManager unit tests', () {
    test('warm state lifecycle and dismissAll', () {
      final manager = ModernTooltipManager.instance;
      manager.dismissAll();
      expect(manager.isWarm, isFalse);

      final fakeEntry = _FakeTooltipEntry();
      manager.onTooltipShown(fakeEntry);
      expect(manager.isWarm, isTrue);

      manager.onTooltipExit(fakeEntry);
      // Still warm immediately after exit
      expect(manager.isWarm, isTrue);

      manager.dismissAll();
      expect(manager.isWarm, isFalse);
      expect(fakeEntry.dismissed, isTrue);
    });

    testWidgets('ModernTooltip overlay remains compact and does not expand to full screen',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ModernTooltip(
                message: '增大歌词字体',
                direction: ModernTooltipDirection.auto,
                child: Text('按钮'),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('按钮')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));

      final textFinder = find.text('增大歌词字体');
      expect(textFinder, findsOneWidget);

      final containerFinder =
          find.ancestor(of: textFinder, matching: find.byType(Container)).first;
      final size = tester.getSize(containerFinder);

      // Tooltip must be compact, far smaller than full screen (1920x1080)
      expect(size.width, lessThan(200.0));
      expect(size.height, lessThan(60.0));

      // Because target is at the top of screen, direction must resolve to bottom
      final tooltipTop = tester.getTopLeft(containerFinder).dy;
      final buttonBottom = tester.getBottomLeft(find.text('按钮')).dy;
      expect(tooltipTop, greaterThan(buttonBottom));
    });
  });
}



class _FakeTooltipEntry implements ModernTooltipEntry {
  bool dismissed = false;

  @override
  void dismissImmediate() {
    dismissed = true;
  }
}

