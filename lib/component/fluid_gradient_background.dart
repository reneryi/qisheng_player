import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme_provider.dart';

List<Color> resolveFluidGradientColors(
  AlbumPalette palette,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  final overlay = isDark ? Colors.black : Colors.white;
  final luminance = (palette.primary.computeLuminance() +
          palette.secondary.computeLuminance() +
          palette.accent.computeLuminance()) /
      3;
  final baseAlpha = isDark
      ? (0.16 + luminance * 0.10).clamp(0.12, 0.28)
      : (0.10 + (1 - luminance) * 0.06).clamp(0.08, 0.18);
  final alphas = [
    baseAlpha,
    (baseAlpha + 0.04).clamp(0.0, 1.0),
    (baseAlpha + 0.08).clamp(0.0, 1.0),
  ];
  final paletteColors = [palette.primary, palette.secondary, palette.accent];
  return [
    for (var index = 0; index < paletteColors.length; index++)
      Color.alphaBlend(
        overlay.withValues(alpha: alphas[index]),
        paletteColors[index],
      ),
  ];
}

Color resolveFluidBaseColor(List<Color> colors) {
  if (colors.isEmpty) return const Color(0xFF0F172A);
  final primary = colors[0];
  final secondary = colors.length > 1 ? colors[1] : primary;
  final accent = colors.length > 2 ? colors[2] : secondary;
  return Color.lerp(
    Color.lerp(primary, secondary, 0.24),
    accent,
    0.10,
  )!;
}

double resolveFluidScrimOpacity(List<Color> colors, Brightness brightness) {
  if (colors.isEmpty) return brightness == Brightness.dark ? 0.22 : 0.28;
  final luminance = colors
          .map((color) => color.computeLuminance())
          .reduce((left, right) => left + right) /
      colors.length;
  return brightness == Brightness.dark
      ? (0.12 + luminance * 0.18).clamp(0.12, 0.24)
      : (0.18 + (1 - luminance) * 0.10).clamp(0.16, 0.28);
}

/// 动态情感交融流体背景组件
/// 能够随歌曲专辑封面的主色调缓慢交融流动，提供极其灵动的质感
class FluidGradientBackground extends StatefulWidget {
  const FluidGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<FluidGradientBackground> createState() =>
      _FluidGradientBackgroundState();
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
  final List<Color> _currentColors = [
    _defaultColor1,
    _defaultColor2,
    _defaultColor3,
  ];

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
            _currentColors[i] =
                Color.lerp(_sourceColors[i], _targetColors[i], t) ??
                    _targetColors[i];
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = context.watch<ThemeProvider>();
    final newColors = resolveFluidGradientColors(
      theme.albumPalette,
      Theme.of(context).brightness,
    );
    if (_sameColors(_targetColors, newColors)) return;
    _triggerColorTransition(newColors);
  }

  bool _sameColors(List<Color> first, List<Color> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _triggerColorTransition(List<Color> newColors) {
    _sourceColors = List.from(_currentColors);
    _targetColors = newColors;
    _colorTransitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.watch<ThemeProvider>();
    final backdropMode = theme.windowBackdropMode;

    // 若当前不是极光流体模式，需做材质隔离
    if (backdropMode != WindowBackdropMode.fluid) {
      // 1. 如果是关闭材质效果，需要显示实色的主题底色作为软件不透光背景
      if (backdropMode == WindowBackdropMode.none) {
        return Container(
          color: isDark
              ? const Color(0xFF0F141C) // 极简暗黑实色背景
              : const Color(0xFFF3F6FB), // 洁净亮白实色背景
          child: widget.child,
        );
      }
      // 2. 如果是云母、云母 Alt、亚克力等原生系统材质，底层必须保持完全透明，让原生桌面背景透过来
      return widget.child;
    }

    // 极光流体模式 (Flutter 软件渲染)
    final scrimOpacity = resolveFluidScrimOpacity(
      _currentColors,
      Theme.of(context).brightness,
    );
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
                  scrimOpacity: scrimOpacity,
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
                ? Colors.black.withValues(alpha: scrimOpacity)
                : Colors.white.withValues(alpha: scrimOpacity),
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
    required this.scrimOpacity,
  });

  final List<Color> colors;
  final double progress;
  final double scrimOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final angle = progress * math.pi * 2;

    // 1. 铺设底色：使用最暗/最淡的主色作为底层画布铺垫
    final bgPaint = Paint()..color = resolveFluidBaseColor(colors);
    canvas.drawRect(rect, bgPaint);

    // 2. 计算光源 1 的运动轨迹：利用正弦与余弦实现圆周状慢飘移动
    final center1 = Offset(
      size.width * (0.5 + 0.3 * math.sin(angle)),
      size.height * (0.4 + 0.25 * math.cos(angle)),
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [colors[0], colors[0].withValues(alpha: 0)],
        radius: 0.9,
      ).createShader(
          Rect.fromCircle(center: center1, radius: size.width * 0.9));
    canvas.drawCircle(center1, size.width * 0.9, paint1);

    // 3. 计算光源 2 的运动轨迹：相位相差 pi/2，实现相向而行的交织流动
    final center2 = Offset(
      size.width * (0.4 + 0.28 * math.cos(angle + math.pi / 2)),
      size.height * (0.6 + 0.22 * math.sin(angle + math.pi / 3)),
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [colors[1], colors[1].withValues(alpha: 0)],
        radius: 0.8,
      ).createShader(
          Rect.fromCircle(center: center2, radius: size.width * 0.8));
    canvas.drawCircle(center2, size.width * 0.8, paint2);

    // 4. 计算光源 3 的运动轨迹：相位相差 pi，在窗口下部和对角线区域呼应
    final center3 = Offset(
      size.width * (0.6 + 0.25 * math.sin(angle + math.pi)),
      size.height * (0.5 + 0.28 * math.cos(angle + math.pi / 4)),
    );
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[2].withValues(alpha: 0.85),
          colors[2].withValues(alpha: 0),
        ],
        radius: 0.75,
      ).createShader(
          Rect.fromCircle(center: center3, radius: size.width * 0.75));
    canvas.drawCircle(center3, size.width * 0.75, paint3);
  }

  @override
  bool shouldRepaint(covariant _FluidGradientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colors != colors ||
        oldDelegate.scrimOpacity != scrimOpacity;
  }
}
