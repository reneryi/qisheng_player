import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _buildTheme(
  UiEffectsLevel level, {
  WindowBackdropMode windowBackdropMode = WindowBackdropMode.auto,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(base),
    effectsLevel: level,
    windowBackdropMode: windowBackdropMode,
  );
}

void main() {
  test('balanced effects profile uses adaptive blur defaults', () {
    final surfaces =
        _buildTheme(UiEffectsLevel.balanced).extension<AppSurfaceTokens>()!;
    expect(surfaces.glassSigma, 20.0);
    expect(surfaces.shadowDepthScale, 0.86);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.adaptive);
  });

  test('visual effects profile increases blur and depth', () {
    final surfaces =
        _buildTheme(UiEffectsLevel.visual).extension<AppSurfaceTokens>()!;
    expect(surfaces.glassSigma, 36.0);
    expect(surfaces.shadowDepthScale, 1.2);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.forceBlur);
  });

  test('performance profile disables glass backdrop blur', () {
    final surfaces =
        _buildTheme(UiEffectsLevel.performance).extension<AppSurfaceTokens>()!;
    expect(surfaces.glassSigma, 16.0);
    expect(surfaces.shadowDepthScale, 0.72);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.solid);
  });

  test('mica has stronger glass effects than disabled backdrop', () {
    final micaTheme = _buildTheme(
      UiEffectsLevel.balanced,
      windowBackdropMode: WindowBackdropMode.mica,
    );
    final noneTheme = _buildTheme(
      UiEffectsLevel.balanced,
      windowBackdropMode: WindowBackdropMode.none,
    );
    final micaSurfaces = micaTheme.extension<AppSurfaceTokens>()!;
    final noneSurfaces = noneTheme.extension<AppSurfaceTokens>()!;
    final micaChrome = micaTheme.extension<AppChromeTokens>()!;
    final noneChrome = noneTheme.extension<AppChromeTokens>()!;

    expect(micaSurfaces.glassSigma, greaterThan(noneSurfaces.glassSigma));
    expect(micaSurfaces.glassAlpha, greaterThan(noneSurfaces.glassAlpha));
    expect(
      micaChrome.backdropBlurSigma,
      greaterThan(noneChrome.backdropBlurSigma),
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
