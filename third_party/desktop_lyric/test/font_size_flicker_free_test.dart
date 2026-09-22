import 'package:desktop_lyric/component/desktop_lyric_body.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel windowManagerChannel =
      MethodChannel('res.yunik.com/window_manager');

  final List<String> windowManagerMethodCalls = [];
  final List<Size> setSizeHistory = [];

  setUp(() {
    windowManagerMethodCalls.clear();
    setSizeHistory.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (MethodCall call) async {
      windowManagerMethodCalls.add(call.method);
      if (call.method == 'setSize') {
        final args = call.arguments as Map<dynamic, dynamic>;
        setSizeHistory.add(Size(
          (args['width'] as num).toDouble(),
          (args['height'] as num).toDouble(),
        ));
        return true;
      }
      if (call.method == 'getSize') {
        return <String, dynamic>{'width': 800.0, 'height': 134.0};
      }
      return null;
    });

    TEXT_DISPLAY_CONTROLLER.lyricFontSize = 22.0;
    TEXT_DISPLAY_CONTROLLER.translationFontSize = 18.0;
    TEXT_DISPLAY_CONTROLLER.followPlayerFont = true;
    TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor = false;
    isDialogOpen.value = false;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, null);
  });

  Widget buildSubject({bool isDarkMode = true}) {
    DesktopLyricController.instance.isDarkMode.value = isDarkMode;
    DesktopLyricController.instance.isPlaying.value = false;
    DesktopLyricController.instance.lyricLine.value =
        const LyricLineChangedMessage(
      '星河浩瀚 韶华不负 Long Lyric Test Line',
      Duration(seconds: 10),
      'Translation sub-lyric line test',
    );

    const testTheme = ThemeChangedMessage(
      0xFF2196F3,
      0xFF1E1E1E,
      0xFFFFFFFF,
    );

    return MultiProvider(
      providers: [
        Provider<ThemeChangedMessage>.value(value: testTheme),
        ChangeNotifierProvider<TextDisplayController>.value(
          value: TEXT_DISPLAY_CONTROLLER,
        ),
      ],
      child: MaterialApp(
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const SizedBox(
          width: 800,
          height: 134,
          child: DesktopLyricBody(),
        ),
      ),
    );
  }

  group('Desktop Lyric Font Size Flicker-Free & Locked Window Invariants', () {
    testWidgets(
        'Clicking A+ and A- updates font sizes but NEVER calls windowManager.setSize (Zero Flash White)',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Trigger hover so action row appears
      final bodyState =
          tester.state<DesktopLyricBodyState>(find.byType(DesktopLyricBody));
      bodyState.setHoveringForTest(true);
      await tester.pumpAndSettle();

      final initialCallsCount = setSizeHistory.length;
      final initialLyricSize = TEXT_DISPLAY_CONTROLLER.lyricFontSize;
      final initialTransSize = TEXT_DISPLAY_CONTROLLER.translationFontSize;

      // Click text_increase_rounded (A+)
      final increaseBtn = find.byIcon(Symbols.text_increase_rounded);
      expect(increaseBtn, findsOneWidget);
      await tester.tap(increaseBtn);
      await tester.pumpAndSettle();

      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, initialLyricSize + 1.0);
      expect(TEXT_DISPLAY_CONTROLLER.translationFontSize, initialTransSize + 1.0);
      // WindowManager setSize must NOT have been called
      expect(setSizeHistory.length, equals(initialCallsCount));

      // Click text_decrease_rounded (A-)
      final decreaseBtn = find.byIcon(Symbols.text_decrease_rounded);
      expect(decreaseBtn, findsOneWidget);
      await tester.tap(decreaseBtn);
      await tester.pumpAndSettle();

      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, initialLyricSize);
      expect(TEXT_DISPLAY_CONTROLLER.translationFontSize, initialTransSize);
      // WindowManager setSize must still NOT have been called
      expect(setSizeHistory.length, equals(initialCallsCount));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '50 successive rapid font adjustments stress: zero setSize calls, zero overflow, perfect layout',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final bodyState =
          tester.state<DesktopLyricBodyState>(find.byType(DesktopLyricBody));
      bodyState.setHoveringForTest(true);
      await tester.pumpAndSettle();

      final increaseBtn = find.byIcon(Symbols.text_increase_rounded);
      final decreaseBtn = find.byIcon(Symbols.text_decrease_rounded);

      // Rapidly increase 20 times
      for (int i = 0; i < 20; i++) {
        await tester.tap(increaseBtn);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, equals(22.0 + 20));
      expect(setSizeHistory, isEmpty,
          reason: 'Dynamic setSize called during font increase, causing white flash!');
      expect(tester.takeException(), isNull,
          reason: 'RenderFlex overflowed when font size was large!');

      // Rapidly decrease 20 times
      for (int i = 0; i < 20; i++) {
        await tester.tap(decreaseBtn);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(TEXT_DISPLAY_CONTROLLER.lyricFontSize, equals(22.0));
      expect(setSizeHistory, isEmpty,
          reason: 'Dynamic setSize called during font decrease, causing white flash!');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Extreme large font sizes inside locked 800x134 window do not throw overflow exception',
        (tester) async {
      TEXT_DISPLAY_CONTROLLER.lyricFontSize = 38.0;
      TEXT_DISPLAY_CONTROLLER.translationFontSize = 30.0;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byKey(LYRIC_TEXT_KEY), findsOneWidget);
      expect(find.byKey(TRANSLATION_TEXT_KEY), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
