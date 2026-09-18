import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/windows_accessibility_tooltip_guard.dart';

void main() {
  test('Windows 语义树启用时 Tooltip 依然保持可用', () {
    expect(
      shouldShowTooltips(isWindows: true, semanticsEnabled: false),
      isTrue,
    );
    expect(
      shouldShowTooltips(isWindows: true, semanticsEnabled: true),
      isTrue,
    );
  });

  test('其他平台 Tooltip 保持可用', () {
    expect(
      shouldShowTooltips(isWindows: false, semanticsEnabled: true),
      isTrue,
    );
  });

  testWidgets('启用语义树后仍可正常创建 Tooltip Overlay', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: WindowsAccessibilityTooltipGuard(
          isWindowsForTesting: true,
          semanticsEnabledForTesting: true,
          child: ListView(
            children: const [
              Tooltip(
                message: 'Tooltip A',
                child: Text('A'),
              ),
              Tooltip(message: 'Tooltip B', child: Text('B')),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('A')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tooltip A'), findsOneWidget);
    await gesture.removePointer();
    semantics.dispose();
  });
}
