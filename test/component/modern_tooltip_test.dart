import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/component/ui/modern_tooltip.dart';
import 'package:qisheng_player/window_controls.dart';

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

  group('ModernTooltip.computePositionAndArrowOffset mathematical tests', () {
    test('computes zero arrowOffset when target is centered horizontally', () {
      final result = ModernTooltip.computePositionAndArrowOffset(
        targetCenter: const Offset(400, 100),
        targetSize: const Size(40, 40),
        childSize: const Size(200, 40),
        overlaySize: const Size(800, 600),
        direction: ModernTooltipDirection.bottom,
      );

      // Ideal left = 400 - 100 = 300. Fits within margin 8 and right bound 800 - 200 - 8 = 592.
      expect(result.offset.dx, 300.0);
      expect(result.offset.dy, 100 + 20 + 6.0); // targetBottom + gap
      expect(result.arrowOffset, 0.0);
    });

    test('computes positive arrowOffset when clamped on screen right boundary', () {
      final result = ModernTooltip.computePositionAndArrowOffset(
        targetCenter: const Offset(760, 100),
        targetSize: const Size(40, 40),
        childSize: const Size(240, 40),
        overlaySize: const Size(800, 600),
        direction: ModernTooltipDirection.bottom,
      );

      // Right boundary clamp = 800 - 240 - 8 = 552.
      expect(result.offset.dx, 552.0);
      // bubbleCenterX = 552 + 120 = 672.
      // arrowOffset = 760 - 672 = 88.0.
      expect(result.arrowOffset, 88.0);
      // Verify tip aligns exactly with targetCenter.dx
      expect(result.offset.dx + 240 / 2 + result.arrowOffset, 760.0);
    });

    test('computes negative arrowOffset when clamped on screen left boundary', () {
      final result = ModernTooltip.computePositionAndArrowOffset(
        targetCenter: const Offset(40, 100),
        targetSize: const Size(40, 40),
        childSize: const Size(240, 40),
        overlaySize: const Size(800, 600),
        direction: ModernTooltipDirection.bottom,
      );

      // Left boundary clamp = margin = 8.0.
      expect(result.offset.dx, 8.0);
      // bubbleCenterX = 8 + 120 = 128.
      // arrowOffset = 40 - 128 = -88.0.
      expect(result.arrowOffset, -88.0);
      // Verify tip aligns exactly with targetCenter.dx
      expect(result.offset.dx + 240 / 2 + result.arrowOffset, 40.0);
    });

    test('computes vertical arrowOffset for left and right directions when clamped', () {
      // Near top edge, direction: left
      final topResult = ModernTooltip.computePositionAndArrowOffset(
        targetCenter: const Offset(500, 30),
        targetSize: const Size(40, 40),
        childSize: const Size(120, 80),
        overlaySize: const Size(800, 600),
        direction: ModernTooltipDirection.left,
      );
      expect(topResult.offset.dy, 8.0); // clamped to top margin
      expect(topResult.arrowOffset, 30 - (8.0 + 40.0)); // 30 - 48 = -18.0
      expect(topResult.offset.dy + 80 / 2 + topResult.arrowOffset, 30.0);

      // Near bottom edge, direction: right
      final bottomResult = ModernTooltip.computePositionAndArrowOffset(
        targetCenter: const Offset(300, 580),
        targetSize: const Size(40, 40),
        childSize: const Size(120, 80),
        overlaySize: const Size(800, 600),
        direction: ModernTooltipDirection.right,
      );
      expect(bottomResult.offset.dy, 600 - 80 - 8.0); // 512.0
      expect(bottomResult.arrowOffset, 580 - (512.0 + 40.0)); // 580 - 552 = 28.0
      expect(bottomResult.offset.dy + 80 / 2 + bottomResult.arrowOffset, 580.0);
    });
  });

  group('ModernTooltip widget right-clamp arrow alignment tests', () {
    testWidgets('arrow offset aligns with button center when clamped at screen right', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, right: 16),
                child: ModernTooltip(
                  message: '切换页面视图：当前为列表视图',
                  direction: ModernTooltipDirection.bottom,
                  child: Container(
                    width: 36,
                    height: 36,
                    color: Colors.blue,
                    child: const Text('BTN'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final btnCenter = tester.getCenter(find.text('BTN'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(btnCenter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));

      final textFinder = find.text('切换页面视图：当前为列表视图');
      expect(textFinder, findsOneWidget);

      final containerFinder =
          find.ancestor(of: textFinder, matching: find.byType(Container)).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      final shape = decoration.shape as BubbleShapeBorder;

      // Because the button is near right edge and tooltip is ~200px wide,
      // arrowOffset must be positive to compensate for leftward clamp.
      expect(shape.arrowOffset, greaterThan(20.0));

      // Global tip X = containerTopLeft.dx + width / 2 + arrowOffset
      final containerRect = tester.getRect(containerFinder);
      final tipGlobalX = containerRect.left + containerRect.width / 2 + shape.arrowOffset;
      expect((tipGlobalX - btnCenter.dx).abs(), lessThan(1.0));
    });
  });

  group('R1: TopBar control buttons tooltip suppression & semantics tests', () {
    testWidgets('CpIconButton with semanticsLabel renders no Tooltip and has semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CpIconButton(
                icon: const Icon(Icons.arrow_back),
                semanticsLabel: '返回',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Verify no Tooltip or ModernTooltip widget is mounted
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(ModernTooltip), findsNothing);

      // Verify Semantics label is present
      expect(find.bySemanticsLabel('返回'), findsOneWidget);

      // Hover over button and verify no tooltip appears
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(CpIconButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure no text overlay popped up
      expect(find.text('返回'), findsNothing);
    });

    testWidgets('TitleBar navigation buttons have no Tooltip and retain Semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NavBackBtn(),
                NavForwardBtn(),
              ],
            ),
          ),
        ),
      );

      // Verify zero Tooltip widgets in Nav buttons
      expect(find.descendant(of: find.byType(NavBackBtn), matching: find.byType(Tooltip)), findsNothing);
      expect(find.descendant(of: find.byType(NavForwardBtn), matching: find.byType(Tooltip)), findsNothing);

      // Verify Semantics labels are accessible
      expect(find.bySemanticsLabel('返回'), findsOneWidget);
      expect(find.bySemanticsLabel('前进'), findsOneWidget);
    });

    testWidgets('WindowControlls buttons have no Tooltip and update Semantics on layoutMode changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WindowControlls(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no Tooltip widget in WindowControlls
      expect(find.descendant(of: find.byType(WindowControlls), matching: find.byType(Tooltip)), findsNothing);

      // Verify semantics
      expect(find.bySemanticsLabel('最大化'), findsOneWidget);
      expect(find.bySemanticsLabel('最小化'), findsOneWidget);
      expect(find.bySemanticsLabel('全屏'), findsOneWidget);
      expect(find.bySemanticsLabel('退出'), findsOneWidget);

      // Switch to maximized mode
      WindowControls.layoutMode.value = WindowLayoutMode.maximized;
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('还原'), findsOneWidget);
      expect(find.bySemanticsLabel('最大化'), findsNothing);

      // Switch to fullscreen mode
      WindowControls.layoutMode.value = WindowLayoutMode.fullscreen;
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('退出全屏'), findsOneWidget);
      expect(find.bySemanticsLabel('全屏模式下不可用'), findsOneWidget);

      // Reset back to normal
      WindowControls.layoutMode.value = WindowLayoutMode.normal;
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('最大化'), findsOneWidget);
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

