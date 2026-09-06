import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

/// 弹出栖声播放器专属的现代毛玻璃桌面弹窗
Future<T?> showModernDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
}) {
  final motion = context.motion;

  return showGeneralDialog<T>(
    context: context,
    // 原生 barrier 始终设为 true 且透明，彻底绕过 Flutter SDK 在 dismissible: false 时硬编码调用的 SystemSound.play(SystemSoundType.alert)
    barrierDismissible: true,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: motion.panelTransitionDuration,
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      return _ModernDialogScaffold(
        barrierDismissible: barrierDismissible,
        animation: animation,
        child: builder(buildContext),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: motion.emphasized,
        reverseCurve: motion.fast,
      );

      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 16.0 * curved.value,
          sigmaY: 16.0 * curved.value,
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ModernDialogScaffold extends StatefulWidget {
  const _ModernDialogScaffold({
    required this.barrierDismissible,
    required this.animation,
    required this.child,
  });

  final bool barrierDismissible;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_ModernDialogScaffold> createState() => _ModernDialogScaffoldState();
}

class _ModernDialogScaffoldState extends State<_ModernDialogScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onBarrierTapped() {
    if (widget.barrierDismissible) {
      Navigator.of(context).maybePop();
    } else {
      // 静默消费点击手势，绝不向下穿透，绝不触发系统反馈音；通过微抖动优雅提示窗口需优先操作
      if (!_shakeController.isAnimating) {
        _shakeController.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final isDark = scheme.brightness == Brightness.dark;

    final scaleCurved = CurvedAnimation(
      parent: widget.animation,
      curve: motion.emphasized,
      reverseCurve: motion.fast,
    );

    return Stack(
      children: [
        // 100% 全域覆盖的防穿透静音遮罩底座
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onBarrierTapped,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, _) {
                return Container(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.45 * widget.animation.value)
                      : Colors.black.withValues(alpha: 0.25 * widget.animation.value),
                );
              },
            ),
          ),
        ),
        // 居中呈现的卡片实体，带入场缩放与不可关闭时的提示微晃反馈
        SafeArea(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(scaleCurved),
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

/// 现代弹窗容器组件（对齐播放队列抽屉的动态取色流光毛玻璃设计）
class ModernDialogFrame extends StatelessWidget {
  const ModernDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;
    final isDark = scheme.brightness == Brightness.dark;
    const blurSigma = 24.0;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(surfaces.radiusXxl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 4),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(surfaces.radiusXxl),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(surfaces.radiusXxl),
                    color: isDark
                        ? Color.alphaBlend(
                            scheme.primary.withValues(alpha: 0.08),
                            const Color(0xFF131822).withValues(alpha: 0.82),
                          )
                        : Color.alphaBlend(
                            scheme.primary.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.86),
                          ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.06),
                              scheme.primary.withValues(alpha: 0.03),
                              Colors.transparent,
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.65),
                              scheme.surfaceContainerLowest
                                  .withValues(alpha: 0.4),
                            ],
                      stops: isDark ? const [0.0, 0.45, 1.0] : null,
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: padding,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

