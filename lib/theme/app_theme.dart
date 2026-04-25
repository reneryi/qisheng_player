import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/theme/app_component_themes.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build({
    required ColorScheme colorScheme,
    String? fontFamily,
    UiEffectsLevel effectsLevel = UiEffectsLevel.balanced,
    UiVisualStyleMode visualStyleMode = UiVisualStyleMode.glass,
  }) {
    GoogleFonts.config.allowRuntimeFetching = false;
    final surfaces = _surfaceTokens(colorScheme, effectsLevel, visualStyleMode);
    final chrome = _chromeTokens(colorScheme, effectsLevel, visualStyleMode);
    final accents = _accentTokens(colorScheme, visualStyleMode);
    final visuals = _visualTokens(visualStyleMode);
    final motion = _motionTokens();
    final player = _playerTokens(visualStyleMode);

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: colorScheme.surface,
      cardColor: surfaces.surfaceRaised,
      splashFactory: InkRipple.splashFactory,
      fontFamily: fontFamily,
      fontFamilyFallback: const [
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'SimSun',
        'SimHei',
        'Segoe UI Emoji',
      ],
    );
    TextTheme textTheme = baseTheme.textTheme;
    TextTheme primaryTextTheme = baseTheme.primaryTextTheme;
    if (fontFamily == null && _hasWidgetsBinding()) {
      textTheme = GoogleFonts.notoSansScTextTheme(baseTheme.textTheme);
      primaryTextTheme =
          GoogleFonts.notoSansScTextTheme(baseTheme.primaryTextTheme);
    }
    textTheme = _refineTextTheme(textTheme, colorScheme);
    primaryTextTheme = _refineTextTheme(primaryTextTheme, colorScheme);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      dividerColor: colorScheme.outline.withValues(
        alpha: visualStyleMode == UiVisualStyleMode.contrast ? 0.44 : 0.22,
      ),
      dialogTheme: AppComponentThemes.dialogTheme(surfaces),
      filledButtonTheme: AppComponentThemes.filledButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      textButtonTheme: AppComponentThemes.textButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      outlinedButtonTheme: AppComponentThemes.outlinedButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      elevatedButtonTheme: AppComponentThemes.elevatedButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      iconButtonTheme: AppComponentThemes.iconButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      inputDecorationTheme: AppComponentThemes.inputDecorationTheme(
        colorScheme,
        surfaces,
      ),
      menuTheme: AppComponentThemes.menuTheme(surfaces),
      segmentedButtonTheme: AppComponentThemes.segmentedButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      tabBarTheme: AppComponentThemes.tabBarTheme(colorScheme, accents),
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        activeTrackColor: accents.progressActive,
        inactiveTrackColor: accents.progressInactive,
        overlayColor: accents.progressActive.withValues(alpha: 0.12),
        thumbColor: accents.progressActive,
      ),
      extensions: [chrome, surfaces, accents, visuals, motion, player],
    );
  }

  static TextTheme _refineTextTheme(TextTheme textTheme, ColorScheme scheme) {
    return textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.04,
        letterSpacing: -0.6,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.06,
        letterSpacing: -0.4,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.08,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.82),
        fontWeight: FontWeight.w400,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w400,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ColorScheme applyChromeSurfaces(
    ColorScheme scheme, {
    UiVisualStyleMode visualStyleMode = UiVisualStyleMode.glass,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final (
      onSurface,
      surface,
      surfaceLow,
      surfaceContainer,
      surfaceHigh,
      outline,
      outlineVariant,
      shadow,
      scrim
    ) = switch (visualStyleMode) {
      UiVisualStyleMode.glass => (
          isDark ? const Color(0xFFEAF1FF) : const Color(0xFF111827),
          isDark ? const Color(0xFF0D1828) : const Color(0xFFF5F7FC),
          isDark ? const Color(0xFF101D2E) : const Color(0xFFF8FAFF),
          isDark ? const Color(0xFF122034) : const Color(0xFFFDFEFF),
          isDark ? const Color(0xFF16263D) : const Color(0xFFFFFFFF),
          isDark ? const Color(0xFF2B3E59) : const Color(0xFFD7DCE8),
          isDark ? const Color(0xFF243349) : const Color(0xFFE7EBF4),
          Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
          Colors.black.withValues(alpha: isDark ? 0.56 : 0.28),
        ),
      UiVisualStyleMode.contrast => (
          isDark ? const Color(0xFFF2F5FA) : const Color(0xFF0F172A),
          isDark ? const Color(0xFF0B1017) : const Color(0xFFF3F6FB),
          isDark ? const Color(0xFF111823) : const Color(0xFFF8FAFE),
          isDark ? const Color(0xFF151E2C) : const Color(0xFFFFFFFF),
          isDark ? const Color(0xFF1B2738) : const Color(0xFFFFFFFF),
          isDark ? const Color(0xFF5B6A80) : const Color(0xFFB7C1D1),
          isDark ? const Color(0xFF3A465B) : const Color(0xFFD4DBE7),
          Colors.black.withValues(alpha: isDark ? 0.52 : 0.16),
          Colors.black.withValues(alpha: isDark ? 0.62 : 0.3),
        ),
    };

    return scheme.copyWith(
      surface: surface,
      onSurface: onSurface,
      surfaceTint: Colors.transparent,
      surfaceDim: surface,
      surfaceBright: surfaceHigh,
      surfaceContainerLowest: surfaceLow,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      secondaryContainer: surfaceContainer,
      onSecondaryContainer: onSurface,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: shadow,
      scrim: scrim,
    );
  }

  static AppChromeTokens _chromeTokens(
    ColorScheme scheme,
    UiEffectsLevel effectsLevel,
    UiVisualStyleMode visualStyleMode,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final backdropSigma = switch (effectsLevel) {
      UiEffectsLevel.performance => 16.0,
      UiEffectsLevel.balanced => 25.0,
      UiEffectsLevel.visual => 30.0,
    };
    final (windowBgTop, windowBgBottom, windowScrim) =
        switch (visualStyleMode) {
      UiVisualStyleMode.glass => (
          isDark ? const Color(0xFF07111F) : const Color(0xFFF4F7FD),
          isDark ? const Color(0xFF02060D) : const Color(0xFFECEFF7),
          isDark
              ? const Color(0xFF0A1526).withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.56),
        ),
      UiVisualStyleMode.contrast => (
          isDark ? const Color(0xFF050A10) : const Color(0xFFEFF3F9),
          isDark ? const Color(0xFF020407) : const Color(0xFFE7ECF4),
          isDark
              ? const Color(0xFF0A0F18).withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.68),
        ),
    };

    return AppChromeTokens(
      windowBgTop: windowBgTop,
      windowBgBottom: windowBgBottom,
      windowScrim: windowScrim,
      titleBarSurface: scheme.surfaceContainerHigh,
      titleBarStroke: scheme.outlineVariant,
      sideNavSurface: scheme.surfaceContainer,
      pagePanelSurface: scheme.surfaceContainer,
      dockSurface: scheme.surfaceContainerHigh,
      sideNavExpandedWidth: 240,
      sideNavCollapsedWidth: 80,
      titleBarHeight: 56,
      dockHeight: 82,
      shellGap: 20,
      shellContentMaxWidth: 1680,
      backdropBlurSigma: backdropSigma,
      searchBarExpandedWidthLarge: 336,
      searchBarExpandedWidthMedium: 272,
    );
  }

  static AppSurfaceTokens _surfaceTokens(
    ColorScheme scheme,
    UiEffectsLevel effectsLevel,
    UiVisualStyleMode visualStyleMode,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final (glassSigma, shadowDepthScale, backdropStrategy) =
        _resolveSurfaceEffects(effectsLevel);

    return switch (visualStyleMode) {
      // 克制玻璃风格：轻表面、柔和描边、低强度阴影。
      UiVisualStyleMode.glass => AppSurfaceTokens(
          radiusSm: 14,
          radiusMd: 18,
          radiusLg: 24,
          radiusXl: 28,
          radiusXxl: 32,
          surfaceBase: scheme.surface,
          surfaceRaised: scheme.surfaceContainer,
          surfaceFloating: scheme.surfaceContainerHigh,
          surfaceInset: scheme.surfaceContainerLow,
          strokeSubtle:
              scheme.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.9),
          strokeStrong: scheme.outline.withValues(alpha: isDark ? 0.9 : 1),
          highlightColor: isDark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.white.withValues(alpha: 0.96),
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.34 : 0.12),
          innerShadowLight: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.8),
          innerShadowDark: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
          shadowBlurSm: 24,
          shadowBlurLg: 42,
          shadowOffsetSm: 4,
          shadowOffsetLg: 10,
          panelAlpha: isDark ? 0.94 : 0.98,
          glassAlpha: isDark ? 0.58 : 0.72,
          glassSigma: glassSigma,
          shadowDepthScale: shadowDepthScale,
          effectsLevel: effectsLevel,
          backdropStrategy: backdropStrategy,
          pressedDepth: 2,
        ),
      UiVisualStyleMode.contrast => AppSurfaceTokens(
          radiusSm: 12,
          radiusMd: 16,
          radiusLg: 20,
          radiusXl: 24,
          radiusXxl: 28,
          surfaceBase: scheme.surface,
          surfaceRaised: scheme.surfaceContainer,
          surfaceFloating: scheme.surfaceContainerHigh,
          surfaceInset: scheme.surfaceContainerLow,
          strokeSubtle: scheme.outlineVariant.withValues(alpha: 0.92),
          strokeStrong: scheme.outline.withValues(alpha: 1.0),
          highlightColor: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.75),
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
          innerShadowLight: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.white.withValues(alpha: 0.68),
          innerShadowDark: Colors.black.withValues(alpha: isDark ? 0.34 : 0.12),
          shadowBlurSm: 18,
          shadowBlurLg: 30,
          shadowOffsetSm: 4,
          shadowOffsetLg: 8,
          panelAlpha: isDark ? 0.98 : 1.0,
          glassAlpha: isDark ? 0.92 : 0.96,
          glassSigma: glassSigma * 0.72,
          shadowDepthScale: shadowDepthScale * 0.9,
          effectsLevel: effectsLevel,
          backdropStrategy: backdropStrategy == AppBackdropStrategy.forceBlur
              ? AppBackdropStrategy.adaptive
              : backdropStrategy,
          pressedDepth: 1.2,
        ),
    };
  }

  static (double, double, AppBackdropStrategy) _resolveSurfaceEffects(
    UiEffectsLevel effectsLevel,
  ) {
    return switch (effectsLevel) {
      UiEffectsLevel.performance => (16.0, 0.72, AppBackdropStrategy.solid),
      UiEffectsLevel.balanced => (30.0, 1.0, AppBackdropStrategy.adaptive),
      UiEffectsLevel.visual => (36.0, 1.2, AppBackdropStrategy.forceBlur),
    };
  }

  static AppAccentTokens _accentTokens(
    ColorScheme scheme,
    UiVisualStyleMode visualStyleMode,
  ) {
    final accent = scheme.primary;
    return switch (visualStyleMode) {
      UiVisualStyleMode.glass => AppAccentTokens(
          accent: accent,
          onAccent: scheme.onPrimary,
          accentSoft: accent.withValues(alpha: 0.18),
          accentContainer:
              Color.lerp(accent, scheme.surfaceContainerHigh, 0.28)!,
          accentGlow: accent.withValues(alpha: 0.28),
          accentFocusRing: accent.withValues(alpha: 0.44),
          progressActive: accent,
          progressInactive: accent.withValues(alpha: 0.18),
          selectionTint: accent.withValues(alpha: 0.14),
          hoverTint: scheme.onSurface.withValues(alpha: 0.08),
        ),
      UiVisualStyleMode.contrast => AppAccentTokens(
          accent: accent,
          onAccent: scheme.onPrimary,
          accentSoft: accent.withValues(alpha: 0.22),
          accentContainer: Color.lerp(accent, scheme.surfaceContainer, 0.18)!,
          accentGlow: accent.withValues(alpha: 0.24),
          accentFocusRing: accent.withValues(alpha: 0.56),
          progressActive: accent,
          progressInactive: accent.withValues(alpha: 0.24),
          selectionTint: accent.withValues(alpha: 0.2),
          hoverTint: scheme.onSurface.withValues(alpha: 0.1),
        ),
    };
  }

  static AppVisualTokens _visualTokens(UiVisualStyleMode visualStyleMode) {
    return switch (visualStyleMode) {
      UiVisualStyleMode.glass => const AppVisualTokens(
          styleMode: UiVisualStyleMode.glass,
          buttonGlowBlur: 20,
          buttonGlowSpread: 0.6,
          buttonGlowOpacity: 0.22,
          buttonHoverGlowScale: 1.36,
          buttonPressedGlowScale: 0.52,
          buttonPressOffset: 1.5,
          buttonFocusRingOpacity: 0.86,
          contentHeaderGap: 14,
        ),
      UiVisualStyleMode.contrast => const AppVisualTokens(
          styleMode: UiVisualStyleMode.contrast,
          buttonGlowBlur: 16,
          buttonGlowSpread: 0.36,
          buttonGlowOpacity: 0.18,
          buttonHoverGlowScale: 1.22,
          buttonPressedGlowScale: 0.56,
          buttonPressOffset: 1.0,
          buttonFocusRingOpacity: 1.0,
          contentHeaderGap: 12,
        ),
    };
  }

  static AppMotionTokens _motionTokens() {
    return const AppMotionTokens(
      fast: Cubic(0.16, 1, 0.3, 1),
      normal: Cubic(0.22, 1, 0.36, 1),
      slow: Cubic(0.2, 0.9, 0.2, 1),
      emphasized: Cubic(0.2, 0.8, 0.2, 1),
      standard: Cubic(0.2, 0, 0, 1),
      microInteractionDuration: Duration(milliseconds: 140),
      controlTransitionDuration: Duration(milliseconds: 220),
      pageTransitionDuration: Duration(milliseconds: 360),
      pageReverseTransitionDuration: Duration(milliseconds: 260),
      lyricScrollDuration: Duration(milliseconds: 420),
      listTransitionDuration: Duration(milliseconds: 220),
      navCollapseDuration: Duration(milliseconds: 280),
      searchExpandDuration: Duration(milliseconds: 220),
      panelTransitionDuration: Duration(milliseconds: 260),
    );
  }

  static PlayerTokens _playerTokens(UiVisualStyleMode visualStyleMode) {
    return switch (visualStyleMode) {
      UiVisualStyleMode.glass => const PlayerTokens(
          coverRadius: 18,
          coverGlowBlur: 28,
          coverGlowOpacity: 0.24,
          controlClusterRadius: 28,
          lyricPanelOpacity: 0.84,
          queuePanelOpacity: 0.82,
          immersiveBackdropSigma: 36,
          studioPanelGap: 24,
          modeSwitchDuration: Duration(milliseconds: 320),
        ),
      UiVisualStyleMode.contrast => const PlayerTokens(
          coverRadius: 18,
          coverGlowBlur: 22,
          coverGlowOpacity: 0.18,
          controlClusterRadius: 26,
          lyricPanelOpacity: 0.9,
          queuePanelOpacity: 0.9,
          immersiveBackdropSigma: 32,
          studioPanelGap: 22,
          modeSwitchDuration: Duration(milliseconds: 320),
        ),
    };
  }

  static bool _hasWidgetsBinding() {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }
}
