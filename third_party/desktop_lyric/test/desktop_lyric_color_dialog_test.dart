import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTheme = ThemeChangedMessage(
    0xFF00F5D4, // Aurora Cyan primary
    0xFF131822, // Dark surfaceContainer
    0xFFFFFFFF, // onSurface
  );

  group('Color Math and Preset Models', () {
    test('colorToHex accurately formats Color to 6-digit uppercase hex with #', () {
      expect(colorToHex(const Color(0xFF00F5D4)), equals('#00F5D4'));
      expect(colorToHex(const Color(0xFFE2E8F0)), equals('#E2E8F0'));
      expect(colorToHex(const Color(0xFFB388FF)), equals('#B388FF'));
      expect(colorToHex(const Color(0xFFFF7043)), equals('#FF7043'));
      expect(colorToHex(const Color(0xFFFFD166)), equals('#FFD166'));
      expect(colorToHex(const Color(0xFFFFFFFF)), equals('#FFFFFF'));
      expect(colorToHex(const Color(0xFF000000)), equals('#000000'));
    });

    test('colorChannel extracts R, G, B components accurately', () {
      const color = Color(0xFFFF7043);
      expect(colorChannel(color, 16), equals(255));
      expect(colorChannel(color, 8), equals(112));
      expect(colorChannel(color, 0), equals(67));
    });

    test('kCuratedColorPresets contains 6 core + 3 auxiliary presets with valid hex', () {
      expect(kCuratedColorPresets.length, equals(9));

      final names = kCuratedColorPresets.map((p) => p.name).toList();
      expect(names, containsAll([
        '极光青',
        '流光银',
        '霓虹紫',
        '落日橙',
        '晨曦金',
        '纯净白',
        '樱落粉',
        '薄荷绿',
        '晴空蓝',
      ]));

      for (final preset in kCuratedColorPresets) {
        expect(colorToHex(preset.color), equals(preset.hex));
      }
    });
  });

  group('DesktopLyricColorDialog Widget UI Tests', () {
    Widget buildTestColorDialog({
      TextDisplayController? customController,
      ThemeChangedMessage theme = testTheme,
      bool isDark = true,
      String lyricContent = '让音乐点亮此刻的生活',
      String? translation = 'Let music brighten this moment',
    }) {
      DesktopLyricController.instance.isDarkMode.value = isDark;
      DesktopLyricController.instance.lyricLine.value =
          LyricLineChangedMessage(lyricContent, Duration.zero, translation);

      return MultiProvider(
        providers: [
          Provider<ThemeChangedMessage>.value(value: theme),
          ChangeNotifierProvider<TextDisplayController>.value(
            value: customController ?? TEXT_DISPLAY_CONTROLLER,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 540,
                  height: 640,
                  child: DesktopLyricColorDialog(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void setupDesktopViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders modern frosted glass card base, header, and badge',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog());
      await tester.pumpAndSettle();

      // Card Base & BackdropFilter
      expect(find.byType(ModernLyricDialogCard), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);

      // Header Elements
      expect(find.text('桌面歌词颜色'), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);

      // Subtitle
      expect(find.textContaining('实时预览'), findsOneWidget);
    });

    testWidgets('renders real-time Preview Banner with tag and dual lyric lines',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog(
        lyricContent: '天青色等烟雨 而我在等你',
        translation: 'Sky blue awaits the rain as I await you',
      ));
      await tester.pumpAndSettle();

      // Preview banner container
      expect(find.byKey(const Key('preview_banner')), findsOneWidget);

      // Tag
      expect(find.byKey(const Key('preview_banner_tag')), findsOneWidget);
      expect(find.text('正在播放：七声音乐 - 歌词大样'), findsOneWidget);

      // Main lyric
      final mainLyricFinder = find.byKey(const Key('preview_banner_main_lyric'));
      expect(mainLyricFinder, findsOneWidget);
      expect(find.text('天青色等烟雨 而我在等你'), findsOneWidget);

      // Translation lyric
      final transLyricFinder = find.byKey(const Key('preview_banner_trans_lyric'));
      expect(transLyricFinder, findsOneWidget);
      expect(find.text('Sky blue awaits the rain as I await you'), findsOneWidget);
    });

    testWidgets('renders all 9 preset chips with names and color dots',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog());
      await tester.pumpAndSettle();

      for (final preset in kCuratedColorPresets) {
        expect(find.byKey(ValueKey('preset_${preset.name}')), findsOneWidget);
        expect(find.text(preset.name), findsOneWidget);
      }
    });

    testWidgets('tapping preset chip updates color, hex field, and controller',
        (tester) async {
      setupDesktopViewport(tester);
      final controller = TextDisplayController();
      controller.hasSpecifiedColor = false;

      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      // Click "落日橙" preset (#FF7043)
      final sunsetChip = find.byKey(const ValueKey('preset_落日橙'));
      expect(sunsetChip, findsOneWidget);
      await tester.ensureVisible(sunsetChip);
      await tester.tap(sunsetChip);
      await tester.pumpAndSettle();

      // Verify subtitle updated
      expect(find.textContaining('落日橙 (#FF7043)'), findsOneWidget);

      // Verify HEX input updated
      final hexField = tester.widget<TextField>(find.byKey(const Key('hex_input')));
      expect(hexField.controller?.text, equals('#FF7043'));

      // Verify preview banner text color
      final mainLyric =
          tester.widget<Text>(find.byKey(const Key('preview_banner_main_lyric')));
      expect(mainLyric.style?.color, equals(const Color(0xFFFF7043)));

      // Verify controller live updated
      expect(controller.hasSpecifiedColor, isTrue);
      expect(controller.specifiedColor, equals(const Color(0xFFFF7043)));

      // Click "霓虹紫" preset (#B388FF)
      final neonChip = find.byKey(const ValueKey('preset_霓虹紫'));
      await tester.ensureVisible(neonChip);
      await tester.tap(neonChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('霓虹紫 (#B388FF)'), findsOneWidget);
      expect(controller.specifiedColor, equals(const Color(0xFFB388FF)));
    });

    testWidgets('HEX input updates color and controller',
        (tester) async {
      setupDesktopViewport(tester);
      final controller = TextDisplayController();
      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      // Enter valid HEX #FF7043 (Sunset Orange)
      final hexFinder = find.byKey(const Key('hex_input'));
      await tester.ensureVisible(hexFinder);
      await tester.enterText(hexFinder, '#FF7043');
      await tester.pumpAndSettle();

      expect(controller.specifiedColor, equals(const Color(0xFFFF7043)));
    });

    testWidgets('ColorWheelPicker renders and aligns with ThemePickerDialog',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog());
      await tester.pumpAndSettle();

      expect(find.byType(ColorWheelPicker), findsOneWidget);
    });

    testWidgets('Follow player theme card resets custom color and updates state',
        (tester) async {
      setupDesktopViewport(tester);
      final controller = TextDisplayController();
      controller.hasSpecifiedColor = true;
      controller.specifiedColor = const Color(0xFFFF7043);

      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      final followCard = find.byKey(const Key('follow_player_theme_card'));
      expect(followCard, findsOneWidget);
      await tester.ensureVisible(followCard);

      await tester.tap(followCard);
      await tester.pumpAndSettle();

      expect(controller.hasSpecifiedColor, isFalse);
      expect(find.textContaining('跟随主播放器主题色'), findsWidgets);
    });

    testWidgets('Cancel button rolls back to initial color and state',
        (tester) async {
      setupDesktopViewport(tester);
      final controller = TextDisplayController();
      controller.hasSpecifiedColor = true;
      controller.specifiedColor = const Color(0xFF00F5D4); // Aurora cyan

      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      // Modify color by tapping Sunset Orange
      final sunsetChip = find.byKey(const ValueKey('preset_落日橙'));
      await tester.ensureVisible(sunsetChip);
      await tester.tap(sunsetChip);
      await tester.pumpAndSettle();
      expect(controller.specifiedColor, equals(const Color(0xFFFF7043)));

      // Click "取消"
      final cancelBtn = find.byKey(const Key('color_dialog_cancel_btn'));
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Controller must be rolled back to Aurora Cyan
      expect(controller.specifiedColor, equals(const Color(0xFF00F5D4)));
      expect(controller.hasSpecifiedColor, isTrue);
    });

    testWidgets('Apply button confirms selected color',
        (tester) async {
      setupDesktopViewport(tester);
      final controller = TextDisplayController();
      controller.hasSpecifiedColor = true;
      controller.specifiedColor = const Color(0xFF00F5D4);

      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      // Modify color by tapping Sunset Orange
      final sunsetChip = find.byKey(const ValueKey('preset_落日橙'));
      await tester.ensureVisible(sunsetChip);
      await tester.tap(sunsetChip);
      await tester.pumpAndSettle();

      // Click "确定"
      final applyBtn = find.byKey(const Key('color_dialog_apply_btn'));
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      // Color confirmed
      expect(controller.specifiedColor, equals(const Color(0xFFFF7043)));
      expect(controller.hasSpecifiedColor, isTrue);
    });

    testWidgets('Color dialog renders directly without scrollbar and has follow card in view',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog());
      await tester.pumpAndSettle();

      // Ensure DesktopLyricColorDialog itself contains no Scrollbar or SingleChildScrollView
      final internalScrollViews = find.descendant(
        of: find.byType(DesktopLyricColorDialog),
        matching: find.byType(SingleChildScrollView),
      );
      expect(internalScrollViews, findsNothing);

      final internalScrollbars = find.descendant(
        of: find.byType(DesktopLyricColorDialog),
        matching: find.byType(Scrollbar),
      );
      expect(internalScrollbars, findsNothing);

      // Follow player theme card is directly visible in view
      final followCard = find.byKey(const Key('follow_player_theme_card'));
      expect(followCard, findsOneWidget);
    });
  });

  group('IPC PreferenceChangedMessage Format Tests', () {
    test('PreferenceChangedMessage correctly encodes specified color and follow theme', () {
      final controller = TextDisplayController();
      controller.spcifiyColor(const Color(0xFF00F5D4));

      final msg = controller.buildPreferenceMessage();
      expect(msg.hasSpecifiedColor, isTrue);
      expect(msg.primary, equals(const Color(0xFF00F5D4).toARGB32()));

      controller.usePlayerTheme();
      final msgTheme = controller.buildPreferenceMessage();
      expect(msgTheme.hasSpecifiedColor, isFalse);
      expect(msgTheme.primary, isNull);
    });
  });
}
