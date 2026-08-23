import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

/// 桌面原生级清脆菜单展开动效
/// 保持 Material 的菜单语义，同时以极速（130ms）淡入与微位移展开，消除多行果冻弹跳
class AnimatedMenuContent extends StatelessWidget {
  const AnimatedMenuContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = theme.extension<AppMotionTokens>();
    final effectsLevel = theme.extension<AppSurfaceTokens>()?.effectsLevel ??
        UiEffectsLevel.balanced;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // 若开启减弱动态效果或为极简性能模式，仅使用超短淡入
    if (reduceMotion || effectsLevel == UiEffectsLevel.performance) {
      return Animate(
        effects: const [
          FadeEffect(
            duration: Duration(milliseconds: 80),
            curve: Curves.linear,
          ),
        ],
        child: child,
      );
    }

    // 现代桌面标准：130ms 迅速淡入 + 3px 轻柔上浮微位移，清脆干净
    return Animate(
      effects: [
        FadeEffect(
          duration: const Duration(milliseconds: 130),
          curve: motion?.fast ?? Curves.easeOutCubic,
        ),
        MoveEffect(
          begin: const Offset(0, 3), // 仅 3 像素微位移，避免遮挡与命中测试抖动
          end: Offset.zero,
          duration: const Duration(milliseconds: 130),
          curve: motion?.fast ?? Curves.easeOutCubic,
          transformHitTests: false,
        ),
      ],
      child: child,
    );
  }
}

/// 快速为一组菜单项注入优雅的挂载动画
List<Widget> animatedMenuChildren(
  BuildContext context,
  Iterable<Widget> children,
) {
  return [
    for (final child in children) AnimatedMenuContent(child: child),
  ];
}
