import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';

/// 歌词景深模糊最大散焦强度（高斯模糊 Sigma 上限）
const double lyricDepthMaxBlurSigma = 5.5;

/// 根据与当前正在播放歌词行的相对距离，计算光学景深梯级模糊度 (Sigma)
///
/// 模拟大光圈相机的物理景深渐进散焦与阅读流向：
/// - [distanceFromCurrent] <= 0（当前播放行）：处于焦平面中心，绝对清晰锐利 (0.0)
/// - [distanceFromCurrent] == 1（紧邻行）：
///     - 若 [blurAdjacent] 为 true，应用轻柔浅景深（约 1.3~1.5），既保证辅助视线与歌词可读性，又让焦点稳固留在当前行；
///     - 若 [blurAdjacent] 为 false（兼容传统宽松模式），保持 0.0；
/// - [distanceFromCurrent] == 2（次级行）：中度弥散模糊（约 2.8~3.2），显著退出视觉聚焦；
/// - [distanceFromCurrent] == 3（深层行）：深度散焦（约 4.0~4.5）；
/// - [distanceFromCurrent] >= 4（远景行）：完全进入背景大气散景 (上限 [lyricDepthMaxBlurSigma])。
/// - [isPastLine]：已唱完的历史行比尚未唱到的未来行多略微深一度散焦，契合用户的顺流阅读与预读心理。
double resolveLyricDepthBlurSigma({
  required int distanceFromCurrent,
  required bool enabled,
  required UiEffectsLevel effectsLevel,
  bool blurAdjacent = true,
  bool isPastLine = false,
  bool isHovered = false,
}) {
  if (!enabled ||
      effectsLevel != UiEffectsLevel.visual ||
      distanceFromCurrent <= 0) {
    return 0;
  }
  if (isHovered) {
    // 悬停交互探视：鼠标滑过时临时降低模糊度至接近合焦，方便用户清晰阅读与点击 Seek
    return 0.3;
  }
  return switch (distanceFromCurrent) {
    1 => blurAdjacent ? (isPastLine ? 1.5 : 1.3) : 0.0,
    2 => isPastLine ? 3.2 : 2.8,
    3 => isPastLine ? 4.5 : 4.0,
    _ => lyricDepthMaxBlurSigma,
  };
}

/// 计算非当前行与当前行之间的光学景深不透明度阶梯
double resolveLyricLineOpacity({
  required int distanceFromCurrent,
  required bool isPastLine,
  bool depthBlurEnabled = false,
  bool isHovered = false,
}) {
  if (distanceFromCurrent <= 0) return 1.0;
  if (isHovered) return 0.95;

  if (depthBlurEnabled) {
    // 开启景深模糊时，高斯扩散会分散文字像素能量，
    // 需保留更充沛的不透明度底色（避免低透光叠加高模糊导致文字发黑、发脏或彻底无法辨认），
    // 呈现如大光圈镜头散景般的通透梦幻质感。
    return switch (distanceFromCurrent) {
      1 => isPastLine ? 0.68 : 0.76,
      2 => isPastLine ? 0.48 : 0.56,
      _ => isPastLine ? 0.36 : 0.42,
    };
  }

  // 未开启景深模糊时的传统透明度分级
  return switch (distanceFromCurrent) {
    1 => isPastLine ? 0.58 : 0.64,
    2 => isPastLine ? 0.40 : 0.46,
    _ => isPastLine ? 0.26 : 0.32,
  };
}

ImageFilter createLyricDepthBlurFilter(double sigma) => ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.decal,
    );

bool shouldApplyLyricDepthBlur({
  required int distanceFromCurrent,
  required bool enabled,
  required UiEffectsLevel effectsLevel,
  bool blurAdjacent = true,
}) {
  return resolveLyricDepthBlurSigma(
        distanceFromCurrent: distanceFromCurrent,
        enabled: enabled,
        effectsLevel: effectsLevel,
        blurAdjacent: blurAdjacent,
      ) >
      0;
}

/// 具备电影级平滑拉焦（Rack Focus Transition）的歌词景深模糊容器
///
/// 当歌词行在当前播放焦点与非焦点之间切换时，滤镜的模糊度会随时间曲线平滑插值过渡，
/// 规避生硬的单帧模糊跳变，同时在完全合焦状态下自动短路移除 [ImageFiltered] 离屏渲染开销。
class AnimatedLyricDepthBlur extends StatelessWidget {
  const AnimatedLyricDepthBlur({
    super.key,
    required this.sigma,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
  });

  final double sigma;
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween<double>(end: sigma),
      builder: (context, animatedSigma, cachedChild) {
        if (animatedSigma <= 0.05) {
          return cachedChild!;
        }
        return ImageFiltered(
          imageFilter: createLyricDepthBlurFilter(animatedSigma),
          child: cachedChild,
        );
      },
      child: child,
    );
  }
}
