import 'package:coriander_player/app_settings.dart';
import 'package:flutter/material.dart';

enum AppBackdropStrategy {
  adaptive,
  forceBlur,
  solid;
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

Duration _lerpDuration(Duration a, Duration b, double t) {
  return Duration(
    microseconds:
        (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t).round(),
  );
}

@immutable
class AppChromeTokens extends ThemeExtension<AppChromeTokens> {
  const AppChromeTokens({
    required this.windowBgTop,
    required this.windowBgBottom,
    required this.windowScrim,
    required this.titleBarSurface,
    required this.titleBarStroke,
    required this.sideNavSurface,
    required this.pagePanelSurface,
    required this.dockSurface,
    required this.sideNavExpandedWidth,
    required this.sideNavCollapsedWidth,
    required this.titleBarHeight,
    required this.dockHeight,
    required this.shellGap,
    required this.shellContentMaxWidth,
    required this.backdropBlurSigma,
    required this.searchBarExpandedWidthLarge,
    required this.searchBarExpandedWidthMedium,
  });

  final Color windowBgTop;
  final Color windowBgBottom;
  final Color windowScrim;
  final Color titleBarSurface;
  final Color titleBarStroke;
  final Color sideNavSurface;
  final Color pagePanelSurface;
  final Color dockSurface;
  final double sideNavExpandedWidth;
  final double sideNavCollapsedWidth;
  final double titleBarHeight;
  final double dockHeight;
  final double shellGap;
  final double shellContentMaxWidth;
  final double backdropBlurSigma;
  final double searchBarExpandedWidthLarge;
  final double searchBarExpandedWidthMedium;

  @override
  AppChromeTokens copyWith({
    Color? windowBgTop,
    Color? windowBgBottom,
    Color? windowScrim,
    Color? titleBarSurface,
    Color? titleBarStroke,
    Color? sideNavSurface,
    Color? pagePanelSurface,
    Color? dockSurface,
    double? sideNavExpandedWidth,
    double? sideNavCollapsedWidth,
    double? titleBarHeight,
    double? dockHeight,
    double? shellGap,
    double? shellContentMaxWidth,
    double? backdropBlurSigma,
    double? searchBarExpandedWidthLarge,
    double? searchBarExpandedWidthMedium,
  }) {
    return AppChromeTokens(
      windowBgTop: windowBgTop ?? this.windowBgTop,
      windowBgBottom: windowBgBottom ?? this.windowBgBottom,
      windowScrim: windowScrim ?? this.windowScrim,
      titleBarSurface: titleBarSurface ?? this.titleBarSurface,
      titleBarStroke: titleBarStroke ?? this.titleBarStroke,
      sideNavSurface: sideNavSurface ?? this.sideNavSurface,
      pagePanelSurface: pagePanelSurface ?? this.pagePanelSurface,
      dockSurface: dockSurface ?? this.dockSurface,
      sideNavExpandedWidth: sideNavExpandedWidth ?? this.sideNavExpandedWidth,
      sideNavCollapsedWidth:
          sideNavCollapsedWidth ?? this.sideNavCollapsedWidth,
      titleBarHeight: titleBarHeight ?? this.titleBarHeight,
      dockHeight: dockHeight ?? this.dockHeight,
      shellGap: shellGap ?? this.shellGap,
      shellContentMaxWidth: shellContentMaxWidth ?? this.shellContentMaxWidth,
      backdropBlurSigma: backdropBlurSigma ?? this.backdropBlurSigma,
      searchBarExpandedWidthLarge:
          searchBarExpandedWidthLarge ?? this.searchBarExpandedWidthLarge,
      searchBarExpandedWidthMedium:
          searchBarExpandedWidthMedium ?? this.searchBarExpandedWidthMedium,
    );
  }

  @override
  AppChromeTokens lerp(ThemeExtension<AppChromeTokens>? other, double t) {
    if (other is! AppChromeTokens) return this;
    return AppChromeTokens(
      windowBgTop: Color.lerp(windowBgTop, other.windowBgTop, t)!,
      windowBgBottom: Color.lerp(windowBgBottom, other.windowBgBottom, t)!,
      windowScrim: Color.lerp(windowScrim, other.windowScrim, t)!,
      titleBarSurface: Color.lerp(titleBarSurface, other.titleBarSurface, t)!,
      titleBarStroke: Color.lerp(titleBarStroke, other.titleBarStroke, t)!,
      sideNavSurface: Color.lerp(sideNavSurface, other.sideNavSurface, t)!,
      pagePanelSurface:
          Color.lerp(pagePanelSurface, other.pagePanelSurface, t)!,
      dockSurface: Color.lerp(dockSurface, other.dockSurface, t)!,
      sideNavExpandedWidth:
          _lerpDouble(sideNavExpandedWidth, other.sideNavExpandedWidth, t),
      sideNavCollapsedWidth:
          _lerpDouble(sideNavCollapsedWidth, other.sideNavCollapsedWidth, t),
      titleBarHeight: _lerpDouble(titleBarHeight, other.titleBarHeight, t),
      dockHeight: _lerpDouble(dockHeight, other.dockHeight, t),
      shellGap: _lerpDouble(shellGap, other.shellGap, t),
      shellContentMaxWidth:
          _lerpDouble(shellContentMaxWidth, other.shellContentMaxWidth, t),
      backdropBlurSigma:
          _lerpDouble(backdropBlurSigma, other.backdropBlurSigma, t),
      searchBarExpandedWidthLarge: _lerpDouble(
        searchBarExpandedWidthLarge,
        other.searchBarExpandedWidthLarge,
        t,
      ),
      searchBarExpandedWidthMedium: _lerpDouble(
        searchBarExpandedWidthMedium,
        other.searchBarExpandedWidthMedium,
        t,
      ),
    );
  }
}

@immutable
class AppSurfaceTokens extends ThemeExtension<AppSurfaceTokens> {
  const AppSurfaceTokens({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusXxl,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceFloating,
    required this.surfaceInset,
    required this.strokeSubtle,
    required this.strokeStrong,
    required this.highlightColor,
    required this.shadowColor,
    required this.innerShadowLight,
    required this.innerShadowDark,
    required this.shadowBlurSm,
    required this.shadowBlurLg,
    required this.shadowOffsetSm,
    required this.shadowOffsetLg,
    required this.panelAlpha,
    required this.glassAlpha,
    required this.glassSigma,
    required this.shadowDepthScale,
    required this.effectsLevel,
    required this.backdropStrategy,
    required this.pressedDepth,
  });

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusXxl;
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color surfaceFloating;
  final Color surfaceInset;
  final Color strokeSubtle;
  final Color strokeStrong;
  final Color highlightColor;
  final Color shadowColor;
  final Color innerShadowLight;
  final Color innerShadowDark;
  final double shadowBlurSm;
  final double shadowBlurLg;
  final double shadowOffsetSm;
  final double shadowOffsetLg;
  final double panelAlpha;
  final double glassAlpha;
  final double glassSigma;
  final double shadowDepthScale;
  final UiEffectsLevel effectsLevel;
  final AppBackdropStrategy backdropStrategy;
  final double pressedDepth;

  @override
  AppSurfaceTokens copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusXxl,
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceFloating,
    Color? surfaceInset,
    Color? strokeSubtle,
    Color? strokeStrong,
    Color? highlightColor,
    Color? shadowColor,
    Color? innerShadowLight,
    Color? innerShadowDark,
    double? shadowBlurSm,
    double? shadowBlurLg,
    double? shadowOffsetSm,
    double? shadowOffsetLg,
    double? panelAlpha,
    double? glassAlpha,
    double? glassSigma,
    double? shadowDepthScale,
    UiEffectsLevel? effectsLevel,
    AppBackdropStrategy? backdropStrategy,
    double? pressedDepth,
  }) {
    return AppSurfaceTokens(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusXxl: radiusXxl ?? this.radiusXxl,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceFloating: surfaceFloating ?? this.surfaceFloating,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      strokeSubtle: strokeSubtle ?? this.strokeSubtle,
      strokeStrong: strokeStrong ?? this.strokeStrong,
      highlightColor: highlightColor ?? this.highlightColor,
      shadowColor: shadowColor ?? this.shadowColor,
      innerShadowLight: innerShadowLight ?? this.innerShadowLight,
      innerShadowDark: innerShadowDark ?? this.innerShadowDark,
      shadowBlurSm: shadowBlurSm ?? this.shadowBlurSm,
      shadowBlurLg: shadowBlurLg ?? this.shadowBlurLg,
      shadowOffsetSm: shadowOffsetSm ?? this.shadowOffsetSm,
      shadowOffsetLg: shadowOffsetLg ?? this.shadowOffsetLg,
      panelAlpha: panelAlpha ?? this.panelAlpha,
      glassAlpha: glassAlpha ?? this.glassAlpha,
      glassSigma: glassSigma ?? this.glassSigma,
      shadowDepthScale: shadowDepthScale ?? this.shadowDepthScale,
      effectsLevel: effectsLevel ?? this.effectsLevel,
      backdropStrategy: backdropStrategy ?? this.backdropStrategy,
      pressedDepth: pressedDepth ?? this.pressedDepth,
    );
  }

  @override
  AppSurfaceTokens lerp(ThemeExtension<AppSurfaceTokens>? other, double t) {
    if (other is! AppSurfaceTokens) return this;
    return AppSurfaceTokens(
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: _lerpDouble(radiusXl, other.radiusXl, t),
      radiusXxl: _lerpDouble(radiusXxl, other.radiusXxl, t),
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceFloating: Color.lerp(surfaceFloating, other.surfaceFloating, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      strokeSubtle: Color.lerp(strokeSubtle, other.strokeSubtle, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      innerShadowLight:
          Color.lerp(innerShadowLight, other.innerShadowLight, t)!,
      innerShadowDark: Color.lerp(innerShadowDark, other.innerShadowDark, t)!,
      shadowBlurSm: _lerpDouble(shadowBlurSm, other.shadowBlurSm, t),
      shadowBlurLg: _lerpDouble(shadowBlurLg, other.shadowBlurLg, t),
      shadowOffsetSm: _lerpDouble(shadowOffsetSm, other.shadowOffsetSm, t),
      shadowOffsetLg: _lerpDouble(shadowOffsetLg, other.shadowOffsetLg, t),
      panelAlpha: _lerpDouble(panelAlpha, other.panelAlpha, t),
      glassAlpha: _lerpDouble(glassAlpha, other.glassAlpha, t),
      glassSigma: _lerpDouble(glassSigma, other.glassSigma, t),
      shadowDepthScale:
          _lerpDouble(shadowDepthScale, other.shadowDepthScale, t),
      effectsLevel: t < 0.5 ? effectsLevel : other.effectsLevel,
      backdropStrategy: t < 0.5 ? backdropStrategy : other.backdropStrategy,
      pressedDepth: _lerpDouble(pressedDepth, other.pressedDepth, t),
    );
  }
}

@immutable
class AppAccentTokens extends ThemeExtension<AppAccentTokens> {
  const AppAccentTokens({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentContainer,
    required this.accentGlow,
    required this.accentFocusRing,
    required this.progressActive,
    required this.progressInactive,
    required this.selectionTint,
    required this.hoverTint,
  });

  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentContainer;
  final Color accentGlow;
  final Color accentFocusRing;
  final Color progressActive;
  final Color progressInactive;
  final Color selectionTint;
  final Color hoverTint;

  @override
  AppAccentTokens copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? accentContainer,
    Color? accentGlow,
    Color? accentFocusRing,
    Color? progressActive,
    Color? progressInactive,
    Color? selectionTint,
    Color? hoverTint,
  }) {
    return AppAccentTokens(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentContainer: accentContainer ?? this.accentContainer,
      accentGlow: accentGlow ?? this.accentGlow,
      accentFocusRing: accentFocusRing ?? this.accentFocusRing,
      progressActive: progressActive ?? this.progressActive,
      progressInactive: progressInactive ?? this.progressInactive,
      selectionTint: selectionTint ?? this.selectionTint,
      hoverTint: hoverTint ?? this.hoverTint,
    );
  }

  @override
  AppAccentTokens lerp(ThemeExtension<AppAccentTokens>? other, double t) {
    if (other is! AppAccentTokens) return this;
    return AppAccentTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      accentFocusRing: Color.lerp(accentFocusRing, other.accentFocusRing, t)!,
      progressActive: Color.lerp(progressActive, other.progressActive, t)!,
      progressInactive:
          Color.lerp(progressInactive, other.progressInactive, t)!,
      selectionTint: Color.lerp(selectionTint, other.selectionTint, t)!,
      hoverTint: Color.lerp(hoverTint, other.hoverTint, t)!,
    );
  }
}

@immutable
class AppVisualTokens extends ThemeExtension<AppVisualTokens> {
  const AppVisualTokens({
    required this.styleMode,
    required this.buttonGlowBlur,
    required this.buttonGlowSpread,
    required this.buttonGlowOpacity,
    required this.buttonHoverGlowScale,
    required this.buttonPressedGlowScale,
    required this.buttonPressOffset,
    required this.buttonFocusRingOpacity,
    required this.contentHeaderGap,
  });

  final UiVisualStyleMode styleMode;
  final double buttonGlowBlur;
  final double buttonGlowSpread;
  final double buttonGlowOpacity;
  final double buttonHoverGlowScale;
  final double buttonPressedGlowScale;
  final double buttonPressOffset;
  final double buttonFocusRingOpacity;
  final double contentHeaderGap;

  @override
  AppVisualTokens copyWith({
    UiVisualStyleMode? styleMode,
    double? buttonGlowBlur,
    double? buttonGlowSpread,
    double? buttonGlowOpacity,
    double? buttonHoverGlowScale,
    double? buttonPressedGlowScale,
    double? buttonPressOffset,
    double? buttonFocusRingOpacity,
    double? contentHeaderGap,
  }) {
    return AppVisualTokens(
      styleMode: styleMode ?? this.styleMode,
      buttonGlowBlur: buttonGlowBlur ?? this.buttonGlowBlur,
      buttonGlowSpread: buttonGlowSpread ?? this.buttonGlowSpread,
      buttonGlowOpacity: buttonGlowOpacity ?? this.buttonGlowOpacity,
      buttonHoverGlowScale: buttonHoverGlowScale ?? this.buttonHoverGlowScale,
      buttonPressedGlowScale:
          buttonPressedGlowScale ?? this.buttonPressedGlowScale,
      buttonPressOffset: buttonPressOffset ?? this.buttonPressOffset,
      buttonFocusRingOpacity:
          buttonFocusRingOpacity ?? this.buttonFocusRingOpacity,
      contentHeaderGap: contentHeaderGap ?? this.contentHeaderGap,
    );
  }

  @override
  AppVisualTokens lerp(ThemeExtension<AppVisualTokens>? other, double t) {
    if (other is! AppVisualTokens) return this;
    return AppVisualTokens(
      styleMode: t < 0.5 ? styleMode : other.styleMode,
      buttonGlowBlur: _lerpDouble(buttonGlowBlur, other.buttonGlowBlur, t),
      buttonGlowSpread:
          _lerpDouble(buttonGlowSpread, other.buttonGlowSpread, t),
      buttonGlowOpacity:
          _lerpDouble(buttonGlowOpacity, other.buttonGlowOpacity, t),
      buttonHoverGlowScale:
          _lerpDouble(buttonHoverGlowScale, other.buttonHoverGlowScale, t),
      buttonPressedGlowScale: _lerpDouble(
        buttonPressedGlowScale,
        other.buttonPressedGlowScale,
        t,
      ),
      buttonPressOffset:
          _lerpDouble(buttonPressOffset, other.buttonPressOffset, t),
      buttonFocusRingOpacity:
          _lerpDouble(buttonFocusRingOpacity, other.buttonFocusRingOpacity, t),
      contentHeaderGap:
          _lerpDouble(contentHeaderGap, other.contentHeaderGap, t),
    );
  }
}

@immutable
class AppMotionTokens extends ThemeExtension<AppMotionTokens> {
  const AppMotionTokens({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.emphasized,
    required this.standard,
    required this.microInteractionDuration,
    required this.controlTransitionDuration,
    required this.pageTransitionDuration,
    required this.pageReverseTransitionDuration,
    required this.lyricScrollDuration,
    required this.listTransitionDuration,
    required this.navCollapseDuration,
    required this.searchExpandDuration,
    required this.panelTransitionDuration,
  });

  final Curve fast;
  final Curve normal;
  final Curve slow;
  final Curve emphasized;
  final Curve standard;
  final Duration microInteractionDuration;
  final Duration controlTransitionDuration;
  final Duration pageTransitionDuration;
  final Duration pageReverseTransitionDuration;
  final Duration lyricScrollDuration;
  final Duration listTransitionDuration;
  final Duration navCollapseDuration;
  final Duration searchExpandDuration;
  final Duration panelTransitionDuration;

  @override
  AppMotionTokens copyWith({
    Curve? fast,
    Curve? normal,
    Curve? slow,
    Curve? emphasized,
    Curve? standard,
    Duration? microInteractionDuration,
    Duration? controlTransitionDuration,
    Duration? pageTransitionDuration,
    Duration? pageReverseTransitionDuration,
    Duration? lyricScrollDuration,
    Duration? listTransitionDuration,
    Duration? navCollapseDuration,
    Duration? searchExpandDuration,
    Duration? panelTransitionDuration,
  }) {
    return AppMotionTokens(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      emphasized: emphasized ?? this.emphasized,
      standard: standard ?? this.standard,
      microInteractionDuration:
          microInteractionDuration ?? this.microInteractionDuration,
      controlTransitionDuration:
          controlTransitionDuration ?? this.controlTransitionDuration,
      pageTransitionDuration:
          pageTransitionDuration ?? this.pageTransitionDuration,
      pageReverseTransitionDuration:
          pageReverseTransitionDuration ?? this.pageReverseTransitionDuration,
      lyricScrollDuration: lyricScrollDuration ?? this.lyricScrollDuration,
      listTransitionDuration:
          listTransitionDuration ?? this.listTransitionDuration,
      navCollapseDuration: navCollapseDuration ?? this.navCollapseDuration,
      searchExpandDuration: searchExpandDuration ?? this.searchExpandDuration,
      panelTransitionDuration:
          panelTransitionDuration ?? this.panelTransitionDuration,
    );
  }

  @override
  AppMotionTokens lerp(ThemeExtension<AppMotionTokens>? other, double t) {
    if (other is! AppMotionTokens) return this;
    return AppMotionTokens(
      fast: t < 0.5 ? fast : other.fast,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
      emphasized: t < 0.5 ? emphasized : other.emphasized,
      standard: t < 0.5 ? standard : other.standard,
      microInteractionDuration: _lerpDuration(
        microInteractionDuration,
        other.microInteractionDuration,
        t,
      ),
      controlTransitionDuration: _lerpDuration(
        controlTransitionDuration,
        other.controlTransitionDuration,
        t,
      ),
      pageTransitionDuration: _lerpDuration(
        pageTransitionDuration,
        other.pageTransitionDuration,
        t,
      ),
      pageReverseTransitionDuration: _lerpDuration(
        pageReverseTransitionDuration,
        other.pageReverseTransitionDuration,
        t,
      ),
      lyricScrollDuration:
          _lerpDuration(lyricScrollDuration, other.lyricScrollDuration, t),
      listTransitionDuration: _lerpDuration(
          listTransitionDuration, other.listTransitionDuration, t),
      navCollapseDuration:
          _lerpDuration(navCollapseDuration, other.navCollapseDuration, t),
      searchExpandDuration:
          _lerpDuration(searchExpandDuration, other.searchExpandDuration, t),
      panelTransitionDuration: _lerpDuration(
        panelTransitionDuration,
        other.panelTransitionDuration,
        t,
      ),
    );
  }
}

@immutable
class PlayerTokens extends ThemeExtension<PlayerTokens> {
  const PlayerTokens({
    required this.coverRadius,
    required this.coverGlowBlur,
    required this.coverGlowOpacity,
    required this.controlClusterRadius,
    required this.lyricPanelOpacity,
    required this.queuePanelOpacity,
    required this.immersiveBackdropSigma,
    required this.studioPanelGap,
    required this.modeSwitchDuration,
  });

  final double coverRadius;
  final double coverGlowBlur;
  final double coverGlowOpacity;
  final double controlClusterRadius;
  final double lyricPanelOpacity;
  final double queuePanelOpacity;
  final double immersiveBackdropSigma;
  final double studioPanelGap;
  final Duration modeSwitchDuration;

  @override
  PlayerTokens copyWith({
    double? coverRadius,
    double? coverGlowBlur,
    double? coverGlowOpacity,
    double? controlClusterRadius,
    double? lyricPanelOpacity,
    double? queuePanelOpacity,
    double? immersiveBackdropSigma,
    double? studioPanelGap,
    Duration? modeSwitchDuration,
  }) {
    return PlayerTokens(
      coverRadius: coverRadius ?? this.coverRadius,
      coverGlowBlur: coverGlowBlur ?? this.coverGlowBlur,
      coverGlowOpacity: coverGlowOpacity ?? this.coverGlowOpacity,
      controlClusterRadius: controlClusterRadius ?? this.controlClusterRadius,
      lyricPanelOpacity: lyricPanelOpacity ?? this.lyricPanelOpacity,
      queuePanelOpacity: queuePanelOpacity ?? this.queuePanelOpacity,
      immersiveBackdropSigma:
          immersiveBackdropSigma ?? this.immersiveBackdropSigma,
      studioPanelGap: studioPanelGap ?? this.studioPanelGap,
      modeSwitchDuration: modeSwitchDuration ?? this.modeSwitchDuration,
    );
  }

  @override
  PlayerTokens lerp(ThemeExtension<PlayerTokens>? other, double t) {
    if (other is! PlayerTokens) return this;
    return PlayerTokens(
      coverRadius: _lerpDouble(coverRadius, other.coverRadius, t),
      coverGlowBlur: _lerpDouble(coverGlowBlur, other.coverGlowBlur, t),
      coverGlowOpacity:
          _lerpDouble(coverGlowOpacity, other.coverGlowOpacity, t),
      controlClusterRadius:
          _lerpDouble(controlClusterRadius, other.controlClusterRadius, t),
      lyricPanelOpacity:
          _lerpDouble(lyricPanelOpacity, other.lyricPanelOpacity, t),
      queuePanelOpacity:
          _lerpDouble(queuePanelOpacity, other.queuePanelOpacity, t),
      immersiveBackdropSigma:
          _lerpDouble(immersiveBackdropSigma, other.immersiveBackdropSigma, t),
      studioPanelGap: _lerpDouble(studioPanelGap, other.studioPanelGap, t),
      modeSwitchDuration:
          _lerpDuration(modeSwitchDuration, other.modeSwitchDuration, t),
    );
  }
}

extension AppThemeContextX on BuildContext {
  AppChromeTokens get chrome => Theme.of(this).extension<AppChromeTokens>()!;

  AppSurfaceTokens get surfaces =>
      Theme.of(this).extension<AppSurfaceTokens>()!;

  AppAccentTokens get accents => Theme.of(this).extension<AppAccentTokens>()!;

  AppVisualTokens get visuals => Theme.of(this).extension<AppVisualTokens>()!;

  AppMotionTokens get motion => Theme.of(this).extension<AppMotionTokens>()!;

  PlayerTokens get playerTokens => Theme.of(this).extension<PlayerTokens>()!;
}
