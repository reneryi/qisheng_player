import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/desktop_lyric_config_launcher.dart';
import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/main.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MockProcess implements Process {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final Completer<int> _exitCodeCompleter = Completer<int>();
  bool wasKilled = false;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  int get pid => 12345;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    wasKilled = true;
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(0);
    }
    return true;
  }

  void emitStdout(String line) {
    _stdoutController.add(utf8.encode('$line\n'));
  }

  void completeExit([int code = 0]) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }

  Future<void> dispose() async {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(0);
    }
    _stdoutController.close();
    _stderrController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopLyricConfigLauncher Process & IPC Tests', () {
    late MockProcess mockProcess;
    late List<String> capturedArgs;

    setUp(() {
      mockProcess = MockProcess();
      capturedArgs = [];

      DesktopLyricConfigLauncher.processStarterOverride =
          (String executable, List<String> arguments) async {
        capturedArgs = List.from(arguments);
        return mockProcess;
      };

      DesktopLyricController.instance.isDarkMode.value = true;
      DesktopLyricController.instance.theme.value = const ThemeChangedMessage(
        0xFF00F5D4,
        0xFF131822,
        0xFFFFFFFF,
      );
      DesktopLyricController.instance.installedFonts.value = [
        'Segoe UI',
        'Microsoft YaHei'
      ];
      DesktopLyricController.instance.playerFontFamily.value = 'Segoe UI';

      TEXT_DISPLAY_CONTROLLER.initializeFromInitArgs(
        playerFont: 'Segoe UI',
        savedFont: null,
        followPlayer: true,
        hasSpecifiedColor: false,
      );
    });

    tearDown(() async {
      DesktopLyricConfigLauncher.processStarterOverride = null;
      await DesktopLyricConfigLauncher.closeActiveConfig();
      await mockProcess.dispose();
    });

    test('Launches font config window with valid arguments and payload',
        () async {
      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.font,
      );

      expect(capturedArgs.length, equals(3));
      expect(capturedArgs[0], equals('--config-window'));
      expect(capturedArgs[1], equals('font'));

      final payload =
          json.decode(capturedArgs[2]) as Map<String, dynamic>;
      expect(payload['isConfigWindow'], isTrue);
      expect(payload['configType'], equals('font'));
      expect(payload['isDarkMode'], isTrue);
      expect(payload['followPlayerFont'], isTrue);
      expect(payload['installedFonts'], contains('Segoe UI'));

      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isTrue);
      expect(isDialogOpen.value, isTrue);
    });

    test('Launches color config window with valid arguments and payload',
        () async {
      TEXT_DISPLAY_CONTROLLER.spcifiyColor(const Color(0xFFFF7043));

      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.color,
      );

      expect(capturedArgs.length, equals(3));
      expect(capturedArgs[0], equals('--config-window'));
      expect(capturedArgs[1], equals('color'));

      final payload =
          json.decode(capturedArgs[2]) as Map<String, dynamic>;
      expect(payload['isConfigWindow'], isTrue);
      expect(payload['configType'], equals('color'));
      expect(payload['hasSpecifiedColor'], isTrue);
      expect(payload['specifiedColor'], equals(const Color(0xFFFF7043).toARGB32()));
    });

    test('Applies PreferenceChangedMessage from child process stdout to parent controller',
        () async {
      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.color,
      );

      expect(TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor, isFalse);

      // Simulate child process emitting PreferenceChangedMessage with new color
      const newColor = 0xFFB388FF;
      const msg = PreferenceChangedMessage(
        newColor,
        0xFF131822,
        0xFFFFFFFF,
        hasSpecifiedColor: true,
        lyricFontFamily: null,
        followPlayerFont: true,
      );
      mockProcess.emitStdout(msg.buildMessageJson());

      // Allow stream to pump
      await Future.delayed(const Duration(milliseconds: 50));

      expect(TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor, isTrue);
      expect(TEXT_DISPLAY_CONTROLLER.specifiedColor, equals(const Color(newColor)));

      // Simulate child switching to player theme
      const msgTheme = PreferenceChangedMessage(
        null,
        0xFF131822,
        0xFFFFFFFF,
        hasSpecifiedColor: false,
      );
      mockProcess.emitStdout(msgTheme.buildMessageJson());

      await Future.delayed(const Duration(milliseconds: 50));
      expect(TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor, isFalse);
    });

    test('Closes previous active config process when launching a second one',
        () async {
      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.font,
      );

      final firstProcess = mockProcess;
      expect(firstProcess.wasKilled, isFalse);

      // Create a second mock process for second launch
      final secondMockProcess = MockProcess();
      DesktopLyricConfigLauncher.processStarterOverride =
          (String executable, List<String> arguments) async {
        return secondMockProcess;
      };

      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.color,
      );

      expect(firstProcess.wasKilled, isTrue);
      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isTrue);

      await secondMockProcess.dispose();
    });

    test('Child process exit resets launcher state cleanly',
        () async {
      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.font,
      );

      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isTrue);
      expect(isDialogOpen.value, isTrue);

      mockProcess.completeExit(0);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isFalse);
      expect(isDialogOpen.value, isFalse);
    });

    test('Receiving ConfigWindowClosed immediately resets isDialogOpen and cleans up process',
        () async {
      await DesktopLyricConfigLauncher.open(
        null,
        LyricConfigType.font,
      );

      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isTrue);
      expect(isDialogOpen.value, isTrue);

      mockProcess.emitStdout(json.encode({
        'type': 'ConfigWindowClosed',
        'message': <String, dynamic>{},
      }));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isFalse);
      expect(isDialogOpen.value, isFalse);
    });

    test('Rapid concurrent launches discard obsolete mid-flight process',
        () async {
      final p1 = MockProcess();
      final p2 = MockProcess();
      final p1Completer = Completer<Process>();

      DesktopLyricConfigLauncher.processStarterOverride =
          (String executable, List<String> arguments) async {
        if (arguments.contains('font')) {
          return p1Completer.future;
        } else {
          return p2;
        }
      };

      // Start font launch (deliberately delayed)
      final f1 = DesktopLyricConfigLauncher.open(null, LyricConfigType.font);

      // Rapidly trigger color launch while font launch is still in flight
      final f2 = DesktopLyricConfigLauncher.open(null, LyricConfigType.color);

      // Now complete the delayed font launch
      p1Completer.complete(p1);

      await Future.wait([f1, f2]);
      await Future.delayed(const Duration(milliseconds: 50));

      // The obsolete process p1 must have been killed
      expect(p1.wasKilled, isTrue);
      // The latest process p2 must be active and not killed
      expect(p2.wasKilled, isFalse);
      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isTrue);

      await p1.dispose();
      await p2.dispose();
    });

    test('closeActiveConfig while launch is in flight kills newly started process',
        () async {
      final p1 = MockProcess();
      final p1Completer = Completer<Process>();

      DesktopLyricConfigLauncher.processStarterOverride =
          (String executable, List<String> arguments) async {
        return p1Completer.future;
      };

      final launchFuture = DesktopLyricConfigLauncher.open(null, LyricConfigType.font);

      // Close requested before process completes starting
      await DesktopLyricConfigLauncher.closeActiveConfig();

      // Complete process startup
      p1Completer.complete(p1);
      await launchFuture;
      await Future.delayed(const Duration(milliseconds: 50));

      // Process must have been killed upon finishing start
      expect(p1.wasKilled, isTrue);
      expect(DesktopLyricConfigLauncher.isConfigWindowOpen, isFalse);
      expect(isDialogOpen.value, isFalse);

      await p1.dispose();
    });
  });

  group('DesktopLyricConfigApp UI Widget Tests', () {
    bool closeWindowCalled = false;

    setUp(() {
      closeWindowCalled = false;
      resetConfigWindowClosingForTesting();
      configWindowCloserOverride = () {
        closeWindowCalled = true;
      };

      DesktopLyricController.instance.isDarkMode.value = true;
      DesktopLyricController.instance.theme.value = const ThemeChangedMessage(
        0xFF00F5D4,
        0xFF131822,
        0xFFFFFFFF,
      );
      DesktopLyricController.instance.installedFonts.value = [
        'Segoe UI',
        'Arial',
      ];
      DesktopLyricController.instance.playerFontFamily.value = 'Segoe UI';
      DesktopLyricController.instance.lyricLine.value =
          const LyricLineChangedMessage('测试预览歌词', Duration.zero, 'Preview Translation');
    });

    tearDown(() {
      configWindowCloserOverride = null;
    });

    testWidgets('Renders font selector dialog cleanly and close button triggers window close',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'font'));
      await tester.pumpAndSettle();

      expect(find.byType(LyricFontSelectorDialog), findsOneWidget);
      expect(find.text('选择字体'), findsOneWidget);

      // Tap the close button (Icons.close_rounded)
      final closeButton = find.byTooltip('关闭');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets('Renders color selector dialog cleanly and close button triggers window close',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'color'));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopLyricColorDialog), findsOneWidget);
      expect(find.text('桌面歌词颜色'), findsOneWidget);

      final closeButton = find.byTooltip('关闭');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets('Clicking apply button in color dialog triggers window close',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'color'));
      await tester.pumpAndSettle();

      final applyButton = find.text('确定');
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets('Clicking cancel button in color dialog triggers window close',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'color'));
      await tester.pumpAndSettle();

      final cancelButton = find.text('取消');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets('Tapping background barrier outside dialog triggers window close',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'font'));
      await tester.pumpAndSettle();

      // Tap near the top edge outside the dialog card
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets('Pressing Escape at root closes the config window',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'font'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets(
        'Pressing Escape in font secondary menu returns to main menu without closing window',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Provide multi-weight variants so tapping opens secondary menu
      DesktopLyricController.instance.installedFonts.value = [
        'Arial Regular',
        'Arial Bold',
      ];

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'font'));
      await tester.pumpAndSettle();

      // Tap on Arial font family to open secondary menu
      final fontTile = find.text('Arial');
      expect(fontTile, findsOneWidget);
      await tester.tap(fontTile);
      await tester.pumpAndSettle();

      // Verify we are now in the secondary menu (shows font family header)
      expect(find.textContaining('选择粗细字重规格'), findsOneWidget);

      // Press Escape - should pop back to main list, NOT close the window!
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isFalse);
      expect(find.text('选择字体'), findsOneWidget);

      // Press Escape again at root - NOW it should close the window
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closeWindowCalled, isTrue);
    });

    testWidgets(
        'Sub-route pop in NavigatorObserver does not close config window; only root pop does',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopLyricConfigApp(configType: 'font'));
      await tester.pumpAndSettle();

      final navContext = tester.element(find.byType(LyricFontSelectorDialog));
      final nav = Navigator.of(navContext);

      // Push a dummy sub-route
      nav.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('SubRoute')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('SubRoute'), findsOneWidget);

      // Pop the sub-route
      nav.pop();
      await tester.pumpAndSettle();

      // Config window should NOT have been closed!
      expect(closeWindowCalled, isFalse);
    });

    test('isConfigSubWindow flag prevents resizeWithForegroundSize and restore methods', () async {
      isConfigSubWindow = true;
      try {
        // Should return immediately without any exceptions or window modifications
        resizeWithForegroundSize();
        await restoreLyricWindowSizeAndPosition();
        await restoreLyricWindowSizeAndPositionIfNeeded();
      } finally {
        isConfigSubWindow = false;
      }
    });
  });
}

