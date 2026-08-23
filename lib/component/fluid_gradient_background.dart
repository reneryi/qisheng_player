import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/theme_provider.dart';

/// 栖声播放器多材质窗口背景容器 (Multi-Material Window Backdrop Pipeline)
class FluidGradientBackground extends StatefulWidget {
  const FluidGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<FluidGradientBackground> createState() =>
      _FluidGradientBackgroundState();
}

class _FluidGradientBackgroundState extends State<FluidGradientBackground>
    with SingleTickerProviderStateMixin {
  // 着色器程序实例缓存
  static ui.FragmentProgram? _meshFlowProgram;
  static ui.FragmentProgram? _waterRippleProgram;
  static ui.FragmentProgram? _lensGlassProgram;

  late final AnimationController _animController;
  double _elapsedTime = 0;

  // 鼠标交互状态（用于水波纹着色器）
  Offset _mousePos = const Offset(0.5, 0.5);
  double _mouseSpeed = 0.0;
  Offset _lastMousePos = const Offset(0.5, 0.5);
  Offset _clickPos = const Offset(-1.0, -1.0);
  DateTime _lastClickTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        setState(() {
          _elapsedTime += 0.016;
        });
      });
    _animController.repeat();

    _loadShaders();
  }

  Future<void> _loadShaders() async {
    try {
      _meshFlowProgram ??=
          await ui.FragmentProgram.fromAsset('shaders/mesh_flow.frag');
      _waterRippleProgram ??=
          await ui.FragmentProgram.fromAsset('shaders/water_ripple.frag');
      _lensGlassProgram ??=
          await ui.FragmentProgram.fromAsset('shaders/lens_glass.frag');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final normalized = Offset(
      event.localPosition.dx / size.width,
      event.localPosition.dy / size.height,
    );
    final dist = (normalized - _lastMousePos).distance;
    setState(() {
      _mouseSpeed = (_mouseSpeed * 0.7) + (dist * 15.0).clamp(0.0, 1.0);
      _mousePos = normalized;
      _lastMousePos = normalized;
    });
  }

  void _onPointerDown(PointerDownEvent event, Size size) {
    if (size.width == 0 || size.height == 0) return;
    setState(() {
      _clickPos = Offset(
        event.localPosition.dx / size.width,
        event.localPosition.dy / size.height,
      );
      _lastClickTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final chrome = context.chrome;

    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.instance.backgroundVersion,
      builder: (context, _, __) {
        final backgroundFile = _resolveBackgroundFile();

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            return Listener(
              onPointerHover: (e) => _onPointerHover(e, size),
              onPointerDown: (e) => _onPointerDown(e, size),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackdropLayer(context, theme, size),
                  if (backgroundFile != null)
                    _UserBackgroundImage(
                      file: backgroundFile,
                      tint: chrome.windowScrim,
                    ),
                  widget.child,
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackdropLayer(
    BuildContext context,
    ThemeProvider theme,
    Size size,
  ) {
    final mode = theme.effectiveWindowBackdropMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = theme.albumPalette;

    // 1. 原生增强型云母 (Mica Alt) 或 实时亚克力 (Acrylic)
    // DWM 材质由系统绘制在窗口背后（最大化/全屏时同样持续生效），本层只保留
    // 极低透明度衬底。严格遵循微软规范：想要透出材质的层必须尽量透明。
    // Mica Alt: 0.06~0.10 极淡底衬，壁纸珠光与色泽浸润完整透出（与 Win11 设置/记事本一致）
    // Acrylic: 0.12~0.15 柔光 scrim，兼顾实时毛玻璃通透与前文文字可读性
    if (mode == WindowBackdropMode.micaAlt ||
        mode == WindowBackdropMode.acrylic) {
      final bool isMicaAlt = mode == WindowBackdropMode.micaAlt;
      final double topScrimAlpha = isMicaAlt ? 0.06 : 0.12;
      final double bottomScrimAlpha = isMicaAlt ? 0.10 : 0.15;

      final topColor = isDark
          ? const Color(0xFF0A1324).withValues(alpha: topScrimAlpha)
          : const Color(0xFFF6F8FA).withValues(alpha: topScrimAlpha);
      final bottomColor = isDark
          ? const Color(0xFF070D18).withValues(alpha: bottomScrimAlpha)
          : const Color(0xFFE8EBF0).withValues(alpha: bottomScrimAlpha);

      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, bottomColor],
          ),
        ),
      );
    }

    // 2. 弥散流彩 / 灵动流光 (Mesh Flow)
    if (mode == WindowBackdropMode.meshFlow && _meshFlowProgram != null) {
      return CustomPaint(
        size: size,
        painter: _MeshFlowPainter(
          program: _meshFlowProgram!,
          time: _elapsedTime,
          palette: palette,
          isDark: isDark,
          baseGradient: theme.backgroundGradient,
        ),
      );
    }

    // 3. 交互水波纹 (Interactive Water Ripple - 独立自洽深色水光)
    if (mode == WindowBackdropMode.waterRipple && _waterRippleProgram != null) {
      final clickElapsed =
          DateTime.now().difference(_lastClickTime).inMilliseconds / 1000.0;
      return CustomPaint(
        size: size,
        painter: _WaterRipplePainter(
          program: _waterRippleProgram!,
          time: _elapsedTime,
          mousePos: _mousePos,
          mouseSpeed: _mouseSpeed,
          clickPos: _clickPos,
          clickTime: clickElapsed,
          bassEnergy: 0.0, // 将在有音频播放时注入低音振幅
        ),
      );
    }

    // 4. 琉璃透镜 (Prismatic Glass)
    if (mode == WindowBackdropMode.prismaticGlass &&
        _lensGlassProgram != null) {
      return CustomPaint(
        size: size,
        painter: _LensGlassPainter(
          program: _lensGlassProgram!,
          time: _elapsedTime,
          tintColor: theme.glassTint,
          isDark: isDark,
        ),
      );
    }

    // 5. 原生默认对角渐变 (Default 135° Gradient: 日间柔和纸白 vs 夜间深邃午夜蓝)
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.backgroundGradient,
        ),
      ),
    );
  }

  File? _resolveBackgroundFile() {
    final path = AppSettings.instance.backgroundImagePath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }
}

/// 弥散流彩着色器绘制器
class _MeshFlowPainter extends CustomPainter {
  const _MeshFlowPainter({
    required this.program,
    required this.time,
    required this.palette,
    required this.isDark,
    required this.baseGradient,
  });

  final ui.FragmentProgram program;
  final double time;
  final AlbumPalette palette;
  final bool isDark;
  final List<Color> baseGradient;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final shader = program.fragmentShader();

    // uniforms 传递
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    // 5 色调和
    _setColor(shader, 3, palette.primary);
    _setColor(shader, 7, palette.secondary);
    _setColor(shader, 11, palette.accent);
    _setColor(shader, 15, palette.muted);
    _setColor(shader, 19, palette.highlight);

    // 底板色
    final baseColor = baseGradient.isNotEmpty
        ? baseGradient.first
        : (isDark ? const Color(0xFF0A1324) : const Color(0xFFF6F8FA));
    _setColor(shader, 23, baseColor);

    // 5 个动态光斑锚点 (基于时间正弦缓慢公转推移)
    final t = time * 0.15;
    shader.setFloat(27, 0.25 + 0.18 * math.cos(t));
    shader.setFloat(28, 0.30 + 0.18 * math.sin(t));

    shader.setFloat(29, 0.75 + 0.15 * math.sin(t * 0.8));
    shader.setFloat(30, 0.25 + 0.15 * math.cos(t * 0.8));

    shader.setFloat(31, 0.35 + 0.20 * math.sin(t * 1.2));
    shader.setFloat(32, 0.75 + 0.15 * math.cos(t * 1.2));

    shader.setFloat(33, 0.80 + 0.12 * math.cos(t * 0.6));
    shader.setFloat(34, 0.70 + 0.16 * math.sin(t * 0.6));

    shader.setFloat(35, 0.50 + 0.14 * math.cos(t * 1.1));
    shader.setFloat(36, 0.50 + 0.14 * math.sin(t * 1.1));

    // 明暗模式控制与强度
    shader.setFloat(37, isDark ? 1.0 : 0.0);
    shader.setFloat(38, 1.0); // 强度

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _setColor(ui.FragmentShader shader, int startIndex, Color color) {
    shader.setFloat(startIndex, color.r);
    shader.setFloat(startIndex + 1, color.g);
    shader.setFloat(startIndex + 2, color.b);
    shader.setFloat(startIndex + 3, color.a);
  }

  @override
  bool shouldRepaint(covariant _MeshFlowPainter oldDelegate) => true;
}

/// 交互水波纹着色器绘制器
class _WaterRipplePainter extends CustomPainter {
  const _WaterRipplePainter({
    required this.program,
    required this.time,
    required this.mousePos,
    required this.mouseSpeed,
    required this.clickPos,
    required this.clickTime,
    required this.bassEnergy,
  });

  final ui.FragmentProgram program;
  final double time;
  final Offset mousePos;
  final double mouseSpeed;
  final Offset clickPos;
  final double clickTime;
  final double bassEnergy;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    shader.setFloat(3, mousePos.dx);
    shader.setFloat(4, mousePos.dy);
    shader.setFloat(5, mouseSpeed);

    shader.setFloat(6, clickPos.dx);
    shader.setFloat(7, clickPos.dy);
    shader.setFloat(8, clickTime);

    shader.setFloat(9, bassEnergy);

    // 深水色、浅水色与镜面高光色 (独立深邃幽静水光空间)
    _setColor(shader, 10, const Color(0xFF06101E));
    _setColor(shader, 14, const Color(0xFF0F2C4A));
    _setColor(shader, 18, const Color(0xFF90D5FF));

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _setColor(ui.FragmentShader shader, int startIndex, Color color) {
    shader.setFloat(startIndex, color.r);
    shader.setFloat(startIndex + 1, color.g);
    shader.setFloat(startIndex + 2, color.b);
    shader.setFloat(startIndex + 3, color.a);
  }

  @override
  bool shouldRepaint(covariant _WaterRipplePainter oldDelegate) => true;
}

/// 琉璃透镜着色器绘制器
class _LensGlassPainter extends CustomPainter {
  const _LensGlassPainter({
    required this.program,
    required this.time,
    required this.tintColor,
    required this.isDark,
  });

  final ui.FragmentProgram program;
  final double time;
  final Color tintColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    // 动态氛围微染色
    shader.setFloat(3, tintColor.r);
    shader.setFloat(4, tintColor.g);
    shader.setFloat(5, tintColor.b);
    shader.setFloat(6, tintColor.a);

    shader.setFloat(7, isDark ? 1.0 : 0.0);
    shader.setFloat(8, 0.85); // 折射强度

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _LensGlassPainter oldDelegate) => true;
}

class _UserBackgroundImage extends StatelessWidget {
  const _UserBackgroundImage({required this.file, required this.tint});

  final File file;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: AppSettings.instance.backgroundImageOpacity,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            ColoredBox(color: tint),
          ],
        ),
      ),
    );
  }
}
