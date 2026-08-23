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
    final secondaryPath = _buildWavePath(
      values.reversed.toList(growable: false),
      size: size,
      baseline: baseline + size.height * 0.08,
      amplitude: amplitude * 0.48,
    );

    final fillPath = Path.from(primaryPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withValues(alpha: 0.15),
            secondary.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          stops: const [0, 0.58, 1],
        ).createShader(rect),
    );

    canvas.drawPath(
      primaryPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = primary.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      primaryPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = primary.withValues(alpha: 0.34),
    );
    canvas.drawPath(
      secondaryPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = secondary.withValues(alpha: 0.18),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            (dark ? Colors.black : Colors.white).withValues(
              alpha: dark ? 0.08 : 0.12,
            ),
          ],
        ).createShader(rect),
    );
  }

  Path _buildWavePath(
    List<double> values, {
    required Size size,
    required double baseline,
    required double amplitude,
  }) {
    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          values.length == 1 ? 0 : index / (values.length - 1) * size.width,
          baseline - math.sqrt(values[index].clamp(0.0, 1.0)) * amplitude,
        ),
    ];
    if (points.length == 1) {
      return Path()
        ..moveTo(0, points.first.dy)
        ..lineTo(size.width, points.first.dy);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    return path..lineTo(points.last.dx, points.last.dy);
  }

  @override
  bool shouldRepaint(covariant LiquidAudioVisualizerPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.dark != dark;
  }
}
