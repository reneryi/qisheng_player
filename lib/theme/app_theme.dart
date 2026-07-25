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
    primaryTextTheme = _refineTextTheme(primaryTextTheme, colorScheme, visualStyleMode);

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
      listTileTheme: const ListTileThemeData(enableFeedback: false),
      menuTheme: AppComponentThemes.menuTheme(surfaces),
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
      tooltipTheme: const TooltipThemeData(enableFeedback: false),
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

  static TextTheme _refineTextTheme(TextTheme textTheme, ColorScheme scheme, UiVisualStyleMode visualStyleMode) {
    final isSharp = visualStyleMode == UiVisualStyleMode.sharpCard;
    return textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: isSharp ? FontWeight.w900 : FontWeight.w700,
        height: 1.04,
        letterSpacing: isSharp ? -0.5 : 0,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: isSharp ? FontWeight.w800 : FontWeight.w700,
        height: 1.06,
        letterSpacing: isSharp ? -0.3 : 0,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: isSharp ? FontWeight.w800 : FontWeight.w700,
        height: 1.08,
        letterSpacing: isSharp ? -0.2 : 0,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: isSharp ? FontWeight.w700 : FontWeight.w600,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: isSharp ? 0.9 : 0.82),
        fontWeight: FontWeight.w400,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: isSharp ? 0.72 : 0.6),
        fontWeight: isSharp ? FontWeight.w500 : FontWeight.w400,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: isSharp ? FontWeight.w700 : FontWeight.w600,
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
          isDark ? const Color(0xFFEAF8FF) : const Color(0xFF17121E),
          // 暗黑玻璃模式：融入 12% 动态封面提取色，呈现调性一致的高级暗沉底色
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), const Color(0xFF07111F))
              : const Color(0xFFF8F4FF),
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), const Color(0xFF0A1829))
              : const Color(0xFFFBF8FF),
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.14), const Color(0xFF0E2236))
              : const Color(0xFFFFFCF6),
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.16), const Color(0xFF142D45))
              : const Color(0xFFFFFFFF),
          isDark ? const Color(0xFF6B91AA) : const Color(0xFFB9BFD0),
          isDark ? const Color(0xFF2A5265) : const Color(0xFFE0E4F1),
          Colors.black.withValues(alpha: isDark ? 0.38 : 0.1),
          Colors.black.withValues(alpha: isDark ? 0.5 : 0.22),
        ),
      UiVisualStyleMode.contrast => (
          isDark ? const Color(0xFFF2F5FA) : const Color(0xFF0F172A),
          // 暗黑高对比模式：融入 10% 动态封面提取色
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), const Color(0xFF0B1017))
              : const Color(0xFFF3F6FB),
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), const Color(0xFF111823))
              : const Color(0xFFF8FAFE),
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), const Color(0xFF151E2C))
              : const Color(0xFFFFFFFF),
          isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.15), const Color(0xFF1B2738))
              : const Color(0xFFFFFFFF),
          isDark ? const Color(0xFF5B6A80) : const Color(0xFFB7C1D1),
          isDark ? const Color(0xFF3A465B) : const Color(0xFFD4DBE7),
          Colors.black.withValues(alpha: isDark ? 0.52 : 0.16),
          Colors.black.withValues(alpha: isDark ? 0.62 : 0.3),
        ),
      UiVisualStyleMode.sharpCard => (
          isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B),
          // 极简锐利模式：从石墨黑转为优雅的深邃暗蓝色 (Slate-900)
          isDark ? const Color(0xFF090D17) : const Color(0xFFF4F5F7), // surface: 最底层
          isDark ? const Color(0xFF0F172A) : const Color(0xFFECEEF2), // surfaceLow: 侧边栏/基础面板
          isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF), // surfaceContainer: 卡片内容页
          isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF), // surfaceHigh: 二级浮动菜单
          isDark ? const Color(0xFF334155) : const Color(0xFFD4D7E1), // outline: 边框线
          isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB), // outlineVariant: 次要边框线
          Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
          Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
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
    WindowBackdropMode windowBackdropMode,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final backdropSigma = switch (effectsLevel) {
      UiEffectsLevel.performance => 16.0,
      UiEffectsLevel.balanced => 18.0,
      UiEffectsLevel.visual => 30.0,
    };
    final (windowBgTop, windowBgBottom, windowScrim) =
        switch (visualStyleMode) {
      UiVisualStyleMode.glass => (
          isDark ? const Color(0xFF061321) : const Color(0xFFF9F5FF),
          isDark ? const Color(0xFF041B25) : const Color(0xFFFFF6DC),
          isDark
              ? const Color(0xFF020813).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.38),
        ),
      UiVisualStyleMode.contrast => (
          isDark ? const Color(0xFF050A10) : const Color(0xFFEFF3F9),
          isDark ? const Color(0xFF020407) : const Color(0xFFE7ECF4),
          isDark
              ? const Color(0xFF0A0F18).withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.68),
        ),
      UiVisualStyleMode.sharpCard => (
          isDark ? const Color(0xFF0D0E10) : const Color(0xFFF4F5F7),
          isDark ? const Color(0xFF090A0C) : const Color(0xFFEBECEF),
          isDark
              ? const Color(0xFF000000).withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.45),
        ),
    };
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
      // 侧边栏与主面板：极简锐利在夜间下统一为固定石墨色 (#181A1F)，与卡片背景 100% 同色无缝融合
      sideNavSurface: visualStyleMode == UiVisualStyleMode.sharpCard
          ? (isDark ? const Color(0xFF181A1F) : const Color(0xFFF4F4F5))
          : (isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), const Color(0xFF0F1218))
              : const Color(0xFFF4F4F5)),
      pagePanelSurface: visualStyleMode == UiVisualStyleMode.sharpCard
          ? (isDark ? const Color(0xFF181A1F) : const Color(0xFFFFFFFF))
          : (isDark
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), const Color(0xFF12151C))
              : const Color(0xFFFFFFFF)),
      dockSurface: scheme.surfaceContainerHigh,
      sideNavExpandedWidth: 160, // 稍微收窄左侧栏避免占比过大
      sideNavCollapsedWidth: 76,
      titleBarHeight: 56,
      dockHeight: 92,
      shellGap: 12, // 悬浮一体画板设计：将多余间隔设为 12 像素，产生完美的四周悬浮间距与呼吸感
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
          panelAlpha:
              ((isDark ? 0.98 : 1.0) + panelAlphaDelta).clamp(0.84, 1.0),
          glassAlpha:
              ((isDark ? 0.92 : 0.96) + glassAlphaDelta).clamp(0.72, 1.0),
          glassSigma: glassSigma * 0.72 * sigmaScale,
          shadowDepthScale: shadowDepthScale * 0.9 * shadowScale,
          effectsLevel: effectsLevel,
          backdropStrategy:
              resolvedBackdropStrategy == AppBackdropStrategy.forceBlur
                  ? AppBackdropStrategy.adaptive
                  : resolvedBackdropStrategy,
          pressedDepth: 1.2,
        ),
      UiVisualStyleMode.sharpCard => AppSurfaceTokens(
          radiusSm: 14,
          radiusMd: 18,
          radiusLg: 22,
          radiusXl: 26,
          radiusXxl: 32,
          surfaceBase: scheme.surface,
          surfaceRaised: scheme.surfaceContainer,
          surfaceFloating: scheme.surfaceContainerHigh,
          surfaceInset: scheme.surfaceContainerLow,
          strokeSubtle: scheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.8),
          strokeStrong: scheme.outline.withValues(alpha: isDark ? 0.85 : 0.95),
          highlightColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.9),
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
          innerShadowLight: Colors.transparent,
          innerShadowDark: Colors.transparent,
          shadowBlurSm: 10,
          shadowBlurLg: 20,
          shadowOffsetSm: 2,
          shadowOffsetLg: 6,
          panelAlpha: 1.0,
          glassAlpha: 1.0,
          glassSigma: 0.0,
          shadowDepthScale: 0.5,
          effectsLevel: effectsLevel,
          backdropStrategy: AppBackdropStrategy.solid,
          pressedDepth: 1.0,
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
      WindowBackdropMode.micaAlt => (0.08, 0.06, 0.72, 1.15), // Mica Alt 采用更鲜明的色调偏置
      WindowBackdropMode.acrylic => (0.12, 0.1, 0.52, 1.55),
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
      // 新增云母 Alt 材质透明度配置，使其极度通透并呈现高级灰色调底图
      WindowBackdropMode.micaAlt => (
          -0.22,
          -0.16,
          1.0,
          0.95,
          AppBackdropStrategy.adaptive,
        ),
      // 原生亚克力材质：使其相比原来更加通透（之前是 -0.18, -0.08）
      WindowBackdropMode.acrylic => (
          -0.24,
          -0.18,
          1.42,
          1.18,
          AppBackdropStrategy.forceBlur,
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
      UiVisualStyleMode.sharpCard => AppAccentTokens(
          accent: accent,
          onAccent: scheme.onPrimary,
          accentSoft: accent.withValues(alpha: 0.18),
          accentContainer: Color.lerp(accent, scheme.surfaceContainer, 0.25)!,
          accentGlow: accent.withValues(alpha: 0.16),
          accentFocusRing: accent.withValues(alpha: 0.48),
          progressActive: accent,
          progressInactive: accent.withValues(alpha: 0.15),
          selectionTint: accent.withValues(alpha: 0.18),
          hoverTint: scheme.onSurface.withValues(alpha: 0.06),
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
      UiVisualStyleMode.sharpCard => const AppVisualTokens(
          styleMode: UiVisualStyleMode.sharpCard,
          buttonGlowBlur: 8,
          buttonGlowSpread: 0.1,
          buttonGlowOpacity: 0.1,
          buttonHoverGlowScale: 1.08,
          buttonPressedGlowScale: 0.75,
          buttonPressOffset: 0.8,
          buttonFocusRingOpacity: 0.9,
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
      UiVisualStyleMode.sharpCard => const PlayerTokens(
          coverRadius: 20,
          coverGlowBlur: 14,
          coverGlowOpacity: 0.1,
          controlClusterRadius: 24,
          lyricPanelOpacity: 0.96,
          queuePanelOpacity: 0.96,
          immersiveBackdropSigma: 24,
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
