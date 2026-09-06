import 'package:qisheng_player/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy visual style values migrate to solidCard or fallback gracefully', () {
    expect(
      AppSettings.parseUiVisualStyleMode('solidCard'),
      UiVisualStyleMode.solidCard,
    );
    expect(
      AppSettings.parseUiVisualStyleMode('borderless'),
      UiVisualStyleMode.borderless,
    );
    expect(
      AppSettings.parseUiVisualStyleMode('liquidGlass'),
      UiVisualStyleMode.liquidGlass,
    );
    expect(
      AppSettings.parseUiVisualStyleMode('glass'),
      UiVisualStyleMode.liquidGlass, // 旧 glass 自动迁移为 liquidGlass
    );
    expect(
      AppSettings.parseUiVisualStyleMode(null),
      UiVisualStyleMode.borderless,
    );
    expect(
      AppSettings.parseUiVisualStyleMode('unknown'),
      UiVisualStyleMode.borderless,
    );
  });

  test('UI visual style mode values completeness', () {
    expect(
      UiVisualStyleMode.values,
      const [
        UiVisualStyleMode.solidCard,
        UiVisualStyleMode.borderless,
        UiVisualStyleMode.liquidGlass,
      ],
    );
  });

  test('Window backdrop mode values completeness', () {
    expect(
      WindowBackdropMode.values,
      const [
        WindowBackdropMode.defaultGradient,
        WindowBackdropMode.micaAlt,
        WindowBackdropMode.acrylic,
        WindowBackdropMode.meshFlow,
        WindowBackdropMode.waterRipple,
        WindowBackdropMode.prismaticGlass,
      ],
    );
  });
}
