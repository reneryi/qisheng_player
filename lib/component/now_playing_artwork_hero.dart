import 'dart:math' as math;
import 'package:flutter/material.dart';

const nowPlayingArtworkHeroTag = 'now-playing-artwork';
const nowPlayingArtworkHeroRadius = 26.0;

// 自定义的高抛弧线 Tween，让共享元素封面飞越轨迹呈显著的物理抛物线
class CustomIntenseArcTween extends RectTween {
  CustomIntenseArcTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    if (begin == null || end == null) return null;
    // 基础的线性大小和位置插值
    final rect = Rect.lerp(begin, end, t)!;

    // 采用正弦函数产生高抛拱起进度：t 在 0.5 时达到最大高抛点
    final arcProgress = math.sin(t * math.pi);

    // 强行在 Y 轴方向加深高抛幅度（向上偏移 110 像素），使飞越轨迹极其瞩目和优雅
    final double offsetY = -110.0 * arcProgress;

    return Rect.fromLTWH(
      rect.left,
      rect.top + offsetY,
      rect.width,
      rect.height,
    );
  }
}

Widget nowPlayingArtworkFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final resolvedHero = (direction == HeroFlightDirection.push
      ? toHeroContext.widget
      : fromHeroContext.widget) as Hero;

  // 去除半透明渐显渐隐过渡，直接返回实心 child，使封面在飞行时的视觉实体感更加坚实清晰
  return resolvedHero.child;
}

class NowPlayingArtworkHeroFrame extends StatelessWidget {
  const NowPlayingArtworkHeroFrame({
    super.key,
    required this.child,
    this.radius = nowPlayingArtworkHeroRadius,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            spreadRadius: -6,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
