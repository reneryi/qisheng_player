import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/windows_accessibility_tooltip_guard.dart';

void main() {
  test('Windows 语义树启用时仅隐藏可视 Tooltip', () {
    expect(
      shouldShowTooltips(isWindows: true, semanticsEnabled: false),
      isTrue,
    );
    expect(
      shouldShowTooltips(isWindows: true, semanticsEnabled: true),
      isFalse,
    );
  });

  test('其他平台不受 Windows 引擎规避逻辑影响', () {
    expect(
      shouldShowTooltips(isWindows: false, semanticsEnabled: true),
      isTrue,
    );
  });

  testWidgets('启用语义树后不创建 Tooltip Overlay', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: WindowsAccessibilityTooltipGuard(
          isWindowsForTesting: true,
          semanticsEnabledForTesting: true,
          child: ListView(
            children: [
              Semantics(
                label: 'Tooltip A',
                excludeSemantics: true,
                child: const Tooltip(
                  message: 'Tooltip A',
                  child: Text('A'),
                ),
              ),
              const Tooltip(message: 'Tooltip B', child: Text('B')),
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

    expect(find.text('Tooltip A'), findsNothing);
    expect(
      tester.getSemantics(find.text('A')),
      matchesSemantics(label: 'Tooltip A'),
    );
    await gesture.removePointer();
    semantics.dispose();
  });
}
