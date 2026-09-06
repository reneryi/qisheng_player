import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

const nowPlayingArtworkHeroTag = 'now-playing-artwork';
const nowPlayingArtworkHeroRadius = 26.0;

/// 高性能平滑弧线 RectTween
class NowPlayingArtworkRectTween extends RectTween {
  NowPlayingArtworkRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    if (begin == null || end == null) return null;
    final rect = Rect.lerp(begin, end, t)!;
    final arcProgress = math.sin(t * math.pi);
    final travelDistance = (end!.center - begin!.center).distance;
    // 极其柔和轻盈的物理微弧，消除反向退场时向上高高扬起后再重重砸落底栏的悬停弹跳感
    final arcAmplitude = (travelDistance * 0.012).clamp(0.0, 7.0);
    final offsetY = -arcAmplitude * arcProgress;

    return Rect.fromLTWH(
      rect.left,
      rect.top + offsetY,
      rect.width,
      rect.height,
    );
  }
}

NowPlayingArtworkCard? _extractArtworkCard(Widget? widget) {
  if (widget is NowPlayingArtworkCard) return widget;
  if (widget is RepaintBoundary && widget.child is NowPlayingArtworkCard) {
    return widget.child as NowPlayingArtworkCard;
  }
  return null;
}

/// 单层无虚影飞行穿梭构建器（插值圆角与阴影）
Widget nowPlayingArtworkFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;

  final fromCard = _extractArtworkCard(fromHero.child);
  final toCard = _extractArtworkCard(toHero.child);

  final startRadius = fromCard?.radius ??
      (direction == HeroFlightDirection.push
          ? nowPlayingArtworkHeroRadius
          : 24.0);
  final endRadius = toCard?.radius ??
      (direction == HeroFlightDirection.push
          ? 24.0
          : nowPlayingArtworkHeroRadius);

  final audio = toCard?.audio ?? fromCard?.audio;
  final provider = toCard?.coverProvider ??
      fromCard?.coverProvider ??
      NowPlayingArtworkCard.getSyncCover(audio);

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value;
      final currentRadius = ui.lerpDouble(startRadius, endRadius, t)!;

      return Material(
        type: MaterialType.transparency,
        child: NowPlayingArtworkCard(
          audio: audio,
          coverProvider: provider,
          radius: currentRadius,
          elevation: 1.0,
          showShadow: true,
        ),
      );
    },
  );
}

/// 播放封面画册通用外框容器（提供标准圆角裁切与柔和黑色投影）
class NowPlayingArtworkHeroFrame extends StatelessWidget {
  const NowPlayingArtworkHeroFrame({
    super.key,
    required this.child,
    this.radius = nowPlayingArtworkHeroRadius,
    this.elevation = 1.0,
    this.showShadow = true,
  });

  final Widget child;
  final double radius;
  final double elevation;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22 * elevation),
                  blurRadius: 20 * elevation,
                  spreadRadius: -4 * elevation,
                  offset: Offset(0, 8 * elevation),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: RepaintBoundary(
          child: child,
        ),
      ),
    );
  }
}

/// 统一播放封面画册核心组件（底栏与播放详情页 1:1 共享）
class NowPlayingArtworkCard extends StatelessWidget {
  const NowPlayingArtworkCard({
    super.key,
    required this.audio,
    this.coverProvider,
    this.radius = nowPlayingArtworkHeroRadius,
    this.elevation = 1.0,
    this.showShadow = true,
  });

  final Audio? audio;
  final ImageProvider? coverProvider;
  final double radius;
  final double elevation;
  final bool showShadow;

  /// 全局同步封面内存缓存，杜绝任何页面转场与 Hero 降落时刻 FutureBuilder 的 1 帧占位闪屏
  static final Map<String, ImageProvider> _syncCoverCache = {};

  static ImageProvider? getSyncCover(Audio? audio) {
    if (audio == null) return null;
    return _syncCoverCache[audio.path];
  }

  static void cacheSyncCover(Audio? audio, ImageProvider? provider) {
    if (audio == null || provider == null) return;
    if (_syncCoverCache.length > 100) {
      _syncCoverCache.remove(_syncCoverCache.keys.first);
    }
    _syncCoverCache[audio.path] = provider;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;

    if (coverProvider != null && audio != null) {
      cacheSyncCover(audio, coverProvider);
    }
    final cachedProvider = coverProvider ?? getSyncCover(audio);

    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            accents.accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Icon(
          Symbols.music_note,
          color: scheme.onSurface.withValues(alpha: 0.7),
          size: 28,
        ),
      ),
    );

    final Widget imageWidget;
    if (cachedProvider != null) {
      imageWidget = Image(
        image: cachedProvider,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else if (audio == null) {
      imageWidget = placeholder;
    } else {
      imageWidget = FutureBuilder<ImageProvider?>(
        future: audio!.cover,
        builder: (context, snapshot) {
          final provider = snapshot.data;
          if (provider != null) {
            cacheSyncCover(audio, provider);
            return Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => placeholder,
            );
          }
          final fallbackSync = getSyncCover(audio);
          if (fallbackSync != null) {
            return Image(
              image: fallbackSync,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => placeholder,
            );
          }
          return placeholder;
        },
      );
    }

    return NowPlayingArtworkHeroFrame(
      radius: radius,
      elevation: elevation,
      showShadow: showShadow,
      child: imageWidget,
    );
  }
}
