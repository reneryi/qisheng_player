import 'package:flutter/material.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

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
/// 默认呈现无界极简悬浮 (borderless) 风格：去底色与硬边框、呼吸微光胶囊、+1.5px 悬浮微动
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
    final isDark = scheme.brightness == Brightness.dark;

    final resolvedRadius = widget.radius ?? surfaces.radiusXl;
    final contentChild = RepaintBoundary(child: widget.child);
    final content = widget.padding == null
        ? contentChild
        : Padding(padding: widget.padding!, child: contentChild);

    // 默认 0 边框、0 阴影，Hover 时浮现与主题色呼应的柔和呼吸微光胶囊（杜绝脏黑高亮）
    final glowColor = _isHovered
        ? (isDark
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.primary.withValues(alpha: 0.08))
        : Colors.transparent;

    final decoration = BoxDecoration(
      color: glowColor,
      borderRadius: BorderRadius.circular(resolvedRadius),
      boxShadow: _isHovered
          ? [
              BoxShadow(
                color: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ]
          : const [],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: const Cubic(0.05, 0.7, 0.1, 1.0),
        margin: widget.margin,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -1.5, 0.0)
            : Matrix4.identity(),
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(resolvedRadius),
          clipBehavior: widget.clipBehavior,
          child: content,
        ),
      ),
    );
  }
}
