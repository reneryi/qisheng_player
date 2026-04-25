import 'package:coriander_player/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseUiVisualStyleMode resolves known values', () {
    expect(
      AppSettings.parseUiVisualStyleMode('glass'),
      UiVisualStyleMode.glass,
    );
    expect(
      AppSettings.parseUiVisualStyleMode('contrast'),
      UiVisualStyleMode.contrast,
    );
  });

  test('parseUiVisualStyleMode falls back to glass for old settings', () {
    expect(
      AppSettings.parseUiVisualStyleMode(null),
      UiVisualStyleMode.glass,
    );
    expect(
      AppSettings.parseUiVisualStyleMode('unknown'),
      UiVisualStyleMode.glass,
    );
  });

  test('UiVisualStyleMode serializes by enum name', () {
    expect(UiVisualStyleMode.glass.name, 'glass');
    expect(UiVisualStyleMode.contrast.name, 'contrast');
  });
}
