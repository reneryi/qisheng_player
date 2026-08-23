import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

/// 纯绘制层歌词过渡容器：保持歌词行的布局绝对稳定，提供丝滑优雅的聚焦与位移过渡
class LyricLineMotion extends StatelessWidget {
  const LyricLineMotion({
    super.key,
    required this.isCurrent,
    required this.child,
    this.distanceFromCurrent = 0,
    this.alignment = Alignment.center,
  });

  final bool isCurrent;
  final int distanceFromCurrent;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enableMotion = !reduceMotion &&
        context.surfaces.effectsLevel != UiEffectsLevel.performance;

    // 采用沉稳克制的 240ms 缓动，避免快歌连续切句时文字剧烈回弹导致的视觉眩晕
    final duration = enableMotion
        ? const Duration(milliseconds: 240)
        : Duration.zero;
    final curve = motion.emphasized; // 使用平滑的三次方缓动 Curves.easeOutCubic
    final depth = distanceFromCurrent.clamp(0, 3);

    return AnimatedSlide(
      duration: duration,
      curve: curve,
      offset: isCurrent ? Offset.zero : Offset(0, 0.008 * depth),
      child: AnimatedScale(
        duration: duration,
        curve: curve,
        scale: isCurrent ? 1.0 : (1.0 - 0.005 * depth),
        alignment: alignment,
        child: child,
      ),
    );
  }
}
