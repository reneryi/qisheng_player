import 'dart:math' as math;

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LiquidAudioVisualizer extends StatelessWidget {
  const LiquidAudioVisualizer({
    super.key,
    required this.spectrum,
    this.enabled = true,
  });

  final ValueListenable<List<double>> spectrum;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    if (!enabled || surfaces.effectsLevel == UiEffectsLevel.performance) {
      return const SizedBox.expand();
    }

    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final intensity = switch (surfaces.effectsLevel) {
      UiEffectsLevel.performance => 0.0,
      UiEffectsLevel.balanced => 0.72,
      UiEffectsLevel.visual => 1.0,
    };

    return RepaintBoundary(
      child: ValueListenableBuilder<List<double>>(
        valueListenable: spectrum,
        builder: (context, values, _) {
          return CustomPaint(
            isComplex: true,
            willChange: values.isNotEmpty,
            painter: _LiquidAudioVisualizerPainter(
              spectrum: List<double>.unmodifiable(values),
              primary: accents.progressActive,
              secondary: Color.lerp(
                scheme.primary,
                scheme.tertiary,
                0.42,
              )!,
              intensity: intensity,
              dark: scheme.brightness == Brightness.dark,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _LiquidAudioVisualizerPainter extends CustomPainter {
  const _LiquidAudioVisualizerPainter({
    required this.spectrum,
    required this.primary,
    required this.secondary,
    required this.intensity,
    required this.dark,
  });

  final List<double> spectrum;
  final Color primary;
  final Color secondary;
  final double intensity;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || intensity <= 0) return;

    final rect = Offset.zero & size;
    final values = _resolveValues();
    final active = spectrum.isNotEmpty;
    final midY = size.height * 0.58;
    final amplitude = size.height * (active ? 0.34 : 0.08) * intensity;
    final primaryPath = _buildWavePath(
      values: values,
      size: size,
      midY: midY,
      amplitude: amplitude,
      direction: 1,
    );
    final secondaryPath = _buildWavePath(
      values: values.reversed.toList(growable: false),
      size: size,
      midY: midY + size.height * 0.12,
      amplitude: amplitude * 0.54,
      direction: -1,
    );

    final fillPath = Path.from(primaryPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillOpacity = (active ? 0.16 : 0.045) * intensity;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withValues(alpha: fillOpacity),
          secondary.withValues(alpha: fillOpacity * 0.48),
          Colors.transparent,
        ],
        stops: const [0, 0.56, 1],
      ).createShader(rect);
    canvas.drawPath(fillPath, fillPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 4.6 : 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        active ? 13 * intensity : 8 * intensity,
      )
      ..color = primary.withValues(alpha: (active ? 0.16 : 0.055) * intensity);
    canvas.drawPath(primaryPath, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.65 : 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = primary.withValues(alpha: (active ? 0.36 : 0.12) * intensity);
    canvas.drawPath(primaryPath, linePaint);

    final secondaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = secondary.withValues(alpha: (active ? 0.18 : 0.06) * intensity);
    canvas.drawPath(secondaryPath, secondaryPaint);

    final veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          (dark ? Colors.black : Colors.white).withValues(
            alpha: dark ? 0.09 : 0.13,
          ),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, veilPaint);
  }

  List<double> _resolveValues() {
    if (spectrum.isNotEmpty) {
      return spectrum
          .map((value) => value.clamp(0.0, 1.0).toDouble())
          .toList(growable: false);
    }

    return List<double>.generate(24, (index) {
      final ripple = math.sin(index * 0.72) * 0.012;
      return (0.04 + ripple).clamp(0.0, 1.0).toDouble();
    }, growable: false);
  }

  Path _buildWavePath({
    required List<double> values,
    required Size size,
    required double midY,
    required double amplitude,
    required int direction,
  }) {
    if (values.isEmpty) {
      return Path()
        ..moveTo(0, midY)
        ..lineTo(size.width, midY);
    }

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final t = values.length == 1 ? 0.0 : i / (values.length - 1);
      final eased = math.sqrt(values[i].clamp(0.0, 1.0));
      final ripple = math.sin(i * 0.46) * amplitude * 0.08;
      final y = midY - direction * (eased * amplitude + ripple);
      points.add(Offset(t * size.width, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
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

    final last = points.last;
    path.lineTo(last.dx, last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _LiquidAudioVisualizerPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        intensity != oldDelegate.intensity ||
        dark != oldDelegate.dark ||
        !listEquals(spectrum, oldDelegate.spectrum);
  }
}
