import 'package:desktop_lyric/component/action_row.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

void main() {
  const testTheme = ThemeChangedMessage(
    0xFF2196F3,
    0xFF1E1E1E,
    0xFFFFFFFF,
  );

  Widget buildSubject({
    ThemeChangedMessage theme = testTheme,
    bool isDarkMode = true,
  }) {
    DesktopLyricController.instance.isDarkMode.value = isDarkMode;
    DesktopLyricController.instance.isPlaying.value = false;

    return MultiProvider(
      providers: [
        Provider<ThemeChangedMessage>.value(value: theme),
        ChangeNotifierProvider<TextDisplayController>.value(
          value: TEXT_DISPLAY_CONTROLLER,
        ),
      ],
      child: MaterialApp(
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 800,
            height: 48,
            child: ActionRow(),
          ),
        ),
      ),
    );
  }

  group('ActionRow Rounded & Solid Aesthetic Tests', () {
    testWidgets('all 10 buttons render with rounded Material Symbols', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Symbols.text_increase_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.text_decrease_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.font_download_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.palette_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.translate_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.close_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.lock_rounded), findsOneWidget);
    });

    testWidgets('core playback controls strictly have NO tooltip per GEMINI.md policy', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      final playFinder = find.byType(DesktopLyricPrimaryPlayButton);
      expect(find.descendant(of: playFinder, matching: find.byType(Tooltip)), findsNothing);

      final prevFinder = find.widgetWithIcon(DesktopLyricTransportButton, Symbols.skip_previous_rounded);
      expect(find.descendant(of: prevFinder, matching: find.byType(Tooltip)), findsNothing);

      final nextFinder = find.widgetWithIcon(DesktopLyricTransportButton, Symbols.skip_next_rounded);
      expect(find.descendant(of: nextFinder, matching: find.byType(Tooltip)), findsNothing);
    });

    testWidgets('secondary utility and font buttons have clear descriptive tooltips', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      expect(find.byTooltip('增大字号'), findsOneWidget);
      expect(find.byTooltip('缩小字号'), findsOneWidget);
      expect(find.byTooltip('歌词字体'), findsOneWidget);
      expect(find.byTooltip('歌词颜色'), findsOneWidget);
      expect(find.byTooltip('隐藏翻译'), findsOneWidget);
      expect(find.byTooltip('关闭歌词'), findsOneWidget);
      expect(find.byTooltip('锁定歌词'), findsOneWidget);
    });

    testWidgets('primary play button transitions between play and pause smoothly', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.pause_rounded), findsNothing);

      DesktopLyricController.instance.isPlaying.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Symbols.pause_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.play_arrow_rounded), findsNothing);
    });

    testWidgets('primary play button has circular decoration and gradient', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      final playButtonFinder = find.byType(DesktopLyricPrimaryPlayButton);
      final containerFinder = find.descendant(
        of: playButtonFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.gradient, isNotNull);
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, 2);
    });

    testWidgets('hovering on primary play button smoothly scales without error', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      final playButtonFinder = find.byType(DesktopLyricPrimaryPlayButton);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(playButtonFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      // After hover, transform scale should be > 1.0
      final transformFinder = find.descendant(
        of: playButtonFinder,
        matching: find.byType(Transform),
      ).first;
      final transform = tester.widget<Transform>(transformFinder);
      expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.0));

      await gesture.moveTo(const Offset(1000, 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await gesture.removePointer();
    });

    testWidgets('font increase and decrease buttons keep lyric and translation font sizes strictly unified', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      TEXT_DISPLAY_CONTROLLER.lyricFontSize = 22.0;
      TEXT_DISPLAY_CONTROLLER.translationFontSize = 22.0;

      await tester.tap(find.byIcon(Symbols.text_increase_rounded));
      await tester.pump();
      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, 23.0);
      expect(TEXT_DISPLAY_CONTROLLER.translationFontSize, 23.0);

      await tester.tap(find.byIcon(Symbols.text_decrease_rounded));
      await tester.pump();
      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, 22.0);
      expect(TEXT_DISPLAY_CONTROLLER.translationFontSize, 22.0);

      // Verify lower boundary (14.0)
      TEXT_DISPLAY_CONTROLLER.lyricFontSize = 14.0;
      TEXT_DISPLAY_CONTROLLER.translationFontSize = 14.0;
      await tester.tap(find.byIcon(Symbols.text_decrease_rounded));
      await tester.pump();
      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, 14.0);
      expect(TEXT_DISPLAY_CONTROLLER.translationFontSize, 14.0);

      // Verify upper boundary (kMaxLyricFontSize = 56.0)
      TEXT_DISPLAY_CONTROLLER.lyricFontSize = TextDisplayController.kMaxLyricFontSize;
      TEXT_DISPLAY_CONTROLLER.translationFontSize = TextDisplayController.kMaxLyricFontSize;
      await tester.tap(find.byIcon(Symbols.text_increase_rounded));
      await tester.pump();
      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, TextDisplayController.kMaxLyricFontSize);
      expect(TEXT_DISPLAY_CONTROLLER.translationFontSize, TextDisplayController.kMaxLyricFontSize);
    });

    testWidgets('translation toggle button switches showTranslation state', (tester) async {
      await tester.pumpWidget(buildSubject(isDarkMode: true));
      await tester.pumpAndSettle();

      TEXT_DISPLAY_CONTROLLER.showTranslation = true;
      await tester.pumpAndSettle();

      final translateBtn = find.byIcon(Symbols.translate_rounded);
      expect(translateBtn, findsOneWidget);
      expect(find.byTooltip('隐藏翻译'), findsOneWidget);

      await tester.tap(translateBtn);
      await tester.pumpAndSettle();

      expect(TEXT_DISPLAY_CONTROLLER.showTranslation, isFalse);
      expect(find.byTooltip('显示翻译'), findsOneWidget);

      await tester.tap(translateBtn);
      await tester.pumpAndSettle();

      expect(TEXT_DISPLAY_CONTROLLER.showTranslation, isTrue);
      expect(find.byTooltip('隐藏翻译'), findsOneWidget);
    });
  });
}
