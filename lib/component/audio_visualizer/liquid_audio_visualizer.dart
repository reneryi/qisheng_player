import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

class LiquidAudioVisualizer extends StatelessWidget {
  const LiquidAudioVisualizer({
    super.key,
    required this.spectrum,
  });

  final ValueListenable<List<double>> spectrum;

  @override
  Widget build(BuildContext context) {
    if (context.surfaces.effectsLevel != UiEffectsLevel.visual ||
        MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.expand();
    }

    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: true,
        painter: LiquidAudioVisualizerPainter(
          spectrum: spectrum,
          primary: accents.progressActive,
          secondary: Color.lerp(scheme.primary, scheme.tertiary, 0.42)!,
          dark: scheme.brightness == Brightness.dark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class LiquidAudioVisualizerPainter extends CustomPainter {
  LiquidAudioVisualizerPainter({
    required this.spectrum,
    required this.primary,
    required this.secondary,
    required this.dark,
  }) : super(repaint: spectrum);

  final ValueListenable<List<double>> spectrum;
  final Color primary;
  final Color secondary;
  final bool dark;

  // 复用画笔对象，杜绝每秒 60 次创建 Paint 对象的 GC 颠簸
  final Paint _fillPaint = Paint();
  final Paint _primaryGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _primaryStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _secondaryStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _rectPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || spectrum.value.isEmpty) return;

    final values = spectrum.value;
    final rect = Offset.zero & size;
    final baseline = size.height * 0.66;
    final amplitude = size.height * 0.38;
    final primaryPath = _buildWavePath(
      values,
      size: size,
      baseline: baseline,
      amplitude: amplitude,
    );
    // 逆序采样直接在流式构建器中完成，消除 values.reversed.toList() 的重复数组堆分配
    final secondaryPath = _buildWavePath(
      values,
      size: size,
      baseline: baseline + size.height * 0.08,
      amplitude: amplitude * 0.48,
      reversed: true,
    );

    final fillPath = Path.from(primaryPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    _fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primary.withValues(alpha: 0.15),
        secondary.withValues(alpha: 0.07),
        Colors.transparent,
      ],
      stops: const [0, 0.58, 1],
    ).createShader(rect);
    canvas.drawPath(fillPath, _fillPaint);

    _primaryGlowPaint.color = primary.withValues(alpha: 0.08);
    canvas.drawPath(primaryPath, _primaryGlowPaint);

    _primaryStrokePaint.color = primary.withValues(alpha: 0.34);
    canvas.drawPath(primaryPath, _primaryStrokePaint);

    _secondaryStrokePaint.color = secondary.withValues(alpha: 0.18);
    canvas.drawPath(secondaryPath, _secondaryStrokePaint);

    _rectPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        (dark ? Colors.black : Colors.white).withValues(
          alpha: dark ? 0.08 : 0.12,
        ),
      ],
    ).createShader(rect);
    canvas.drawRect(rect, _rectPaint);
  }

  Path _buildWavePath(
    List<double> values, {
    required Size size,
    required double baseline,
    required double amplitude,
    bool reversed = false,
  }) {
    final len = values.length;
    if (len == 0) return Path();
    if (len == 1) {
      final y = baseline - math.sqrt(values[0].clamp(0.0, 1.0)) * amplitude;
      return Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y);
    }

    final path = Path();
    final firstVal = reversed ? values[len - 1] : values[0];
    final firstY = baseline - math.sqrt(firstVal.clamp(0.0, 1.0)) * amplitude;
    path.moveTo(0, firstY);

    var prevX = 0.0;
    var prevY = firstY;

    // 直接流式计算贝塞尔曲线控制点，彻底移除每帧分配数十个 Offset 对象的开销
    for (var index = 1; index < len; index++) {
      final val = reversed ? values[len - 1 - index] : values[index];
      final currX = index / (len - 1) * size.width;
      final currY = baseline - math.sqrt(val.clamp(0.0, 1.0)) * amplitude;
      final midX = (prevX + currX) / 2;
      final midY = (prevY + currY) / 2;
      path.quadraticBezierTo(prevX, prevY, midX, midY);
      prevX = currX;
      prevY = currY;
    }
    return path..lineTo(size.width, prevY);
  }

  @override
  bool shouldRepaint(covariant LiquidAudioVisualizerPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.dark != dark;
  }
}
