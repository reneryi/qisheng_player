import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';

const String liquidSurfaceShaderAsset = 'shaders/liquid_surface.frag';

Future<ui.FragmentProgram?>? _liquidSurfaceProgramFuture;

Future<ui.FragmentProgram?> _loadLiquidSurfaceProgram() {
  return _liquidSurfaceProgramFuture ??= () async {
    try {
      return await ui.FragmentProgram.fromAsset(liquidSurfaceShaderAsset);
    } catch (_) {
      return null;
    }
  }();
}

/// A clipped, palette-driven background intended for the app's main surface.
class LiquidSurfaceBackground extends StatefulWidget {
  const LiquidSurfaceBackground({
    super.key,
    required this.paletteColors,
    required this.effectsLevel,
    required this.child,
    required this.borderRadius,
    this.transitionDuration = const Duration(milliseconds: 600),
  });

  final List<Color> paletteColors;
  final UiEffectsLevel effectsLevel;
  final Widget child;
  final BorderRadius borderRadius;
  final Duration transitionDuration;

  @override
  State<LiquidSurfaceBackground> createState() =>
      _LiquidSurfaceBackgroundState();
}

class _LiquidSurfaceBackgroundState extends State<LiquidSurfaceBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late math.Random _random;
  late List<LiquidFlowTrack> _tracks;
  Timer? _paletteSeedTimer;
  ui.FragmentProgram? _shaderProgram;
  double _elapsedShaderSeconds = 0;
  bool _appVisible = true;
  bool _animationsAllowed = true;

  bool get _animated =>
      widget.effectsLevel == UiEffectsLevel.visual &&
      _appVisible &&
      _animationsAllowed;

  @override
  void initState() {
    super.initState();
    _random = math.Random(_paletteSeed(widget.paletteColors));
    _tracks = _createTracks();
    _controller = AnimationController(
      vsync: this,
      duration: _nextSegmentDuration(),
    )..addStatusListener(_handleSegmentStatus);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadLiquidSurfaceProgram().then((program) {
      if (!mounted || program == null) return;
      setState(() => _shaderProgram = program);
    }));
    _syncAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAnimationsAllowed = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (_animationsAllowed == nextAnimationsAllowed) return;
    _animationsAllowed = nextAnimationsAllowed;
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextVisible =
        state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
    if (_appVisible == nextVisible) return;
    _appVisible = nextVisible;
    if (!nextVisible) _paletteSeedTimer?.cancel();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LiquidSurfaceBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effectsLevel != widget.effectsLevel) {
      _syncAnimation();
    }
    if (_paletteSeed(oldWidget.paletteColors) !=
        _paletteSeed(widget.paletteColors)) {
      _paletteSeedTimer?.cancel();
      _paletteSeedTimer = Timer(widget.transitionDuration, () {
        if (!mounted) return;
        _random = math.Random(_paletteSeed(widget.paletteColors));
      });
    }
  }

  int _paletteSeed(List<Color> colors) {
    var seed = 0x45D9F3B;
    for (final color in colors) {
      seed = 0x7FFFFFFF & (seed * 31 + color.toARGB32());
    }
    return seed;
  }

  List<LiquidFlowTrack> _createTracks() {
    final previous = generateLiquidFlowPoints(_random);
    final current = generateLiquidFlowPoints(_random);
    final target = generateLiquidFlowPoints(_random);
    final next = generateLiquidFlowPoints(_random);
    return List.generate(
      3,
      (index) => LiquidFlowTrack(
        previous: previous[index],
        current: current[index],
        target: target[index],
        next: next[index],
      ),
      growable: false,
    );
  }

  Duration _nextSegmentDuration() => Duration(
        milliseconds: 6000 + _random.nextInt(4001),
      );

  void _handleSegmentStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _elapsedShaderSeconds +=
        (_controller.duration?.inMicroseconds.toDouble() ?? 0) /
            Duration.microsecondsPerSecond;
    final nextStage = generateLiquidFlowPoints(_random);
    _tracks = List.generate(
      _tracks.length,
      (index) => _tracks[index].advance(nextStage[index]),
      growable: false,
    );
    _controller.duration = _nextSegmentDuration();
    if (_animated) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
  }

  void _syncAnimation() {
    if (_animated) {
      if (!_controller.isAnimating) {
        _controller.forward(from: _controller.value);
      }
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paletteSeedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = LiquidSurfacePalette.fromColors(widget.paletteColors)
        .resolveForTheme(theme.colorScheme);

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<LiquidSurfacePalette>(
          tween: _LiquidSurfacePaletteTween(end: palette),
          duration: widget.transitionDuration,
          curve: Curves.easeInOutCubic,
          builder: (context, animatedPalette, child) {
            return AnimatedBuilder(
              animation: _controller,
              child: child,
              builder: (context, child) {
                return CustomPaint(
                  painter: LiquidSurfacePainter(
                    palette: animatedPalette,
                    phase: _animated ? _controller.value : 0,
                    shaderTime: _animated
                        ? _elapsedShaderSeconds +
                            _controller.value *
                                (_controller.duration?.inMilliseconds ?? 0) /
                                1000
                        : 0,
                    effectsLevel: widget.effectsLevel,
                    brightness: theme.brightness,
                    fragmentProgram: _shaderProgram,
                    seed: _paletteSeed(widget.paletteColors),
                    positions: [
                      for (final track in _tracks)
                        track.positionAt(
                          _animated ? _controller.value : 0,
                        ),
                    ],
                  ),
                  child: child,
                );
              },
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

@immutable
class LiquidFlowTrack {
  const LiquidFlowTrack({
    required this.previous,
    required this.current,
    required this.target,
    required this.next,
  });

  final Offset previous;
  final Offset current;
  final Offset target;
  final Offset next;

  Offset positionAt(double t) {
    final progress = t.clamp(0.0, 1.0);
    final t2 = progress * progress;
    final t3 = t2 * progress;
    return Offset(
      _catmullRom(
        previous.dx,
        current.dx,
        target.dx,
        next.dx,
        progress,
        t2,
        t3,
      ).clamp(0.05, 0.95),
      _catmullRom(
        previous.dy,
        current.dy,
        target.dy,
        next.dy,
        progress,
        t2,
        t3,
      ).clamp(0.08, 0.92),
    );
  }

  LiquidFlowTrack advance(Offset following) => LiquidFlowTrack(
        previous: current,
        current: target,
        target: next,
        next: following,
      );

  static double _catmullRom(
    double p0,
    double p1,
    double p2,
    double p3,
    double t,
    double t2,
    double t3,
  ) {
    return 0.5 *
        ((2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}

List<Offset> generateLiquidFlowPoints(
  math.Random random, {
  int count = 3,
  double minimumSeparation = 0.18,
}) {
  final points = <Offset>[];
  for (var index = 0; index < count; index++) {
    Offset candidate = Offset.zero;
    var attempts = 0;
    do {
      candidate = Offset(
        0.05 + random.nextDouble() * 0.90,
        0.08 + random.nextDouble() * 0.84,
      );
      attempts++;
    } while (attempts < 32 &&
        points
            .any((point) => (point - candidate).distance < minimumSeparation));
    points.add(candidate);
  }
  return List.unmodifiable(points);
}

@immutable
class LiquidSurfacePalette {
  const LiquidSurfacePalette({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;

  factory LiquidSurfacePalette.fromColors(List<Color> colors) {
    const fallback = Color(0xFF345B68);
    final primary = colors.isNotEmpty ? colors[0] : fallback;
    final secondary = colors.length > 1 ? colors[1] : primary;
    final accent = colors.length > 2 ? colors[2] : secondary;
    return LiquidSurfacePalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
    );
  }

  static LiquidSurfacePalette lerp(
    LiquidSurfacePalette begin,
    LiquidSurfacePalette end,
    double t,
  ) {
    return LiquidSurfacePalette(
      primary: Color.lerp(begin.primary, end.primary, t)!,
      secondary: Color.lerp(begin.secondary, end.secondary, t)!,
      accent: Color.lerp(begin.accent, end.accent, t)!,
    );
  }

  LiquidSurfacePalette resolveForTheme(ColorScheme scheme) {
    Color resolve(Color color) {
      if (scheme.brightness == Brightness.light) {
        return Color.alphaBlend(
          color.withValues(alpha: 0.18),
          scheme.surfaceContainer,
        );
      }

      final hsl = HSLColor.fromColor(color);
      final isNeutral = hsl.saturation < 0.08;
      final normalized = hsl
          .withSaturation(
            isNeutral ? 0 : hsl.saturation.clamp(0.12, 0.76).toDouble(),
          )
          .withLightness(
            isNeutral
                ? hsl.lightness.clamp(0.24, 0.44).toDouble()
                : hsl.lightness.clamp(0.26, 0.60).toDouble(),
          )
          .toColor();
      return _compressLuminance(normalized);
    }

    return LiquidSurfacePalette(
      primary: resolve(primary),
      secondary: resolve(secondary),
      accent: resolve(accent),
    );
  }

  static Color _compressLuminance(
    Color color, {
    double targetLuminance = 0.30,
  }) {
    if (color.computeLuminance() <= targetLuminance) return color;

    var low = 0.0;
    var high = 1.0;
    for (var iteration = 0; iteration < 14; iteration++) {
      final candidate = (low + high) / 2;
      final compressed = Color.alphaBlend(
        Colors.black.withValues(alpha: candidate),
        color,
      );
      if (compressed.computeLuminance() > targetLuminance) {
        low = candidate;
      } else {
        high = candidate;
      }
    }
    return Color.alphaBlend(
      Colors.black.withValues(alpha: high),
      color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidSurfacePalette &&
          primary == other.primary &&
          secondary == other.secondary &&
          accent == other.accent;

  @override
  int get hashCode => Object.hash(primary, secondary, accent);
}

class _LiquidSurfacePaletteTween extends Tween<LiquidSurfacePalette> {
  _LiquidSurfacePaletteTween({required LiquidSurfacePalette end})
      : super(end: end);

  @override
  LiquidSurfacePalette lerp(double t) {
    final start = begin ?? end!;
    return LiquidSurfacePalette.lerp(start, end!, t);
  }
}

class LiquidSurfacePainter extends CustomPainter {
  const LiquidSurfacePainter({
    required this.palette,
    required this.phase,
    required this.shaderTime,
    required this.effectsLevel,
    required this.brightness,
    required this.fragmentProgram,
    required this.seed,
    this.positions = const [],
  });

  final LiquidSurfacePalette palette;
  final double phase;
  final double shaderTime;
  final UiEffectsLevel effectsLevel;
  final Brightness brightness;
  final ui.FragmentProgram? fragmentProgram;
  final int seed;
  final List<Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final profile = switch ((effectsLevel, brightness)) {
      (UiEffectsLevel.performance, Brightness.dark) => (
          outer: 0.28,
          inner: 0.30
        ),
      (UiEffectsLevel.balanced, Brightness.dark) => (outer: 0.38, inner: 0.42),
      (UiEffectsLevel.visual, Brightness.dark) => (outer: 0.56, inner: 0.62),
      (UiEffectsLevel.performance, Brightness.light) => (
          outer: 0.18,
          inner: 0.20
        ),
      (UiEffectsLevel.balanced, Brightness.light) => (outer: 0.24, inner: 0.28),
      (UiEffectsLevel.visual, Brightness.light) => (outer: 0.34, inner: 0.42),
    };
    final program = fragmentProgram;
    if (program != null && effectsLevel != UiEffectsLevel.performance) {
      _paintShader(canvas, size, program, profile);
      return;
    }
    _paintFallback(canvas, size, profile);
  }

  void _paintShader(
    Canvas canvas,
    Size size,
    ui.FragmentProgram program,
    ({double outer, double inner}) profile,
  ) {
    final shader = program.fragmentShader();
    var uniform = 0;
    void set(double value) => shader.setFloat(uniform++, value);
    void setColor(Color color) {
      set(color.r);
      set(color.g);
      set(color.b);
      set(color.a);
    }

    set(size.width);
    set(size.height);
    set(shaderTime);
    setColor(palette.primary);
    setColor(palette.secondary);
    setColor(palette.accent);
    setColor(resolveDyeCoreColor(palette.primary));
    setColor(resolveDyeCoreColor(palette.secondary));
    setColor(resolveDyeCoreColor(palette.accent, lightnessScale: 0.88));
    for (var index = 0; index < 3; index++) {
      final center = _resolveNormalizedCenter(positions, index);
      set(center.dx);
      set(center.dy);
    }
    set(profile.outer);
    set(profile.inner);
    set(seed / 0x7FFFFFFF);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  void _paintFallback(
    Canvas canvas,
    Size size,
    ({double outer, double inner}) profile,
  ) {
    final base = Color.lerp(
      Color.lerp(palette.primary, palette.secondary, 0.24),
      palette.accent,
      0.10,
    )!;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final colors = [palette.primary, palette.secondary, palette.accent];
    const outerScales = [0.64, 0.60, 0.68];
    const innerScales = [0.34, 0.31, 0.36];
    const opacityScales = [1.0, 0.96, 0.82];
    for (var index = 0; index < 3; index++) {
      final normalized = _resolveNormalizedCenter(positions, index);
      final center = Offset(
        size.width * normalized.dx,
        size.height * normalized.dy,
      );
      final shapeSeed = seed * 0.000001 + index * 1.93;
      final outerColor = colors[index].withValues(
        alpha: profile.outer * opacityScales[index],
      );
      final outerBounds = Rect.fromCircle(
        center: center,
        radius: size.shortestSide * outerScales[index],
      );
      canvas.drawPath(
        buildLiquidBlobPath(
          size: size,
          center: center,
          radius: size.shortestSide * outerScales[index],
          seed: shapeSeed,
          time: shaderTime,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              outerColor,
              outerColor.withValues(alpha: outerColor.a * 0.46),
              Colors.transparent,
            ],
            stops: const [0, 0.62, 1],
          ).createShader(outerBounds),
      );
      final coreColor = resolveDyeCoreColor(
        colors[index],
        lightnessScale: index == 2 ? 0.88 : 0.78,
      ).withValues(alpha: profile.inner * opacityScales[index]);
      final innerBounds = Rect.fromCircle(
        center: center,
        radius: size.shortestSide * innerScales[index],
      );
      canvas.drawPath(
        buildLiquidBlobPath(
          size: size,
          center: center,
          radius: size.shortestSide * innerScales[index],
          seed: shapeSeed + 0.71,
          time: shaderTime * 1.13,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              coreColor,
              coreColor.withValues(alpha: coreColor.a * 0.55),
              Colors.transparent,
            ],
            stops: const [0, 0.68, 1],
          ).createShader(innerBounds),
      );
    }
  }

  Offset _resolveNormalizedCenter(List<Offset> points, int index) {
    const fallback = [
      Offset(0.22, 0.26),
      Offset(0.74, 0.42),
      Offset(0.48, 0.78),
    ];
    return index < points.length ? points[index] : fallback[index];
  }

  @override
  bool shouldRepaint(covariant LiquidSurfacePainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.phase != phase ||
        oldDelegate.shaderTime != shaderTime ||
        oldDelegate.effectsLevel != effectsLevel ||
        oldDelegate.brightness != brightness ||
        oldDelegate.fragmentProgram != fragmentProgram ||
        oldDelegate.seed != seed ||
        !_samePositions(oldDelegate.positions, positions);
  }

  bool _samePositions(List<Offset> first, List<Offset> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

Color resolveDyeCoreColor(
  Color color, {
  double lightnessScale = 0.78,
}) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.saturation < 0.08) {
    return hsl
        .withSaturation(0)
        .withLightness((hsl.lightness * lightnessScale).clamp(0.0, 1.0))
        .toColor();
  }
  return hsl
      .withSaturation((hsl.saturation + 0.06).clamp(0.0, 0.86))
      .withLightness((hsl.lightness * lightnessScale).clamp(0.0, 1.0))
      .toColor();
}

Path buildLiquidBlobPath({
  required Size size,
  required Offset center,
  required double radius,
  required double seed,
  required double time,
  int pointCount = 36,
}) {
  if (size.isEmpty || radius <= 0 || pointCount < 8) return Path();
  final points = generateLiquidBlobPoints(
    center: center,
    radius: radius,
    seed: seed,
    time: time,
    pointCount: pointCount,
  );

  Offset midpoint(Offset left, Offset right) => (left + right) / 2;
  final firstMidpoint = midpoint(points.last, points.first);
  final path = Path()..moveTo(firstMidpoint.dx, firstMidpoint.dy);
  for (var index = 0; index < points.length; index++) {
    final point = points[index];
    final next = points[(index + 1) % points.length];
    final middle = midpoint(point, next);
    path.quadraticBezierTo(point.dx, point.dy, middle.dx, middle.dy);
  }
  return path..close();
}

List<Offset> generateLiquidBlobPoints({
  required Offset center,
  required double radius,
  required double seed,
  required double time,
  int pointCount = 36,
}) {
  if (radius <= 0 || pointCount < 8) return const [];
  final points = <Offset>[];
  final rotation = seed * 0.73 + math.sin(time * 0.037 + seed) * 0.32;
  for (var index = 0; index < pointCount; index++) {
    final angle = index / pointCount * math.pi * 2;
    final deformation = 1 +
        math.sin(angle * 3 + seed * 2.7 + time * 0.041) * 0.17 +
        math.sin(angle * 5 - seed * 1.9 - time * 0.029) * 0.11 +
        math.cos(angle * 7 + seed * 3.1 + time * 0.023) * 0.065;
    final local = Offset(
      math.cos(angle) * radius * deformation,
      math.sin(angle) * radius * deformation * 0.78,
    );
    points.add(
      center +
          Offset(
            local.dx * math.cos(rotation) - local.dy * math.sin(rotation),
            local.dx * math.sin(rotation) + local.dy * math.cos(rotation),
          ),
    );
  }
  return List.unmodifiable(points);
}
