import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveRegisterModeName returns none when input is focused', () {
    expect(
      HotkeysHelper.resolveRegisterModeName(
        windowFocused: true,
        inputFocused: true,
      ),
      'none',
    );
  });

  test('resolveRegisterModeName returns foreground when focused without input',
      () {
    expect(
      HotkeysHelper.resolveRegisterModeName(
        windowFocused: true,
        inputFocused: false,
      ),
      'foreground',
    );
  });

  test('resolveRegisterModeName returns background when window is blurred', () {
    expect(
      HotkeysHelper.resolveRegisterModeName(
        windowFocused: false,
        inputFocused: false,
      ),
      'background',
    );
  });

  test('goForward has a default mouse forward binding', () {
    final binding = HotkeysHelper.getDefaultBinding(HotkeyAction.goForward);

    expect(binding.keyId, PhysicalKeyboardKey.browserForward.usbHidUsage);
    expect(binding.modifiers, isEmpty);
  });
}
