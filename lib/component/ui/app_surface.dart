import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/theme_provider.dart';

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

/// 栖声播放器现代 UI 表面容器 (UI Surface Container)
/// 负责实现纯净实体卡片 (solidCard)、无界极简悬浮 (borderless)、液态玻璃 (liquidGlass)
class AppSurface extends StatefulWidget {
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
  State<AppSurface> createState() => _AppSurfaceState();
}

class _AppSurfaceState extends State<AppSurface> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    final styleMode = context.select<ThemeProvider, UiVisualStyleMode>(
      (p) => p.visualStyleMode,
    );
    Color glassTint = scheme.primary;
    try {
      glassTint = context.select<ThemeProvider, Color>(
        (provider) => provider.glassTint,
      );
    } catch (_) {}

    final resolvedRadius = widget.radius ?? surfaces.radiusXl;
    final contentChild = RepaintBoundary(child: widget.child);
    final content = widget.padding == null
        ? contentChild
        : Padding(padding: widget.padding!, child: contentChild);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: const Cubic(0.05, 0.7, 0.1, 1.0),
        margin: widget.margin,
        transform: (styleMode == UiVisualStyleMode.borderless && _isHovered)
            ? Matrix4.translationValues(0.0, -1.5, 0.0)
            : Matrix4.identity(),
        child: _buildSurfaceContent(
          context,
          styleMode,
          scheme,
          surfaces,
          resolvedRadius,
          glassTint,
          content,
        ),
      ),
    );
  }

  Widget _buildSurfaceContent(
    BuildContext context,
    UiVisualStyleMode styleMode,
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    double radius,
    Color glassTint,
    Widget content,
  ) {
    return switch (styleMode) {
      // 1. 纯净实体卡片风格
      UiVisualStyleMode.solidCard => _buildSolidCard(
          scheme,
          surfaces,
          radius,
          content,
        ),

      // 2. 无界极简悬浮风格
      UiVisualStyleMode.borderless => _buildBorderless(
          scheme,
          surfaces,
          radius,
          content,
        ),

      // 3. 液态玻璃空间风格 (Apple iOS / visionOS 空间 UI 质感)
      UiVisualStyleMode.liquidGlass => _buildLiquidGlass(
          scheme,
          surfaces,
          radius,
          glassTint,
          content,
        ),
    };
  }

  Widget _buildSolidCard(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    double radius,
    Widget content,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = switch (widget.variant) {
      AppSurfaceVariant.inset => surfaces.surfaceInset,
      AppSurfaceVariant.raised => surfaces.surfaceRaised,
      AppSurfaceVariant.floating => surfaces.surfaceFloating,
      AppSurfaceVariant.glass => surfaces.surfaceRaised,
    };

    final decoration = BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? const Color(0xFF2C3A52).withValues(alpha: 0.65)
            : const Color(0xFFE1E4E8),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

    return Container(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: widget.clipBehavior,
        child: content,
      ),
    );
  }

  Widget _buildBorderless(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    double radius,
    Widget content,
  ) {
    final isDark = scheme.brightness == Brightness.dark;

    // 默认 0 边框、0 阴影，Hover 时浮现呼吸微光胶囊
    final glowColor = _isHovered
        ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
        : Colors.transparent;

    final decoration = BoxDecoration(
      color: glowColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: _isHovered
          ? [
              BoxShadow(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ]
          : const [],
    );

    return Container(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: widget.clipBehavior,
        child: content,
      ),
    );
  }

  Widget _buildLiquidGlass(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    double radius,
    Color glassTint,
    Widget content,
  ) {
    final isDark = scheme.brightness == Brightness.dark;

    // 液态玻璃底色与内边缘次表面高光
    final glassFill = Color.alphaBlend(
      glassTint.withValues(alpha: isDark ? 0.16 : 0.08),
      (isDark ? const Color(0xFF0C1626) : Colors.white).withValues(alpha: isDark ? 0.45 : 0.65),
    );

    final decoration = BoxDecoration(
      color: glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: _isHovered ? 0.28 : 0.16)
            : Colors.white.withValues(alpha: _isHovered ? 0.90 : 0.70),
        width: 1.2,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // 左上受光面 1.2px 内高光反射
          (isDark ? Colors.white : Colors.white).withValues(alpha: isDark ? 0.15 : 0.50),
          // 顺滑过渡到底色
          glassFill,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
          blurRadius: 22,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: widget.clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }
}
