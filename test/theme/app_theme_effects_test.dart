import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/theme/app_theme.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _buildTheme(
  UiEffectsLevel level, {
  UiVisualStyleMode visualStyleMode = UiVisualStyleMode.glass,
}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(
      baseScheme,
      visualStyleMode: visualStyleMode,
    ),
    effectsLevel: level,
    visualStyleMode: visualStyleMode,
  );
}

void main() {
  test('balanced effects profile uses adaptive blur defaults', () {
    final theme = _buildTheme(UiEffectsLevel.balanced);
    final surfaces = theme.extension<AppSurfaceTokens>();

    expect(surfaces, isNotNull);
    expect(surfaces!.effectsLevel, UiEffectsLevel.balanced);
    // 现代简约：balanced 模式的 glassSigma 从 25 增到 30
    expect(surfaces.glassSigma, 30.0);
    expect(surfaces.shadowDepthScale, 1.0);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.adaptive);
  });

  test('visual effects profile increases blur and depth', () {
    final theme = _buildTheme(UiEffectsLevel.visual);
    final surfaces = theme.extension<AppSurfaceTokens>();

    expect(surfaces, isNotNull);
    expect(surfaces!.effectsLevel, UiEffectsLevel.visual);
    // 现代简约：visual 模式的 glassSigma 从 30 增到 36
    expect(surfaces.glassSigma, 36.0);
    expect(surfaces.shadowDepthScale, 1.2);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.forceBlur);
  });

  test('performance profile disables glass backdrop blur', () {
    final theme = _buildTheme(UiEffectsLevel.performance);
    final surfaces = theme.extension<AppSurfaceTokens>();

    expect(surfaces, isNotNull);
    expect(surfaces!.effectsLevel, UiEffectsLevel.performance);
    // 现代简约：performance 模式的 glassSigma 从 12 增到 16
    expect(surfaces.glassSigma, 16.0);
    expect(surfaces.shadowDepthScale, 0.72);
    expect(surfaces.backdropStrategy, AppBackdropStrategy.solid);
  });

  test('contrast visual mode exposes stronger contour tokens', () {
    final theme = _buildTheme(
      UiEffectsLevel.balanced,
      visualStyleMode: UiVisualStyleMode.contrast,
    );
    final surfaces = theme.extension<AppSurfaceTokens>();
    final visuals = theme.extension<AppVisualTokens>();

    expect(surfaces, isNotNull);
    expect(visuals, isNotNull);
    expect(visuals!.styleMode, UiVisualStyleMode.contrast);
    expect(visuals.buttonHoverGlowScale, greaterThan(1));
    expect(visuals.buttonPressedGlowScale, lessThan(1));
    expect(surfaces!.panelAlpha, greaterThanOrEqualTo(0.98));
    // 现代简约：contrast 模式的 radiusXxl 从 ≤24 调整为 ≤28
    expect(surfaces.radiusXxl, lessThanOrEqualTo(28));
  });
}
