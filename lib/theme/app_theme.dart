import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_component_themes.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build({
    required ColorScheme colorScheme,
    String? fontFamily,
    UiEffectsLevel effectsLevel = UiEffectsLevel.balanced,
    UiVisualStyleMode visualStyleMode = UiVisualStyleMode.glass,
    WindowBackdropMode windowBackdropMode = WindowBackdropMode.auto,
  }) {
    GoogleFonts.config.allowRuntimeFetching = false;
    final surfaces = _surfaceTokens(
      colorScheme,
      effectsLevel,
      visualStyleMode,
      windowBackdropMode,
    );
    final chrome = _chromeTokens(
      colorScheme,
      effectsLevel,
      visualStyleMode,
      windowBackdropMode,
    );
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
        'MiSans',
        'HarmonyOS Sans SC',
        'OPPO Sans',
        'Segoe UI Variable Text',
        'Segoe UI Variable Display',
        'Microsoft YaHei UI',
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
    textTheme = _refineTextTheme(textTheme, colorScheme, visualStyleMode);
    primaryTextTheme =
        _refineTextTheme(primaryTextTheme, colorScheme, visualStyleMode);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      dividerColor: colorScheme.outline.withValues(alpha: 0.22),
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
      listTileTheme: const ListTileThemeData(enableFeedback: false),
      menuTheme: AppComponentThemes.menuTheme(colorScheme, surfaces),
      // 注册全局菜单项按钮主题以应用全新的无边框、精致圆角及状态颜色高亮交互
      menuButtonTheme: AppComponentThemes.menuButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      popupMenuTheme: const PopupMenuThemeData(enableFeedback: false),
      segmentedButtonTheme: AppComponentThemes.segmentedButtonTheme(
        colorScheme,
        surfaces,
        accents,
        visuals,
      ),
      tabBarTheme: AppComponentThemes.tabBarTheme(colorScheme, accents),
      tooltipTheme: TooltipThemeData(
        enableFeedback: false,
        textStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
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

  static TextTheme _refineTextTheme(
    TextTheme textTheme,
    ColorScheme scheme,
    UiVisualStyleMode visualStyleMode,
  ) {
    return textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.04,
        letterSpacing: 0,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.06,
        letterSpacing: 0,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: 0,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
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
    final onSurface =
        isDark ? const Color(0xFFEAF8FF) : const Color(0xFF17121E);
    final surface = isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.12),
            const Color(0xFF07111F),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.045),
            const Color(0xFFF8F4FF),
          );
    final surfaceLow = isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.10),
            const Color(0xFF0A1829),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.055),
            const Color(0xFFFBF8FF),
          );
    final surfaceContainer = isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.18),
            const Color(0xFF0E2236),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.075),
            const Color(0xFFFFFCF6),
          );
    final surfaceHigh = isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.24),
            const Color(0xFF142D45),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.09),
            Colors.white,
          );
    final outline = isDark ? const Color(0xFF6B91AA) : const Color(0xFFB9BFD0);
    final outlineVariant =
        isDark ? const Color(0xFF2A5265) : const Color(0xFFE0E4F1);
    final shadow = Colors.black.withValues(alpha: isDark ? 0.38 : 0.1);
    final scrim = Colors.black.withValues(alpha: isDark ? 0.5 : 0.22);

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
    WindowBackdropMode windowBackdropMode,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final backdropSigma = switch (effectsLevel) {
      UiEffectsLevel.performance => 16.0,
      UiEffectsLevel.balanced => 18.0,
      UiEffectsLevel.visual => 30.0,
    };
    final windowBgTop =
        isDark ? const Color(0xFF061321) : const Color(0xFFF9F5FF);
    final windowBgBottom =
        isDark ? const Color(0xFF041B25) : const Color(0xFFFFF6DC);
    final windowScrim = isDark
        ? const Color(0xFF020813).withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.38);
    final (topTintAlpha, bottomTintAlpha, scrimFactor, backdropSigmaScale) =
        _resolveBackdropChromeProfile(windowBackdropMode);

    return AppChromeTokens(
      windowBgTop: Color.alphaBlend(
        scheme.primary.withValues(alpha: topTintAlpha),
        windowBgTop,
      ),
      windowBgBottom: Color.alphaBlend(
        scheme.primary.withValues(alpha: bottomTintAlpha),
        windowBgBottom,
      ),
      windowScrim: windowScrim.withValues(alpha: windowScrim.a * scrimFactor),
      titleBarSurface: scheme.surfaceContainerHigh,
      titleBarStroke: scheme.outlineVariant,
      sideNavSurface: isDark
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.12),
              const Color(0xFF0F1218),
            )
          : const Color(0xFFF4F4F5),
      pagePanelSurface: isDark
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.08),
              const Color(0xFF12151C),
            )
          : const Color(0xFFFFFFFF),
      dockSurface: scheme.surfaceContainerHigh,
      sideNavExpandedWidth: 160, // 稍微收窄左侧栏避免占比过大
      sideNavCollapsedWidth: 76,
      titleBarHeight: 56,
      dockHeight: 92,
      shellGap: 10,
      shellContentMaxWidth: 2400,
      backdropBlurSigma: backdropSigma * backdropSigmaScale,
      searchBarExpandedWidthLarge: 336,
      searchBarExpandedWidthMedium: 272,
    );
  }

  static AppSurfaceTokens _surfaceTokens(
    ColorScheme scheme,
    UiEffectsLevel effectsLevel,
    UiVisualStyleMode visualStyleMode,
    WindowBackdropMode windowBackdropMode,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final (glassSigma, shadowDepthScale, backdropStrategy) =
        _resolveSurfaceEffects(effectsLevel);
    final (
      panelAlphaDelta,
      glassAlphaDelta,
      sigmaScale,
      shadowScale,
      resolvedBackdropStrategy
    ) = _resolveBackdropSurfaceProfile(
      windowBackdropMode,
      backdropStrategy,
    );

    return switch (visualStyleMode) {
      // 鍏嬪埗鐜荤拑椋庢牸锛氳交琛ㄩ潰銆佹煍鍜屾弿杈广€佷綆寮哄害闃村奖銆?
      UiVisualStyleMode.glass => AppSurfaceTokens(
          radiusSm: 14,
          radiusMd: 18,
          radiusLg: 24,
          radiusXl: 30,
          radiusXxl: 34,
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
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
          innerShadowLight: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.8),
          innerShadowDark: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
          shadowBlurSm: 28,
          shadowBlurLg: 56,
          shadowOffsetSm: 4,
          shadowOffsetLg: 12,
          panelAlpha: (0.48 + panelAlphaDelta).clamp(0.24, 0.82),
          glassAlpha:
              ((isDark ? 0.34 : 0.36) + glassAlphaDelta).clamp(0.0, 0.72),
          glassSigma: glassSigma * sigmaScale,
          shadowDepthScale: shadowDepthScale * shadowScale,
          effectsLevel: effectsLevel,
          backdropStrategy: resolvedBackdropStrategy,
          pressedDepth: 2,
        ),
    };
  }

  static (double, double, double, double) _resolveBackdropChromeProfile(
    WindowBackdropMode mode,
  ) {
    return switch (mode) {
      WindowBackdropMode.none => (0.02, 0.01, 1.25, 0.0),
      WindowBackdropMode.fluid => (0.04, 0.03, 0.92, 1.0), // 流体背景沿用默认偏置
      WindowBackdropMode.auto => (0.04, 0.03, 0.92, 1.0),
      WindowBackdropMode.mica => (0.05, 0.04, 0.82, 1.08),
    };
  }

  static (double, double, double, double, AppBackdropStrategy)
      _resolveBackdropSurfaceProfile(
    WindowBackdropMode mode,
    AppBackdropStrategy fallbackStrategy,
  ) {
    return switch (mode) {
      WindowBackdropMode.none => (
          0.22,
          -0.36,
          0.0,
          0.72,
          AppBackdropStrategy.solid,
        ),
      WindowBackdropMode.fluid => (
          0.0,
          0.0,
          1.0,
          1.0,
          fallbackStrategy,
        ),
      WindowBackdropMode.auto => (
          0.0,
          0.0,
          1.0,
          1.0,
          fallbackStrategy,
        ),
      // 优化原生云母材质透明度，大幅度降低不透明度（之前是 -0.02, -0.04）以体现通透感
      WindowBackdropMode.mica => (
          -0.18,
          -0.12,
          0.88,
          0.9,
          AppBackdropStrategy.adaptive,
        ),
    };
  }

  static (double, double, AppBackdropStrategy) _resolveSurfaceEffects(
    UiEffectsLevel effectsLevel,
  ) {
    return switch (effectsLevel) {
      UiEffectsLevel.performance => (16.0, 0.72, AppBackdropStrategy.solid),
      UiEffectsLevel.balanced => (20.0, 0.86, AppBackdropStrategy.adaptive),
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
          accentSoft: accent.withValues(alpha: 0.22),
          accentContainer:
              Color.lerp(accent, scheme.surfaceContainerHigh, 0.28)!,
          accentGlow: accent.withValues(alpha: 0.36),
          accentFocusRing: accent.withValues(alpha: 0.52),
          progressActive: accent,
          progressInactive: accent.withValues(alpha: 0.18),
          selectionTint: accent.withValues(alpha: 0.2),
          hoverTint: scheme.onSurface.withValues(alpha: 0.08),
        ),
    };
  }

  static AppVisualTokens _visualTokens(UiVisualStyleMode visualStyleMode) {
    return switch (visualStyleMode) {
      UiVisualStyleMode.glass => const AppVisualTokens(
          styleMode: UiVisualStyleMode.glass,
          buttonGlowBlur: 24,
          buttonGlowSpread: 0.8,
          buttonGlowOpacity: 0.28,
          buttonHoverGlowScale: 1.42,
          buttonPressedGlowScale: 0.52,
          buttonPressOffset: 1.5,
          buttonFocusRingOpacity: 0.86,
          contentHeaderGap: 14,
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
