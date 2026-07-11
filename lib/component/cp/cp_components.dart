import 'dart:ui';

import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

enum CpButtonVariant { primary, secondary, outline, ghost, destructive, immersive } // 按钮变体，新增 immersive 表示沉浸式样式

enum CpSurfaceTone { panel, card, subtle, floating }

class CpAnimatedSwitcher extends StatelessWidget {
  const CpAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration,
    this.reverseDuration,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration? duration;
  final Duration? reverseDuration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return AnimatedSwitcher(
      duration: duration ?? motion.controlTransitionDuration,
      reverseDuration: reverseDuration ?? motion.microInteractionDuration,
      switchInCurve: motion.emphasized,
      switchOutCurve: motion.fast,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: alignment,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved =
            CurvedAnimation(parent: animation, curve: motion.emphasized);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class CpMotionPressable extends StatefulWidget {
  const CpMotionPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTapDown,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.enabled = true,
    this.semanticLabel,
    this.hoverScale = 1.0,
    this.pressScale = 0.992,
    this.hoverShadow = false,
    this.selectedGlow = false,
    this.hoverShadowOpacity,
    this.selectedGlowOpacity,
    this.border = true, // 是否绘制外边边框，默认为 true。增加此参数以便实现无边框悬浮呼吸效果。
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool enabled;
  final String? semanticLabel;
  final double hoverScale;
  final double pressScale;
  final bool hoverShadow;
  final bool selectedGlow;
  final double? hoverShadowOpacity;
  final double? selectedGlowOpacity;
  final bool border; // 是否绘制边框标志

  @override
  State<CpMotionPressable> createState() => _CpMotionPressableState();
}

class _CpMotionPressableState extends State<CpMotionPressable> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final surfaces = context.surfaces;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(surfaces.radiusLg);
    final active = _hovered || widget.selected;
    final scale = _pressed
        ? widget.pressScale
        : _hovered
            ? widget.hoverScale
            : 1.0;
    final background = widget.selected
        ? scheme.primary.withValues(alpha: 0.13)
        : _hovered
            ? scheme.onSurface.withValues(alpha: 0.055)
            : Colors.transparent;
    final shadows = _buildShadows(context);

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _interactive ? widget.onTap : null,
        onTapDown: _interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            _interactive ? () => setState(() => _pressed = false) : null,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: Semantics(
          button: widget.onTap != null,
          selected: widget.selected,
          label: widget.semanticLabel,
          child: AnimatedScale(
            scale: scale,
            duration: motion.microInteractionDuration,
            curve: motion.fast,
            child: AnimatedContainer(
              duration: motion.microInteractionDuration,
              curve: motion.normal,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: background,
                borderRadius: radius,
                border: widget.border
                    ? Border.all(
                        color: active
                            ? widget.selected
                                ? scheme.primary.withValues(alpha: 0.34)
                                : scheme.outlineVariant.withValues(alpha: 0.52)
                            : Colors.transparent,
                        width: 1,
                      )
                    : null,
                boxShadow: shadows,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _buildShadows(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    final shadows = <BoxShadow>[];

    if (widget.hoverShadow && _hovered && _interactive) {
      final opacity = widget.hoverShadowOpacity ??
          (scheme.brightness == Brightness.dark ? 0.22 : 0.14);
      shadows.add(
        BoxShadow(
          color: surfaces.shadowColor.withValues(
            alpha: opacity * surfaces.shadowDepthScale,
          ),
          blurRadius: surfaces.shadowBlurSm * 0.78,
          offset: Offset(0, surfaces.shadowOffsetSm * 0.54),
        ),
      );
    }

    if (widget.selectedGlow && widget.selected) {
      final opacity = widget.selectedGlowOpacity ?? 0.18;
      shadows.add(
        BoxShadow(
          color: scheme.primary.withValues(alpha: opacity),
          blurRadius: surfaces.shadowBlurSm * 0.86,
          spreadRadius: 0.4,
        ),
      );
    }

    return shadows;
  }
}

class CpSurface extends StatelessWidget {
  const CpSurface({
    super.key,
    required this.child,
    this.tone = CpSurfaceTone.card,
    this.padding,
    this.radius,
    this.margin,
    this.border = true,
    this.clip = true,
  });

  final Widget child;
  final CpSurfaceTone tone;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final EdgeInsetsGeometry? margin;
  final bool border;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final surfaces = context.surfaces;
    final resolvedRadius = radius ??
        switch (tone) {
          CpSurfaceTone.panel => surfaces.radiusXxl,
          CpSurfaceTone.card => surfaces.radiusXl,
          CpSurfaceTone.subtle => surfaces.radiusLg,
          CpSurfaceTone.floating => surfaces.radiusXxl,
        };
    final isDark = scheme.brightness == Brightness.dark;
    
    // 基础面板及容器颜色设定
    final baseColor = switch (tone) {
      CpSurfaceTone.panel => scheme.surfaceContainer,
      CpSurfaceTone.card => scheme.surfaceContainerHighest,
      CpSurfaceTone.subtle => scheme.surfaceContainerLow,
      CpSurfaceTone.floating => scheme.surfaceContainerHighest,
    };
    
    // 自适应不透明度计算：绑定 AppSurfaceTokens 的 panelAlpha 和 glassAlpha
    // 能够根据当前设置的背景材质（云母/亚克力等）做出完美的透明度反应，防止挡住系统桌面背景
    final resolvedOpacity = switch (tone) {
      CpSurfaceTone.panel => surfaces.panelAlpha * (isDark ? 0.72 : 0.75),
      CpSurfaceTone.floating => surfaces.panelAlpha * (isDark ? 0.76 : 0.82),
      CpSurfaceTone.card => surfaces.glassAlpha * (isDark ? 0.88 : 0.92),
      CpSurfaceTone.subtle => surfaces.glassAlpha * (isDark ? 0.64 : 0.68),
    };
    
    final color = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.12 : 0.04),
      baseColor.withValues(alpha: resolvedOpacity),
    );
    
    final shadow = tone == CpSurfaceTone.floating
        ? [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: isDark ? 0.2 : 0.12),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.08),
              blurRadius: 30,
              spreadRadius: -8,
            ),
          ]
        : const <BoxShadow>[];
        
    final applyBlur = surfaces.backdropStrategy != AppBackdropStrategy.solid;

    // 微光渐变描边优化：混合主导强调色和白色，使边框在暗黑与亮色下均有温润的情感氛围微光
    final glowBorderColor = Color.lerp(
      scheme.primary.withValues(alpha: isDark ? 0.18 : 0.36),
      Colors.white.withValues(alpha: isDark ? 0.12 : 0.44),
      0.72, // 72% 白色与 28% 主题色混合
    )!;

    final content = AnimatedContainer(
      duration: motion.panelTransitionDuration,
      curve: motion.normal,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(resolvedRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.08 : 0.46),
              color,
            ),
            Color.alphaBlend(
              scheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
              color.withValues(alpha: isDark ? 0.78 : 0.68),
            ),
          ],
        ),
        border: border
            ? Border.all(
                color: glowBorderColor,
                width: 1.0,
              )
            : null,
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );

    if (!clip) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(resolvedRadius),
      child: applyBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: surfaces.glassSigma * _toneSigmaScale(),
                sigmaY: surfaces.glassSigma * _toneSigmaScale(),
              ),
              child: content,
            )
          : content,
    );
  }

  double _toneSigmaScale() {
    return switch (tone) {
      CpSurfaceTone.panel => 0.86,
      CpSurfaceTone.card => 0.78,
      CpSurfaceTone.subtle => 0.62,
      CpSurfaceTone.floating => 1.0,
    };
  }
}

class CpButton extends StatelessWidget {
  const CpButton({
    super.key,
    required this.child,
    this.onPressed,
    this.leading,
    this.trailing,
    this.variant = CpButtonVariant.secondary,
    this.small = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final CpButtonVariant variant;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        child,
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 9);

    return switch (variant) {
      CpButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(padding: padding),
          child: content,
        ),
      CpButtonVariant.secondary => FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(padding: padding),
          child: content,
        ),
      CpButtonVariant.outline => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: padding),
          child: content,
        ),
      CpButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(padding: padding),
          child: content,
        ),
      CpButtonVariant.destructive => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: content,
        ),
      // 沉浸式文本按钮样式分支：完全透明背景，通过 WidgetStateProperty 动态高亮文本和图标
      CpButtonVariant.immersive => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: padding,
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
          ).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final scheme = Theme.of(context).colorScheme;
              if (states.contains(WidgetState.disabled)) {
                return scheme.onSurface.withValues(alpha: 0.34);
              }
              if (states.contains(WidgetState.pressed)) {
                return scheme.primary; // 按下时为品牌强调色
              }
              if (states.contains(WidgetState.hovered)) {
                return scheme.onSurface; // 悬停时文本完全高亮
              }
              return scheme.onSurface.withValues(alpha: 0.62); // 默认状态下为半透明
            }),
          ),
          child: content,
        ),
    };
  }
}

class CpIconButton extends StatelessWidget {
  const CpIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.variant = CpButtonVariant.ghost,
    this.small = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final CpButtonVariant variant;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      enableFeedback: false,
      icon: icon,
      style: _iconButtonStyle(context),
      visualDensity: small ? VisualDensity.compact : VisualDensity.standard,
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  ButtonStyle? _iconButtonStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    final glassShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(surfaces.radiusXxl),
    );
    return switch (variant) {
      CpButtonVariant.primary => IconButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: glassShape,
        ),
      CpButtonVariant.secondary => IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          foregroundColor: scheme.onSecondaryContainer,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          shape: glassShape,
        ),
      CpButtonVariant.outline => IconButton.styleFrom(
          side:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.72)),
          shape: glassShape,
        ),
      CpButtonVariant.ghost => IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.075),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          shape: glassShape,
        ),
      CpButtonVariant.destructive => IconButton.styleFrom(
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
          shape: glassShape,
        ),
      // 沉浸式按钮样式：默认完全透明无描边，悬停与按下时仅改变图标颜色/亮度，无任何背景色和物理边框
      CpButtonVariant.immersive => IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onSurface.withValues(alpha: 0.62),
          side: BorderSide.none,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: glassShape,
        ).copyWith(
          // 动态调整图标颜色以满足交互反馈（Hover 高亮，Pressed 显示强调色）
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.34);
            }
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary; // 按下时呈现主题高亮强调色
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.onSurface; // 悬停时图标完全高亮不透明
            }
            return scheme.onSurface.withValues(alpha: 0.62); // 默认显示 62% 不透明度
          }),
        ),
    };
  }
}

class CpListTile extends StatelessWidget {
  const CpListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onSecondaryTapDown,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return CpMotionPressable(
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      selected: selected,
      padding: padding,
      hoverScale: 1.006,
      pressScale: 0.992,
      hoverShadow: true,
      selectedGlow: true,
      hoverShadowOpacity: 0.1,
      selectedGlowOpacity: 0.12,
      child: Row(
        children: [
          if (leading != null) ...[
            RepaintBoundary(child: leading!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.58),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
