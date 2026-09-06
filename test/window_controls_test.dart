import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WindowBackdropModeResult parses platform payload', () {
    final result = WindowBackdropModeResult.fromMap(
      const {
        'requestedMode': 'meshFlow',
        'appliedMode': 'meshFlow',
        'nativeBackdropSupported': true,
        'nativeApplySucceeded': false,
        'fallbackReason': 'fallback',
      },
      WindowBackdropMode.defaultGradient,
    );

    expect(result.requestedMode, WindowBackdropMode.meshFlow);
    expect(result.appliedMode, WindowBackdropMode.meshFlow);
    expect(result.nativeBackdropSupported, isTrue);
    expect(result.nativeApplySucceeded, isFalse);
    expect(result.fallbackReason, 'fallback');
    expect(result.usesSimulatedBackdropOnly, isTrue);
  });

  test('WindowBackdropModeResult fallback keeps requested mode', () {
    final result = WindowBackdropModeResult.fallback(
      WindowBackdropMode.meshFlow,
      appliedMode: WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: false,
      fallbackReason: 'platform_exception',
    );

    expect(result.requestedMode, WindowBackdropMode.meshFlow);
    expect(result.appliedMode, WindowBackdropMode.defaultGradient);
    expect(result.nativeBackdropSupported, isFalse);
    expect(result.nativeApplySucceeded, isFalse);
    expect(result.fallbackReason, 'platform_exception');
  });

  test('WindowLayoutMode and shellGap update appropriately', () {
    WindowControls.layoutMode.value = WindowLayoutMode.normal;
    expect(WindowControls.shellGap, 10.0);

    WindowControls.layoutMode.value = WindowLayoutMode.maximized;
    expect(WindowControls.shellGap, 20.0);

    WindowControls.layoutMode.value = WindowLayoutMode.fullscreen;
    expect(WindowControls.shellGap, 10.0);
  });

  testWidgets('WindowControlls updates button state when WindowControls.layoutMode changes', (tester) async {
    WindowControls.layoutMode.value = WindowLayoutMode.normal;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: WindowControlls(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In normal mode: maximize button tooltip is '最大化'
    expect(find.byTooltip('最大化'), findsOneWidget);
    expect(find.byTooltip('还原'), findsNothing);
    expect(find.byTooltip('全屏'), findsOneWidget);

    // Switch to maximized mode via WindowControls.layoutMode notifier
    WindowControls.layoutMode.value = WindowLayoutMode.maximized;
    await tester.pumpAndSettle();

    // In maximized mode: maximize button tooltip is '还原'
    expect(find.byTooltip('还原'), findsOneWidget);
    expect(find.byTooltip('最大化'), findsNothing);

    // Switch to fullscreen mode
    WindowControls.layoutMode.value = WindowLayoutMode.fullscreen;
    await tester.pumpAndSettle();

    // In fullscreen mode: tooltip is '退出全屏' and '全屏模式下不可用'
    expect(find.byTooltip('退出全屏'), findsOneWidget);
    expect(find.byTooltip('全屏模式下不可用'), findsOneWidget);

    // Reset back to normal
    WindowControls.layoutMode.value = WindowLayoutMode.normal;
    await tester.pumpAndSettle();
    expect(find.byTooltip('最大化'), findsOneWidget);
  });

  testWidgets('WindowControls native channel calls handle layout and buttons', (tester) async {
    final List<MethodCall> calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      (MethodCall methodCall) async {
        calls.add(methodCall);
        switch (methodCall.method) {
          case 'get_window_layout_mode':
            return 'maximized';
          case 'is_maximized':
            return true;
          case 'is_fullscreen':
            return false;
          case 'is_minimized':
            return false;
          case 'toggle_maximize':
            return true;
          case 'toggle_fullscreen':
            return false;
          case 'minimize':
            return null;
          case 'set_maximize_button_rect':
            return null;
          default:
            return null;
        }
      },
    );

    // Test maximize rect call
    await WindowControls.setMaximizeButtonRect(
      left: 100,
      top: 50,
      width: 46,
      height: 32,
      devicePixelRatio: 1.5,
    );
    expect(calls.any((c) => c.method == 'set_maximize_button_rect'), isTrue);

    // Test minimize call
    await WindowControls.minimize();
    expect(calls.any((c) => c.method == 'minimize'), isTrue);

    // Test syncWindowLayoutMode
    await WindowControls.syncWindowLayoutMode();
    expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      null,
    );
  });

  testWidgets('WindowControlls resets maximize button rect on disposal', (tester) async {
    final List<MethodCall> rectCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'set_maximize_button_rect') {
          rectCalls.add(methodCall);
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: WindowControlls(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pump a different widget to trigger dispose
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify reset call was sent with width: 0, height: 0
    final lastCall = rectCalls.lastOrNull;
    expect(lastCall, isNotNull);
    final args = lastCall!.arguments as Map?;
    expect(args?['width'], 0.0);
    expect(args?['height'], 0.0);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      null,
    );
  });

  testWidgets('WindowControls full action suite invokes expected native methods', (tester) async {
    final List<String> methods = [];
    final Map<String, dynamic> lastArgs = {};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      (MethodCall methodCall) async {
        methods.add(methodCall.method);
        if (methodCall.arguments != null) {
          lastArgs[methodCall.method] = methodCall.arguments;
        }
        switch (methodCall.method) {
          case 'is_maximized':
            return true;
          case 'is_fullscreen':
            return false;
          case 'is_minimized':
            return false;
          case 'get_window_layout_mode':
            return 'normal';
          default:
            return null;
        }
      },
    );

    expect(await WindowControls.isMaximized(), isTrue);
    expect(await WindowControls.isFullScreen(), isFalse);
    expect(await WindowControls.isMinimized(), isFalse);

    await WindowControls.maximize();
    expect(methods.contains('maximize'), isTrue);

    await WindowControls.unmaximize();
    expect(methods.contains('unmaximize'), isTrue);

    await WindowControls.toggleFullscreen();
    expect(methods.contains('toggle_fullscreen'), isTrue);

    await WindowControls.setFullScreen(true);
    expect(methods.contains('set_fullscreen'), isTrue);
    expect((lastArgs['set_fullscreen'] as Map)['isFullScreen'], isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      null,
    );
  });
}
