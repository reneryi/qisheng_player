import 'dart:ui';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum AppSurfaceVariant {
  inset,
  raised,
  floating,
  glass,
}

enum AppSurfaceGlassDensity {
  low,
  medium,
  high,
}

enum AppSurfaceBackdropBehavior {
  themeDefault,
  preferStableGlass,
  forceBlur,
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.variant = AppSurfaceVariant.raised,
    this.radius,
    this.clipBehavior = Clip.antiAlias,
    this.glassDensity = AppSurfaceGlassDensity.medium,
    this.backdropBehavior = AppSurfaceBackdropBehavior.themeDefault,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AppSurfaceVariant variant;
  final double? radius;
  final Clip clipBehavior;
  final AppSurfaceGlassDensity glassDensity;
  final AppSurfaceBackdropBehavior backdropBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    Color glassTint = scheme.primary;
    try {
      glassTint = context.select<ThemeProvider, Color>(
        (provider) => provider.glassTint,
      );
    } catch (_) {}

    final resolvedRadius = radius ?? surfaces.radiusXl;
    final contentChild = RepaintBoundary(child: child);
    final content = padding == null
        ? contentChild
        : Padding(padding: padding!, child: contentChild);
    final shouldUseGlass = variant == AppSurfaceVariant.glass ||
        surfaces.backdropStrategy != AppBackdropStrategy.solid;
    final applyBlur = _resolveApplyBlur(surfaces);

    final surface = shouldUseGlass
        ? _GlassSurface(
            variant: variant,
            radius: resolvedRadius,
            margin: margin,
            clipBehavior: clipBehavior,
            sigma: _resolveGlassSigma(surfaces) * _variantSigmaScale(),
            applyBlur: applyBlur,
            tintColor: glassTint,
            shadowColor: surfaces.shadowColor,
            shadowBlur: surfaces.shadowBlurLg * surfaces.shadowDepthScale,
            shadowOffset: surfaces.shadowOffsetSm * surfaces.shadowDepthScale,
            child: content,
          )
        : Container(
            margin: margin,
            decoration: _buildSolidDecoration(
              scheme,
              surfaces,
              resolvedRadius,
              glassTint,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(resolvedRadius),
              clipBehavior: clipBehavior,
              child: content,
            ),
          );

    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: context.motion.panelTransitionDuration,
        curve: context.motion.normal,
        child: surface,
      ),
    );
  }

  double _resolveGlassSigma(AppSurfaceTokens surfaces) {
    final densityScale = switch (glassDensity) {
      AppSurfaceGlassDensity.low => 1.0,
      AppSurfaceGlassDensity.medium => 1.12,
      AppSurfaceGlassDensity.high => 1.24,
    };
    return surfaces.glassSigma * densityScale;
  }

  double _variantSigmaScale() {
    return switch (variant) {
      AppSurfaceVariant.inset => 0.72,
      AppSurfaceVariant.raised => 0.88,
      AppSurfaceVariant.floating => 1.04,
      AppSurfaceVariant.glass => 1.0,
    };
  }

  bool _resolveApplyBlur(AppSurfaceTokens surfaces) {
    return switch (backdropBehavior) {
      AppSurfaceBackdropBehavior.themeDefault =>
        surfaces.backdropStrategy != AppBackdropStrategy.solid,
      AppSurfaceBackdropBehavior.preferStableGlass => false,
      AppSurfaceBackdropBehavior.forceBlur => true,
    };
  }

  BoxDecoration _buildSolidDecoration(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    double radius,
    Color glassTint,
  ) {
    final isSharpCard =
        AppSettings.instance.uiVisualStyleMode == UiVisualStyleMode.sharpCard;
    final isDark = scheme.brightness == Brightness.dark;
    final depthScale = surfaces.shadowDepthScale;
    
    // 极简锐利模式：使用原始 base，消除 glass 模式下默认的玻璃色混合
    final baseColor = switch (variant) {
      AppSurfaceVariant.inset => surfaces.surfaceInset,
      AppSurfaceVariant.raised => surfaces.surfaceRaised,
      AppSurfaceVariant.floating => surfaces.surfaceFloating,
      AppSurfaceVariant.glass => isSharpCard
          ? surfaces.surfaceRaised // 修复：卡片必须对应 surfaceContainer/surfaceRaised 才能与周围面板 CpSurfaceTone.panel 完全一致
          : Color.alphaBlend(
              glassTint.withValues(alpha: scheme.brightness == Brightness.dark ? 0.28 : 0.12),
              surfaces.surfaceRaised.withValues(alpha: surfaces.glassAlpha),
            ),
    };

    final outerShadow = switch (variant) {
      AppSurfaceVariant.inset => <BoxShadow>[],
      AppSurfaceVariant.raised => [
          BoxShadow(
            color: surfaces.shadowColor,
            blurRadius: surfaces.shadowBlurSm * depthScale,
            offset: Offset(0, surfaces.shadowOffsetSm * depthScale),
          ),
          BoxShadow(
            color: surfaces.highlightColor,
            blurRadius: 12,
            offset: const Offset(-2, -2),
            spreadRadius: -2,
          ),
        ],
      AppSurfaceVariant.floating => [
          BoxShadow(
            color: surfaces.shadowColor,
            blurRadius: surfaces.shadowBlurLg * depthScale,
            offset: Offset(0, surfaces.shadowOffsetLg * depthScale),
          ),
          BoxShadow(
            color: surfaces.highlightColor,
            blurRadius: 18,
            offset: const Offset(-3, -3),
            spreadRadius: -4,
          ),
        ],
      AppSurfaceVariant.glass => <BoxShadow>[],
    };

    return BoxDecoration(
      // 极简锐利模式：使用 100% 绝对实色，不叠加 panelAlpha 衰减，避免变黑
      color: isSharpCard ? baseColor : baseColor.withValues(alpha: surfaces.panelAlpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isSharpCard
            ? surfaces.strokeSubtle.withValues(alpha: isDark ? 0.35 : 0.6)
            : switch (variant) {
                AppSurfaceVariant.inset => surfaces.strokeSubtle,
                AppSurfaceVariant.glass => Colors.white.withValues(alpha: 0.08),
                _ => surfaces.strokeStrong.withValues(alpha: 0.72),
              },
      ),
      boxShadow: outerShadow,
      // 极简锐利模式：彻底抛弃所有渐变，使用完全平铺纯色画板
      gradient: isSharpCard
          ? null
          : switch (variant) {
              AppSurfaceVariant.inset => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withValues(alpha: 0.96),
                    baseColor.withValues(alpha: 0.82),
                  ],
                ),
              AppSurfaceVariant.glass => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      scheme.primary.withValues(alpha: 0.08),
                      baseColor.withValues(alpha: 0.94),
                    ),
                    baseColor.withValues(alpha: 0.84),
                  ],
                ),
              _ => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withValues(alpha: 0.96),
                    baseColor,
                  ],
                ),
            },
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.variant,
    required this.radius,
    required this.margin,
    required this.clipBehavior,
    required this.sigma,
    required this.applyBlur,
    required this.tintColor,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.child,
  });

  final AppSurfaceVariant variant;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;
  final double sigma;
  final bool applyBlur;
  final Color tintColor;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    final isDark = scheme.brightness == Brightness.dark;
    final isSharpCard = AppSettings.instance.uiVisualStyleMode == UiVisualStyleMode.sharpCard;

    // 彻底摒弃硬编码死深色，统一下发消费 AppSurfaceTokens，确保极简锐利模式统一为精致石墨黑 (#18191C)，动态模式完全融合封面色
    final base = switch (variant) {
      AppSurfaceVariant.inset => surfaces.surfaceInset,
      AppSurfaceVariant.raised => surfaces.surfaceRaised,
      AppSurfaceVariant.floating => surfaces.surfaceFloating,
      AppSurfaceVariant.glass => isSharpCard 
          ? surfaces.surfaceRaised 
          : surfaces.surfaceBase,
    };
    final tintAlpha = switch (variant) {
      AppSurfaceVariant.inset => 0.1,
      AppSurfaceVariant.raised => 0.13,
      AppSurfaceVariant.floating => isDark ? 0.22 : 0.16,
      AppSurfaceVariant.glass => isDark ? 0.36 : 0.18,
    };
    final fillAlpha = switch (variant) {
      AppSurfaceVariant.inset => isDark ? 0.28 : 0.3,
      AppSurfaceVariant.raised => isDark ? 0.3 : 0.36,
      AppSurfaceVariant.floating => isDark ? 0.36 : 0.44,
      AppSurfaceVariant.glass => isDark ? 0.28 : 0.34,
    };

    // 极简锐利模式：卡片背景与周围主面板 100% 同色平铺无缝融合 (#181A1F)
    final cardBase = base;

    final background = isSharpCard
        ? cardBase
        : Color.alphaBlend(
            tintColor.withValues(alpha: tintAlpha),
            base.withValues(alpha: fillAlpha),
          );

    final decoration = BoxDecoration(
      color: isSharpCard ? cardBase : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isSharpCard
            ? surfaces.strokeSubtle.withValues(alpha: isDark ? 0.35 : 0.6)
            : Colors.white.withValues(alpha: isDark ? 0.18 : 0.52),
        width: 1,
      ),
      gradient: isSharpCard
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.46),
                  background,
                ),
                Color.alphaBlend(
                  tintColor.withValues(alpha: isDark ? 0.1 : 0.06),
                  background.withValues(alpha: isDark ? 0.78 : 0.68),
                ),
              ],
            ),
    );

    final inner = Container(decoration: decoration, child: child);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.18),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
          ),
          BoxShadow(
            color: tintColor.withValues(alpha: 0.08),
            blurRadius: shadowBlur * 0.72,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clipBehavior,
        child: applyBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: inner,
              )
            : inner,
      ),
    );
  }
}
