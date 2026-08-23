import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:provider/provider.dart';

/// 拟真黑胶唱盘与机械唱针组件：
/// 支持播放时缓慢平滑匀速旋转、暂停时阻尼停转、唱针自动起落以及精致的黑胶反光沟槽质感。
class VinylRecordPlayerView extends StatefulWidget {
  const VinylRecordPlayerView({
    super.key,
    required this.size,
    required this.coverProvider,
    this.showTonearm = true,
  });

  final double size;
  final ImageProvider<Object>? coverProvider;
  final bool showTonearm;

  @override
  State<VinylRecordPlayerView> createState() => _VinylRecordPlayerViewState();
}

class _VinylRecordPlayerViewState extends State<VinylRecordPlayerView>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _tonearmController;

  @override
  void initState() {
    super.initState();
    // 旋转控制器：单圈约 20 秒，呈现优雅拟真的黑胶转速
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    // 唱针控制器：800ms 优雅阻尼摆动
    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  void _syncPlaybackState(bool isPlaying, bool animationsEnabled) {
    if (!animationsEnabled) {
      _spinController.stop();
      _tonearmController.value = isPlaying ? 1.0 : 0.0;
      return;
    }

    if (isPlaying) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
      if (_tonearmController.value < 1.0 &&
          _tonearmController.status != AnimationStatus.forward) {
        _tonearmController.forward();
      }
    } else {
      if (_spinController.isAnimating) {
        _spinController.stop();
      }
      if (_tonearmController.value > 0.0 &&
          _tonearmController.status != AnimationStatus.reverse) {
        _tonearmController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectsLevel = context.surfaces.effectsLevel;
    final animationsEnabled = effectsLevel != UiEffectsLevel.performance &&
        !MediaQuery.disableAnimationsOf(context);

    return Selector<PlaybackController, bool>(
      selector: (_, playback) => playback.isPlaying,
      builder: (context, isPlaying, _) {
        _syncPlaybackState(isPlaying, animationsEnabled);

        final diskSize = widget.size;
        final centerCoverSize = diskSize * 0.44;

        return SizedBox(
          width: diskSize * (widget.showTonearm ? 1.15 : 1.0),
          height: diskSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // 1. 黑胶唱盘底座与旋转层
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, child) {
                    final angle = _spinController.value * 2 * math.pi;
                    return Transform.rotate(
                      angle: angle,
                      child: child,
                    );
                  },
                  child: _VinylDiscBody(
                    size: diskSize,
                    coverProvider: widget.coverProvider,
                    centerCoverSize: centerCoverSize,
                  ),
                ),
              ),

              // 2. 机械唱针层
              if (widget.showTonearm)
                Positioned(
                  top: -diskSize * 0.08,
                  right: 0,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _tonearmController,
                      builder: (context, child) {
                        // 唱针角度：未播放 -0.32 rad（抬起靠外），播放时 0.0 rad（落入唱片音轨）
                        final curved = CurvedAnimation(
                          parent: _tonearmController,
                          curve: Curves.easeInOutCubic,
                        );
                        final tonearmAngle =
                            math.sin((1 - curved.value) * math.pi * 0.5) * -0.35;
                        return Transform.rotate(
                          angle: tonearmAngle,
                          alignment: const Alignment(0.75, -0.9),
                          child: _TonearmWidget(height: diskSize * 0.8),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VinylDiscBody extends StatelessWidget {
  const _VinylDiscBody({
    required this.size,
    required this.coverProvider,
    required this.centerCoverSize,
  });

  final double size;
  final ImageProvider<Object>? coverProvider;
  final double centerCoverSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111215),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 黑胶唱片同心圆声槽刻纹 CustomPaint
          CustomPaint(
            size: Size(size, size),
            painter: const _VinylGroovePainter(),
          ),

          // 中心圆形专辑封面（唱标 Label）
          Container(
            width: centerCoverSize,
            height: centerCoverSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF22252C),
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: coverProvider != null
                  ? Image(
                      image: coverProvider!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _VinylCenterPlaceholder(),
                    )
                  : const _VinylCenterPlaceholder(),
            ),
          ),

          // 中心黑胶中轴孔
          Container(
            width: size * 0.06,
            height: size * 0.06,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A0B0D),
              border: Border.all(
                color: const Color(0xFFD4D8E2).withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VinylCenterPlaceholder extends StatelessWidget {
  const _VinylCenterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E232F),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: Colors.white38,
          size: 28,
        ),
      ),
    );
  }
}

/// 绘制高拟真同心圆声槽反光质感
class _VinylGroovePainter extends CustomPainter {
  const _VinylGroovePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.5;

    // 1. 绘制多圈细微声槽线
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..color = Colors.white.withValues(alpha: 0.04);

    for (double r = radius * 0.48; r < radius * 0.95; r += 3.2) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // 2. 绘制双向 45 度径向锥形光泽渐变（拟真唱片反光）
    final glossPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.96, glossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 唱针组件
class _TonearmWidget extends StatelessWidget {
  const _TonearmWidget({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 0.38;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TonearmPainter(),
      ),
    );
  }
}

class _TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivotCenter = Offset(size.width * 0.8, size.height * 0.12);

    // 绘制旋转底座轴承
    final pivotPaint = Paint()
      ..color = const Color(0xFF2C3038)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pivotCenter, 14, pivotPaint);

    final pivotRim = Paint()
      ..color = const Color(0xFF717888)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(pivotCenter, 14, pivotRim);

    // 绘制金属唱臂杆
    final armPath = Path()
      ..moveTo(pivotCenter.dx, pivotCenter.dy)
      ..lineTo(size.width * 0.45, size.height * 0.48)
      ..lineTo(size.width * 0.38, size.height * 0.82);

    final armPaint = Paint()
      ..color = const Color(0xFFB8C0D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(armPath, armPaint);

    // 绘制唱头（Cartridge）
    final cartridgeCenter = Offset(size.width * 0.36, size.height * 0.86);
    final cartridgePaint = Paint()..color = const Color(0xFFE24A4A);
    canvas.save();
    canvas.translate(cartridgeCenter.dx, cartridgeCenter.dy);
    canvas.rotate(-0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 22),
        const Radius.circular(3),
      ),
      cartridgePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
