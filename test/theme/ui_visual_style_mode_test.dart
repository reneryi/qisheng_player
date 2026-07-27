import 'package:qisheng_player/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy visual style values migrate to glass', () {
    expect(
        AppSettings.parseUiVisualStyleMode('glass'), UiVisualStyleMode.glass);
    expect(AppSettings.parseUiVisualStyleMode('contrast'),
        UiVisualStyleMode.glass);
    expect(AppSettings.parseUiVisualStyleMode('sharpCard'),
        UiVisualStyleMode.glass);
    expect(AppSettings.parseUiVisualStyleMode(null), UiVisualStyleMode.glass);
    expect(
        AppSettings.parseUiVisualStyleMode('unknown'), UiVisualStyleMode.glass);
  });

  test('glass is the only visual style', () {
    expect(UiVisualStyleMode.values, const [UiVisualStyleMode.glass]);
  });

  test('legacy backdrop values migrate to auto', () {
    expect(
      WindowBackdropMode.fromName('micaAlt'),
      WindowBackdropMode.auto,
    );
    expect(
      WindowBackdropMode.fromName('acrylic'),
      WindowBackdropMode.auto,
    );
    expect(
      WindowBackdropMode.values,
      const [
        WindowBackdropMode.auto,
        WindowBackdropMode.mica,
        WindowBackdropMode.fluid,
        WindowBackdropMode.none,
      ],
    );
  });
}
