import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

/// 动态情感交融流体背景组件
/// 能够随歌曲专辑封面的主色调缓慢交融流动，提供极其灵动的质感
class FluidGradientBackground extends StatefulWidget {
  const FluidGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<FluidGradientBackground> createState() => _FluidGradientBackgroundState();
}

class _FluidGradientBackgroundState extends State<FluidGradientBackground>
    with TickerProviderStateMixin {
  // 慢速流体运动动画控制器
  late final AnimationController _fluidController;
  // 颜色平滑渐变过渡动画控制器
  late final AnimationController _colorTransitionController;

  // 默认的主题色彩，在未播放或无封面时使用 Zinc/Slate 的高雅冷灰色调
  static const Color _defaultColor1 = Color(0xFF1E293B); // Slate 800
  static const Color _defaultColor2 = Color(0xFF0F172A); // Slate 900
  static const Color _defaultColor3 = Color(0xFF020617); // Slate 950

  List<Color> _sourceColors = [_defaultColor1, _defaultColor2, _defaultColor3];
  List<Color> _targetColors = [_defaultColor1, _defaultColor2, _defaultColor3];
  List<Color> _currentColors = [_defaultColor1, _defaultColor2, _defaultColor3];

  Audio? _lastAudio;

  @override
  void initState() {
    super.initState();
    // 25 秒超慢循环：用于驱动背景流体光源的平移流动，确保灵动且温和
    _fluidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    // 1.5 秒颜色渐变控制器：用于在切换新歌曲、提取出新色调时，实现色彩过渡的无缝化
    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        setState(() {
          final t = _colorTransitionController.value;
          for (int i = 0; i < 3; i++) {
            _currentColors[i] = Color.lerp(_sourceColors[i], _targetColors[i], t) ?? _targetColors[i];
          }
        });
      });
  }

  @override
  void dispose() {
    _fluidController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  /// 异步提取专辑封面颜色并触发平滑渐变
  Future<void> _updateColorsForAudio(Audio? audio) async {
    if (audio == null) {
      _triggerColorTransition([_defaultColor1, _defaultColor2, _defaultColor3]);
      return;
    }

    try {
      final coverProvider = await audio.cover;
      if (coverProvider == null) {
        _triggerColorTransition([_defaultColor1, _defaultColor2, _defaultColor3]);
        return;
      }

      // 使用 PaletteGenerator 异步提取封面主色
      final palette = await PaletteGenerator.fromImageProvider(
        coverProvider,
        maximumColorCount: 8,
      );

      final isDark = Theme.of(context).brightness == Brightness.dark;

      // 提取主色调，若提取失败则使用具有音乐氛围的替代色
      final dominant = palette.dominantColor?.color ?? _defaultColor1;
      final vibrant = palette.vibrantColor?.color ?? palette.mutedColor?.color ?? _defaultColor2;
      final darkMuted = palette.darkMutedColor?.color ?? palette.lightMutedColor?.color ?? _defaultColor3;

      // 针对深浅色模式做适当的亮暗微调，使其在背景下更为和谐，保护前台文字的可读性
      List<Color> newColors;
      if (isDark) {
        newColors = [
          Color.alphaBlend(Colors.black.withOpacity(0.55), dominant),
          Color.alphaBlend(Colors.black.withOpacity(0.70), vibrant),
          Color.alphaBlend(Colors.black.withOpacity(0.85), darkMuted),
        ];
      } else {
        newColors = [
          Color.alphaBlend(Colors.white.withOpacity(0.65), dominant),
          Color.alphaBlend(Colors.white.withOpacity(0.75), vibrant),
          Color.alphaBlend(Colors.white.withOpacity(0.85), darkMuted),
        ];
      }

      _triggerColorTransition(newColors);
    } catch (_) {
      // 提取失败时 fallback 到默认冷灰色
      _triggerColorTransition([_defaultColor1, _defaultColor2, _defaultColor3]);
    }
  }

  void _triggerColorTransition(List<Color> newColors) {
    _sourceColors = List.from(_currentColors);
    _targetColors = newColors;
    _colorTransitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final currentAudio = playback.nowPlaying;

    // 监控切歌状态
    if (currentAudio != _lastAudio) {
      _lastAudio = currentAudio;
      // 触发异步颜色更新
      scheduleMicrotask(() => _updateColorsForAudio(currentAudio));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 流体渲染 Canvas 层：在其内绘制慢速移动的径向渐变
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _fluidController,
            builder: (context, _) {
              return CustomPaint(
                painter: _FluidGradientPainter(
                  colors: _currentColors,
                  progress: _fluidController.value,
                ),
              );
            },
          ),
        ),
        // 2. 超强模糊毛玻璃层：把上面的多光源径向渐变，完美相融渲染成平滑温润的“流体渐变”
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 96, sigmaY: 96),
            child: const SizedBox.shrink(),
          ),
        ),
        // 3. 微弱的遮罩叠加层：保证前台文字和控件有足够的高对比度与舒适观感
        Positioned.fill(
          child: Container(
            color: isDark
                ? Colors.black.withOpacity(0.38)  // 暗黑模式：加一层朦胧半透黑，保护前景色
                : Colors.white.withOpacity(0.48), // 亮色模式：加一层朦胧半透白，防晃眼
          ),
        ),
        // 4. 内容层
        widget.child,
      ],
    );
  }
}

/// 绘制流体背景中漂移色块的 Painter
class _FluidGradientPainter extends CustomPainter {
  const _FluidGradientPainter({
    required this.colors,
    required this.progress,
  });

  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final angle = progress * math.pi * 2;

    // 1. 铺设底色：使用最暗/最淡的主色作为底层画布铺垫
    final bgPaint = Paint()..color = colors[2];
    canvas.drawRect(rect, bgPaint);

    // 2. 计算光源 1 的运动轨迹：利用正弦与余弦实现圆周状慢飘移动
    final center1 = Offset(
      size.width * (0.5 + 0.3 * math.sin(angle)),
      size.height * (0.4 + 0.25 * math.cos(angle)),
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [colors[0], colors[0].withOpacity(0)],
        radius: 0.9,
      ).createShader(Rect.fromCircle(center: center1, radius: size.width * 0.9));
    canvas.drawCircle(center1, size.width * 0.9, paint1);

    // 3. 计算光源 2 的运动轨迹：相位相差 pi/2，实现相向而行的交织流动
    final center2 = Offset(
      size.width * (0.4 + 0.28 * math.cos(angle + math.pi / 2)),
      size.height * (0.6 + 0.22 * math.sin(angle + math.pi / 3)),
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [colors[1], colors[1].withOpacity(0)],
        radius: 0.8,
      ).createShader(Rect.fromCircle(center: center2, radius: size.width * 0.8));
    canvas.drawCircle(center2, size.width * 0.8, paint2);

    // 4. 计算光源 3 的运动轨迹：相位相差 pi，在窗口下部和对角线区域呼应
    final center3 = Offset(
      size.width * (0.6 + 0.25 * math.sin(angle + math.pi)),
      size.height * (0.5 + 0.28 * math.cos(angle + math.pi / 4)),
    );
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [colors[0].withOpacity(0.85), colors[0].withOpacity(0)],
        radius: 0.75,
      ).createShader(Rect.fromCircle(center: center3, radius: size.width * 0.75));
    canvas.drawCircle(center3, size.width * 0.75, paint3);
  }

  @override
  bool shouldRepaint(covariant _FluidGradientPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
