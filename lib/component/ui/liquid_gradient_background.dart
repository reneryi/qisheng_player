import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coriander_player/app_settings.dart';
import 'package:flutter/material.dart';

@immutable
class LiquidGradientProfile {
  const LiquidGradientProfile({
    required this.animated,
    required this.period,
    required this.bandOpacity,
    required this.bandBlurSigma,
    required this.scrimOpacity,
    required this.mixStrength,
  });

  final bool animated;
  final Duration period;
  final double bandOpacity;
  final double bandBlurSigma;
  final double scrimOpacity;
  final double mixStrength;
}

LiquidGradientProfile resolveLiquidGradientProfile(
  UiEffectsLevel level, {
  bool tintOnly = false,
}) {
  final tintScale = tintOnly ? 0.46 : 1.0;
  return switch (level) {
    UiEffectsLevel.performance => LiquidGradientProfile(
        animated: false,
        period: const Duration(seconds: 44),
        bandOpacity: 0.13 * tintScale,
        bandBlurSigma: 0,
        scrimOpacity: tintOnly ? 0.08 : 0.18,
        mixStrength: tintOnly ? 0.16 : 0.36,
      ),
    UiEffectsLevel.balanced => LiquidGradientProfile(
        animated: true,
        period: const Duration(seconds: 40),
        bandOpacity: 0.18 * tintScale,
        bandBlurSigma: 28,
        scrimOpacity: tintOnly ? 0.1 : 0.2,
        mixStrength: tintOnly ? 0.18 : 0.42,
      ),
    UiEffectsLevel.visual => LiquidGradientProfile(
        animated: true,
        period: const Duration(seconds: 30),
        bandOpacity: 0.26 * tintScale,
        bandBlurSigma: 42,
        scrimOpacity: tintOnly ? 0.12 : 0.24,
        mixStrength: tintOnly ? 0.22 : 0.52,
      ),
  };
}

class LiquidGradientBackground extends StatefulWidget {
  const LiquidGradientBackground({
    super.key,
    required this.backgroundColors,
    required this.paletteColors,
    required this.effectsLevel,
    this.tintOnly = false,
    this.transitionDuration = const Duration(milliseconds: 620),
    this.transitionCurve = Curves.easeOutCubic,
  });

  final List<Color> backgroundColors;
  final List<Color> paletteColors;
  final UiEffectsLevel effectsLevel;
  final bool tintOnly;
  final Duration transitionDuration;
  final Curve transitionCurve;

  @override
  State<LiquidGradientBackground> createState() =>
      _LiquidGradientBackgroundState();
}

class _LiquidGradientBackgroundState extends State<LiquidGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  LiquidGradientProfile get _profile => resolveLiquidGradientProfile(
        widget.effectsLevel,
        tintOnly: widget.tintOnly,
      );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant LiquidGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  void _syncController() {
    final profile = _profile;
    if (!profile.animated) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (_controller.isAnimating && _controller.duration == profile.period) {
      return;
    }
    _controller
      ..duration = profile.period
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LiquidPalette.fromColors(
      backgroundColors: widget.backgroundColors,
      paletteColors: widget.paletteColors,
    );
    final profile = _profile;

    return RepaintBoundary(
      child: TweenAnimationBuilder<_LiquidPalette>(
        tween: _LiquidPaletteTween(end: palette),
        duration: widget.transitionDuration,
        curve: widget.transitionCurve,
        builder: (context, animatedPalette, _) {
          if (!profile.animated) {
            return CustomPaint(
              painter: _LiquidGradientPainter(
                palette: animatedPalette,
                profile: profile,
                phase: 0,
              ),
              child: const SizedBox.expand(),
            );
          }

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _LiquidGradientPainter(
                  palette: animatedPalette,
                  profile: profile,
                  phase: _controller.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          );
        },
      ),
    );
  }
}

@immutable
class _LiquidPalette {
  const _LiquidPalette({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.muted,
  });

  final Color top;
  final Color middle;
  final Color bottom;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color muted;

  factory _LiquidPalette.fromColors({
    required List<Color> backgroundColors,
    required List<Color> paletteColors,
  }) {
    const fallbackTop = Color(0xFF0C1219);
    const fallbackMiddle = Color(0xFF040609);
    const fallbackBottom = Color(0xFF010203);

    Color bgAt(int index, Color fallback) {
      if (index >= backgroundColors.length) return fallback;
      return backgroundColors[index];
    }

    final primary =
        paletteColors.isNotEmpty ? paletteColors[0] : bgAt(0, fallbackTop);
    final secondary = paletteColors.length > 1 ? paletteColors[1] : primary;
    final accent = paletteColors.length > 2 ? paletteColors[2] : secondary;
    final muted = paletteColors.length > 3 ? paletteColors[3] : secondary;

    return _LiquidPalette(
      top: bgAt(0, fallbackTop),
      middle: bgAt(1, fallbackMiddle),
      bottom: bgAt(2, fallbackBottom),
      primary: primary,
      secondary: secondary,
      accent: accent,
      muted: muted,
    );
  }

  static _LiquidPalette lerp(
    _LiquidPalette begin,
    _LiquidPalette end,
    double t,
  ) {
    return _LiquidPalette(
      top: Color.lerp(begin.top, end.top, t)!,
      middle: Color.lerp(begin.middle, end.middle, t)!,
      bottom: Color.lerp(begin.bottom, end.bottom, t)!,
      primary: Color.lerp(begin.primary, end.primary, t)!,
      secondary: Color.lerp(begin.secondary, end.secondary, t)!,
      accent: Color.lerp(begin.accent, end.accent, t)!,
      muted: Color.lerp(begin.muted, end.muted, t)!,
    );
  }
}

class _LiquidPaletteTween extends Tween<_LiquidPalette> {
  _LiquidPaletteTween({required _LiquidPalette end}) : super(end: end);

  @override
  _LiquidPalette lerp(double t) {
    final begin = this.begin ?? end!;
    return _LiquidPalette.lerp(begin, end!, t);
  }
}

class _LiquidGradientPainter extends CustomPainter {
  const _LiquidGradientPainter({
    required this.palette,
    required this.profile,
    required this.phase,
  });

  final _LiquidPalette palette;
  final LiquidGradientProfile profile;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    _paintBase(canvas, size);
    _paintBand(
      canvas,
      size,
      seed: 0.0,
      verticalBias: -0.18,
      thickness: 0.58,
      colorA: palette.primary,
      colorB: palette.accent,
      opacity: profile.bandOpacity,
    );
    _paintBand(
      canvas,
      size,
      seed: 0.37,
      verticalBias: 0.16,
      thickness: 0.7,
      colorA: palette.secondary,
      colorB: palette.muted,
      opacity: profile.bandOpacity * 0.82,
      flip: true,
    );
    _paintBand(
      canvas,
      size,
      seed: 0.69,
      verticalBias: 0.42,
      thickness: 0.54,
      colorA: palette.accent,
      colorB: palette.primary,
      opacity: profile.bandOpacity * 0.62,
    );
    _paintScrim(canvas, size);
  }

  void _paintBase(Canvas canvas, Size size) {
    final mixedTop = Color.lerp(
      palette.top,
      palette.primary,
      profile.mixStrength,
    )!;
    final mixedMiddle = Color.lerp(
      palette.middle,
      palette.secondary,
      profile.mixStrength * 0.52,
    )!;
    final mixedBottom = Color.lerp(
      palette.bottom,
      palette.muted,
      profile.mixStrength * 0.3,
    )!;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [mixedTop, mixedMiddle, mixedBottom],
        stops: const [0, 0.54, 1],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintBand(
    Canvas canvas,
    Size size, {
    required double seed,
    required double verticalBias,
    required double thickness,
    required Color colorA,
    required Color colorB,
    required double opacity,
    bool flip = false,
  }) {
    final wave = math.sin((phase + seed) * math.pi * 2);
    final drift = math.cos((phase * 0.72 + seed) * math.pi * 2);
    final height = size.height;
    final width = size.width;
    final padX = width * 0.18;
    final bandHeight = height * thickness;
    final centerY = height * (0.5 + verticalBias + wave * 0.08);
    final startY = centerY - bandHeight / 2;
    final endY = centerY + bandHeight / 2;

    final path = Path()
      ..moveTo(-padX, startY)
      ..cubicTo(
        width * (flip ? 0.24 : 0.18),
        startY + height * (0.2 + drift * 0.06),
        width * (flip ? 0.58 : 0.48),
        startY - height * (0.12 + wave * 0.05),
        width + padX,
        startY + height * (0.16 - drift * 0.05),
      )
      ..lineTo(width + padX, endY)
      ..cubicTo(
        width * (flip ? 0.66 : 0.72),
        endY - height * (0.18 - wave * 0.05),
        width * (flip ? 0.22 : 0.36),
        endY + height * (0.14 + drift * 0.04),
        -padX,
        endY - height * (0.1 + wave * 0.04),
      )
      ..close();

    final bounds = Rect.fromLTWH(-padX, startY, width + padX * 2, bandHeight);
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: flip ? Alignment.centerRight : Alignment.centerLeft,
        end: flip ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          colorA.withValues(alpha: opacity * 0.14),
          colorA.withValues(alpha: opacity),
          colorB.withValues(alpha: opacity * 0.72),
          colorB.withValues(alpha: opacity * 0.1),
        ],
        stops: const [0, 0.34, 0.72, 1],
      ).createShader(bounds);

    if (profile.bandBlurSigma > 0) {
      paint.maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        profile.bandBlurSigma,
      );
    }

    canvas.drawPath(path, paint);
  }

  void _paintScrim(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: profile.scrimOpacity * 0.18),
          Colors.black.withValues(alpha: profile.scrimOpacity),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGradientPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.profile != profile ||
        oldDelegate.phase != phase;
  }
}
