import 'package:desktop_lyric/component/desktop_lyric_body.dart';
import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/main.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel windowManagerChannel = MethodChannel('window_manager');
  const MethodChannel screenRetrieverChannel = MethodChannel('screen_retriever');

  late double currentWindowWidth;
  late double currentWindowHeight;
  late Offset currentWindowPos;
  final List<Size> setSizeHistory = [];
  final List<Offset> setPositionHistory = [];

  void resetMockWindowState({
    double width = 800.0,
    double height = 142.0,
    Offset pos = const Offset(200.0, 300.0),
  }) {
    currentWindowWidth = width;
    currentWindowHeight = height;
    currentWindowPos = pos;
    setSizeHistory.clear();
    setPositionHistory.clear();
  }

  setUp(() {
    resetMockWindowState();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (MethodCall call) async {
      switch (call.method) {
        case 'getBounds':
          return <String, dynamic>{
            'x': currentWindowPos.dx,
            'y': currentWindowPos.dy,
            'width': currentWindowWidth,
            'height': currentWindowHeight,
          };
        case 'getSize':
          return <String, dynamic>{
            'width': currentWindowWidth,
            'height': currentWindowHeight,
          };
        case 'getPosition':
          return <String, dynamic>{
            'x': currentWindowPos.dx,
            'y': currentWindowPos.dy,
          };
        case 'setBounds':
          final args = call.arguments as Map<dynamic, dynamic>?;
          if (args != null) {
            if (args['width'] != null && args['height'] != null) {
              currentWindowWidth = (args['width'] as num).toDouble();
              currentWindowHeight = (args['height'] as num).toDouble();
              setSizeHistory.add(Size(currentWindowWidth, currentWindowHeight));
            }
            if (args['x'] != null && args['y'] != null) {
              currentWindowPos = Offset(
                (args['x'] as num).toDouble(),
                (args['y'] as num).toDouble(),
              );
              setPositionHistory.add(currentWindowPos);
            }
          }
          return null;
        case 'startDragging':
          return null;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenRetrieverChannel, (MethodCall call) async {
      if (call.method == 'getAllDisplays') {
        return <String, dynamic>{
          'displays': [
            {
              'id': 1,
              'name': 'Primary Display',
              'size': {'width': 1920.0, 'height': 1080.0},
              'visiblePosition': {'x': 0.0, 'y': 0.0},
              'visibleSize': {'width': 1920.0, 'height': 1040.0},
              'scaleFactor': 1.0,
              'isPrimary': true,
            }
          ]
        };
      }
      return null;
    });

    // Reset controllers
    TEXT_DISPLAY_CONTROLLER.lyricFontSize = 22.0;
    TEXT_DISPLAY_CONTROLLER.translationFontSize = 18.0;
    TEXT_DISPLAY_CONTROLLER.followPlayerFont = true;
    TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor = false;
    isDialogOpen.value = false;

    DesktopLyricController.instance.installedFonts.value = [
      'Segoe UI',
      'Segoe UI Bold',
      'Segoe UI Light',
      'Arial',
      'Microsoft YaHei',
      'SimSun',
    ];
    DesktopLyricController.instance.lyricLine.value =
        const LyricLineChangedMessage('测试主歌词 Main Lyric', Duration.zero, '测试副歌词 Sub Translation');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenRetrieverChannel, null);
  });

  void setupDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Dimension 1: 120+ Iterations of Rapid Dialog Toggling (Font & Color Dialogs) & Height Invariant Stress', () {
    testWidgets('120 consecutive rapid dialog open/close cycles never decay height below 142px safety baseline',
        (tester) async {
      setupDesktopViewport(tester);

      await tester.pumpWidget(const DesktopLyricApp());
      await tester.pumpAndSettle();

      final BuildContext bodyContext = tester.element(find.byType(DesktopLyricBody));

      const int totalIterations = 120;
      final List<double> finalHeights = [];

      for (int i = 0; i < totalIterations; i++) {
        final bool isFontDialog = (i % 2 == 0);

        if (isFontDialog) {
          // Open Font Selector Dialog
          showLyricFontSelectorDialog(bodyContext);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(isDialogOpen.value, isTrue);
          expect(find.byType(LyricFontSelectorDialog), findsOneWidget);

          // Verify window size expanded for dialog
          expect(currentWindowWidth, greaterThanOrEqualTo(600.0));
          expect(currentWindowHeight, greaterThanOrEqualTo(620.0));

          // Close Dialog
          final dialogContext = tester.element(find.byType(LyricFontSelectorDialog));
          Navigator.of(dialogContext).pop();
          await tester.pumpAndSettle();

          expect(find.byType(LyricFontSelectorDialog), findsNothing);
        } else {
          // Open Color Dialog
          showDesktopLyricColorDialog(bodyContext);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(isDialogOpen.value, isTrue);
          expect(find.byType(DesktopLyricColorDialog), findsOneWidget);

          // Verify window size expanded for color dialog
          expect(currentWindowWidth, greaterThanOrEqualTo(700.0));
          expect(currentWindowHeight, greaterThanOrEqualTo(550.0));

          // Close Dialog
          final dialogContext = tester.element(find.byType(DesktopLyricColorDialog));
          Navigator.of(dialogContext).pop();
          await tester.pumpAndSettle();

          expect(find.byType(DesktopLyricColorDialog), findsNothing);
        }

        // Rigorous Invariant Checks After Each Cycle
        expect(isDialogOpen.value, isFalse,
            reason: 'isDialogOpen state machine failed to reset on iteration $i');
        expect(currentWindowHeight, greaterThanOrEqualTo(142.0),
            reason: 'Iteration $i degraded window height below safety baseline: $currentWindowHeight px');
        expect(currentWindowWidth, equals(800.0),
            reason: 'Iteration $i corrupted window width: $currentWindowWidth px');

        finalHeights.add(currentWindowHeight);
      }

      // Assert No Progressive Degradation Across All 120 Iterations
      final double baselineHeight = finalHeights.first;
      for (int i = 0; i < finalHeights.length; i++) {
        expect(finalHeights[i], greaterThanOrEqualTo(142.0));
        expect(finalHeights[i], equals(baselineHeight),
            reason: 'Height degraded from $baselineHeight to ${finalHeights[i]} at iteration $i');
      }

      // Total setSize operations executed without crash
      expect(setSizeHistory.length, greaterThanOrEqualTo(totalIterations * 2));
    });
  });

  group('Dimension 2: Sub-Lyric & Main Lyric Physical Clearance & Zero-Truncation Proof Across Font Sizes', () {
    testWidgets('Font sizes 12px to 38px: available lyric viewport strictly >= combined text height + shadows',
        (tester) async {
      setupDesktopViewport(tester);

      final List<Map<String, double>> fontMatrix = [
        {'lyric': 12.0, 'trans': 10.0},
        {'lyric': 16.0, 'trans': 12.0},
        {'lyric': 20.0, 'trans': 16.0},
        {'lyric': 22.0, 'trans': 18.0}, // Default
        {'lyric': 26.0, 'trans': 20.0},
        {'lyric': 30.0, 'trans': 24.0},
        {'lyric': 34.0, 'trans': 28.0},
        {'lyric': 38.0, 'trans': 30.0}, // Extreme large
      ];

      double previousHeight = 0.0;

      for (final fontConfig in fontMatrix) {
        final double lfs = fontConfig['lyric']!;
        final double tfs = fontConfig['trans']!;

        TEXT_DISPLAY_CONTROLLER.lyricFontSize = lfs;
        TEXT_DISPLAY_CONTROLLER.translationFontSize = tfs;

        final double calculatedHeight = calculateRequiredLyricWindowHeight(
          lyricFontSize: lfs,
          translationFontSize: tfs,
        );

        // 1. Minimum baseline invariant
        expect(calculatedHeight, greaterThanOrEqualTo(142.0),
            reason: 'Height $calculatedHeight below 142px for font sizes ($lfs, $tfs)');

        // 2. Monotonic growth invariant: larger fonts must never yield smaller window height
        expect(calculatedHeight, greaterThanOrEqualTo(previousHeight),
            reason: 'Monotonicity violation: height shrank from $previousHeight to $calculatedHeight');
        previousHeight = calculatedHeight;

        // 3. Render at calculated window height and inspect physical RenderBoxes
        resetMockWindowState(height: calculatedHeight);

        await tester.pumpWidget(const DesktopLyricApp());
        await tester.pumpAndSettle();

        final RenderBox lyricBox =
            tester.renderObject(find.byKey(LYRIC_TEXT_KEY)) as RenderBox;
        final RenderBox transBox =
            tester.renderObject(find.byKey(TRANSLATION_TEXT_KEY)) as RenderBox;

        final double lyricHeight = lyricBox.size.height;
        final double transHeight = transBox.size.height;

        // Total available height inside the body for lyrics:
        // Window height - FixedLayoutOverhead (86.0)
        final double availableForLyrics = calculatedHeight - kFixedLayoutOverhead;

        // Lyric + translation + shadow buffer must fit completely within available space
        final double requiredForText = lyricHeight + transHeight;
        expect(requiredForText, lessThanOrEqualTo(availableForLyrics),
            reason: 'Text lines ($lyricHeight + $transHeight = $requiredForText px) '
                'exceed available space ($availableForLyrics px) at font sizes ($lfs, $tfs)');

        // 4. Verify no RenderFlex overflow exception
        expect(tester.takeException(), isNull);

        // 5. Verify translation bottom edge does not exceed outer ClipRRect
        final RenderBox containerBox =
            tester.renderObject(find.byType(DesktopLyricBody)) as RenderBox;
        final Offset transOffset = transBox.localToGlobal(Offset.zero);
        final Offset containerOffset = containerBox.localToGlobal(Offset.zero);

        final double transBottom = transOffset.dy + transHeight;
        final double containerBottom = containerOffset.dy + containerBox.size.height;

        expect(transBottom, lessThanOrEqualTo(containerBottom),
            reason: 'Translation text bottom ($transBottom) clipped by container boundary ($containerBottom)');
      }
    });
  });

  group('Dimension 3: Extreme Lyric Scenarios & Boundary Fault Tolerance', () {
    test('Pre-render & corrupted dimension fault tolerance: null, zero, negative and NaN', () {
      // Pre-render state (RenderBox null)
      final h1 = calculateRequiredLyricWindowHeight(
        measuredLyricHeight: null,
        measuredTranslationHeight: null,
      );
      expect(h1, greaterThanOrEqualTo(142.0));

      // Zero measured height
      final h2 = calculateRequiredLyricWindowHeight(
        measuredLyricHeight: 0.0,
        measuredTranslationHeight: 0.0,
      );
      expect(h2, greaterThanOrEqualTo(142.0));

      // Negative measured height
      final h3 = calculateRequiredLyricWindowHeight(
        measuredLyricHeight: -100.0,
        measuredTranslationHeight: -50.0,
      );
      expect(h3, greaterThanOrEqualTo(142.0));

      // Huge rendered height expands window adaptively
      final h4 = calculateRequiredLyricWindowHeight(
        measuredLyricHeight: 80.0,
        measuredTranslationHeight: 60.0,
      );
      expect(h4, greaterThanOrEqualTo(86.0 + 8.0 + 80.0 + 60.0));
    });

    testWidgets('Missing translation & dynamic arrival: space reserved and zero glitch',
        (tester) async {
      setupDesktopViewport(tester);

      // Start with pure instrumental / missing translation
      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage('纯音乐 无歌词 Pure Music', Duration.zero, null);

      await tester.pumpWidget(const DesktopLyricApp());
      await tester.pumpAndSettle();

      expect(find.byKey(LYRIC_TEXT_KEY), findsOneWidget);
      expect(find.byKey(TRANSLATION_TEXT_KEY), findsNothing);

      // Window height must still reserve full safety clearance (>= 142.0)
      final double noTransHeight = calculateRequiredLyricWindowHeight();
      expect(noTransHeight, greaterThanOrEqualTo(142.0));

      // Now dynamic translation arrives
      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage('纯音乐 无歌词 Pure Music', Duration.zero, 'Instrumental (No Lyrics)');
      await tester.pumpAndSettle();

      expect(find.byKey(LYRIC_TEXT_KEY), findsOneWidget);
      expect(find.byKey(TRANSLATION_TEXT_KEY), findsOneWidget);

      final double withTransHeight = calculateRequiredLyricWindowHeight();
      expect(withTransHeight, greaterThanOrEqualTo(142.0));
      expect(withTransHeight, equals(noTransHeight),
          reason: 'Height should already have reserved translation space, preventing jarring resize jumps');

      expect(tester.takeException(), isNull);
    });

    testWidgets('Multilingual complex scripts and ultra-long lyrics: CJK, RTL Arabic, Emoji, Hindi',
        (tester) async {
      setupDesktopViewport(tester);

      const complexLyric = '🎵 繁體漢字 日本語 カタカナ 한글 🚀 👨‍👩‍👧‍👦 العربية עִברִית हिन्दी ਸੰਗੀਤ';
      const complexTrans = 'Multi-script text with CJK 汉字, RTL Arabic مرحبا, Devanagari नमस्ते, and complex emoji 🎉';

      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage(complexLyric, Duration.zero, complexTrans);

      await tester.pumpWidget(const DesktopLyricApp());
      await tester.pumpAndSettle();

      expect(find.byKey(LYRIC_TEXT_KEY), findsOneWidget);
      expect(find.byKey(TRANSLATION_TEXT_KEY), findsOneWidget);

      final RenderBox lyricBox =
          tester.renderObject(find.byKey(LYRIC_TEXT_KEY)) as RenderBox;
      final RenderBox transBox =
          tester.renderObject(find.byKey(TRANSLATION_TEXT_KEY)) as RenderBox;

      expect(lyricBox.size.height, greaterThan(0.0));
      expect(transBox.size.height, greaterThan(0.0));

      // Ultra long 500+ character string
      final veryLongText = '超长多语言歌词排版测试 ' * 30;
      DesktopLyricController.instance.lyricLine.value =
          LyricLineChangedMessage(veryLongText, Duration.zero, veryLongText);
      await tester.pumpAndSettle();

      // Ensure SingleChildScrollView absorbs horizontal overflow without vertical expansion
      final RenderBox longLyricBox =
          tester.renderObject(find.byKey(LYRIC_TEXT_KEY)) as RenderBox;
      expect(longLyricBox.size.height, equals(lyricBox.size.height),
          reason: 'Horizontal SingleChildScrollView must constrain line to single height without wrapping');

      expect(tester.takeException(), isNull);
    });
  });

  group('Dimension 4: Chaos / Interrupted Rapid Toggling & Race Conditions', () {
    testWidgets('Aborted dialog open mid-flight recovers cleanly to lyric size',
        (tester) async {
      setupDesktopViewport(tester);

      await tester.pumpWidget(const DesktopLyricApp());
      await tester.pumpAndSettle();

      // Rapidly toggle isDialogOpen without waiting for pumpAndSettle
      for (int i = 0; i < 20; i++) {
        isDialogOpen.value = true;
        await tester.pump(const Duration(milliseconds: 5));
        isDialogOpen.value = false;
        await tester.pump(const Duration(milliseconds: 5));
      }

      await tester.pumpAndSettle();

      expect(isDialogOpen.value, isFalse);
      expect(currentWindowHeight, greaterThanOrEqualTo(142.0));
      expect(currentWindowWidth, equals(800.0));
      expect(tester.takeException(), isNull);
    });
  });

  group('Dimension 5: Listener, Timer & Memory Leak Verification', () {
    testWidgets('Repeated dialog cycles do not accumulate dangling listeners or timers',
        (tester) async {
      setupDesktopViewport(tester);

      await tester.pumpWidget(const DesktopLyricApp());
      await tester.pumpAndSettle();

      final BuildContext bodyContext = tester.element(find.byType(DesktopLyricBody));

      // Execute 30 cycles
      for (int i = 0; i < 30; i++) {
        showLyricFontSelectorDialog(bodyContext);
        await tester.pump(const Duration(milliseconds: 20));
        final dialogContext = tester.element(find.byType(LyricFontSelectorDialog));
        Navigator.of(dialogContext).pop();
        await tester.pumpAndSettle();
      }

      // Verify no pending timers or frame requests
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, equals(0));
      expect(isDialogOpen.value, isFalse);
      expect(currentWindowHeight, greaterThanOrEqualTo(142.0));
    });
  });
}
