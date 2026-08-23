import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _buildTheme(
  UiEffectsLevel level, {
  UiVisualStyleMode visualStyleMode = UiVisualStyleMode.liquidGlass,
  WindowBackdropMode windowBackdropMode = WindowBackdropMode.micaAlt,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(
      base,
      visualStyleMode: visualStyleMode,
    ),
    effectsLevel: level,
    visualStyleMode: visualStyleMode,
    windowBackdropMode: windowBackdropMode,
  );
}

void main() {
  test('balanced effects profile uses adaptive blur defaults', () {
    final surfaces =
        _buildTheme(UiEffectsLevel.balanced).extension<AppSurfaceTokens>()!;
    expect(surfaces.glassSigma, 20.0 * 0.88);
    expect(surfaces.shadowDepthScale, 0.86 * 0.9);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.adaptive);
  });

  test('visual effects profile increases blur and depth', () {
    final surfaces =
        _buildTheme(UiEffectsLevel.visual).extension<AppSurfaceTokens>()!;
    expect(surfaces.glassSigma, 36.0 * 0.88);
    expect(surfaces.shadowDepthScale, 1.2 * 0.9);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.forceBlur);
  });

  test('performance profile disables glass backdrop blur', () {
    final surfaces =
        _buildTheme(UiEffectsLevel.performance).extension<AppSurfaceTokens>()!;
    expect(surfaces.glassSigma, 16.0 * 0.88);
    expect(surfaces.shadowDepthScale, 0.72 * 0.9);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.solid);
  });

  test('disabled backdrop uses opaque-friendly surfaces without blur', () {
    final micaTheme = _buildTheme(
      UiEffectsLevel.balanced,
      windowBackdropMode: WindowBackdropMode.micaAlt,
    );
    final defaultTheme = _buildTheme(
      UiEffectsLevel.balanced,
      windowBackdropMode: WindowBackdropMode.defaultGradient,
    );
    final micaSurfaces = micaTheme.extension<AppSurfaceTokens>()!;
    final defaultSurfaces = defaultTheme.extension<AppSurfaceTokens>()!;
    final micaChrome = micaTheme.extension<AppChromeTokens>()!;
    final defaultChrome = defaultTheme.extension<AppChromeTokens>()!;

    expect(micaSurfaces.glassSigma, greaterThan(defaultSurfaces.glassSigma));
    expect(defaultSurfaces.backdropStrategy, AppBackdropStrategy.solid);
    expect(
      micaChrome.backdropBlurSigma,
      greaterThan(defaultChrome.backdropBlurSigma),
    );
  });

  test('tooltip text uses the global 14 pixel size', () {
    final theme = _buildTheme(UiEffectsLevel.balanced);
    expect(theme.tooltipTheme.textStyle?.fontSize, 14);
  });

  test('surface colors follow the active seed color', () {
    ColorScheme themed(Color seed) => AppTheme.applyChromeSurfaces(
          ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        );

    final red = themed(const Color(0xFFE05252));
    final blue = themed(const Color(0xFF528CE0));
    expect(red.surfaceContainerHigh, isNot(blue.surfaceContainerHigh));
    expect(red.surfaceContainer, isNot(blue.surfaceContainer));
  });
}
