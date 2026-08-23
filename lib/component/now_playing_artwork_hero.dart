import 'dart:math' as math;
import 'package:flutter/material.dart';

const nowPlayingArtworkHeroTag = 'now-playing-artwork';
const nowPlayingArtworkHeroRadius = 26.0;

class NowPlayingArtworkRectTween extends RectTween {
  NowPlayingArtworkRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    if (begin == null || end == null) return null;
    final rect = Rect.lerp(begin, end, t)!;
    final arcProgress = math.sin(t * math.pi);
    final travelDistance = (end!.center - begin!.center).distance;
    final offsetY =
        -1.0 * (travelDistance * 0.06).clamp(12.0, 40.0) * arcProgress;

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
