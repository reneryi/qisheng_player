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

  Widget buildTestColorDialog({
    TextDisplayController? customController,
    ThemeChangedMessage theme = const ThemeChangedMessage(
      0xFF00F5D4,
      0xFF131822,
      0xFFFFFFFF,
    ),
    bool isDark = true,
  }) {
    DesktopLyricController.instance.isDarkMode.value = isDark;
    DesktopLyricController.instance.lyricLine.value =
        const LyricLineChangedMessage('对抗压力验证大样', Duration.zero, 'Adversarial Lyric Test');

    return MultiProvider(
      providers: [
        Provider<ThemeChangedMessage>.value(value: theme),
        ChangeNotifierProvider<TextDisplayController>.value(
          value: customController ?? TEXT_DISPLAY_CONTROLLER,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: DesktopLyricColorDialog(),
        ),
      ),
    );
  }

  group('Dimension 1: Multi-Resolution & Multi-DPI Zero-Scrollbar Layout Bounds', () {
    final resolutions = [
      const Size(700, 550),   // Exact target window size in showDesktopLyricColorDialog
      const Size(800, 600),   // SVGA
      const Size(1024, 768),  // XGA
      const Size(1280, 720),  // 720p HD
      const Size(1366, 768),  // Laptop standard
      const Size(1920, 1080), // 1080p FHD
      const Size(2560, 1440), // 2K QHD
      const Size(3840, 2160), // 4K UHD
    ];

    final dpis = [1.0, 1.25, 1.5, 2.0];

    for (final res in resolutions) {
      for (final dpi in dpis) {
        testWidgets(
          'Viewport ${res.width.toInt()}x${res.height.toInt()} @ DPR $dpi: 100% zero scrollbars & all widgets in bounds',
          (tester) async {
            tester.view.physicalSize = Size(res.width * dpi, res.height * dpi);
            tester.view.devicePixelRatio = dpi;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(buildTestColorDialog());
            await tester.pumpAndSettle();

            // 1. ABSOLUTE ZERO SCROLLBARS: find.byType(Scrollbar) MUST BE 0!
            expect(
              find.byType(Scrollbar),
              findsNothing,
              reason: 'Scrollbar found at resolution $res @ DPR $dpi! Requirement R3 violated.',
            );
            expect(
              find.byType(SingleChildScrollView),
              findsNothing,
              reason: 'SingleChildScrollView found inside DesktopLyricColorDialog!',
            );
            expect(
              find.byType(ListView),
              findsNothing,
              reason: 'ListView found inside DesktopLyricColorDialog!',
            );

            // 2. NO RenderFlex overflow exception
            expect(tester.takeException(), isNull);

            // 3. Verify all 7 critical UI regions exist and are strictly within the viewport
            final viewportHeight = res.height;
            final viewportWidth = res.width;

            // (a) Preview Banner
            final previewBannerFinder = find.byKey(const Key('preview_banner'));
            expect(previewBannerFinder, findsOneWidget);
            final previewRect = tester.getRect(previewBannerFinder);
            expect(previewRect.top >= 0 && previewRect.bottom <= viewportHeight, isTrue,
                reason: 'Preview banner out of vertical viewport: $previewRect vs $viewportHeight');
            expect(previewRect.left >= 0 && previewRect.right <= viewportWidth, isTrue,
                reason: 'Preview banner out of horizontal viewport: $previewRect vs $viewportWidth');

            // (b) Follow Theme Card
            final followCardFinder = find.byKey(const Key('follow_player_theme_card'));
            expect(followCardFinder, findsOneWidget);
            final followRect = tester.getRect(followCardFinder);
            expect(followRect.top >= 0 && followRect.bottom <= viewportHeight, isTrue,
                reason: 'Follow theme card out of vertical viewport: $followRect vs $viewportHeight');
            expect(followRect.left >= 0 && followRect.right <= viewportWidth, isTrue);

            // (c) All 9 curated presets
            for (final preset in kCuratedColorPresets) {
              final chipFinder = find.byKey(ValueKey('preset_${preset.name}'));
              expect(chipFinder, findsOneWidget);
              final chipRect = tester.getRect(chipFinder);
              expect(chipRect.top >= 0 && chipRect.bottom <= viewportHeight, isTrue,
                  reason: 'Chip ${preset.name} out of vertical viewport: $chipRect vs $viewportHeight');
              expect(chipRect.left >= 0 && chipRect.right <= viewportWidth, isTrue);
            }

            // (d) ColorWheelPicker
            final wheelFinder = find.byType(ColorWheelPicker);
            expect(wheelFinder, findsOneWidget);
            final wheelRect = tester.getRect(wheelFinder);
            expect(wheelRect.top >= 0 && wheelRect.bottom <= viewportHeight, isTrue,
                reason: 'ColorWheelPicker out of vertical viewport: $wheelRect vs $viewportHeight');
            expect(wheelRect.left >= 0 && wheelRect.right <= viewportWidth, isTrue);

            // (e) Hex Input
            final hexFinder = find.byKey(const Key('hex_input'));
            expect(hexFinder, findsOneWidget);
            final hexRect = tester.getRect(hexFinder);
            expect(hexRect.top >= 0 && hexRect.bottom <= viewportHeight, isTrue,
                reason: 'Hex input out of vertical viewport: $hexRect vs $viewportHeight');
            expect(hexRect.left >= 0 && hexRect.right <= viewportWidth, isTrue);

            // (f) Cancel & Apply Action Buttons
            final cancelFinder = find.byKey(const Key('color_dialog_cancel_btn'));
            final applyFinder = find.byKey(const Key('color_dialog_apply_btn'));
            expect(cancelFinder, findsOneWidget);
            expect(applyFinder, findsOneWidget);

            final cancelRect = tester.getRect(cancelFinder);
            final applyRect = tester.getRect(applyFinder);
            expect(cancelRect.top >= 0 && cancelRect.bottom <= viewportHeight, isTrue,
                reason: 'Cancel button out of vertical viewport: $cancelRect vs $viewportHeight');
            expect(applyRect.top >= 0 && applyRect.bottom <= viewportHeight, isTrue,
                reason: 'Apply button out of vertical viewport: $applyRect vs $viewportHeight');
          },
        );
      }
    }
  });

  group('Dimension 2: 9 Curated Presets & Extreme Theme Color Blending & Contrast Fidelity', () {
    final extremeThemes = [
      {
        'name': 'Pure White (#FFFFFF)',
        'primary': 0xFFFFFFFF,
        'surface': 0xFFF8FAFC,
        'onSurface': 0xFF0F172A,
      },
      {
        'name': 'Pure Black (#000000)',
        'primary': 0xFF000000,
        'surface': 0xFF121212,
        'onSurface': 0xFFFFFFFF,
      },
      {
        'name': 'Fluorescent Yellow (#FFFF00)',
        'primary': 0xFFFFFF00,
        'surface': 0xFF1E2533,
        'onSurface': 0xFFFFFFFF,
      },
      {
        'name': 'Deep Purple (#31004A)',
        'primary': 0xFF31004A,
        'surface': 0xFF131822,
        'onSurface': 0xFFFFFFFF,
      },
      {
        'name': 'Pure Green (#00FF00)',
        'primary': 0xFF00FF00,
        'surface': 0xFF121212,
        'onSurface': 0xFFFFFFFF,
      },
      {
        'name': 'Pure Blue (#0000FF)',
        'primary': 0xFF0000FF,
        'surface': 0xFFF1F5F9,
        'onSurface': 0xFF0F172A,
      },
      {
        'name': 'Pure Red (#FF0000)',
        'primary': 0xFFFF0000,
        'surface': 0xFF131822,
        'onSurface': 0xFFFFFFFF,
      },
      {
        'name': 'Aurora Cyan (#00F5D4)',
        'primary': 0xFF00F5D4,
        'surface': 0xFF131822,
        'onSurface': 0xFFFFFFFF,
      },
    ];

    for (final themeCase in extremeThemes) {
      for (final isDark in [true, false]) {
        testWidgets(
          'Extreme Theme ${themeCase['name']} (isDark: $isDark): contrast fidelity & alpha blend safety',
          (tester) async {
            tester.view.physicalSize = const Size(1200, 900);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final themeMsg = ThemeChangedMessage(
              themeCase['primary'] as int,
              themeCase['surface'] as int,
              themeCase['onSurface'] as int,
            );

            await tester.pumpWidget(buildTestColorDialog(
              theme: themeMsg,
              isDark: isDark,
            ));
            await tester.pumpAndSettle();

            // No exceptions during build & paint
            expect(tester.takeException(), isNull);

            // Verify Apply button contrast algorithm
            final primaryColor = Color(themeMsg.primary);
            final applyBtnFinder = find.byKey(const Key('color_dialog_apply_btn'));
            final filledButton = tester.widget<FilledButton>(applyBtnFinder);
            final fgColor = filledButton.style?.foregroundColor?.resolve({});
            final bgColor = filledButton.style?.backgroundColor?.resolve({});

            expect(bgColor, equals(primaryColor));

            // If luminance > 0.45, foreground MUST be dark #0F172A for high contrast
            // If luminance <= 0.45, foreground MUST be white
            if (primaryColor.computeLuminance() > 0.45) {
              expect(fgColor, equals(const Color(0xFF0F172A)),
                  reason: 'High luminance primary ${themeCase['name']} must use dark text for contrast');
            } else {
              expect(fgColor, equals(Colors.white),
                  reason: 'Low luminance primary ${themeCase['name']} must use white text for contrast');
            }

            // Verify all 9 preset chips are present and clickable
            for (final preset in kCuratedColorPresets) {
              final chip = find.byKey(ValueKey('preset_${preset.name}'));
              expect(chip, findsOneWidget);
            }

            // Verify White preset (#FFFFFF) has border so it never disappears on white
            final whitePreset = kCuratedColorPresets.firstWhere((p) => p.hex == '#FFFFFF');
            expect(whitePreset.color, equals(const Color(0xFFFFFFFF)));
          },
        );
      }
    }

    testWidgets('Tapping all 9 presets sequentially updates color, text and controller fidelity',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = TextDisplayController();
      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      for (final preset in kCuratedColorPresets) {
        final chipFinder = find.byKey(ValueKey('preset_${preset.name}'));
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        // Subtitle shows preset name and hex
        expect(find.textContaining('${preset.name} (${preset.hex})'), findsOneWidget);

        // Hex input matches preset hex
        final hexField = tester.widget<TextField>(find.byKey(const Key('hex_input')));
        expect(hexField.controller?.text, equals(preset.hex));

        // Controller reflects new color
        expect(controller.hasSpecifiedColor, isTrue);
        expect(controller.specifiedColor, equals(preset.color));
      }
    });
  });

  group('Dimension 3: Hex Input Deformation & Error Trapping', () {
    test('Pure mathematical parser fromRGBHexString adversarial input matrix (35+ test vectors)', () {
      final strictlyInvalidVectors = [
        '',
        ' ',
        '   \t\r\n',
        '#',
        '##',
        '###',
        '#1',
        '#12',
        '#123',
        '#1234',
        '#12345',
        '#1234567',
        '#12345678',
        '#1234567890ABCDEF',
        '#GGGGGG',
        '#ZZZZZZ',
        '#12G456',
        '#12345Z',
        '#------',
        '# 123456',
        '#12 3456',
        '<script>',
        '--DROP',
        '\x00\x00\x00\x00\x00\x00',
        '#你好世界',
        '#🔥🚀✨',
        'null',
        'undefined',
        'NaN',
        'Infinity',
        '-Infinity',
        '#' * 200,
        'F' * 200,
      ];

      for (final vec in strictlyInvalidVectors) {
        expect(fromRGBHexString(vec), isNull,
            reason: 'Vector "$vec" should safely return null but was parsed or crashed');
      }

      // Adversarial Boundary Discovery:
      // Dart's int.tryParse(s, radix: 16) permits leading '+' and '-' signs.
      // Therefore 6-character inputs like "+12345" and "-12345" are parsed:
      final signedPos = fromRGBHexString('#+12345');
      expect(signedPos, isNotNull, reason: 'Dart int.tryParse parses "+12345" as 0x012345');
      expect(toRGBHexString(signedPos!), equals('#012345'));

      final signedNeg = fromRGBHexString('#-12345');
      expect(signedNeg, isNotNull, reason: 'Dart int.tryParse parses "-12345" as -74565');
      expect(toRGBHexString(signedNeg!), equals('#FEDCBB'));

      final validVectors = [
        {'input': '#00F5D4', 'expected': const Color(0xFF00F5D4)},
        {'input': '00F5D4', 'expected': const Color(0xFF00F5D4)},
        {'input': '#FFFFFF', 'expected': const Color(0xFFFFFFFF)},
        {'input': 'FFFFFF', 'expected': const Color(0xFFFFFFFF)},
        {'input': '#000000', 'expected': const Color(0xFF000000)},
        {'input': '000000', 'expected': const Color(0xFF000000)},
        {'input': '#FF7043', 'expected': const Color(0xFFFF7043)},
        {'input': '#B388FF', 'expected': const Color(0xFFB388FF)},
        {'input': '#69f0ae', 'expected': const Color(0xFF69F0AE)},
        {'input': '#40C4ff', 'expected': const Color(0xFF40C4FF)},
      ];

      for (final entry in validVectors) {
        final input = entry['input'] as String;
        final expected = entry['expected'] as Color;
        final result = fromRGBHexString(input);
        expect(result, equals(expected), reason: 'Failed parsing valid vector: $input');
        expect(toRGBHexString(result!), equals(toRGBHexString(expected)));
      }
    });

    testWidgets('UI Hex input deformation: entering malformed text never crashes dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = TextDisplayController();
      controller.spcifiyColor(const Color(0xFF00F5D4));

      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      final hexFinder = find.byKey(const Key('hex_input'));
      expect(hexFinder, findsOneWidget);

      final stressInputs = [
        '#',
        '#12',
        '#ZZZZZZ',
        '#1234567890',
        'malformed',
        '',
        '   ',
        '#你好',
        '#🚀🔥',
        ';DROP TABLE;',
      ];

      for (final malformed in stressInputs) {
        await tester.enterText(hexFinder, malformed);
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown when entering malformed hex: "$malformed"');
        // Controller color should NOT be corrupted by invalid input
        expect(controller.specifiedColor, equals(const Color(0xFF00F5D4)));
      }

      // Enter valid color #FF80AB
      await tester.enterText(hexFinder, '#FF80AB');
      await tester.pumpAndSettle();
      expect(controller.specifiedColor, equals(const Color(0xFFFF80AB)));
    });
  });

  group('Dimension 4: HSV Precision & Bidirectional Cycle-Lock Prevention', () {
    test('HSV boundary mathematics: hue [0, 360], sat [0, 1], val [0, 1]', () {
      // 1. Hue 0 and 360 are identical red
      final hsv0 = const HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0).toColor();
      final hsv360 = const HSVColor.fromAHSV(1.0, 360.0, 1.0, 1.0).toColor();
      expect(hsv0, equals(const Color(0xFFFF0000)));
      expect(hsv360, equals(const Color(0xFFFF0000)));

      // 2. Grayscale (S = 0): V controls brightness
      for (double v = 0.0; v <= 1.0; v += 0.2) {
        final gray = HSVColor.fromAHSV(1.0, 180.0, 0.0, v).toColor();
        final expectedByte = (v * 255).round();
        expect(colorChannel(gray, 16), equals(expectedByte));
        expect(colorChannel(gray, 8), equals(expectedByte));
        expect(colorChannel(gray, 0), equals(expectedByte));
      }

      // 3. Black (V = 0): always black regardless of H or S
      for (double h = 0.0; h <= 360.0; h += 45.0) {
        for (double s = 0.0; s <= 1.0; s += 0.5) {
          final black = HSVColor.fromAHSV(1.0, h, s, 0.0).toColor();
          expect(colorChannel(black, 16), 0);
          expect(colorChannel(black, 8), 0);
          expect(colorChannel(black, 0), 0);
        }
      }

      // 4. Primary & secondary pure hues at full saturation & brightness
      final hueMap = {
        0.0: const Color(0xFFFF0000),   // Red
        60.0: const Color(0xFFFFFF00),  // Yellow
        120.0: const Color(0xFF00FF00), // Green
        180.0: const Color(0xFF00FFFF), // Cyan
        240.0: const Color(0xFF0000FF), // Blue
        300.0: const Color(0xFFFF00FF), // Magenta
      };

      for (final entry in hueMap.entries) {
        final color = HSVColor.fromAHSV(1.0, entry.key, 1.0, 1.0).toColor();
        expect(color, equals(entry.value));
      }
    });

    testWidgets('Bidirectional synchronization & cycle-lock prevention stress (30 alternating cycles)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = TextDisplayController();
      await tester.pumpWidget(buildTestColorDialog(customController: controller));
      await tester.pumpAndSettle();

      final hexFinder = find.byKey(const Key('hex_input'));
      final wheelFinder = find.byType(ColorWheelPicker);
      expect(wheelFinder, findsOneWidget);

      final alternatingColors = [
        '#FF0000',
        '#00FF00',
        '#0000FF',
        '#FFFF00',
        '#FF00FF',
        '#00FFFF',
      ];

      for (int i = 0; i < 30; i++) {
        final targetHex = alternatingColors[i % alternatingColors.length];

        if (i % 2 == 0) {
          // Action 1: User types in Hex input
          await tester.enterText(hexFinder, targetHex);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(controller.specifiedColor, equals(fromRGBHexString(targetHex)));
        } else {
          // Action 2: User clicks a preset chip which updates wheel and text
          final preset = kCuratedColorPresets[i % kCuratedColorPresets.length];
          final chipFinder = find.byKey(ValueKey('preset_${preset.name}'));
          await tester.tap(chipFinder);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(controller.specifiedColor, equals(preset.color));

          final hexField = tester.widget<TextField>(hexFinder);
          expect(hexField.controller?.text, equals(preset.hex));
        }
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
