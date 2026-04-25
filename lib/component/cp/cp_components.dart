import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

enum CpButtonVariant { primary, secondary, outline, ghost, destructive }

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
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool enabled;
  final String? semanticLabel;

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
    final background = widget.selected
        ? scheme.primary.withValues(alpha: 0.13)
        : _hovered
            ? scheme.onSurface.withValues(alpha: 0.055)
            : Colors.transparent;

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
            scale: _pressed ? 0.992 : 1,
            duration: motion.microInteractionDuration,
            curve: motion.fast,
            child: AnimatedContainer(
              duration: motion.microInteractionDuration,
              curve: motion.normal,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: background,
                borderRadius: radius,
                border: Border.all(
                  color: active
                      ? scheme.outlineVariant.withValues(alpha: 0.52)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
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
    final color = switch (tone) {
      CpSurfaceTone.panel => scheme.surfaceContainer.withValues(alpha: 0.72),
      CpSurfaceTone.card =>
        scheme.surfaceContainerHighest.withValues(alpha: 0.58),
      CpSurfaceTone.subtle =>
        scheme.surfaceContainerLow.withValues(alpha: 0.42),
      CpSurfaceTone.floating =>
        scheme.surfaceContainerHighest.withValues(alpha: 0.78),
    };
    final shadow = tone == CpSurfaceTone.floating
        ? [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ]
        : const <BoxShadow>[];

    final content = AnimatedContainer(
      duration: motion.panelTransitionDuration,
      curve: motion.normal,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: border
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28))
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
      child: content,
    );
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
      icon: icon,
      style: _iconButtonStyle(context),
      visualDensity: small ? VisualDensity.compact : VisualDensity.standard,
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  ButtonStyle? _iconButtonStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (variant) {
      CpButtonVariant.primary => IconButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      CpButtonVariant.secondary => IconButton.styleFrom(
          backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.72),
          foregroundColor: scheme.onSecondaryContainer,
        ),
      CpButtonVariant.outline => IconButton.styleFrom(
          side:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.72)),
        ),
      CpButtonVariant.ghost => IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onSurface,
        ),
      CpButtonVariant.destructive => IconButton.styleFrom(
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
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
