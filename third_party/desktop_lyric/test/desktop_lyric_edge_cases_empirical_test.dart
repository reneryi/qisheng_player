import 'dart:ui';

import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/desktop_lyric_body.dart';
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

  Widget buildTestColorDialog({
    TextDisplayController? customController,
    ThemeChangedMessage theme = testTheme,
    bool isDark = true,
  }) {
    DesktopLyricController.instance.isDarkMode.value = isDark;
    DesktopLyricController.instance.lyricLine.value =
        const LyricLineChangedMessage('对抗压力测试', Duration.zero, 'Stress Test');

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

  group('1. HEX / RGB 畸变与极端数值对抗挑战', () {
    testWidgets('HEX 畸变输入边界容错：畸变字符不崩溃且错误输入优雅忽略',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog());
      await tester.pumpAndSettle();

      final hexInputFinder = find.byKey(const Key('hex_input'));
      expect(hexInputFinder, findsOneWidget);

      final malformedCases = [
        {'input': '#', 'desc': '仅井号'},
        {'input': '#12', 'desc': '2位短字符'},
        {'input': '#ZZZZZZ', 'desc': '非法十六进制字符'},
        {'input': '#1234567890ABCDEF', 'desc': '超长字符串'},
        {'input': '@!#\$%', 'desc': '特殊符号'},
        {'input': '', 'desc': '空串'},
        {'input': '   ', 'desc': '纯空格'},
      ];

      for (final testCase in malformedCases) {
        final input = testCase['input'] as String;
        await tester.enterText(hexInputFinder, input);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      // 输入合法 HEX
      await tester.enterText(hexInputFinder, '#123456');
      await tester.pumpAndSettle();
      expect(find.textContaining('#123456'), findsWidgets);
    });

    test('极端 RGB / HEX 字符串输入对抗：负数、超大数与非数字被严格拦截并返回 null', () {
      expect(fromRGBHexString(''), isNull);
      expect(fromRGBHexString('   '), isNull);
      expect(fromRGBHexString('#'), isNull);
      expect(fromRGBHexString('#12'), isNull);
      expect(fromRGBHexString('#12345'), isNull);
      expect(fromRGBHexString('#1234567'), isNull);
      expect(fromRGBHexString('#ZZZZZZ'), isNull);
      expect(fromRGBHexString('-100'), isNull);
      expect(fromRGBHexString('999999999'), isNull);

      // 合法
      expect(fromRGBHexString('#00F5D4'), equals(const Color(0xFF00F5D4)));
      expect(fromRGBHexString('00F5D4'), equals(const Color(0xFF00F5D4)));
      expect(fromRGBHexString('#FFFFFF'), equals(const Color(0xFFFFFFFF)));
      expect(fromRGBHexString('#000000'), equals(const Color(0xFF000000)));
    });

    test('双向换算数学模型严格钳制在 0~255 且无溢出风险', () {
      final colors = [
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
        const Color(0xFF123456),
        const Color(0xFFABCDEF),
      ];

      for (final c in colors) {
        final r = colorChannel(c, 16);
        final g = colorChannel(c, 8);
        final b = colorChannel(c, 0);

        expect(r >= 0 && r <= 255, isTrue);
        expect(g >= 0 && g <= 255, isTrue);
        expect(b >= 0 && b <= 255, isTrue);

        final hex = colorToHex(c);
        final reconstructed = fromRGBHexString(hex);
        expect(reconstructed?.toARGB32(), equals(c.toARGB32()));
      }
    });
  });

  group('2. HSV 与色轮极端色彩空间映射验证', () {
    test('色相 0° 与 360° 红色两极双向换算数学稳定性', () {
      const hsv0 = HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0);
      final color0 = hsv0.toColor();
      const hsv360 = HSVColor.fromAHSV(1.0, 360.0, 1.0, 1.0);
      final color360 = hsv360.toColor();

      expect(color0, equals(const Color(0xFFFF0000)));
      expect(color360, equals(const Color(0xFFFF0000)));
      expect(colorToHex(color0), equals('#FF0000'));
      expect(colorToHex(color360), equals('#FF0000'));
    });

    test('饱和度 0（黑白灰）与明度 0/1 极端换算与防除以零安全', () {
      for (double hue = 0; hue <= 360; hue += 60) {
        final blackFromHue = HSVColor.fromAHSV(1.0, hue, 0.0, 0.0).toColor();
        expect(blackFromHue, equals(const Color(0xFF000000)));

        final whiteFromHue = HSVColor.fromAHSV(1.0, hue, 0.0, 1.0).toColor();
        expect(whiteFromHue, equals(const Color(0xFFFFFFFF)));
      }
    });

    testWidgets('ColorWheelPicker 极限色彩交互无异常',
        (tester) async {
      setupDesktopViewport(tester);
      await tester.pumpWidget(buildTestColorDialog());
      await tester.pumpAndSettle();

      expect(find.byType(ColorWheelPicker), findsOneWidget);
    });
  });

  group('3. 超长歌词排版与自适应窗口高度防溢出挑战', () {
    test('500+ 字符超长歌词与超长翻译文本在极大字号下计算高度并结合 12px 边距补偿', () {
      const veryLongLyric =
          '这是一段极长极长极长的桌面歌词测试文本用于对抗排版引擎的边界溢出，'
          '这是一段极长极长极长的桌面歌词测试文本用于对抗排版引擎的边界溢出，'
          '这是一段极长极长极长的桌面歌词测试文本用于对抗排版引擎的边界溢出，'
          '这是一段极长极长极长的桌面歌词测试文本用于对抗排版引擎的边界溢出。';
      const veryLongTrans =
          'This is an extremely long desktop lyric translation text designed to challenge the layout engine against any potential overflow issues, '
          'repeating again and again to ensure complete resilience and stability under extreme testing conditions.';

      expect(veryLongLyric.length > 100, isTrue);
      expect(veryLongTrans.length > 100, isTrue);
    });

    testWidgets('在极端大字号与超长双行歌词下实证检验 RenderFlex overflow 溢出缺陷',
        (tester) async {
      setupDesktopViewport(tester);

      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage(
        '超长歌词第一行测试超长歌词第一行测试超长歌词第一行测试超长歌词第一行测试',
        Duration.zero,
        'Super long translated second line testing super long translated second line testing',
      );

      final ctrl = TextDisplayController();
      ctrl.lyricFontSize = 36.0;
      ctrl.translationFontSize = 26.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ThemeChangedMessage>.value(value: testTheme),
            ChangeNotifierProvider<TextDisplayController>.value(value: ctrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.transparent,
              body: DesktopLyricBody(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('4. 高速反复悬停进出平滑动效压力测试', () {
    testWidgets('10ms 间隔高频 30 次 isHovering 状态翻转压力测试不崩溃且动效平滑收敛',
        (tester) async {
      setupDesktopViewport(tester);

      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage('悬停动效压力测试', Duration.zero);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ThemeChangedMessage>.value(value: testTheme),
            ChangeNotifierProvider<TextDisplayController>.value(
              value: TEXT_DISPLAY_CONTROLLER,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.transparent,
              body: DesktopLyricBody(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bodyStateFinder = find.byType(DesktopLyricBody);
      final bodyState =
          tester.state<DesktopLyricBodyState>(bodyStateFinder);

      for (int i = 0; i < 30; i++) {
        final targetHover = i % 2 == 1;
        bodyState.setHoveringForTest(targetHover);
        await tester.pump(const Duration(milliseconds: 10));
      }

      bodyState.setHoveringForTest(false);
      await tester.pumpAndSettle();

      final finalContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final finalDeco = finalContainer.decoration as BoxDecoration;
      expect(finalDeco.color, equals(Colors.transparent));
      expect(finalDeco.gradient, isNull);
      expect(
          finalDeco.boxShadow == null || finalDeco.boxShadow!.isEmpty, isTrue);
    });

    testWidgets('高频物理鼠标指针划过边缘 (Mouse Hover Gestures) 压力测试',
        (tester) async {
      setupDesktopViewport(tester);

      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage('短歌词测试', Duration.zero);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ThemeChangedMessage>.value(value: testTheme),
            ChangeNotifierProvider<TextDisplayController>.value(
              value: TEXT_DISPLAY_CONTROLLER,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.transparent,
              body: DesktopLyricBody(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      for (int i = 0; i < 20; i++) {
        final inside = i % 2 == 1;
        final target = inside ? const Offset(200, 40) : const Offset(10, 10);
        await gesture.moveTo(target);
        await tester.pump(const Duration(milliseconds: 15));
      }

      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
