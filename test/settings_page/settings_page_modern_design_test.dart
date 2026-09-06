import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/page/settings_page/artist_separator_editor.dart';
import 'package:qisheng_player/page/settings_page/other_settings.dart';
import 'package:qisheng_player/page/settings_page/page.dart';
import 'package:qisheng_player/page/settings_page/theme_picker_dialog.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';

ThemeData _buildTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SettingsPage renders wide layout with categories and latest design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: ChangeNotifierProvider<ThemeProvider>.value(
          value: ThemeProvider.instance,
          child: const Scaffold(
            body: SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify categories
    expect(find.text('外观与特效'), findsAtLeast(1));
    expect(find.text('播放与音频'), findsAtLeast(1));
    expect(find.text('系统与热键'), findsAtLeast(1));
    expect(find.text('关于与更新'), findsAtLeast(1));

    // Verify Appearance section description matches screenshot exactly
    expect(
      find.text('控制物理画布材质（默认 / 弥散流彩 / 水波纹 / 极光漫染）与自定义壁纸。'),
      findsOneWidget,
    );

    // Verify 4 backdrop chips
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('弥散流彩'), findsOneWidget);
    expect(find.text('水波纹'), findsOneWidget);
    expect(find.text('极光漫染'), findsOneWidget);

    // Verify obsolete chips are NOT present
    expect(find.text('默认渐变'), findsNothing);
    expect(find.text('增强云母'), findsNothing);
    expect(find.text('亚克力'), findsNothing);

    // Verify hint
    expect(
      find.textContaining('包含默认、弥散流彩、水波纹与极光漫染。当前实际模式：'),
      findsOneWidget,
    );

    // Verify System Theme Mode Switch hint
    expect(find.text('跟随系统明暗模式设置。'), findsOneWidget);

    // Verify Lyric Depth Blur (scroll down if needed)
    await tester.scrollUntilVisible(
      find.text('歌词景深模糊'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('歌词景深模糊'), findsOneWidget);
    expect(find.text('模糊非当前歌词行，聚焦当前演唱内容。'), findsOneWidget);

    // Switch to System category
    await tester.tap(find.text('系统与热键').first);
    await tester.pumpAndSettle();
    expect(find.text('快捷键设置'), findsOneWidget);

    // Switch to About category
    await tester.tap(find.text('关于与更新').first);
    await tester.pumpAndSettle();
    expect(find.text('报告问题'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });

  testWidgets('ThemePickerDialog renders using ModernDialogFrame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: const Scaffold(
          body: ThemePickerDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ModernDialogFrame), findsOneWidget);
    expect(find.text('主题选择器'), findsOneWidget);
  });

  testWidgets('ArtistSeparatorEditDialog renders using ModernDialogFrame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: const Scaffold(
          body: ArtistSeparatorEditor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('管理艺术家分隔符'));
    await tester.pumpAndSettle();

    expect(find.byType(ModernDialogFrame), findsOneWidget);
    expect(find.text('管理艺术家分隔符'), findsAtLeast(1));
  });

  testWidgets('AudioLibraryEditorDialog renders using ModernDialogFrame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: const Scaffold(
          body: AudioLibraryEditor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '文件夹管理'));
    await tester.pumpAndSettle();

    expect(find.byType(ModernDialogFrame), findsOneWidget);
    expect(find.text('管理文件夹'), findsAtLeast(1));
  });

  testWidgets('HotkeySettingsTile opens dialog with ModernDialogFrame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: const Scaffold(
          body: HotkeySettingsTile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('配置快捷键'));
    await tester.pumpAndSettle();

    expect(find.byType(ModernDialogFrame), findsOneWidget);
    expect(find.text('快捷键设置'), findsAtLeast(1));
    expect(find.text('全部恢复默认'), findsOneWidget);
  });
}
