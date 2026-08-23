import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/window_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WindowBackdropModeResult parses platform payload', () {
    final result = WindowBackdropModeResult.fromMap(
      const {
        'requestedMode': 'acrylic',
        'appliedMode': 'micaalt',
        'nativeBackdropSupported': true,
        'nativeApplySucceeded': false,
        'fallbackReason': 'native_backdrop_not_supported',
      },
      WindowBackdropMode.acrylic,
    );

    expect(result.requestedMode, WindowBackdropMode.acrylic);
    expect(result.appliedMode, WindowBackdropMode.micaAlt);
    expect(result.nativeBackdropSupported, isTrue);
    expect(result.nativeApplySucceeded, isFalse);
    expect(result.fallbackReason, 'native_backdrop_not_supported');
    expect(result.usesSimulatedBackdropOnly, isTrue);
    expect(result.effectiveRenderMode, WindowBackdropMode.defaultGradient);
  });

  test('WindowBackdropModeResult parses confirmed micaAlt payload', () {
    final result = WindowBackdropModeResult.fromMap(
      const {
        'requestedMode': 'micaalt',
        'appliedMode': 'micaalt',
        'nativeBackdropSupported': true,
        'nativeApplySucceeded': true,
        'fallbackReason': '',
      },
      WindowBackdropMode.micaAlt,
    );

    expect(result.requestedMode, WindowBackdropMode.micaAlt);
    expect(result.appliedMode, WindowBackdropMode.micaAlt);
    expect(result.nativeApplySucceeded, isTrue);
    expect(result.usesSimulatedBackdropOnly, isFalse);
    expect(result.effectiveRenderMode, WindowBackdropMode.micaAlt);
  });

  test('WindowBackdropModeResult parses confirmed acrylic payload', () {
    final result = WindowBackdropModeResult.fromMap(
      const {
        'requestedMode': 'acrylic',
        'appliedMode': 'acrylic',
        'nativeBackdropSupported': true,
        'nativeApplySucceeded': true,
        'fallbackReason': '',
      },
      WindowBackdropMode.acrylic,
    );

    expect(result.requestedMode, WindowBackdropMode.acrylic);
    expect(result.appliedMode, WindowBackdropMode.acrylic);
    expect(result.nativeApplySucceeded, isTrue);
    expect(result.usesSimulatedBackdropOnly, isFalse);
    expect(result.effectiveRenderMode, WindowBackdropMode.acrylic);
  });

  test('WindowBackdropModeResult fallback keeps requested mode', () {
    final result = WindowBackdropModeResult.fallback(
      WindowBackdropMode.micaAlt,
      appliedMode: WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: false,
      fallbackReason: 'platform_exception',
    );

    expect(result.requestedMode, WindowBackdropMode.micaAlt);
    expect(result.appliedMode, WindowBackdropMode.defaultGradient);
    expect(result.nativeBackdropSupported, isFalse);
    expect(result.nativeApplySucceeded, isFalse);
    expect(result.fallbackReason, 'platform_exception');
    expect(result.effectiveRenderMode, WindowBackdropMode.defaultGradient);
  });

  test('effective render mode only trusts confirmed native results', () {
    const nativeMicaAlt = WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.micaAlt,
      appliedMode: WindowBackdropMode.micaAlt,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );
    const softwareMeshFlow = WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.meshFlow,
      appliedMode: WindowBackdropMode.meshFlow,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );

    expect(nativeMicaAlt.effectiveRenderMode, WindowBackdropMode.micaAlt);
    expect(softwareMeshFlow.effectiveRenderMode, WindowBackdropMode.meshFlow);
  });

  test('native parameter protocol sends canonical lowercase modes', () async {
    const channel = MethodChannel('qisheng_player/window_controls');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final capturedModes = <String>[];

    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'set_window_backdrop_mode');
      capturedModes.add((call.arguments as Map)['mode'] as String);
      return <Object?, Object?>{
        'requestedMode': capturedModes.last,
        'appliedMode': capturedModes.last,
        'nativeBackdropSupported': true,
        'nativeApplySucceeded': true,
        'fallbackReason': '',
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await WindowControls.setWindowBackdropMode(WindowBackdropMode.micaAlt);
    await WindowControls.setWindowBackdropMode(WindowBackdropMode.acrylic);
    // 软件渲染材质应通知原生层关闭 DWM 材质
    await WindowControls.setWindowBackdropMode(WindowBackdropMode.defaultGradient);
    await WindowControls.setWindowBackdropMode(WindowBackdropMode.meshFlow);

    expect(
      capturedModes,
      ['micaalt', 'acrylic', 'none', 'none'],
    );
  });

  test('fallback reason for Windows 11 21H2 maps to readable label', () {
    const result = WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.acrylic,
      appliedMode: WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: false,
      nativeApplySucceeded: false,
      fallbackReason: 'system_backdrop_requires_win11_22h2',
    );
    expect(result.fallbackReason, 'system_backdrop_requires_win11_22h2');
    expect(result.effectiveRenderMode, WindowBackdropMode.defaultGradient);
  });
}
