import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTheme = ThemeChangedMessage(
    0xFF00F5D4,
    0xFF131822,
    0xFFFFFFFF,
  );

  group('Font Parser and Grouping Logic', () {
    test('correctly parses family, style, and weight from various font names', () {
      final rawFonts = [
        'Segoe UI',
        'Segoe UI Bold',
        'Segoe UI Bold Italic',
        'Segoe UI Light',
        'Segoe UI SemiBold',
        'Arial Regular',
        '思源黑体 Heavy',
        '霞鹜文楷',
        'Fira Code Medium',
        'PingFang SC Light',
      ];

      final groups = parseFontFamilyGroups(rawFonts);

      // Verify Segoe UI group
      final segoeGroup =
          groups.firstWhere((g) => g.familyName.toLowerCase() == 'segoe ui');
      expect(segoeGroup.variants.length, equals(5));
      expect(segoeGroup.hasMultipleWeights, isTrue);

      // Verify primary variant is Regular (weight 400, not italic)
      expect(segoeGroup.primaryVariant.weight, equals(400));
      expect(segoeGroup.primaryVariant.isItalic, isFalse);

      // Verify weights
      final boldVar =
          segoeGroup.variants.firstWhere((v) => v.styleName == 'Bold');
      expect(boldVar.weight, equals(700));
      expect(boldVar.fontWeight, equals(FontWeight.w700));

      final lightVar =
          segoeGroup.variants.firstWhere((v) => v.styleName == 'Light');
      expect(lightVar.weight, equals(300));
      expect(lightVar.fontWeight, equals(FontWeight.w300));

      final boldItalicVar =
          segoeGroup.variants.firstWhere((v) => v.styleName == 'Bold Italic');
      expect(boldItalicVar.weight, equals(700));
      expect(boldItalicVar.isItalic, isTrue);

      // Verify Arial
      final arialGroup =
          groups.firstWhere((g) => g.familyName.toLowerCase() == 'arial');
      expect(arialGroup.variants.first.weight, equals(400));

      // Verify Heavy
      final siyuanGroup =
          groups.firstWhere((g) => g.familyName.contains('思源黑体'));
      expect(siyuanGroup.variants.first.weight, equals(900));

      // Verify Chinese font
      final wenkaiGroup =
          groups.firstWhere((g) => g.familyName == '霞鹜文楷');
      expect(wenkaiGroup.variants.length, equals(1));
      expect(wenkaiGroup.hasMultipleWeights, isFalse);
    });

    test('primaryVariant falls back gracefully when Regular is absent', () {
      final groups = parseFontFamilyGroups([
        'CustomFont Bold',
        'CustomFont Light',
      ]);
      final group = groups.first;
      // Should pick Light (300) before Bold (700)
      expect(group.primaryVariant.styleName, equals('Light'));
    });
  });

  group('TextDisplayController Font State Management', () {
    test('initial state defaults to following player font', () {
      final ctrl = TextDisplayController();
      expect(ctrl.followPlayerFont, isTrue);
      expect(ctrl.preferenceLyricFontFamily, isNull);
    });

    test('applyFont switches mode between custom font and follow player', () {
      final ctrl = TextDisplayController();

      // State 3: Custom font
      ctrl.applyFont(family: 'PingFang SC', followPlayer: false);
      expect(ctrl.followPlayerFont, isFalse);
      expect(ctrl.preferenceLyricFontFamily, equals('PingFang SC'));
      expect(ctrl.lyricFontFamily, equals('PingFang SC'));

      // State 1: Follow player
      ctrl.applyFont(family: null, followPlayer: true);
      expect(ctrl.followPlayerFont, isTrue);
      expect(ctrl.preferenceLyricFontFamily, isNull);

      // State 2: Explicit system default
      ctrl.applyFont(family: null, followPlayer: false);
      expect(ctrl.followPlayerFont, isFalse);
      expect(ctrl.preferenceLyricFontFamily, isNull);
      expect(ctrl.lyricFontFamily, isNull);
    });

    test('font initialization from player respects followPlayerFont', () {
      final ctrl = TextDisplayController();
      DesktopLyricController.instance.currentFontFamily.value = 'HostFont';

      // While following player, lyricFontFamily reflects player font
      ctrl.initializeFontFamilyFromPlayer('HostFont');
      expect(ctrl.lyricFontFamily, equals('HostFont'));

      // When custom font is set, player changes do not override it
      ctrl.applyFont(family: 'CustomFont', followPlayer: false);
      ctrl.initializeFontFamilyFromPlayer('NewHostFont');
      expect(ctrl.lyricFontFamily, equals('CustomFont'));
    });
  });

  group('DesktopLyricController Font Messaging Integration', () {
    test('handles PlayerFontChangedMessage', () {
      final dlc = DesktopLyricController.instance;

      const fontFrame =
          '{"type":"PlayerFontChangedMessage","message":{"fontFamily":"CustomSans"}}\n';
      dlc.parseStdinChunkForTest(fontFrame);

      expect(dlc.currentFontFamily.value, equals('CustomSans'));
    });

    test('handles InstalledFontsMessage with saved font and followPlayer preferences', () {
      final dlc = DesktopLyricController.instance;

      const installedFrame =
          '{"type":"InstalledFontsMessage","message":{"fonts":["Arial","Segoe UI","Consolas"],'
          '"currentFontFamily":"HostGlobal","savedLyricFontFamily":"Consolas","followPlayerFont":false}}\n';
      dlc.parseStdinChunkForTest(installedFrame);

      expect(dlc.installedFonts.value, containsAll(['Arial', 'Segoe UI', 'Consolas']));
      expect(dlc.currentFontFamily.value, equals('HostGlobal'));
      expect(TEXT_DISPLAY_CONTROLLER.followPlayerFont, isFalse);
      expect(TEXT_DISPLAY_CONTROLLER.preferenceLyricFontFamily, equals('Consolas'));
    });
  });

  group('LyricFontSelectorDialog UI Widget Tests', () {
    Widget buildTestDialog({
      TextDisplayController? customController,
      List<String> mockFonts = const [
        'Segoe UI',
        'Segoe UI Bold',
        'Arial',
        'Microsoft YaHei',
      ],
      String? playerFont = 'Segoe UI',
    }) {
      DesktopLyricController.instance.isDarkMode.value = true;
      DesktopLyricController.instance.installedFonts.value = mockFonts;
      DesktopLyricController.instance.currentFontFamily.value = playerFont;

      return MultiProvider(
        providers: [
          Provider<ThemeChangedMessage>.value(value: testTheme),
          ChangeNotifierProvider<TextDisplayController>.value(
            value: customController ?? TEXT_DISPLAY_CONTROLLER,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 700,
              child: LyricFontSelectorDialog(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders modern frosted glass card header, badge, and close button',
        (tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Card Base
      expect(find.byType(ModernLyricDialogCard), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);

      // Header title and icon badge
      expect(find.text('选择字体'), findsOneWidget);
      expect(find.byIcon(Icons.text_fields_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Subtitle indicates active font and scope isolation reminder
      expect(find.textContaining('仅作用于桌面歌词'), findsOneWidget);
    });

    testWidgets('renders pinned items for follow player and system default',
        (tester) async {
      final ctrl = TextDisplayController();
      ctrl.applyFont(family: null, followPlayer: true);

      await tester.pumpWidget(buildTestDialog(customController: ctrl, playerFont: 'PingFang SC'));
      await tester.pumpAndSettle();

      expect(find.text('跟随主播放器字体'), findsOneWidget);
      expect(find.text('当前播放器字体：PingFang SC'), findsOneWidget);
      expect(find.text('系统默认字体'), findsOneWidget);

      // Click "系统默认字体"
      await tester.tap(find.text('系统默认字体'));
      await tester.pumpAndSettle();

      expect(ctrl.followPlayerFont, isFalse);
      expect(ctrl.preferenceLyricFontFamily, isNull);
    });

    testWidgets('search box filters font list by family and style name',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(mockFonts: [
        'Arial',
        'Microsoft YaHei',
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Arial'), findsOneWidget);
      expect(find.text('Microsoft YaHei'), findsOneWidget);

      // Type "YaHei" into search
      await tester.enterText(find.byType(TextField), 'YaHei');
      await tester.pumpAndSettle();

      expect(find.text('Microsoft YaHei'), findsOneWidget);
      expect(find.text('Arial'), findsNothing);
    });

    testWidgets('renders sample preview text',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(mockFonts: ['Microsoft YaHei']));
      await tester.pumpAndSettle();

      expect(find.text('AaBbCc 永和九年 岁在癸丑 123'), findsOneWidget);
    });

    testWidgets('selecting a single-variant font updates controller and applies font',
        (tester) async {
      final ctrl = TextDisplayController();
      ctrl.applyFont(family: null, followPlayer: true);

      await tester.pumpWidget(buildTestDialog(
        customController: ctrl,
        mockFonts: ['Segoe UI', 'Arial'],
      ));
      await tester.pumpAndSettle();

      // Tap Arial
      await tester.tap(find.text('Arial'));
      await tester.pumpAndSettle();

      expect(ctrl.followPlayerFont, isFalse);
      expect(ctrl.preferenceLyricFontFamily, equals('Arial'));
    });

    testWidgets('tapping multi-weight font enters secondary menu with weight badges',
        (tester) async {
      final ctrl = TextDisplayController();
      await tester.pumpWidget(buildTestDialog(
        customController: ctrl,
        mockFonts: [
          'Segoe UI',
          'Segoe UI Bold',
          'Segoe UI Light',
        ],
      ));
      await tester.pumpAndSettle();

      // Segoe UI has multiple weights badge
      expect(find.text('3 种粗细'), findsOneWidget);

      // Tap Segoe UI to enter secondary menu
      await tester.tap(find.text('Segoe UI'));
      await tester.pumpAndSettle();

      // Verify secondary menu title and subtitle
      expect(find.text('选择粗细字重规格（共 3 种）'), findsOneWidget);
      expect(find.text('常规 Regular'), findsOneWidget);
      expect(find.text('粗体 Bold'), findsOneWidget);
      expect(find.text('细体 Light'), findsOneWidget);

      // Tap Bold variant
      await tester.tap(find.text('粗体 Bold'));
      await tester.pumpAndSettle();

      expect(ctrl.followPlayerFont, isFalse);
      expect(ctrl.preferenceLyricFontFamily, equals('Segoe UI Bold'));
    });

    testWidgets('close button calls Navigator.pop', (tester) async {
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => MultiProvider(
                    providers: [
                      Provider<ThemeChangedMessage>.value(value: testTheme),
                      ChangeNotifierProvider<TextDisplayController>.value(
                        value: TEXT_DISPLAY_CONTROLLER,
                      ),
                    ],
                    child: const LyricFontSelectorDialog(),
                  ),
                );
                popped = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(LyricFontSelectorDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.byType(LyricFontSelectorDialog), findsNothing);
    });
  });
}
