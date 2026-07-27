import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WindowBackdropModeResult parses platform payload', () {
    final result = WindowBackdropModeResult.fromMap(
      const {
        'requestedMode': 'acrylic',
        'appliedMode': 'mica',
        'nativeBackdropSupported': true,
        'nativeApplySucceeded': false,
        'fallbackReason': 'acrylic_requires_windows_11_22h2',
      },
      WindowBackdropMode.auto,
    );

    expect(result.requestedMode, WindowBackdropMode.auto);
    expect(result.appliedMode, WindowBackdropMode.mica);
    expect(result.nativeBackdropSupported, isTrue);
    expect(result.nativeApplySucceeded, isFalse);
    expect(result.fallbackReason, 'acrylic_requires_windows_11_22h2');
    expect(result.usesSimulatedBackdropOnly, isTrue);
  });

  test('WindowBackdropModeResult fallback keeps requested mode', () {
    final result = WindowBackdropModeResult.fallback(
      WindowBackdropMode.mica,
      appliedMode: WindowBackdropMode.none,
      nativeBackdropSupported: false,
      fallbackReason: 'platform_exception',
    );

    expect(result.requestedMode, WindowBackdropMode.mica);
    expect(result.appliedMode, WindowBackdropMode.none);
    expect(result.nativeBackdropSupported, isFalse);
    expect(result.nativeApplySucceeded, isFalse);
    expect(result.fallbackReason, 'platform_exception');
  });
}
