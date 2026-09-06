import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/album_palette.dart';
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
    with TickerProviderStateMixin {
  // 着色器程序实例缓存
  static ui.FragmentProgram? _meshFlowProgram;
  static ui.FragmentProgram? _waterRippleProgram;

  late final AnimationController _animController;
  AnimationController? _paletteTransitionController;
  AnimationController? _brightnessTransitionController;

  // 懒加载安全获取色彩过渡控制器（1200ms 感知平滑渐变融化，专注切歌色彩平滑过渡）
  AnimationController get _paletteController {
    return _paletteTransitionController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((_) => _syncTickerState());
  }

  // 懒加载安全获取明暗切换控制器（350ms 无痕平滑过渡，与全局 UI 动画同频同步）
  AnimationController get _brightnessController {
    return _brightnessTransitionController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    )..addStatusListener((_) => _syncTickerState());
  }

  // 切歌色彩平滑过渡状态（丝滑渐变融化）
  AlbumPalette? _currentInterpolatedPalette;
  AlbumPalette? _fromPalette;
  AlbumPalette? _targetPalette;

  // 独立多波源水波纹物理管理器 (0 setState，纯 GPU 驱动)
  final WaterRippleManager _rippleManager = WaterRippleManager();

  // 系统级高精度单调计时器，用于着色器时间源
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    // 60/120fps VSync 动画时钟，直接驱动 CustomPainter，绝不在每帧触发全局 setState
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _loadShaders();
  }

  void _syncTickerState([WindowBackdropMode? explicitMode]) {
    if (!mounted) return;
    try {
      final mode = explicitMode ??
          Provider.of<ThemeProvider>(context, listen: false)
              .effectiveWindowBackdropMode;
      final isDynamicShader = mode == WindowBackdropMode.meshFlow ||
          mode == WindowBackdropMode.waterRipple;
      final isPaletteAnimating = _paletteTransitionController != null &&
          _paletteTransitionController!.isAnimating;
      final isBrightnessAnimating = _brightnessTransitionController != null &&
          _brightnessTransitionController!.isAnimating;

      final shouldTick =
          isDynamicShader || isPaletteAnimating || isBrightnessAnimating;
      if (shouldTick) {
        if (!_animController.isAnimating) {
          _animController.repeat();
        }
      } else {
        if (_animController.isAnimating) {
          _animController.stop();
        }
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Provider.of<ThemeProvider>(context);
    final targetPalette = theme.albumPalette;

    // 关键优化：明暗模式切换直接响应 ThemeProvider 的真实 effectiveBrightness，
    // 彻底消除上层 AnimatedTheme 的 250ms 半程跳变延迟，实现立即可见、同频无痕的 350ms 平滑融化。
    final isDark = theme.effectiveBrightness == Brightness.dark;
    final targetDarkness = isDark ? 1.0 : 0.0;
    if (_brightnessTransitionController == null) {
      _brightnessTransitionController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
        value: targetDarkness,
      )..addStatusListener((_) => _syncTickerState());
    } else if ((_brightnessTransitionController!.value - targetDarkness).abs() >
        0.001) {
      _brightnessTransitionController!.animateTo(
        targetDarkness,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      _syncTickerState();
    }

    // 关键优化：切歌调色板过渡仅当 targetPalette 实际变化时触发，
    // 绝不因为明暗模式切换误触发慢速通道，做到二者完全解耦。
    if (_targetPalette != targetPalette) {
      _fromPalette =
          _currentInterpolatedPalette ?? _targetPalette ?? targetPalette;
      _targetPalette = targetPalette;
      _paletteController.forward(from: 0.0);
      _syncTickerState();
    } else {
      _syncTickerState(theme.effectiveWindowBackdropMode);
    }
  }

  Future<void> _loadShaders() async {
    try {
      _meshFlowProgram ??=
          await ui.FragmentProgram.fromAsset('shaders/mesh_flow.frag');
      _waterRippleProgram ??=
          await ui.FragmentProgram.fromAsset('shaders/water_ripple.frag');
      if (mounted) {
        _syncTickerState();
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _paletteTransitionController?.dispose();
    _brightnessTransitionController?.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final currentTime = _stopwatch.elapsedMicroseconds / 1000000.0;
    final normalized = Offset(
      event.localPosition.dx / size.width,
      event.localPosition.dy / size.height,
    );
    _rippleManager.onPointerMove(
      normalizedPos: normalized,
      screenSize: size,
      currentTime: currentTime,
    );
  }

  void _onPointerDown(PointerDownEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final currentTime = _stopwatch.elapsedMicroseconds / 1000000.0;
    final normalized = Offset(
      event.localPosition.dx / size.width,
      event.localPosition.dy / size.height,
    );
    _rippleManager.addClickRipple(normalized, currentTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.instance.backgroundVersion,
      builder: (context, _, __) {
        final backgroundFile = _resolveBackgroundFile();

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            final listensForPointer = theme.effectiveWindowBackdropMode ==
                WindowBackdropMode.waterRipple;
            return MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final focus = FocusManager.instance.primaryFocus;
                  if (focus != null && focus.hasFocus) {
                    focus.unfocus();
                  }
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerHover:
                      listensForPointer ? (e) => _onPointerHover(e, size) : null,
                  onPointerDown:
                      listensForPointer ? (e) => _onPointerDown(e, size) : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: backgroundFile != null
                            ? _UserBackgroundImage(
                                file: backgroundFile,
                                isDark: theme.effectiveBrightness ==
                                    Brightness.dark,
                              )
                            : _buildBackdropLayer(context, theme, size),
                      ),
                      widget.child,
                    ],
                  ),
                ),
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
    // 使用 AnimatedBuilder 局部监听时钟、切歌控制器与明暗切换控制器，实现 120Hz 满帧自渲染且 0 页面级 Rebuild
    return AnimatedBuilder(
      animation: Listenable.merge([
        _animController,
        _paletteController,
        _brightnessController,
      ]),
      builder: (context, _) {
        final mode = theme.effectiveWindowBackdropMode;
        final targetPalette = theme.albumPalette;

        final double transitionProgress = Curves.easeInOutCubic.transform(
          _paletteController.value,
        );

        final activePalette = AlbumPalette.lerp(
              _fromPalette,
              _targetPalette,
              transitionProgress,
            ) ??
            targetPalette;
        _currentInterpolatedPalette = activePalette;

        // 连续平滑明暗度因子 (0.0: 明亮, 1.0: 夜间)，350ms 贝塞尔曲线
        final double darkness = Curves.easeInOutCubic.transform(
          _brightnessController.value.clamp(0.0, 1.0),
        );

        // 纯净中性对角渐变底色（日间哑光柔和白，夜间深邃暗蓝，随 darkness 350ms Oklab 平滑插值过渡）
        final neutralLight = pureNeutralGradient(Brightness.light);
        final neutralDark = pureNeutralGradient(Brightness.dark);
        final neutralGradient = _lerpGradient(
          neutralLight,
          neutralDark,
          darkness,
        );

        final currentTime = _stopwatch.elapsedMicroseconds / 1000000.0;

        // 1. 弥散流彩 / 灵动流光 (Mesh Flow: Apple Music 级凝聚态流体光斑)
        if (mode == WindowBackdropMode.meshFlow) {
          final lightPalette = activePalette.forLightMode();
          final darkPalette = activePalette.forDarkMode();
          final modePalette = AlbumPalette.lerp(
                lightPalette,
                darkPalette,
                darkness,
              ) ??
              (darkness > 0.5 ? darkPalette : lightPalette);

          final meshLightBase = buildDynamicBackgroundGradient(
            activePalette.secondary,
            Brightness.light,
          );
          final meshDarkBase = buildDynamicBackgroundGradient(
            activePalette.secondary,
            Brightness.dark,
          );
          final meshBaseGradient = _lerpGradient(
            meshLightBase,
            meshDarkBase,
            darkness,
          );

          if (_meshFlowProgram == null) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: meshBaseGradient,
                ),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: meshBaseGradient,
                  ),
                ),
              ),
              CustomPaint(
                size: size,
                painter: _MeshFlowPainter(
                  program: _meshFlowProgram!,
                  time: currentTime,
                  palette: modePalette,
                  darkness: darkness,
                  baseGradient: meshBaseGradient,
                ),
              ),
            ],
          );
        }

        // 2. 交互水波纹 (Interactive Water Ripple - 独立雨天自洽深色水光多波源干涉)
        if (mode == WindowBackdropMode.waterRipple) {
          if (_waterRippleProgram == null) {
            return const ColoredBox(color: Color(0xFF0C1014));
          }

          try {
            final spectrum =
                PlayService.instance.playbackService.audioSpectrum.value;
            if (spectrum.isNotEmpty) {
              _rippleManager.onBassSample(spectrum, currentTime);
            }
          } catch (_) {}

          _rippleManager.updateAmbientRain(currentTime);
          _rippleManager.pruneExpired(currentTime);

          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF0C1014)),
              CustomPaint(
                size: size,
                painter: _WaterRipplePainter(
                  program: _waterRippleProgram!,
                  time: currentTime,
                  ripples: _rippleManager.ripples,
                ),
              ),
            ],
          );
        }

        // 3. 极光漫染 (Aurora Glow: 多色调和的静态高斯漫射光晕)
        if (mode == WindowBackdropMode.prismaticGlass) {
          final lightPalette = activePalette.forLightMode();
          final darkPalette = activePalette.forDarkMode();
          final modePalette = AlbumPalette.lerp(
                lightPalette,
                darkPalette,
                darkness,
              ) ??
              (darkness > 0.5 ? darkPalette : lightPalette);

          final auroraLightBase = buildAuroraGlowGradient(
            activePalette,
            Brightness.light,
          );
          final auroraDarkBase = buildAuroraGlowGradient(
            activePalette,
            Brightness.dark,
          );
          final auroraBaseGradient = _lerpGradient(
            auroraLightBase,
            auroraDarkBase,
            darkness,
          );

          return CustomPaint(
            size: size,
            painter: _AuroraGlowPainter(
              palette: modePalette,
              darkness: darkness,
              baseGradient: auroraBaseGradient,
            ),
          );
        }

        // 4. 原生默认对角渐变 (Default 135° Gradient: 日间哑光柔和白 vs 夜间深邃暗蓝)
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: neutralGradient,
            ),
          ),
        );
      },
    );
  }

  /// 渐变色列表感知均匀 Oklab 线性插值（告别 RGB 跨色相灰色脏区）
  List<Color> _lerpGradient(List<Color> a, List<Color> b, double t) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    final count = math.max(a.length, b.length);
    return List.generate(count, (index) {
      final colorA = a[index % a.length];
      final colorB = b[index % b.length];
      return AlbumPalette.lerpColor(colorA, colorB, t);
    });
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
    double? darkness,
    bool? isDark,
    required this.baseGradient,
  }) : darkness = darkness ?? (isDark == true ? 1.0 : 0.0);

  final ui.FragmentProgram program;
  final double time;
  final AlbumPalette palette;
  final double darkness;
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

    // 底板色（随 baseGradient 平滑插值融化）
    final baseColor = baseGradient.isNotEmpty
        ? baseGradient.first
        : (darkness > 0.5 ? const Color(0xFF0A1324) : const Color(0xFFF6F8FA));
    _setColor(shader, 23, baseColor);

    // 5 个动态流体核心源锚点 (基于大尺度李萨如椭圆与对冲轨迹，8~14 秒周期)
    // 主导色与强调色分布在对角/两侧，配合涡流场形成如 Apple Music 般的强烈色彩冲撞与卷曲
    final t = time * 0.45;

    // 光斑 1 (主导色 Primary): 左侧核心区漫游
    final p1x = (0.28 + 0.20 * math.cos(t * 0.65)).clamp(0.05, 0.95);
    final p1y = (0.42 + 0.18 * math.sin(t * 0.52 + 0.5)).clamp(0.05, 0.95);
    shader.setFloat(27, p1x);
    shader.setFloat(28, p1y);

    // 光斑 2 (次主色 Secondary - 如青蓝): 左下方至底部，向中心螺旋延伸
    final p2x = (0.35 + 0.22 * math.sin(t * 0.58 + 2.0)).clamp(0.05, 0.95);
    final p2y = (0.75 + 0.18 * math.cos(t * 0.48 + 1.2)).clamp(0.05, 0.95);
    shader.setFloat(29, p2x);
    shader.setFloat(30, p2y);

    // 光斑 3 (强调色 Accent - 如鲜艳玫红/朱红): 右侧至右上核心区，强力对冲
    final p3x = (0.75 + 0.18 * math.cos(t * 0.60 + 3.4)).clamp(0.05, 0.95);
    final p3y = (0.35 + 0.22 * math.sin(t * 0.70 + 1.8)).clamp(0.05, 0.95);
    shader.setFloat(31, p3x);
    shader.setFloat(32, p3y);

    // 光斑 4 (柔和底色 Muted): 右下方大面积铺底
    final p4x = (0.70 + 0.20 * math.sin(t * 0.45 + 4.2)).clamp(0.05, 0.95);
    final p4y = (0.78 + 0.16 * math.cos(t * 0.55 + 3.0)).clamp(0.05, 0.95);
    shader.setFloat(33, p4x);
    shader.setFloat(34, p4y);

    // 光斑 5 (高光点缀 Highlight): 中央 8 字形慢速穿透漫游
    final p5x = (0.50 + 0.22 * math.sin(t * 0.75 + 0.8)).clamp(0.05, 0.95);
    final p5y = (0.50 + 0.18 * math.sin(t * 1.50 + 1.6)).clamp(0.05, 0.95);
    shader.setFloat(35, p5x);
    shader.setFloat(36, p5y);

    // 明暗模式连续平滑过渡 (0.0: 明亮, 1.0: 暗色) 与强度
    shader.setFloat(37, darkness.clamp(0.0, 1.0));
    shader.setFloat(38, 1.0); // 强度

    const warpStrength = 1.0;
    const blobScale = 1.0;
    const layerMix = 0.55;
    const luminanceLimit = 0.40;
    shader.setFloat(39, warpStrength);
    shader.setFloat(40, blobScale);
    shader.setFloat(41, layerMix);
    shader.setFloat(42, luminanceLimit);

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

/// 独立水波源类型
enum RippleType {
  click,
  trail,
  bass,
  rain,
}

/// 独立水波源数据模型
class RippleSource {
  const RippleSource({
    required this.origin,
    required this.birthTime,
    required this.duration,
    required this.amplitude,
    required this.speed,
    required this.frequency,
    required this.damping,
    required this.type,
  });

  final Offset origin;
  final double birthTime;
  final double duration;
  final double amplitude;
  final double speed;
  final double frequency;
  final double damping;
  final RippleType type;
}

/// 独立多波源水波纹物理管理器 (零 setState，纯 GPU 驱动，全时自然随机细雨仿真)
class WaterRippleManager {
  static const int maxRipples = 16;
  final List<RippleSource> _ripples = [];

  // 轨迹微澜节流状态
  double _lastTrailTime = 0.0;
  Offset _lastTrailPos = const Offset(-1.0, -1.0);
  double _lastMoveTime = 0.0;

  // 点击波纹节流与防重叠状态
  double _lastClickTime = 0.0;
  Offset _lastClickPos = const Offset(-1.0, -1.0);

  // 全时自然小雨涟漪调度状态 (泊松随机时间间隔与全屏散落)
  double _nextRainDropTime = 0.0;
  final math.Random _random = math.Random();

  // 低音节拍检测状态
  double _lastBassTime = 0.0;
  double _bassAvgEnergy = 0.0;

  List<RippleSource> get ripples => _ripples;

  void addClickRipple(Offset normalizedPos, double currentTime) {
    // 快速重复点击同一位置去抖：100ms 内且距离小于 0.02 时平滑跳过，防止多层生硬重叠
    if (_lastClickPos.dx >= 0 && (currentTime - _lastClickTime) < 0.10) {
      final delta = normalizedPos - _lastClickPos;
      if (delta.distance < 0.02) {
        return;
      }
    }
    _lastClickPos = normalizedPos;
    _lastClickTime = currentTime;

    _addRipple(
      RippleSource(
        origin: normalizedPos,
        birthTime: currentTime,
        duration: 2.0,
        amplitude: 0.32,
        speed: 0.30,
        frequency: 16.0,
        damping: 2.2,
        type: RippleType.click,
      ),
      currentTime,
    );
  }

  void onPointerMove({
    required Offset normalizedPos,
    required Size screenSize,
    required double currentTime,
  }) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return;

    if (_lastTrailPos.dx < 0) {
      _lastTrailPos = normalizedPos;
      _lastTrailTime = currentTime;
      _lastMoveTime = currentTime;
      return;
    }

    final pixelDelta = Offset(
      (normalizedPos.dx - _lastTrailPos.dx) * screenSize.width,
      (normalizedPos.dy - _lastTrailPos.dy) * screenSize.height,
    );
    final dist = pixelDelta.distance;
    final timeSinceLastTrail = currentTime - _lastTrailTime;
    final timeSinceLastMove = math.max(0.001, currentTime - _lastMoveTime);
    _lastMoveTime = currentTime;

    // 空间-时间双阈值节流：位移门槛加大到 >= 85px 且时间间隔加大到 >= 220ms (轻快稀疏舒展)
    if (dist >= 85.0 && timeSinceLastTrail >= 0.220) {
      final speed =
          (dist / (timeSinceLastMove * 1000.0)).clamp(0.0, 1.0); // 速度估算
      // 过滤慢速微移操作
      if (speed >= 0.08) {
        final amplitude = (speed * 0.26 + 0.05).clamp(0.08, 0.18);

        _addRipple(
          RippleSource(
            origin: normalizedPos,
            birthTime: currentTime,
            duration: 0.65,
            amplitude: amplitude,
            speed: 0.26,
            frequency: 22.0,
            damping: 4.5,
            type: RippleType.trail,
          ),
          currentTime,
        );

        _lastTrailPos = normalizedPos;
        _lastTrailTime = currentTime;
      }
    }
  }

  void onBassSample(List<double> spectrum, double currentTime) {
    if (spectrum.isEmpty) return;

    // 计算 Sub-Bass 频段 (0 ~ 120Hz，前 3 个 bins) 能量
    final subBassCount = math.min(spectrum.length, 3);
    var sum = 0.0;
    for (var i = 0; i < subBassCount; i++) {
      sum += spectrum[i];
    }
    final bassEnergy = sum / subBassCount;

    // 瞬态节拍检测：能量 > 0.40 且超过背景平均值，冷却时间 > 380ms
    final timeSinceLastBass = currentTime - _lastBassTime;
    final isBeat = bassEnergy > 0.40 &&
        (bassEnergy > _bassAvgEnergy * 1.15 || bassEnergy > 0.68) &&
        timeSinceLastBass > 0.38;

    _bassAvgEnergy = _bassAvgEnergy * 0.85 + bassEnergy * 0.15;

    if (isBeat) {
      _addRipple(
        RippleSource(
          origin: const Offset(0.5, 0.5), // 从中心向外扩散宽厚低音波
          birthTime: currentTime,
          duration: 2.0,
          amplitude: (bassEnergy * 0.45).clamp(0.22, 0.45),
          speed: 0.26,
          frequency: 12.0,
          damping: 1.8,
          type: RippleType.bass,
        ),
        currentTime,
      );
      _lastBassTime = currentTime;
    }
  }

  void updateAmbientRain(double currentTime) {
    pruneExpired(currentTime);

    // 首次启动或初始化：一次性散落 3 个处于不同扩散阶段的舒缓雨滴
    if (_nextRainDropTime == 0.0) {
      final initialOffsets = [
        Offset(
            0.20 + _random.nextDouble() * 0.25, 0.25 + _random.nextDouble() * 0.25),
        Offset(
            0.60 + _random.nextDouble() * 0.25, 0.35 + _random.nextDouble() * 0.30),
        Offset(
            0.35 + _random.nextDouble() * 0.35, 0.65 + _random.nextDouble() * 0.25),
      ];
      final timeDeltas = [2.0, 1.0, 0.0]; // 分别处于扩散末期、扩散中期、刚落水阶段
      for (var i = 0; i < 3; i++) {
        final bTime = currentTime - timeDeltas[i];
        _addRipple(
          RippleSource(
            origin: initialOffsets[i],
            birthTime: bTime,
            duration: 3.2,
            amplitude: 0.26 + _random.nextDouble() * 0.08,
            speed: 0.22 + _random.nextDouble() * 0.03,
            frequency: 18.0 + _random.nextDouble() * 4.0,
            damping: 1.6,
            type: RippleType.rain,
          ),
          currentTime,
        );
      }
      _nextRainDropTime = currentTime + 1.2 + _random.nextDouble() * 0.8;
      return;
    }

    // 保证画面中维持至少 3 个活跃雨滴（舒缓补入）
    final currentCount = _ripples
        .where((r) =>
            r.type == RippleType.rain &&
            (currentTime - r.birthTime) < r.duration)
        .length;
    if (currentCount < 3) {
      _spawnRainDrop(currentTime);
      _nextRainDropTime = currentTime + 1.1 + _random.nextDouble() * 0.9;
      return;
    }

    // 舒缓自然小雨涟漪调度 (间隔 1.1s ~ 2.0s 落下一滴，活跃雨滴稳定在 3 ~ 4 个之间)
    if (currentTime >= _nextRainDropTime && currentCount < 4) {
      _spawnRainDrop(currentTime);
      _nextRainDropTime = currentTime + 1.1 + _random.nextDouble() * 0.9;
    }
  }

  void _spawnRainDrop(double currentTime) {
    final rx = 0.08 + _random.nextDouble() * 0.84;
    final ry = 0.08 + _random.nextDouble() * 0.84;
    final amp = 0.26 + _random.nextDouble() * 0.08;
    final spd = 0.22 + _random.nextDouble() * 0.03;
    final freq = 18.0 + _random.nextDouble() * 4.0;

    _addRipple(
      RippleSource(
        origin: Offset(rx, ry),
        birthTime: currentTime,
        duration: 3.2,
        amplitude: amp,
        speed: spd,
        frequency: freq,
        damping: 1.6,
        type: RippleType.rain,
      ),
      currentTime,
    );
  }

  void _addRipple(RippleSource ripple, double currentTime) {
    _ripples.removeWhere((r) => (currentTime - r.birthTime) > r.duration);

    if (_ripples.length >= maxRipples) {
      _ripples.removeAt(0);
    }
    _ripples.add(ripple);
  }

  void pruneExpired(double currentTime) {
    _ripples.removeWhere((r) => (currentTime - r.birthTime) > r.duration);
  }
}

/// 交互水波纹着色器绘制器 (16 独立波源物理干涉叠加与单次遍历解析导数法线，雨天纯净冷灰玄青光学)
class _WaterRipplePainter extends CustomPainter {
  const _WaterRipplePainter({
    required this.program,
    required this.time,
    required this.ripples,
  });

  final ui.FragmentProgram program;
  final double time;
  final List<RippleSource> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    final activeCount = math.min(ripples.length, WaterRippleManager.maxRipples);
    shader.setFloat(3, activeCount.toDouble());

    // 16 个波源几何与物理参数 (Slot 4 ~ 67: u_ripples, Slot 68 ~ 131: u_ripple_params)
    for (var i = 0; i < WaterRippleManager.maxRipples; i++) {
      final rIndex = 4 + i * 4;
      final pIndex = 68 + i * 4;

      if (i < activeCount) {
        final r = ripples[i];
        shader.setFloat(rIndex + 0, r.origin.dx);
        shader.setFloat(rIndex + 1, r.origin.dy);
        shader.setFloat(rIndex + 2, r.birthTime);
        shader.setFloat(rIndex + 3, r.amplitude);

        shader.setFloat(pIndex + 0, r.speed);
        shader.setFloat(pIndex + 1, r.frequency);
        shader.setFloat(pIndex + 2, r.damping);
        shader.setFloat(pIndex + 3, r.duration);
      } else {
        shader.setFloat(rIndex + 0, 0.0);
        shader.setFloat(rIndex + 1, 0.0);
        shader.setFloat(rIndex + 2, 0.0);
        shader.setFloat(rIndex + 3, 0.0);

        shader.setFloat(pIndex + 0, 0.0);
        shader.setFloat(pIndex + 1, 0.0);
        shader.setFloat(pIndex + 2, 0.0);
        shader.setFloat(pIndex + 3, 0.0);
      }
    }

    // 独立雨天水体光学色彩 (Slot 132 ~ 147)
    // 严格使用独立雨天冷灰青玄墨光谱，杜绝任何外部专辑主题色染色
    _setColor(shader, 132, const Color(0xFF0C1014)); // 深水基底色 (深邃玄灰青)
    _setColor(shader, 136, const Color(0xFF1B252E)); // 浅水漫射散射色 (雨天冷灰青水色)
    _setColor(shader, 140, const Color(0xFFE2EFF8)); // 镜面高光色 (清冽冷白微芒)
    _setColor(shader, 144, const Color(0xFF506270)); // 阴天天光微光色 (柔和漫反射灰蓝)

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

/// 极光漫染绘制器（多点调和的静态高斯漫射光晕，呈现 Apple Music 级海报微光质感）
class _AuroraGlowPainter extends CustomPainter {
  const _AuroraGlowPainter({
    required this.palette,
    required this.darkness,
    required this.baseGradient,
  });

  final AlbumPalette palette;
  final double darkness;
  final List<Color> baseGradient;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final maxDim = math.max(size.width, size.height);
    final isDark = darkness > 0.5;
    final hsl = HSLColor.fromColor(palette.primary);
    final lum = AlbumPalette.pureHueLuminance(hsl.hue);
    final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
    final alphaDamp = 1.0 - excess * (isDark ? 0.28 : 0.20);

    // 1. 底层左右横向环境底色渐变（左主色 -> 中间过渡 -> 右次主色）
    final baseColors = baseGradient.isNotEmpty
        ? baseGradient
        : (isDark
            ? const [
                Color(0xFF060A13),
                Color(0xFF080D18),
                Color(0xFF060A13),
              ]
            : const [
                Color(0xFFF7F9FD),
                Color(0xFFF1F5FA),
                Color(0xFFF6F8FD),
              ]);
    final baseGradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: baseColors,
      ).createShader(rect);
    canvas.drawRect(rect, baseGradientPaint);

    // 2. 左右宏观水彩浸润漫染（左半区主导水彩 + 右半区次主水彩 + 中央湿画交融）
    // 【左半区 - 主导水彩群】
    // 左翼 1：主色核心水彩大晕染 (左侧中央偏上 18%, 46% - 宽域大面积舒展)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.18, size.height * 0.46),
      radius: maxDim * 0.78,
      color: palette.primary,
      alpha: (isDark ? 0.32 : 0.25) * alphaDamp,
    );

    // 左翼 2：左上方灵动水彩泛光 (28%, 18%)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.28, size.height * 0.18),
      radius: maxDim * 0.56,
      color: palette.accent,
      alpha: (isDark ? 0.26 : 0.20) * alphaDamp,
    );

    // 左翼 3：左下方底蕴水彩层 (15%, 82%)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.15, size.height * 0.82),
      radius: maxDim * 0.58,
      color: palette.muted,
      alpha: (isDark ? 0.25 : 0.18) * alphaDamp,
    );

    // 【右半区 - 次主水彩群】
    // 右翼 1：次主色核心水彩大漫染 (右侧中央偏下 82%, 48% - 饱满通透水彩铺底)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.82, size.height * 0.48),
      radius: maxDim * 0.80,
      color: palette.secondary,
      alpha: (isDark ? 0.30 : 0.24) * alphaDamp,
    );

    // 右翼 2：右上方珠光水彩漫晕 (78%, 18%)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.78, size.height * 0.18),
      radius: maxDim * 0.60,
      color: palette.highlight,
      alpha: (isDark ? 0.20 : 0.18) * alphaDamp,
    );

    // 右翼 3：右下方延伸水彩层 (85%, 80%)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.85, size.height * 0.80),
      radius: maxDim * 0.54,
      color: palette.accent,
      alpha: (isDark ? 0.22 : 0.16) * alphaDamp,
    );

    // 【中央交汇 - 湿画法水彩交融】
    // 中央 1：中央水彩柔和漫晕 (50%, 50% - 衔接左右水彩流变)
    _drawGlowBlob(
      canvas: canvas,
      center: Offset(size.width * 0.50, size.height * 0.50),
      radius: maxDim * 0.65,
      color: palette.highlight,
      alpha: (isDark ? 0.16 : 0.14) * alphaDamp,
    );
  }

  void _drawGlowBlob({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    if (radius <= 0) return;
    // 5 阶水彩羽化多重阻尼曲线（模拟真实水彩颜料在湿画纸上的柔滑自然晕开）
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.78),
          color.withValues(alpha: alpha * 0.42),
          color.withValues(alpha: alpha * 0.10),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.55, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraGlowPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.darkness != darkness ||
        oldDelegate.baseGradient != baseGradient;
  }
}

class _UserBackgroundImage extends StatelessWidget {
  const _UserBackgroundImage({
    required this.file,
    required this.isDark,
  });

  final File file;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final opacity = AppSettings.instance.backgroundImageOpacity.clamp(0.3, 1.0);
    // 随透明度动态调谐的微调光罩与暗角保护，确保即使在 100% 透明度下文字依然具有极佳可读性
    final scrimBaseAlpha =
        isDark ? (0.16 + 0.12 * opacity) : (0.12 + 0.10 * opacity);
    final scrimColor = isDark
        ? Colors.black.withValues(alpha: scrimBaseAlpha)
        : Colors.white.withValues(alpha: scrimBaseAlpha);

    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 纯净底色防穿透
            ColoredBox(
              color: isDark
                  ? const Color(0xFF090D14)
                  : const Color(0xFFF2F4F7),
            ),
            // 用户壁纸图片
            Opacity(
              opacity: opacity,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // 全局微光罩
            ColoredBox(color: scrimColor),
            // 顶部与底部文字对比度智能微渐变
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.20 : 0.15),
                    Colors.transparent,
                    Colors.transparent,
                    (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.25 : 0.18),
                  ],
                  stops: const [0.0, 0.18, 0.82, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
