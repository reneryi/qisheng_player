import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/page/settings_page/theme_settings.dart';
import 'package:qisheng_player/src/rust/api/installed_font.dart';
import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:qisheng_player/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme settings controls tests', () {
    late AppSettings settings;
    late ThemeProvider theme;

    setUp(() {
      settings = AppSettings.instance;
      theme = ThemeProvider.instance;
      theme.setDynamicAlbumPaletteForTesting(null);
      settings.dynamicTheme = true;
      SelectFontCombobox.cachedSystemFonts = null;
      SelectFontCombobox.cachedImportedFonts = [];
      SelectFontCombobox.isSelecting = false;
      SelectFontCombobox.isResetting = false;
      SelectFontCombobox.isImporting = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          if (call.method == 'set_window_backdrop_mode') {
            return {
              'applied_mode': 'none',
              'native_backdrop_supported': true,
              'fallback_reason': null,
            };
          }
          return null;
        },
      );
    });

    testWidgets('UseSystemThemeSwitch toggles useSystemTheme', (tester) async {
      settings.useSystemTheme = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: UseSystemThemeSwitch(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('启动时使用系统主题色'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.useSystemTheme, isTrue);
    });

    testWidgets('UseSystemThemeModeSwitch toggles useSystemThemeMode and updates mode',
        (tester) async {
      settings.useSystemThemeMode = false;
      theme.applyThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: UseSystemThemeModeSwitch(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('使用系统明暗模式'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.useSystemThemeMode, isTrue);
      expect(theme.themeMode, equals(ThemeMode.system));

      // Toggle off -> returns to manual mode based on current effective brightness
      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.useSystemThemeMode, isFalse);
      expect(theme.themeMode, isNot(equals(ThemeMode.system)));
    });

    testWidgets('ThemeModeControl manual selection disables useSystemThemeMode',
        (tester) async {
      settings.useSystemThemeMode = true;
      theme.applyThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: ThemeModeControl(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('明暗模式'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);

      // Tap Dark mode (different from initial light mode)
      await tester.tap(find.text('深色'));
      await tester.pump();

      expect(settings.useSystemThemeMode, isFalse);
      expect(settings.themeMode, equals(ThemeMode.dark));
      expect(theme.themeMode, equals(ThemeMode.dark));

      // Tap Light mode
      await tester.tap(find.text('浅色'));
      await tester.pump();

      expect(settings.useSystemThemeMode, isFalse);
      expect(settings.themeMode, equals(ThemeMode.light));
      expect(theme.themeMode, equals(ThemeMode.light));
    });

    testWidgets('SelectFontCombobox displays action buttons and handles default reset',
        (tester) async {
      settings.fontFamily = 'CustomTestFont';
      theme.changeFontFamily('CustomTestFont');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('自定义字体'), findsOneWidget);
      expect(find.text('选择字体'), findsOneWidget);
      expect(find.text('添加字体'), findsOneWidget);
      expect(find.text('恢复默认'), findsOneWidget);

      // Tap Reset to Default
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();

      expect(settings.fontFamily, isNull);
      expect(settings.fontPath, isNull);
      expect(theme.fontFamily, isNull);

      // Reset button should now be gone
      expect(find.text('恢复默认'), findsNothing);
    });

    testWidgets(
        'UseSystemThemeModeSwitch updates visually when ThemeModeControl toggles manual mode',
        (tester) async {
      settings.useSystemThemeMode = true;
      theme.applyThemeMode(ThemeMode.system);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: Column(
                children: [
                  UseSystemThemeModeSwitch(),
                  ThemeModeControl(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially UseSystemThemeModeSwitch is true
      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Manually tap "深色" in ThemeModeControl
      await tester.tap(find.text('深色'));
      await tester.pump();

      // Settings and ThemeProvider should be updated
      expect(settings.useSystemThemeMode, isFalse);
      expect(theme.themeMode, equals(ThemeMode.dark));

      // The Switch widget must reflect the false state without unmounting
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      // Now toggle Switch back on
      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.useSystemThemeMode, isTrue);
      expect(theme.themeMode, equals(ThemeMode.system));
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
    });

    testWidgets(
        'UseSystemThemeSwitch updates visually when seedColor changes and turns off useSystemTheme',
        (tester) async {
      settings.useSystemTheme = true;
      theme.applyTheme(seedColor: const Color(0xFF4F8DFF));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: UseSystemThemeSwitch(),
            ),
          ),
        ),
      );
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Simulate a custom color being selected by user in dialog
      settings.useSystemTheme = false;
      theme.applyTheme(seedColor: const Color(0xFFFF5500));
      await tester.pump();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });

    test('AppTheme.build propagates custom fontFamily to textTheme', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF53A4FF),
        brightness: Brightness.dark,
      );

      final themeWithFont = AppTheme.build(
        colorScheme: scheme,
        fontFamily: 'CustomFontTest',
      );

      expect(themeWithFont.textTheme.bodyMedium?.fontFamily, equals('CustomFontTest'));
      expect(themeWithFont.textTheme.titleMedium?.fontFamily, equals('CustomFontTest'));
      expect(themeWithFont.textTheme.displaySmall?.fontFamily, equals('CustomFontTest'));
    });

    test('AppTheme.build with null fontFamily retains fallback list without external fetch', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF53A4FF),
        brightness: Brightness.dark,
      );

      final themeDefault = AppTheme.build(
        colorScheme: scheme,
        fontFamily: null,
      );

      expect(themeDefault.textTheme.bodyMedium?.fontFamilyFallback, isNotNull);
      expect(themeDefault.textTheme.bodyMedium?.fontFamilyFallback?.contains('MiSans'), isTrue);
      expect(themeDefault.textTheme.bodyMedium?.fontFamilyFallback?.contains('Microsoft YaHei UI'), isTrue);
    });

    test('ThemeProvider.changeFontFamily avoids duplicate notifications for same family', () {
      theme.changeFontFamily(null);
      var notificationCount = 0;
      void listener() => notificationCount++;
      theme.addListener(listener);

      // Re-applying null should not notify
      theme.changeFontFamily(null);
      expect(notificationCount, equals(0));

      // Applying a new font should notify once
      theme.changeFontFamily('SomeNewFont');
      expect(notificationCount, equals(1));

      // Re-applying the same font should not notify
      theme.changeFontFamily('SomeNewFont');
      expect(notificationCount, equals(1));

      // Setting back to null notifies once
      theme.changeFontFamily(null);
      expect(notificationCount, equals(2));

      theme.removeListener(listener);
    });

    testWidgets('SelectFontCombobox opens font selector dialog, handles default click when already default',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(path: r'C:\Windows\Fonts\arial.ttf', fullName: 'Arial'),
      ];
      settings.fontFamily = null;
      settings.fontPath = null;
      theme.changeFontFamily(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "选择字体" to open the dialog
      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      // Dialog should be open
      expect(find.text('选择字体'), findsNWidgets(2)); // Button + Dialog title
      expect(find.text('系统默认字体'), findsOneWidget);
      expect(find.text('当前字体：系统默认'), findsOneWidget);

      // Tap "系统默认字体" while already default
      await tester.tap(find.text('系统默认字体'));
      await tester.pumpAndSettle();

      // Dialog should safely close and remain on default font
      expect(find.text('当前字体：系统默认'), findsNothing);
      expect(theme.fontFamily, isNull);
      expect(settings.fontFamily, isNull);
    });

    testWidgets('SelectFontCombobox font selector dialog resets custom font to default',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(path: r'C:\Windows\Fonts\arial.ttf', fullName: 'Arial'),
      ];
      settings.fontFamily = 'Arial';
      settings.fontPath = r'C:\Windows\Fonts\arial.ttf';
      theme.changeFontFamily('Arial');

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      expect(find.text('当前字体：Arial'), findsOneWidget);

      // Tap "系统默认字体"
      await tester.tap(find.text('系统默认字体'));
      await tester.pumpAndSettle();

      // Font should be reset to default
      expect(theme.fontFamily, isNull);
      expect(settings.fontFamily, isNull);
      expect(settings.fontPath, isNull);
    });

    testWidgets('SelectFontCombobox font selector dialog selects and applies system font',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(path: r'C:\Windows\Fonts\arial.ttf', fullName: 'Arial'),
      ];
      settings.fontFamily = null;
      settings.fontPath = null;
      theme.changeFontFamily(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      // Tap system font "Arial"
      expect(find.text('Arial'), findsOneWidget);
      await tester.tap(find.text('Arial'));
      await tester.pumpAndSettle();

      // Font should now be Arial
      expect(theme.fontFamily, equals('Arial'));
      expect(settings.fontFamily, equals('Arial'));
      expect(settings.fontPath, equals(r'C:\Windows\Fonts\arial.ttf'));
    });

    testWidgets('SelectFontCombobox dialog cancel button dismisses without changing font',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(path: r'C:\Windows\Fonts\arial.ttf', fullName: 'Arial'),
      ];
      settings.fontFamily = 'OriginalFont';
      theme.changeFontFamily('OriginalFont');

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(theme.fontFamily, equals('OriginalFont'));
      expect(settings.fontFamily, equals('OriginalFont'));
    });

    testWidgets('SelectFontCombobox anti-reentry prevents duplicate dialogs on rapid tap',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(path: r'C:\Windows\Fonts\arial.ttf', fullName: 'Arial'),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rapidly tap twice
      await tester.tap(find.text('选择字体'));
      await tester.tap(find.text('选择字体'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Exactly one dialog should be visible (only one cancel button)
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('取消'), findsNothing);
    });

    testWidgets('SelectFontCombobox font selector search filter filters list',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(path: r'C:\Windows\Fonts\arial.ttf', fullName: 'Arial'),
        const InstalledFont(path: r'C:\Windows\Fonts\simhei.ttf', fullName: 'SimHei'),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      expect(find.text('Arial'), findsOneWidget);
      expect(find.text('SimHei'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'hei');
      await tester.pumpAndSettle();

      expect(find.text('SimHei'), findsOneWidget);
      expect(find.text('Arial'), findsNothing);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    testWidgets('SelectFontCombobox groups font variants and opens secondary menu with live weight preview',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(
          path: r'C:\Windows\Fonts\msyh.ttc',
          fullName: '微软雅黑',
          familyName: '微软雅黑',
          styleName: 'Regular',
          weight: 400,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Windows\Fonts\msyhl.ttc',
          fullName: '微软雅黑 Light',
          familyName: '微软雅黑',
          styleName: 'Light',
          weight: 290,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Windows\Fonts\msyhbd.ttc',
          fullName: '微软雅黑 Bold',
          familyName: '微软雅黑',
          styleName: 'Bold',
          weight: 700,
          isItalic: false,
        ),
      ];
      settings.fontFamily = null;
      settings.fontPath = null;
      theme.changeFontFamily(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      // Top level list: 微软雅黑 should appear ONCE with "3 种粗细" badge
      expect(find.text('微软雅黑'), findsOneWidget);
      expect(find.text('3 种粗细'), findsOneWidget);
      // Individual variants should NOT appear on the top-level list
      expect(find.text('微软雅黑 Bold'), findsNothing);
      expect(find.text('微软雅黑 Light'), findsNothing);

      // Tap on "微软雅黑" row to enter the secondary menu (二级菜单)
      await tester.tap(find.text('微软雅黑'));
      await tester.pumpAndSettle();

      // Secondary menu is now open
      expect(find.text('选择粗细字重规格（共 3 种）'), findsOneWidget);
      expect(find.text('细体 Light'), findsOneWidget);
      expect(find.text('常规 Regular'), findsOneWidget);
      expect(find.text('粗体 Bold'), findsOneWidget);
      expect(find.text('290'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
      expect(find.text('700'), findsOneWidget);
      expect(find.text('返回字体列表'), findsOneWidget);

      // Preview text should be visible with appropriate font style
      expect(find.text('AaBbCc 永和九年 岁在癸丑 123'), findsNWidgets(3));

      // Test "返回字体列表" button
      await tester.tap(find.text('返回字体列表'));
      await tester.pumpAndSettle();

      // We should be back at the primary menu
      expect(find.text('选择粗细字重规格（共 3 种）'), findsNothing);
      expect(find.text('3 种粗细'), findsOneWidget);

      // Re-enter secondary menu and select "粗体 Bold"
      await tester.tap(find.text('微软雅黑'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('粗体 Bold'));
      await tester.pumpAndSettle();

      // Dialog should close and "微软雅黑 Bold" should be applied!
      expect(find.text('选择粗细字重规格（共 3 种）'), findsNothing);
      expect(theme.fontFamily, equals('微软雅黑 Bold'));
      expect(settings.fontFamily, equals('微软雅黑 Bold'));
      expect(settings.fontPath, equals(r'C:\Windows\Fonts\msyhbd.ttc'));
    });

    testWidgets('SelectFontCombobox search filters by variant style name',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(
          path: r'C:\Windows\Fonts\arial.ttf',
          fullName: 'Arial',
          familyName: 'Arial',
          styleName: 'Regular',
          weight: 400,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Windows\Fonts\arialbd.ttf',
          fullName: 'Arial Bold',
          familyName: 'Arial',
          styleName: 'Bold',
          weight: 700,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Windows\Fonts\simfang.ttf',
          fullName: '仿宋',
          familyName: '仿宋',
          styleName: 'Regular',
          weight: 400,
          isItalic: false,
        ),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      expect(find.text('Arial'), findsOneWidget);
      expect(find.text('仿宋'), findsOneWidget);

      // Search for "bold"
      await tester.enterText(find.byType(TextField), 'bold');
      await tester.pumpAndSettle();

      // Arial has a Bold variant, so Arial matches
      expect(find.text('Arial'), findsOneWidget);
      // 仿宋 only has Regular, so does not match
      expect(find.text('仿宋'), findsNothing);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    test('AppTheme.extractFamilyFallbacks generates correct fallbacks for styled families', () {
      expect(AppTheme.extractFamilyFallbacks('Arial Bold').first, equals('Arial'));
      expect(AppTheme.extractFamilyFallbacks('微软雅黑 Bold').first, equals('微软雅黑'));
      expect(AppTheme.extractFamilyFallbacks('Dubai Light').first, equals('Dubai'));
      expect(AppTheme.extractFamilyFallbacks('Times New Roman Bold Italic').first, equals('Times New Roman'));
      expect(AppTheme.extractFamilyFallbacks('MiSans').first, equals('MiSans'));
      expect(AppTheme.extractFamilyFallbacks(null), equals(AppTheme.fallbackList));
    });

    testWidgets('SelectFontCombobox search filters by weight number',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(
          path: r'C:\Windows\Fonts\arial.ttf',
          fullName: 'Arial',
          familyName: 'Arial',
          styleName: 'Regular',
          weight: 400,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Windows\Fonts\arialbd.ttf',
          fullName: 'Arial Bold',
          familyName: 'Arial',
          styleName: 'Bold',
          weight: 700,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Windows\Fonts\simfang.ttf',
          fullName: '仿宋',
          familyName: '仿宋',
          styleName: 'Regular',
          weight: 400,
          isItalic: false,
        ),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      // Search for "700"
      await tester.enterText(find.byType(TextField), '700');
      await tester.pumpAndSettle();

      // Arial has a 700 weight variant
      expect(find.text('Arial'), findsOneWidget);
      // 仿宋 only has 400, so does not match
      expect(find.text('仿宋'), findsNothing);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'UseSystemThemeSwitch in meshFlow mode is rejected, remains false, and displays rejection snackbar',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.meshFlow;
      settings.useSystemTheme = false;
      settings.customTheme = const Color(0xFF112233).toARGB32();
      settings.defaultTheme = settings.customTheme;

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: UseSystemThemeSwitch(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('弥散流彩由当前歌曲封面色彩实时驱动，系统主题色在此模式下暂不生效。'),
        findsOneWidget,
      );

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pump();

      // Must NOT change settings or defaultTheme
      expect(settings.useSystemTheme, isFalse);
      expect(settings.defaultTheme, equals(settings.customTheme));
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(find.text('弥散流彩模式由当前歌曲封面色彩实时驱动'), findsOneWidget);
    });

    testWidgets(
        'UseSystemThemeSwitch in prismaticGlass mode toggles on/off correctly, covering and restoring customTheme',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      const initialCustom = Color(0xFF9C27B0);
      settings.useSystemTheme = false;
      settings.customTheme = initialCustom.toARGB32();
      settings.defaultTheme = initialCustom.toARGB32();
      theme.applyTheme(seedColor: initialCustom);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: UseSystemThemeSwitch(),
            ),
          ),
        ),
      );
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(theme.auroraPalette.primary, equals(initialCustom));

      // Toggle ON -> system theme color covers
      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.useSystemTheme, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      final sysThemeColor = Color(AppSettings.getWindowsTheme());
      expect(settings.defaultTheme, equals(sysThemeColor.toARGB32()));
      expect(settings.customTheme, equals(initialCustom.toARGB32()));
      expect(theme.auroraPalette.primary, equals(sysThemeColor));
      expect(find.text('已应用系统主题色'), findsOneWidget);

      // Toggle OFF -> restores customTheme
      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.useSystemTheme, isFalse);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(settings.defaultTheme, equals(initialCustom.toARGB32()));
      expect(settings.customTheme, equals(initialCustom.toARGB32()));
      expect(theme.auroraPalette.primary, equals(initialCustom));
      expect(find.text('已恢复动态取色'), findsOneWidget);
    });

    test('MeshFlow palette is preserved and independent from auroraPalette and theme changes', () {
      final provider = ThemeProvider.instance;
      const coverPalette = AlbumPalette(
        primary: Color(0xFF112233),
        secondary: Color(0xFF223344),
        accent: Color(0xFF334455),
        muted: Color(0xFF445566),
        highlight: Color(0xFF556677),
      );

      provider.setDynamicAlbumPaletteForTesting(coverPalette);
      expect(provider.meshFlowPalette.primary, equals(const Color(0xFF112233)));

      // In dynamic mode, auroraPalette uses coverPalette
      expect(provider.auroraPalette.primary, equals(const Color(0xFF112233)));

      // Changing static theme color with dynamicTheme disabled drives auroraPalette without wiping out meshFlowPalette
      settings.dynamicTheme = false;
      provider.applyTheme(seedColor: const Color(0xFFFF9900));
      expect(provider.meshFlowPalette.primary, equals(const Color(0xFF112233)));
      expect(provider.auroraPalette.primary, equals(const Color(0xFFFF9900)));
    });

    testWidgets(
        'ThemeSelector in meshFlow mode is rejected with snackbar',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.meshFlow;

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: ThemeSelector(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('弥散流彩由当前歌曲封面色彩实时驱动，手动选色在此模式下暂不生效。'),
        findsOneWidget,
      );

      await tester.tap(find.text('选择颜色'));
      await tester.pump();

      expect(find.text('弥散流彩模式由当前歌曲封面色彩实时驱动'), findsOneWidget);
    });

    test('albumPalette switches between meshFlowPalette and auroraPalette based on windowBackdropMode', () {
      final provider = ThemeProvider.instance;
      const coverPalette = AlbumPalette(
        primary: Color(0xFF123456),
        secondary: Color(0xFF234567),
        accent: Color(0xFF345678),
        muted: Color(0xFF456789),
        highlight: Color(0xFF56789A),
      );

      provider.setDynamicAlbumPaletteForTesting(coverPalette);

      // In dynamicTheme mode: both meshFlow and prismaticGlass use coverPalette
      provider.windowBackdropMode = WindowBackdropMode.meshFlow;
      expect(provider.albumPalette, equals(provider.meshFlowPalette));
      expect(provider.albumPalette.primary, equals(const Color(0xFF123456)));

      provider.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      expect(provider.albumPalette, equals(provider.auroraPalette));
      expect(provider.albumPalette.primary, equals(const Color(0xFF123456)));

      // In static mode: prismaticGlass uses static theme seed color
      settings.dynamicTheme = false;
      provider.applyTheme(seedColor: const Color(0xFFAABBCC));
      expect(provider.albumPalette, equals(provider.auroraPalette));
      expect(provider.albumPalette.primary, equals(const Color(0xFFAABBCC)));
    });

    testWidgets(
        'Manual color selection and useSystemTheme are at the same level and mutually affect each other',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      const initialCustom = Color(0xFF00AA55);
      settings.useSystemTheme = false;
      settings.customTheme = initialCustom.toARGB32();
      settings.defaultTheme = initialCustom.toARGB32();
      theme.applyTheme(seedColor: initialCustom);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: Column(
                children: [
                  UseSystemThemeSwitch(),
                  ThemeSelector(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(theme.auroraPalette.primary, equals(initialCustom));

      // 1. Turn on system theme
      await tester.tap(switchFinder);
      await tester.pump();
      expect(settings.useSystemTheme, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      final sysThemeColor = Color(AppSettings.getWindowsTheme());
      expect(theme.auroraPalette.primary, equals(sysThemeColor));
      expect(settings.customTheme, equals(initialCustom.toARGB32()));

      // 2. User manually selects a new color (simulated via ThemeSelector flow)
      const newManualColor = Color(0xFFFF3366);
      settings.customTheme = newManualColor.toARGB32();
      settings.defaultTheme = newManualColor.toARGB32();
      settings.useSystemTheme = false;
      theme.applyTheme(seedColor: newManualColor);
      await tester.pump();

      // Switch must automatically turn off and auroraPalette must update
      expect(settings.useSystemTheme, isFalse);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(theme.auroraPalette.primary, equals(newManualColor));

      // 3. Turn on system theme again -> covers new manual color
      await tester.tap(switchFinder);
      await tester.pump();
      expect(settings.useSystemTheme, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(sysThemeColor));
      expect(settings.customTheme, equals(newManualColor.toARGB32()));

      // 4. Turn off system theme again -> restores new manual color
      await tester.tap(switchFinder);
      await tester.pump();
      expect(settings.useSystemTheme, isFalse);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(theme.auroraPalette.primary, equals(newManualColor));
      expect(settings.defaultTheme, equals(newManualColor.toARGB32()));
    });

    test(
        'Full lifecycle backdrop switching preserves dynamic cover palette without interference from aurora theme',
        () async {
      final provider = ThemeProvider.instance;
      const coverPalette = AlbumPalette(
        primary: Color(0xFF112233),
        secondary: Color(0xFF223344),
        accent: Color(0xFF334455),
        muted: Color(0xFF445566),
        highlight: Color(0xFF556677),
      );

      provider.setDynamicAlbumPaletteForTesting(coverPalette);
      provider.applyTheme(seedColor: const Color(0xFFE91E63));

      // In meshFlow: uses coverPalette
      provider.windowBackdropMode = WindowBackdropMode.meshFlow;
      expect(provider.meshFlowPalette.primary, equals(const Color(0xFF112233)));
      expect(provider.albumPalette, equals(provider.meshFlowPalette));

      // Switch to defaultGradient
      provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
      expect(provider.meshFlowPalette.primary, equals(const Color(0xFF112233)));
      // Switch to waterRipple
      provider.windowBackdropMode = WindowBackdropMode.waterRipple;
      expect(provider.meshFlowPalette.primary, equals(const Color(0xFF112233)));

      // Switch to prismaticGlass (aurora): in dynamicTheme mode uses coverPalette
      provider.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      expect(provider.auroraPalette.primary, equals(const Color(0xFF112233)));
      expect(provider.albumPalette, equals(provider.auroraPalette));

      // Change static theme in prismaticGlass (covers aurora when dynamicTheme is false)
      settings.dynamicTheme = false;
      provider.applyTheme(seedColor: const Color(0xFF00BCD4));
      expect(provider.auroraPalette.primary, equals(const Color(0xFF00BCD4)));
      expect(provider.albumPalette, equals(provider.auroraPalette));

      // Re-enabling dynamic theme restores dynamic coverPalette
      settings.dynamicTheme = true;
      expect(provider.auroraPalette.primary, equals(const Color(0xFF112233)));
      expect(provider.albumPalette, equals(provider.auroraPalette));

      // Switch back to meshFlow: coverPalette must remain completely intact
      provider.windowBackdropMode = WindowBackdropMode.meshFlow;
      expect(provider.albumPalette, equals(provider.meshFlowPalette));
      expect(provider.meshFlowPalette.primary, equals(const Color(0xFF112233)));
    });

    testWidgets(
        'In prismaticGlass, toggling UseSystemThemeSwitch toggles dynamicTheme off/on and restores dynamic aurora palette',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      settings.dynamicTheme = true;
      settings.useSystemTheme = false;

      const coverPalette = AlbumPalette(
        primary: Color(0xFF112233),
        secondary: Color(0xFF223344),
        accent: Color(0xFF334455),
        muted: Color(0xFF445566),
        highlight: Color(0xFF556677),
      );
      theme.setDynamicAlbumPaletteForTesting(coverPalette);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: Column(
                children: [
                  UseSystemThemeSwitch(),
                  DynamicThemeSwitch(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final switches = find.byType(Switch);
      final systemThemeSwitchFinder = switches.at(0);
      final dynamicThemeSwitchFinder = switches.at(1);

      // Initially, system theme is off, dynamic theme is on, auroraPalette is dynamic cover palette
      expect(tester.widget<Switch>(systemThemeSwitchFinder).value, isFalse);
      expect(tester.widget<Switch>(dynamicThemeSwitchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(const Color(0xFF112233)));

      // 1. Turn on system theme switch
      await tester.tap(systemThemeSwitchFinder);
      await tester.pump();

      // System theme switch is on, dynamic theme switch is toggled off, system theme covers aurora
      expect(settings.useSystemTheme, isTrue);
      expect(settings.dynamicTheme, isFalse);
      expect(tester.widget<Switch>(systemThemeSwitchFinder).value, isTrue);
      expect(tester.widget<Switch>(dynamicThemeSwitchFinder).value, isFalse);
      final sysThemeColor = Color(AppSettings.getWindowsTheme());
      expect(theme.auroraPalette.primary, equals(sysThemeColor));

      // 2. Turn off system theme switch
      await tester.tap(systemThemeSwitchFinder);
      await tester.pump();

      // System theme switch is off, dynamic theme switch is toggled back on, restores dynamic aurora palette!
      expect(settings.useSystemTheme, isFalse);
      expect(settings.dynamicTheme, isTrue);
      expect(tester.widget<Switch>(systemThemeSwitchFinder).value, isFalse);
      expect(tester.widget<Switch>(dynamicThemeSwitchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(const Color(0xFF112233)));
      expect(find.text('已恢复动态取色'), findsOneWidget);
    });

    testWidgets(
        'In prismaticGlass, manual color selection switches dynamicTheme to false, and manually re-opening dynamicTheme restores dynamic aurora palette',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      settings.dynamicTheme = true;
      settings.useSystemTheme = false;

      const coverPalette = AlbumPalette(
        primary: Color(0xFF112233),
        secondary: Color(0xFF223344),
        accent: Color(0xFF334455),
        muted: Color(0xFF445566),
        highlight: Color(0xFF556677),
      );
      theme.setDynamicAlbumPaletteForTesting(coverPalette);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: Column(
                children: [
                  ThemeSelector(),
                  DynamicThemeSwitch(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dynamicSwitchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(dynamicSwitchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(const Color(0xFF112233)));

      // 1. Manually select color
      const manualColor = Color(0xFFFF5722);
      settings.customTheme = manualColor.toARGB32();
      settings.defaultTheme = manualColor.toARGB32();
      settings.useSystemTheme = false;
      await theme.applyDynamicTheme(false);
      theme.applyTheme(seedColor: manualColor);
      await tester.pump();

      // Dynamic theme is switched off, manual color covers aurora
      expect(settings.dynamicTheme, isFalse);
      expect(tester.widget<Switch>(dynamicSwitchFinder).value, isFalse);
      expect(theme.auroraPalette.primary, equals(manualColor));

      // 2. Manually toggle dynamic theme switch back on
      await tester.tap(dynamicSwitchFinder);
      await tester.pump();

      // Dynamic theme is on, aurora restores to dynamic cover palette!
      expect(settings.dynamicTheme, isTrue);
      expect(tester.widget<Switch>(dynamicSwitchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(const Color(0xFF112233)));
    });

    testWidgets(
        'In prismaticGlass, turning ON DynamicThemeSwitch when useSystemTheme is active disables useSystemTheme and restores dynamic aurora palette',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      const initialCustom = Color(0xFF4CAF50);
      settings.customTheme = initialCustom.toARGB32();
      settings.defaultTheme = AppSettings.getWindowsTheme();
      settings.useSystemTheme = true;
      settings.dynamicTheme = false;

      const coverPalette = AlbumPalette(
        primary: Color(0xFF3F51B5),
        secondary: Color(0xFF303F9F),
        accent: Color(0xFFFF4081),
        muted: Color(0xFFC5CAE9),
        highlight: Color(0xFFE8EAF6),
      );
      theme.setDynamicAlbumPaletteForTesting(coverPalette);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: Column(
                children: [
                  UseSystemThemeSwitch(),
                  DynamicThemeSwitch(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final switches = find.byType(Switch);
      final systemThemeSwitchFinder = switches.at(0);
      final dynamicThemeSwitchFinder = switches.at(1);

      expect(tester.widget<Switch>(systemThemeSwitchFinder).value, isTrue);
      expect(tester.widget<Switch>(dynamicThemeSwitchFinder).value, isFalse);
      expect(settings.useSystemTheme, isTrue);
      expect(settings.dynamicTheme, isFalse);

      // Tap dynamic theme switch to turn it ON
      await tester.tap(dynamicThemeSwitchFinder);
      await tester.pump();

      // System theme turns off, dynamic theme turns on, defaultTheme restored to customTheme
      expect(settings.useSystemTheme, isFalse);
      expect(settings.dynamicTheme, isTrue);
      expect(settings.defaultTheme, equals(initialCustom.toARGB32()));
      expect(tester.widget<Switch>(systemThemeSwitchFinder).value, isFalse);
      expect(tester.widget<Switch>(dynamicThemeSwitchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(const Color(0xFF3F51B5)));
    });

    test(
        'Switching backdrop mode to meshFlow and back to prismaticGlass with useSystemTheme active preserves state machine',
        () async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      const customColor = Color(0xFFE91E63);
      settings.customTheme = customColor.toARGB32();
      settings.defaultTheme = AppSettings.getWindowsTheme();
      settings.useSystemTheme = true;
      settings.dynamicTheme = false;
      theme.applyTheme(seedColor: Color(settings.defaultTheme));

      const coverPalette = AlbumPalette(
        primary: Color(0xFF009688),
        secondary: Color(0xFF00796B),
        accent: Color(0xFFFFC107),
        muted: Color(0xFFB2DFDB),
        highlight: Color(0xFFE0F2F1),
      );
      theme.setDynamicAlbumPaletteForTesting(coverPalette);

      // In prismaticGlass with useSystemTheme = true:
      expect(settings.dynamicTheme, isFalse);
      expect(theme.auroraPalette.primary, equals(Color(AppSettings.getWindowsTheme())));

      // Switch to meshFlow
      await theme.applyWindowBackdropMode(WindowBackdropMode.meshFlow);
      expect(settings.dynamicTheme, isTrue);
      expect(theme.meshFlowPalette.primary, equals(const Color(0xFF009688)));

      // Switch back to prismaticGlass: because useSystemTheme is still true, dynamicTheme is disabled
      await theme.applyWindowBackdropMode(WindowBackdropMode.prismaticGlass);
      expect(settings.dynamicTheme, isFalse);
      expect(settings.useSystemTheme, isTrue);
      expect(theme.auroraPalette.primary, equals(Color(AppSettings.getWindowsTheme())));
    });

    testWidgets(
        'DynamicThemeSwitch toggle in prismaticGlass toggles between cover palette and custom seed, persisting settings',
        (tester) async {
      theme.windowBackdropMode = WindowBackdropMode.prismaticGlass;
      const customColor = Color(0xFF9C27B0);
      settings.customTheme = customColor.toARGB32();
      settings.defaultTheme = customColor.toARGB32();
      settings.useSystemTheme = false;
      settings.dynamicTheme = true;
      theme.applyTheme(seedColor: customColor);

      const coverPalette = AlbumPalette(
        primary: Color(0xFF00E676),
        secondary: Color(0xFF00B0FF),
        accent: Color(0xFFFFD600),
        muted: Color(0xFF69F0AE),
        highlight: Color(0xFFB9F6CA),
      );
      theme.setDynamicAlbumPaletteForTesting(coverPalette);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          home: ChangeNotifierProvider<ThemeProvider>.value(
            value: theme,
            child: const Scaffold(
              body: DynamicThemeSwitch(),
            ),
          ),
        ),
      );
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(theme.auroraPalette.primary, equals(const Color(0xFF00E676)));

      // Tap to turn off dynamicTheme
      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.dynamicTheme, isFalse);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      // Aurora should now be covered by customColor
      expect(theme.auroraPalette.primary, equals(customColor));

      // Tap to turn back on dynamicTheme
      await tester.tap(switchFinder);
      await tester.pump();

      expect(settings.dynamicTheme, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      // Aurora restored to coverPalette!
      expect(theme.auroraPalette.primary, equals(const Color(0xFF00E676)));
    });

    test('FontVariant.fontWeight prioritizes semantic style name over nonstandard numeric weights (e.g. MiSans)', () {
      const regularVariant = FontVariant(
        font: InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Regular.ttf',
          fullName: 'MiSans',
          familyName: 'MiSans',
          styleName: 'Regular',
          weight: 330,
        ),
        styleName: 'Regular',
        weight: 330,
      );
      expect(regularVariant.fontWeight, equals(FontWeight.w400));

      const mediumVariant = FontVariant(
        font: InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Medium.ttf',
          fullName: 'MiSans Medium',
          familyName: 'MiSans',
          styleName: 'Medium',
          weight: 380,
        ),
        styleName: 'Medium',
        weight: 380,
      );
      expect(mediumVariant.fontWeight, equals(FontWeight.w500));

      const demiboldVariant = FontVariant(
        font: InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Demibold.ttf',
          fullName: 'MiSans Demibold',
          familyName: 'MiSans',
          styleName: 'Demibold',
          weight: 450,
        ),
        styleName: 'Demibold',
        weight: 450,
      );
      expect(demiboldVariant.fontWeight, equals(FontWeight.w600));

      const group = FontFamilyGroup(
        familyName: 'MiSans',
        isImported: false,
        variants: [mediumVariant, regularVariant, demiboldVariant],
      );
      // primaryVariant must pick the true Regular variant, NOT Medium (which has weight 380)
      expect(group.primaryVariant.styleName, equals('Regular'));
      expect(group.primaryVariant.weight, equals(330));
    });

    testWidgets('SelectFontCombobox secondary menu applies full font family with auto weights',
        (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Regular.ttf',
          fullName: 'MiSans',
          familyName: 'MiSans',
          styleName: 'Regular',
          weight: 330,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Bold.ttf',
          fullName: 'MiSans Bold',
          familyName: 'MiSans',
          styleName: 'Bold',
          weight: 630,
          isItalic: false,
        ),
      ];
      settings.fontFamily = null;
      settings.fontPath = null;
      theme.changeFontFamily(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      expect(find.text('MiSans'), findsOneWidget);
      await tester.tap(find.text('MiSans'));
      await tester.pumpAndSettle();

      expect(find.text('应用全字重家族'), findsOneWidget);
      await tester.tap(find.text('应用全字重家族'));
      await tester.pumpAndSettle();

      // Should apply 'MiSans' as fontFamily (the complete family) rather than single variant
      expect(theme.fontFamily, equals('MiSans'));
      expect(settings.fontFamily, equals('MiSans'));
      expect(settings.fontPath, equals(r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Regular.ttf'));
    });

    testWidgets('SelectFontCombobox secondary menu does not overflow on narrow viewports', (tester) async {
      SelectFontCombobox.cachedSystemFonts = [
        const InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Regular.ttf',
          fullName: 'MiSans',
          familyName: 'MiSans',
          styleName: 'Regular',
          weight: 330,
          isItalic: false,
        ),
        const InstalledFont(
          path: r'C:\Users\reneryi\AppData\Local\Microsoft\Windows\Fonts\MiSans-Bold.ttf',
          fullName: 'MiSans Bold',
          familyName: 'MiSans',
          styleName: 'Bold',
          weight: 630,
          isItalic: false,
        ),
      ];
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        SelectFontCombobox.cachedSystemFonts = null;
      });

      final theme = ThemeProvider.instance;
      theme.changeFontFamily(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const MaterialApp(
            home: Scaffold(
              body: SelectFontCombobox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择字体'));
      await tester.pumpAndSettle();

      expect(find.text('MiSans'), findsOneWidget);
      await tester.tap(find.text('MiSans'));
      await tester.pumpAndSettle();

      // Ensure no overflow exception was thrown
      expect(tester.takeException(), isNull);
      expect(find.text('返回字体列表'), findsOneWidget);
      expect(find.text('应用全字重家族'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });
  });
}

