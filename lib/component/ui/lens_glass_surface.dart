import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/audio_spectrum.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

const String lensGlassShaderAsset = 'shaders/lens_glass.frag';

Future<ui.FragmentProgram?>? _lensGlassProgramFuture;

Future<ui.FragmentProgram?> loadLensGlassProgram() {
  return _lensGlassProgramFuture ??= () async {
    try {
      return await ui.FragmentProgram.fromAsset(lensGlassShaderAsset);
    } catch (_) {
      return null;
    }
  }();
}

/// 光学色散折射晶体容器 (Optical Refractive Lens Glass Surface)
/// 基于 `shaders/lens_glass.frag` 的 SDF 圆角边缘折射、RGB 微棱镜色散与声学频谱共振材质，
/// 专用于悬浮声学控制舱 (Floating Pod)、全局命令面板、信号链检视器与杂志焦点卡片。
class LensGlassSurface extends StatefulWidget {
  const LensGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.refractionStrength = 1.0,
    this.padding,
    this.margin,
    this.tintColor,
    this.enableBackdropBlur = true,
    this.blurSigma = 18.0,
    this.enableAudioReactivity = true,
    this.enablePointerSpotlight = true,
  });

  final Widget child;
  final double borderRadius;
  final double refractionStrength;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final bool enableBackdropBlur;
  final double blurSigma;
  final bool enableAudioReactivity;
  final bool enablePointerSpotlight;

  @override
  State<LensGlassSurface> createState() => _LensGlassSurfaceState();
}

class _LensGlassSurfaceState extends State<LensGlassSurface> {
  ui.FragmentProgram? _program;
  Offset _pointerUv = Offset.zero;
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    unawaited(
      loadLensGlassProgram().then((program) {
        if (!mounted || program == null) return;
        setState(() => _program = program);
      }),
    );
  }

  void _handleHover(PointerEvent event, Size size) {
    if (!widget.enablePointerSpotlight) return;
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return;
    final next = Offset(
      (event.localPosition.dx / size.width).clamp(0.0, 1.0),
      (event.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    if ((next - _pointerUv).distance > 0.015) {
      setState(() => _pointerUv = next);
    }
  }

  void _handleExit(PointerEvent _) {
    if (_pointerUv != Offset.zero) {
      setState(() => _pointerUv = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final accents = context.accents;
    final effectsLevel = context.surfaces.effectsLevel;
    final resolvedTint = widget.tintColor ?? accents.accent;
    final radius = BorderRadius.circular(widget.borderRadius);

    ValueListenable<List<double>>? spectrumListenable;
    if (widget.enableAudioReactivity &&
        effectsLevel != UiEffectsLevel.performance) {
      try {
        spectrumListenable = PlayService.instance.playbackService.audioSpectrum;
      } catch (_) {
        spectrumListenable = null;
      }
    }

    Widget buildPaintedSurface(List<double> spectrum) {
      final features = computeAcousticFeatures(spectrum);
      final timeSec = _stopwatch.elapsedMicroseconds / 1000000.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.hasBoundedWidth ? constraints.maxWidth : 320,
            constraints.hasBoundedHeight ? constraints.maxHeight : 80,
          );
          final content = widget.padding != null
              ? Padding(padding: widget.padding!, child: widget.child)
              : widget.child;

          Widget painted = CustomPaint(
            painter: LensGlassPainter(
              program:
                  effectsLevel == UiEffectsLevel.performance ? null : _program,
              time: timeSec,
              tintColor: resolvedTint,
              isDark: isDark,
              refractionStrength: widget.refractionStrength,
              cornerRadius: widget.borderRadius,
              bassEnergy: features.subBassEnergy,
              spectralCentroid: features.spectralCentroid,
              pointerUv: _pointerUv,
            ),
            child: content,
          );

          if (widget.enableBackdropBlur &&
              effectsLevel != UiEffectsLevel.performance &&
              widget.blurSigma > 0) {
            painted = BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: widget.blurSigma,
                sigmaY: widget.blurSigma,
              ),
              child: painted,
            );
          }

          return MouseRegion(
            onHover: (e) => _handleHover(e, size),
            onExit: _handleExit,
            child: Container(
              margin: widget.margin,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  if (features.subBassEnergy > 0.08)
                    BoxShadow(
                      color: resolvedTint.withValues(
                        alpha: (features.subBassEnergy * (isDark ? 0.22 : 0.12))
                            .clamp(0.0, 0.26),
                      ),
                      blurRadius: 20 + features.subBassEnergy * 12,
                      spreadRadius: -6,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: painted,
              ),
            ),
          );
        },
      );
    }

    if (spectrumListenable == null) {
      return RepaintBoundary(child: buildPaintedSurface(const <double>[]));
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<List<double>>(
        valueListenable: spectrumListenable,
        builder: (context, spectrum, _) => buildPaintedSurface(spectrum),
      ),
    );
  }
}

class LensGlassPainter extends CustomPainter {
  const LensGlassPainter({
    required this.program,
    required this.time,
    required this.tintColor,
    required this.isDark,
    this.refractionStrength = 1.0,
    this.cornerRadius = 24.0,
    this.bassEnergy = 0.0,
    this.spectralCentroid = 0.0,
    this.pointerUv = Offset.zero,
  });

  final ui.FragmentProgram? program;
  final double time;
  final Color tintColor;
  final bool isDark;
  final double refractionStrength;
  final double cornerRadius;
  final double bassEnergy;
  final double spectralCentroid;
  final Offset pointerUv;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final shaderProgram = program;
    if (shaderProgram != null) {
      final shader = shaderProgram.fragmentShader();
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, time.isFinite ? time : 0.0);
      shader.setFloat(3, tintColor.r);
      shader.setFloat(4, tintColor.g);
      shader.setFloat(5, tintColor.b);
      shader.setFloat(6, tintColor.a);
      shader.setFloat(7, isDark ? 1.0 : 0.0);
      shader.setFloat(8, refractionStrength.clamp(0.0, 2.0));
      shader.setFloat(9, cornerRadius.clamp(1.0, 120.0));
      shader.setFloat(10, bassEnergy.isFinite ? bassEnergy.clamp(0.0, 1.0) : 0.0);
      shader.setFloat(
        11,
        spectralCentroid.isFinite ? spectralCentroid.clamp(0.0, 1.0) : 0.0,
      );
      shader.setFloat(12, pointerUv.dx.clamp(0.0, 1.0));
      shader.setFloat(13, pointerUv.dy.clamp(0.0, 1.0));

      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      return;
    }

    // 优雅降级绘制：当片元着色器未加载或处于性能模式时，使用多阶渐变模拟晶体边缘光泽
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
    final baseColor = isDark
        ? Color.alphaBlend(
            tintColor.withValues(alpha: 0.12 + bassEnergy * 0.04),
            const Color(0xFF0B0F17).withValues(alpha: 0.62),
          )
        : Color.alphaBlend(
            tintColor.withValues(alpha: 0.08 + bassEnergy * 0.02),
            const Color(0xFFF5F8FC).withValues(alpha: 0.68),
          );

    canvas.drawRRect(rrect, Paint()..color = baseColor);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.22 : 0.55),
          tintColor.withValues(alpha: isDark ? 0.26 : 0.20),
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.55), rimPaint);
  }

  @override
  bool shouldRepaint(covariant LensGlassPainter oldDelegate) {
    return oldDelegate.program != program ||
        oldDelegate.time != time ||
        oldDelegate.tintColor != tintColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.refractionStrength != refractionStrength ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.bassEnergy != bassEnergy ||
        oldDelegate.spectralCentroid != spectralCentroid ||
        oldDelegate.pointerUv != pointerUv;
  }
}
