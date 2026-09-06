import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

/// 高性能弹簧微交互反馈组件：
/// 提供具有物理质量、刚度与阻尼的悬浮微放大和按压弹性缩放体验。
class SpringScaleFeedback extends StatefulWidget {
  const SpringScaleFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.hoverScale = 1.035,
    this.pressedScale = 0.96,
    this.alignment = Alignment.center,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final double hoverScale;
  final double pressedScale;
  final Alignment alignment;
  final HitTestBehavior behavior;
  final bool enabled;

  @override
  State<SpringScaleFeedback> createState() => _SpringScaleFeedbackState();
}

class _SpringScaleFeedbackState extends State<SpringScaleFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHovering = false;
  bool _isPressed = false;

  // 弹簧物理参数配置：刚度 280, 阻尼 24.0 (阻尼比 ~0.82 黄金弹簧物理模型)
  static const SpringDescription _springDesc = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 24.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _targetScale(UiEffectsLevel effectsLevel) {
    if (effectsLevel == UiEffectsLevel.performance || !widget.enabled) {
      return 1.0;
    }
    if (_isPressed) {
      return widget.pressedScale;
    }
    if (_isHovering) {
      return widget.hoverScale;
    }
    return 1.0;
  }

  void _animateToTarget(UiEffectsLevel effectsLevel) {
    final target = _targetScale(effectsLevel);
    if (effectsLevel == UiEffectsLevel.performance || !widget.enabled) {
      _controller.value = 1.0;
      return;
    }

    if (effectsLevel == UiEffectsLevel.visual) {
      final simulation = SpringSimulation(
        _springDesc,
        _controller.value,
        target,
        0,
      );
      _controller.animateWith(simulation);
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectsLevel = context.surfaces.effectsLevel;

    return MouseRegion(
      cursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (!mounted || !widget.enabled) return;
        _isHovering = true;
        _animateToTarget(effectsLevel);
      },
      onExit: (_) {
        if (!mounted || !widget.enabled) return;
        _isHovering = false;
        _isPressed = false;
        _animateToTarget(effectsLevel);
      },
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) {
          if (!mounted || !widget.enabled) return;
          _isPressed = true;
          _animateToTarget(effectsLevel);
        },
        onTapUp: (_) {
          if (!mounted || !widget.enabled) return;
          _isPressed = false;
          _animateToTarget(effectsLevel);
        },
        onTapCancel: () {
          if (!mounted || !widget.enabled) return;
          _isPressed = false;
          _animateToTarget(effectsLevel);
        },
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onSecondaryTap: widget.enabled ? widget.onSecondaryTap : null,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _controller.value,
                alignment: widget.alignment,
                child: child,
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
