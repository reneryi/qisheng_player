import 'dart:ui';

import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:coriander_player/theme_provider.dart';
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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AppSurfaceVariant variant;
  final double? radius;
  final Clip clipBehavior;
  final AppSurfaceGlassDensity glassDensity;

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
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);

    final surface = switch (variant) {
      AppSurfaceVariant.glass => _GlassSurface(
          radius: resolvedRadius,
          margin: margin,
          clipBehavior: clipBehavior,
          sigma: _resolveGlassSigma(surfaces),
          applyBlur: surfaces.backdropStrategy != AppBackdropStrategy.solid,
          tintColor: glassTint,
          shadowColor: surfaces.shadowColor,
          shadowBlur: surfaces.shadowBlurLg * surfaces.shadowDepthScale,
          shadowOffset: surfaces.shadowOffsetSm * surfaces.shadowDepthScale,
          child: content,
        ),
      _ => Container(
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
        ),
    };

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

  BoxDecoration _buildSolidDecoration(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    double radius,
    Color glassTint,
  ) {
    final depthScale = surfaces.shadowDepthScale;
    final baseColor = switch (variant) {
      AppSurfaceVariant.inset => surfaces.surfaceInset,
      AppSurfaceVariant.raised => surfaces.surfaceRaised,
      AppSurfaceVariant.floating => surfaces.surfaceFloating,
      AppSurfaceVariant.glass => Color.alphaBlend(
          glassTint.withValues(alpha: 0.12),
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
      color: baseColor.withValues(alpha: surfaces.panelAlpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: switch (variant) {
          AppSurfaceVariant.inset => surfaces.strokeSubtle,
          AppSurfaceVariant.glass => Colors.white.withValues(alpha: 0.08),
          _ => surfaces.strokeStrong.withValues(alpha: 0.72),
        },
      ),
      boxShadow: outerShadow,
      gradient: switch (variant) {
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
    // 现代简约：微调毛玻璃底色混合度
    final background = Color.alphaBlend(
      tintColor.withValues(alpha: 0.14),
      Colors.white.withValues(alpha: 0.04),
    );

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      // 现代简约：稍微增强内边框可见度
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.10),
        width: 1,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          background.withValues(alpha: 0.96),
          background.withValues(alpha: 0.82),
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
            color: shadowColor.withValues(alpha: 0.22),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
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
