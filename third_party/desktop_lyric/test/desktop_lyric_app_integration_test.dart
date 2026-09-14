import 'package:desktop_lyric/component/desktop_lyric_body.dart';
import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'DesktopLyricApp provides TEXT_DISPLAY_CONTROLLER globally to dialogs without ProviderNotFoundException',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopLyricApp());
    await tester.pumpAndSettle();

    // Verify root is rendered cleanly
    expect(find.byType(DesktopLyricApp), findsOneWidget);

    final context = tester.element(find.byType(DesktopLyricBody));

    // 1. Open Font Selector Dialog
    showLyricFontSelectorDialog(context);
    await tester.pumpAndSettle();

    // Verify dialog opened without ErrorWidget
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(LyricFontSelectorDialog), findsOneWidget);
    expect(find.text('选择字体'), findsOneWidget);

    // Close Dialog
    final closeButtonFinder = find.byTooltip('关闭');
    if (closeButtonFinder.evaluate().isNotEmpty) {
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();
    } else {
      final navigator = Navigator.of(tester.element(find.byType(LyricFontSelectorDialog)));
      navigator.pop();
      await tester.pumpAndSettle();
    }
    expect(find.byType(LyricFontSelectorDialog), findsNothing);

    // 2. Open Color Dialog
    showDesktopLyricColorDialog(context);
    await tester.pumpAndSettle();

    // Verify color dialog opened without ErrorWidget
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(DesktopLyricColorDialog), findsOneWidget);
    expect(find.text('桌面歌词颜色'), findsOneWidget);

    // Close Color Dialog
    final cancelBtn = find.text('取消');
    expect(cancelBtn, findsOneWidget);
    await tester.tap(cancelBtn, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopLyricColorDialog), findsNothing);
  });
}
