import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/album_palette.dart';
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
    UiVisualStyleMode visualStyleMode = UiVisualStyleMode.solidCard,
    WindowBackdropMode windowBackdropMode = WindowBackdropMode.defaultGradient,
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

  // 优化全局排版体系：注入等宽数字与现代字阶层级，避免播放进度、时间跳动时文字晃动
  static TextTheme _refineTextTheme(
    TextTheme textTheme,
    ColorScheme scheme,
    UiVisualStyleMode visualStyleMode,
  ) {
    const tabularFeatures = [FontFeature.tabularFigures()];

    return textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.04,
        letterSpacing: -0.5,
        fontFeatures: tabularFeatures,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.06,
        letterSpacing: -0.3,
        fontFeatures: tabularFeatures,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.2,
        fontFeatures: tabularFeatures,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        fontFeatures: tabularFeatures,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
        fontFeatures: tabularFeatures,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.84),
        fontWeight: FontWeight.w400,
        fontFeatures: tabularFeatures,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.62),
        fontWeight: FontWeight.w400,
        fontFeatures: tabularFeatures,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        fontFeatures: tabularFeatures,
      ),
      labelMedium: textTheme.labelMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
        fontFeatures: tabularFeatures,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        fontFeatures: tabularFeatures,
      ),
    );
  }

  static ColorScheme applyChromeSurfaces(
    ColorScheme scheme, {
    UiVisualStyleMode visualStyleMode = UiVisualStyleMode.solidCard,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(scheme.primary);
    final lum = AlbumPalette.pureHueLuminance(hsl.hue);
    final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);

    // 基于 Material 3 动态/手动主题色阶有机调和，针对高感知亮度色相降低暗色容器混合度，彻底杜绝奶浊发黄与刺眼死白
    final surfaceAlpha = isDark ? (0.06 - excess * 0.02) : 0.02;
    final surfaceLowAlpha = isDark ? (0.04 - excess * 0.015) : 0.015;
    final surfaceContainerAlpha = isDark ? (0.08 - excess * 0.03) : 0.035;
    final surfaceHighAlpha = isDark ? (0.12 - excess * 0.05) : 0.05;
    final surfaceHighestAlpha = isDark ? (0.16 - excess * 0.07) : 0.065;

    final surface = Color.alphaBlend(
      scheme.primary.withValues(alpha: surfaceAlpha),
      scheme.surface,
    );
    final surfaceLow = Color.alphaBlend(
      scheme.primary.withValues(alpha: surfaceLowAlpha),
      scheme.surfaceContainerLow,
    );
    final surfaceContainer = Color.alphaBlend(
      scheme.primary.withValues(alpha: surfaceContainerAlpha),
      scheme.surfaceContainer,
    );
    final surfaceHigh = Color.alphaBlend(
      scheme.primary.withValues(alpha: surfaceHighAlpha),
      scheme.surfaceContainerHigh,
    );
    final surfaceHighest = Color.alphaBlend(
      scheme.primary.withValues(alpha: surfaceHighestAlpha),
      scheme.surfaceContainerHighest,
    );

    final onSurface = scheme.onSurface;
    final outline = scheme.outline;
    final outlineVariant = scheme.outlineVariant;
    final shadow = Colors.black.withValues(alpha: isDark ? 0.35 : 0.08);
    final scrim = Colors.black.withValues(alpha: isDark ? 0.5 : 0.22);

    return scheme.copyWith(
      surface: surface,
      onSurface: onSurface,
      surfaceTint: Colors.transparent,
      surfaceDim: scheme.surfaceDim,
      surfaceBright: scheme.surfaceBright,
      surfaceContainerLowest: scheme.surfaceContainerLowest,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      secondaryContainer: surfaceContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
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
      // 液态玻璃风格：轻表面、柔和描边、低强度阴影与通透感
      UiVisualStyleMode.liquidGlass => AppSurfaceTokens(
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
      // 纯净实体卡片风格：清晰色阶、实体触感、去模糊、极佳可读性
      UiVisualStyleMode.solidCard => AppSurfaceTokens(
          radiusSm: 12,
          radiusMd: 16,
          radiusLg: 20,
          radiusXl: 24,
          radiusXxl: 28,
          surfaceBase: scheme.surface,
          surfaceRaised: scheme.surfaceContainerLow,
          surfaceFloating: scheme.surfaceContainer,
          surfaceInset: scheme.surfaceContainerLowest,
          strokeSubtle:
              scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45),
          strokeStrong: scheme.outline.withValues(alpha: isDark ? 0.6 : 0.75),
          highlightColor: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.7),
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
          innerShadowLight: Colors.transparent,
          innerShadowDark: Colors.transparent,
          shadowBlurSm: 16,
          shadowBlurLg: 32,
          shadowOffsetSm: 2,
          shadowOffsetLg: 6,
          panelAlpha: 0.96,
          glassAlpha: 0.0,
          glassSigma: 0.0,
          shadowDepthScale: shadowDepthScale * 0.8,
          effectsLevel: effectsLevel,
          backdropStrategy: AppBackdropStrategy.solid,
          pressedDepth: 1.5,
        ),
      // 无界极简悬浮风格：去底色、空间留白、依靠呼吸光与间距组织视觉
      UiVisualStyleMode.borderless => AppSurfaceTokens(
          radiusSm: 16,
          radiusMd: 20,
          radiusLg: 26,
          radiusXl: 32,
          radiusXxl: 36,
          surfaceBase: Colors.transparent,
          surfaceRaised: Colors.transparent,
          surfaceFloating: scheme.surfaceContainer.withValues(alpha: 0.35),
          surfaceInset: Colors.transparent,
          strokeSubtle: Colors.transparent,
          strokeStrong: scheme.outlineVariant.withValues(alpha: 0.25),
          highlightColor: Colors.transparent,
          shadowColor: Colors.transparent,
          innerShadowLight: Colors.transparent,
          innerShadowDark: Colors.transparent,
          shadowBlurSm: 0,
          shadowBlurLg: 0,
          shadowOffsetSm: 0,
          shadowOffsetLg: 0,
          panelAlpha: 0.0,
          glassAlpha: 0.0,
          glassSigma: 0.0,
          shadowDepthScale: 0.0,
          effectsLevel: effectsLevel,
          backdropStrategy: AppBackdropStrategy.solid,
          pressedDepth: 1,
        ),
    };
  }

  static (double, double, double, double) _resolveBackdropChromeProfile(
    WindowBackdropMode mode,
  ) {
    return switch (mode) {
      WindowBackdropMode.defaultGradient => (0.02, 0.01, 1.25, 0.0),
      WindowBackdropMode.meshFlow => (0.04, 0.03, 0.92, 1.0),
      WindowBackdropMode.waterRipple => (0.04, 0.03, 0.95, 1.0),
      WindowBackdropMode.prismaticGlass => (0.06, 0.05, 0.85, 1.1),
      WindowBackdropMode.micaAlt => (0.05, 0.04, 0.82, 1.08),
      WindowBackdropMode.acrylic => (0.06, 0.05, 0.80, 1.15),
    };
  }

  static (double, double, double, double, AppBackdropStrategy)
      _resolveBackdropSurfaceProfile(
    WindowBackdropMode mode,
    AppBackdropStrategy fallbackStrategy,
  ) {
    return switch (mode) {
      WindowBackdropMode.defaultGradient => (
          0.34,
          0.34,
          0.0,
          0.72,
          AppBackdropStrategy.solid,
        ),
      WindowBackdropMode.meshFlow => (
          0.0,
          0.0,
          1.0,
          1.0,
          AppBackdropStrategy.solid,
        ),
      WindowBackdropMode.waterRipple => (
          0.0,
          0.0,
          1.0,
          1.0,
          AppBackdropStrategy.solid,
        ),
      WindowBackdropMode.prismaticGlass => (
          0.04,
          0.04,
          0.9,
          1.0,
          fallbackStrategy,
        ),
      WindowBackdropMode.micaAlt => (
          0.08,
          0.08,
          0.88,
          0.9,
          fallbackStrategy,
        ),
      WindowBackdropMode.acrylic => (
          0.06,
          0.06,
          0.92,
          0.95,
          fallbackStrategy,
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
      UiVisualStyleMode.liquidGlass => AppAccentTokens(
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
      UiVisualStyleMode.solidCard => AppAccentTokens(
          accent: accent,
          onAccent: scheme.onPrimary,
          accentSoft: accent.withValues(alpha: 0.16),
          accentContainer: Color.lerp(accent, scheme.surfaceContainer, 0.22)!,
          accentGlow: accent.withValues(alpha: 0.18),
          accentFocusRing: accent.withValues(alpha: 0.44),
          progressActive: accent,
          progressInactive: accent.withValues(alpha: 0.14),
          selectionTint: accent.withValues(alpha: 0.16),
          hoverTint: scheme.onSurface.withValues(alpha: 0.05),
        ),
      UiVisualStyleMode.borderless => AppAccentTokens(
          accent: accent,
          onAccent: scheme.onPrimary,
          accentSoft: accent.withValues(alpha: 0.28),
          accentContainer: Color.lerp(accent, scheme.surface, 0.35)!,
          accentGlow: accent.withValues(alpha: 0.48),
          accentFocusRing: accent.withValues(alpha: 0.6),
          progressActive: accent,
          progressInactive: accent.withValues(alpha: 0.22),
          selectionTint: accent.withValues(alpha: 0.24),
          hoverTint: scheme.onSurface.withValues(alpha: 0.1),
        ),
    };
  }

  static AppVisualTokens _visualTokens(UiVisualStyleMode visualStyleMode) {
    return switch (visualStyleMode) {
      UiVisualStyleMode.liquidGlass => const AppVisualTokens(
          styleMode: UiVisualStyleMode.liquidGlass,
          buttonGlowBlur: 24,
          buttonGlowSpread: 0.8,
          buttonGlowOpacity: 0.28,
          buttonHoverGlowScale: 1.42,
          buttonPressedGlowScale: 0.52,
          buttonPressOffset: 1.5,
          buttonFocusRingOpacity: 0.86,
          contentHeaderGap: 14,
        ),
      UiVisualStyleMode.solidCard => const AppVisualTokens(
          styleMode: UiVisualStyleMode.solidCard,
          buttonGlowBlur: 14,
          buttonGlowSpread: 0.2,
          buttonGlowOpacity: 0.14,
          buttonHoverGlowScale: 1.15,
          buttonPressedGlowScale: 0.3,
          buttonPressOffset: 1.0,
          buttonFocusRingOpacity: 0.65,
          contentHeaderGap: 14,
        ),
      UiVisualStyleMode.borderless => const AppVisualTokens(
          styleMode: UiVisualStyleMode.borderless,
          buttonGlowBlur: 28,
          buttonGlowSpread: 1.2,
          buttonGlowOpacity: 0.38,
          buttonHoverGlowScale: 1.6,
          buttonPressedGlowScale: 0.65,
          buttonPressOffset: 2.0,
          buttonFocusRingOpacity: 0.92,
          contentHeaderGap: 16,
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
      elastic: Curves.elasticOut,
      microInteractionDuration: Duration(milliseconds: 140),
      controlTransitionDuration: Duration(milliseconds: 220),
      pageTransitionDuration: Duration(milliseconds: 360),
      pageReverseTransitionDuration: Duration(milliseconds: 260),
      lyricScrollDuration: Duration(milliseconds: 420),
      listTransitionDuration: Duration(milliseconds: 220),
      navCollapseDuration: Duration(milliseconds: 280),
      searchExpandDuration: Duration(milliseconds: 220),
      panelTransitionDuration: Duration(milliseconds: 260),
      elasticTransitionDuration: Duration(milliseconds: 420),
    );
  }

  static PlayerTokens _playerTokens(UiVisualStyleMode visualStyleMode) {
    return switch (visualStyleMode) {
      UiVisualStyleMode.liquidGlass => const PlayerTokens(
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
      UiVisualStyleMode.solidCard => const PlayerTokens(
          coverRadius: 14,
          coverGlowBlur: 16,
          coverGlowOpacity: 0.12,
          controlClusterRadius: 20,
          lyricPanelOpacity: 0.95,
          queuePanelOpacity: 0.92,
          immersiveBackdropSigma: 0,
          studioPanelGap: 20,
          modeSwitchDuration: Duration(milliseconds: 260),
        ),
      UiVisualStyleMode.borderless => const PlayerTokens(
          coverRadius: 22,
          coverGlowBlur: 36,
          coverGlowOpacity: 0.36,
          controlClusterRadius: 32,
          lyricPanelOpacity: 0.5,
          queuePanelOpacity: 0.5,
          immersiveBackdropSigma: 44,
          studioPanelGap: 28,
          modeSwitchDuration: Duration(milliseconds: 360),
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
