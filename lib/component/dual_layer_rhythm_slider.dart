import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/utils.dart';

/// 频段动能解算结果
class SpectrumEnergy {
  const SpectrumEnergy({
    required this.bass,
    required this.mid,
    required this.treble,
    required this.hasRealFft,
  });

  final double bass;
  final double mid;
  final double treble;
  final bool hasRealFft;

  static const zero = SpectrumEnergy(
    bass: 0.0,
    mid: 0.0,
    treble: 0.0,
    hasRealFft: false,
  );
}

/// 从 64 维对数频段解算 Bass (0..11), Mid (12..37), Treble (38..63) 动能
SpectrumEnergy resolveSpectrumEnergy(List<double>? bins) {
  if (bins == null || bins.isEmpty) {
    return SpectrumEnergy.zero;
  }

  final len = bins.length;
  // 计算 Bass: 前 12 个频段 (~20Hz - 250Hz)
  final bassEnd = math.min(12, len);
  double bassSum = 0.0;
  for (int i = 0; i < bassEnd; i++) {
    final v = bins[i];
    final safeBin = v.isFinite ? v.clamp(0.0, 1.0) : 0.0;
    bassSum += math.pow(safeBin, 1.2).toDouble();
  }
  final bass = bassEnd > 0 ? (bassSum / bassEnd).clamp(0.0, 1.0) : 0.0;

  // 计算 Mid: 12 - 37 频段 (~250Hz - 2.5kHz)
  final midStart = math.min(12, len);
  final midEnd = math.min(38, len);
  double midSum = 0.0;
  final midCount = midEnd - midStart;
  for (int i = midStart; i < midEnd; i++) {
    final v = bins[i];
    final safeBin = v.isFinite ? v.clamp(0.0, 1.0) : 0.0;
    midSum += safeBin;
  }
  final mid = midCount > 0 ? (midSum / midCount).clamp(0.0, 1.0) : 0.0;

  // 计算 Treble: 38 - 63 频段 (~2.5kHz - 20kHz)
  final trebleStart = math.min(38, len);
  final trebleEnd = math.min(64, len);
  double trebleSum = 0.0;
  final trebleCount = trebleEnd - trebleStart;
  for (int i = trebleStart; i < trebleEnd; i++) {
    final v = bins[i];
    final safeBin = v.isFinite ? v.clamp(0.0, 1.0) : 0.0;
    trebleSum += safeBin;
  }
  final treble =
      trebleCount > 0 ? (trebleSum / trebleCount).clamp(0.0, 1.0) : 0.0;

  final hasRealFft = (bass + mid + treble) > 0.005;
  return SpectrumEnergy(
    bass: bass,
    mid: mid,
    treble: treble,
    hasRealFft: hasRealFft,
  );
}

/// 双层灵动呼吸光轨 (Dual-Layer Ambient Rhythm Slider)
///
/// 架构设计：
/// 1. 【顶层】高精度纯时间域线性控制轨 (Top Precision Track)：
///    - 毫秒级 Seek 几何确定性，不受频域扭曲干扰；
///    - 3.5px 极简流体轨道 + 发光 Seek 晶体滑块；
///    - 悬停平滑展开、毛玻璃时间气泡、滚轮 5 秒步进微调；
/// 2. 【底层】柔和漫射的双层贝塞尔微波与伴侣呼吸光晕 (Bottom Ambient Rhythm Layer)：
///    - 接入 BASS 64 频段 FFT 频谱能量 (Bass 低频冲程 + Mid 中频微波)；
///    - 内置 75BPM 自适应呼吸律动发生器，在 WASAPI 独占或暂停时平滑淡入兜底；
///    - 随播放点同步前行、跟随节拍收缩膨胀的伴侣光晕 (Ambient Seek Halo)；
/// 3. 宿主高度严格保持在 14~20px，独立 RepaintBoundary 保证 60fps 丝滑渲染。
class DualLayerRhythmSlider extends StatefulWidget {
  const DualLayerRhythmSlider({
    super.key,
    required this.value,
    required this.max,
    this.spectrum,
    this.spectrumActive = false,
    this.isPlaying = true,
    this.onChanged,
    this.onChangeEnd,
    this.height = 20.0,
  });

  final double value;
  final double max;
  final ValueListenable<List<double>>? spectrum;
  final bool spectrumActive;
  final bool isPlaying;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;

  @override
  State<DualLayerRhythmSlider> createState() => _DualLayerRhythmSliderState();
}

class _DualLayerRhythmSliderState extends State<DualLayerRhythmSlider>
    with TickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _hoverAnimation;

  // 75BPM (周期 2.4s) 持续周期性自激发生器
  late final AnimationController _rhythmTicker;

  // 暂停阻尼平滑“归于平静”发生器 (0.0: 完全展平平静, 1.0: 极光星尘生波)
  late final AnimationController _calmController;

  bool _isHovering = false;
  double _hoverPercent = 0.0;

  bool _isDragging = false;
  double _dragPercent = 0.0;

  Timer? _wheelThrottleTimer;
  double? _pendingWheelSeek;

  // 频谱置信度系数平滑滤波 (0.0 -> 1.0)
  double _fftConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _rhythmTicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _calmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: widget.isPlaying ? 1.0 : 0.0,
    );

    if (widget.isPlaying) {
      _rhythmTicker.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DualLayerRhythmSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_rhythmTicker.isAnimating) {
          _rhythmTicker.repeat();
        }
        _calmController.forward();
      } else {
        _calmController.reverse().then((_) {
          if (mounted && !widget.isPlaying && _rhythmTicker.isAnimating) {
            _rhythmTicker.stop();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _wheelThrottleTimer?.cancel();
    _hoverController.dispose();
    _rhythmTicker.dispose();
    _calmController.dispose();
    super.dispose();
  }

  void _handleHover(double localX, double totalWidth) {
    if (!widget.max.isFinite || widget.max <= 0 || !totalWidth.isFinite || totalWidth <= 0 || !localX.isFinite) {
      if (_isHovering) _handleHoverExit();
      return;
    }
    final percent = (localX / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _hoverPercent = percent;
      _isHovering = true;
    });
    _hoverController.forward();
  }

  void _handleHoverExit() {
    if (_isHovering) {
      setState(() => _isHovering = false);
      _hoverController.reverse();
    }
  }

  void _handleDragStart(double localX, double totalWidth) {
    if (!widget.max.isFinite || widget.max <= 0 || !totalWidth.isFinite || totalWidth <= 0 || !localX.isFinite) return;
    final percent = (localX / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _dragPercent = percent;
    });
    final targetSec = percent * widget.max;
    widget.onChanged?.call(targetSec);
  }

  void _handleDragUpdate(double localX, double totalWidth) {
    if (!_isDragging) return;
    if (!widget.max.isFinite || widget.max <= 0 || !totalWidth.isFinite || totalWidth <= 0 || !localX.isFinite) return;
    final percent = (localX / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _dragPercent = percent;
    });
    final targetSec = percent * widget.max;
    widget.onChanged?.call(targetSec);
  }

  void _handleDragEnd() {
    if (!_isDragging) return;
    final wasDragging = _isDragging;
    final targetPercent = _dragPercent;
    setState(() => _isDragging = false);
    if (wasDragging && widget.max.isFinite && widget.max > 0) {
      final targetSec = targetPercent * widget.max;
      widget.onChangeEnd?.call(targetSec);
    }
  }

  void _handlePointerSignal(PointerSignalEvent signal, double totalWidth) {
    if (signal is! PointerScrollEvent) return;
    if (!widget.max.isFinite || widget.max <= 0 || !totalWidth.isFinite || totalWidth <= 0) return;

    final step = signal.scrollDelta.dy < 0 ? 5.0 : -5.0;
    final startPos = (_pendingWheelSeek ?? (widget.value.isFinite ? widget.value : 0.0))
        .clamp(0.0, widget.max);
    final nextPos = (startPos + step).clamp(0.0, widget.max).toDouble();
    _pendingWheelSeek = nextPos;

    _wheelThrottleTimer?.cancel();
    _wheelThrottleTimer = Timer(const Duration(milliseconds: 40), () {
      final target = _pendingWheelSeek;
      _pendingWheelSeek = null;
      if (target != null && mounted) {
        widget.onChangeEnd?.call(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasValidMax = widget.max.isFinite && widget.max > 0;
    final clampedMax = hasValidMax ? widget.max : 1.0;
    final currentPercent = _isDragging
        ? _dragPercent
        : (hasValidMax && widget.value.isFinite
            ? (widget.value / clampedMax).clamp(0.0, 1.0)
            : 0.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        if (totalWidth <= 0) return SizedBox(height: widget.height);

        final showTooltip =
            (_isHovering || _isDragging) && widget.max.isFinite && widget.max > 0;
        final tooltipPercent = _isDragging ? _dragPercent : _hoverPercent;
        final tooltipSeconds = showTooltip ? tooltipPercent * widget.max : 0.0;
        final activeX = tooltipPercent * totalWidth;
        const bubbleWidth = 72.0;
        final bubbleLeft = (activeX - bubbleWidth / 2.0).clamp(
          0.0,
          math.max<double>(0.0, totalWidth - bubbleWidth),
        );

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isPerformance =
            context.surfaces.effectsLevel == UiEffectsLevel.performance;

        return Listener(
          onPointerSignal: (signal) => _handlePointerSignal(signal, totalWidth),
          child: SizedBox(
            width: totalWidth,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 底层：实时音频律动光雾与自适应呼吸微波 (独立 RepaintBoundary，排除无障碍语义以避免 AXTree 冗余更新)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _rhythmTicker,
                        _calmController,
                        if (widget.spectrum != null) widget.spectrum!,
                      ]),
                      builder: (context, _) {
                        final rawBins = widget.spectrumActive
                            ? widget.spectrum?.value
                            : null;
                        final energy = resolveSpectrumEnergy(rawBins);

                        // 平滑互溶置信度：当有实际 FFT 帧时平滑升高，否则退化为 0
                        if (energy.hasRealFft && widget.spectrumActive) {
                          _fftConfidence = math.min(1.0, _fftConfidence + 0.15);
                        } else {
                          _fftConfidence = math.max(0.0, _fftConfidence - 0.08);
                        }

                        return RepaintBoundary(
                          child: CustomPaint(
                            size: Size(totalWidth, widget.height),
                            painter: _DualLayerBottomAmbientPainter(
                              progressPercent: currentPercent,
                              energy: energy,
                              fftConfidence: _fftConfidence,
                              rhythmPhase: _rhythmTicker.value,
                              calmFactor: _calmController.value,
                              colorScheme: colorScheme,
                              isPerformance: isPerformance,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 顶层：高精度纯时间域线性控制轨与手势层
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) =>
                        _handleDragStart(d.localPosition.dx, totalWidth),
                    onHorizontalDragUpdate: (d) =>
                        _handleDragUpdate(d.localPosition.dx, totalWidth),
                    onHorizontalDragEnd: (_) => _handleDragEnd(),
                    onHorizontalDragCancel: () => _handleDragEnd(),
                    onTapDown: (d) {
                      _handleDragStart(d.localPosition.dx, totalWidth);
                      _handleDragEnd();
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onHover: (d) =>
                          _handleHover(d.localPosition.dx, totalWidth),
                      onExit: (_) => _handleHoverExit(),
                      child: AnimatedBuilder(
                        animation: _hoverAnimation,
                        builder: (context, _) {
                          return RepaintBoundary(
                            child: CustomPaint(
                              size: Size(totalWidth, widget.height),
                              painter: _DualLayerTopTrackPainter(
                                percent: currentPercent,
                                hoverProgress: _hoverAnimation.value,
                                isDragging: _isDragging,
                                colorScheme: colorScheme,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 悬空时间预览气泡
                if (showTooltip)
                  Positioned(
                    left: bubbleLeft,
                    bottom: widget.height + 8.0,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: bubbleWidth,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer
                                  .withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              Duration(
                                milliseconds: tooltipSeconds.isFinite
                                    ? (tooltipSeconds * 1000).round()
                                    : 0,
                              ).toStringHMMSS(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                letterSpacing: 0.3,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 底层氛围绘制器：流体贝塞尔微波与伴侣呼吸光晕 (Ambient Seek Halo)
class _DualLayerBottomAmbientPainter extends CustomPainter {
  _DualLayerBottomAmbientPainter({
    required this.progressPercent,
    required this.energy,
    required this.fftConfidence,
    required this.rhythmPhase,
    required this.calmFactor,
    required this.colorScheme,
    required this.isPerformance,
  });

  final double progressPercent;
  final SpectrumEnergy energy;
  final double fftConfidence;
  final double rhythmPhase;
  final double calmFactor;
  final ColorScheme colorScheme;
  final bool isPerformance;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0 || !width.isFinite || !height.isFinite) return;

    final centerY = height / 2.0;

    // 1. 计算自适应呼吸律动 (75BPM 兜底，严格 2pi 整数倍周期谐波，杜绝循环跳变)
    final phi = rhythmPhase * 2 * math.pi;
    final fallbackBreathing =
        0.35 + 0.40 * math.sin(phi) + 0.15 * math.sin(2.0 * phi + 0.5);

    // 2. 真实频谱与兜底呼吸平滑互溶，并受 calmFactor 调制 (暂停时平滑展平归零)
    final effectiveBass = ((1.0 - fftConfidence) * fallbackBreathing +
            fftConfidence * energy.bass) *
        calmFactor;
    final effectiveMid = ((1.0 - fftConfidence) * (0.3 + 0.2 * math.cos(phi)) +
            fftConfidence * energy.mid) *
        calmFactor;

    final seekX = (progressPercent * width).clamp(0.0, width);

    // 3. 伴侣呼吸光晕 (Ambient Seek Halo) 回升至黄金通透尺寸 (Rx = 26~40px, Ry = 12~18px)
    if (seekX >= 0) {
      final haloRx = (26.0 + 14.0 * effectiveBass).clamp(22.0, 42.0);
      final rawRy = (12.0 + 6.0 * effectiveBass).clamp(10.0, 18.0);
      final haloRy = height <= 8.0 ? math.max(1.0, height) : rawRy;
      final haloCenter = Offset(seekX, centerY);

      // 双层呼吸光晕：内层白金激发核心 + 外层极光晕染
      final haloPaint = Paint()
        ..shader = RadialGradient(
          stops: const [0.0, 0.35, 0.70, 1.0],
          colors: [
            // 0.0: 白金高光激发核
            Color.lerp(colorScheme.primary, Colors.white, 0.55)!
                .withValues(alpha: (0.75 * (0.50 + 0.50 * effectiveBass)).clamp(0.2, 0.85)),
            // 0.35: 核心能量区 (主色)
            colorScheme.primary
                .withValues(alpha: (0.52 * (0.50 + 0.50 * effectiveBass)).clamp(0.15, 0.60)),
            // 0.70: 极光光幔扩散区
            (colorScheme.tertiary != colorScheme.primary
                    ? colorScheme.tertiary
                    : colorScheme.secondary)
                .withValues(alpha: (0.22 * (0.35 + 0.65 * effectiveBass)).clamp(0.04, 0.30)),
            // 1.0: 边缘完全消隐
            colorScheme.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCenter(
          center: haloCenter,
          width: haloRx * 2,
          height: haloRy * 2,
        ));

      if (!isPerformance) {
        haloPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5);
      }

      canvas.drawOval(
        Rect.fromCenter(
          center: haloCenter,
          width: haloRx * 2,
          height: haloRy * 2,
        ),
        haloPaint,
      );
    }

    // 4. 极光丝绸缎带 (Silk Aurora Ribbon)
    // 纯净双层流体丝绸缎带，以进度条为中心线（centerY）上下优雅浮动，无任何底部填充框或边缘切痕
    final maxAmp1 = math.max(2.0, height * 0.44);
    final maxAmp2 = math.max(1.5, height * 0.32);
    // 暂停时随 calmFactor 平滑降为 0，波形优雅展平为一条水平直线基轨
    final waveAmplitude1 =
        (4.2 + 8.5 * effectiveBass).clamp(2.0, maxAmp1) * calmFactor;
    final waveAmplitude2 =
        (2.6 + 5.8 * effectiveMid).clamp(1.5, maxAmp2) * calmFactor;

    final path1 = Path();
    final path2 = Path();

    const int waveSegments = 48;
    final segmentWidth = width / waveSegments;

    for (int i = 0; i <= waveSegments; i++) {
      final x = i * segmentWidth;
      final u = i / waveSegments;
      // 严格保证所有 phi 系数为整数 (1, -2, -1, 2)，在循环 2pi 边界时 sin/cos 严格连续无缝，彻底杜绝跳变
      final wavePhase1 = u * 2.0 * math.pi + phi;
      final wavePhase1Sub = u * 4.0 * math.pi - phi * 2.0;
      final wavePhase2 = u * 3.0 * math.pi - phi + 0.9;
      final wavePhase2Sub = u * 5.0 * math.pi + phi * 2.0;

      final y1 = centerY +
          (math.sin(wavePhase1) * 0.76 + math.sin(wavePhase1Sub * 0.5) * 0.24) *
              waveAmplitude1;
      final y2 = centerY +
          (math.cos(wavePhase2) * 0.72 + math.sin(wavePhase2Sub * 0.5) * 0.28) *
              waveAmplitude2;

      if (i == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
      }
    }

    final secondaryColor = colorScheme.tertiary != colorScheme.primary
        ? colorScheme.tertiary
        : Color.lerp(colorScheme.primary, colorScheme.secondary, 0.5)!;

    // 4.1 次波丝绸流带 (Secondary Aurora Ribbon)：以进度条中心线上下对称浮动，柔焦光晕 + 丝滑细线
    if (!isPerformance) {
      final waveAuraPaint = Paint()
        ..color = secondaryColor.withValues(
          alpha: (0.32 * (0.35 + 0.65 * effectiveMid) * calmFactor).clamp(0.0, 0.65),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
      canvas.drawPath(path2, waveAuraPaint);
    }
    final waveLinePaint = Paint()
      ..color = Color.lerp(secondaryColor, Colors.white, 0.25)!.withValues(
        alpha: (0.45 * (0.40 + 0.60 * effectiveMid) * calmFactor).clamp(0.0, 0.90),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path2, waveLinePaint);

    // 4.2 主波白金极光丝绸 (Primary Aurora Silk Ribbon)：以进度条中心线上下对称浮动，双重柔焦光晕 + 白金纤细脊线
    if (!isPerformance) {
      final ribbonGlowPaint = Paint()
        ..color = Color.lerp(colorScheme.primary, Colors.white, 0.35)!.withValues(
          alpha: (0.48 * (0.35 + 0.65 * effectiveBass) * calmFactor).clamp(0.0, 0.82),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
      canvas.drawPath(path1, ribbonGlowPaint);
    }
    final ribbonCorePaint = Paint()
      ..color = Color.lerp(colorScheme.primary, Colors.white, 0.65)!.withValues(
        alpha: (0.60 * (0.45 + 0.55 * effectiveBass) * calmFactor).clamp(0.0, 0.98),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path1, ribbonCorePaint);
  }

  @override
  bool shouldRepaint(covariant _DualLayerBottomAmbientPainter oldDelegate) {
    return oldDelegate.progressPercent != progressPercent ||
        oldDelegate.energy.bass != energy.bass ||
        oldDelegate.energy.mid != energy.mid ||
        oldDelegate.fftConfidence != fftConfidence ||
        oldDelegate.rhythmPhase != rhythmPhase ||
        oldDelegate.calmFactor != calmFactor ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.isPerformance != isPerformance;
  }
}

/// 顶层控制轨绘制器：纯时间域严格线性映射轨与晶体 Seek 滑块
class _DualLayerTopTrackPainter extends CustomPainter {
  _DualLayerTopTrackPainter({
    required this.percent,
    required this.hoverProgress,
    required this.isDragging,
    required this.colorScheme,
  });

  final double percent;
  final double hoverProgress;
  final bool isDragging;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0 || !width.isFinite || !height.isFinite) return;

    final centerY = height / 2.0;

    // 轨道三态厚度：常态 5.0px -> 悬停 7.0px -> 拖拽 8.5px
    const normalTrackHeight = 5.0;
    const hoveredTrackHeight = 7.0;
    const draggingTrackHeight = 8.5;
    final currentTrackHeight = isDragging
        ? draggingTrackHeight
        : (normalTrackHeight +
            (hoveredTrackHeight - normalTrackHeight) * hoverProgress);

    final trackRadius = Radius.circular(currentTrackHeight / 2.0);

    // 1. 背景底轨
    final bgPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        centerY - currentTrackHeight / 2.0,
        width,
        currentTrackHeight,
      ),
      trackRadius,
    );
    canvas.drawRRect(bgRect, bgPaint);

    final progressX = (percent * width).clamp(0.0, width);

    // 2. 激活时间轨
    if (progressX > 0) {
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.85),
            colorScheme.primary,
          ],
        ).createShader(Rect.fromLTWH(0, centerY - currentTrackHeight / 2.0,
            progressX, currentTrackHeight))
        ..style = PaintingStyle.fill;

      final activeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          centerY - currentTrackHeight / 2.0,
          progressX,
          currentTrackHeight,
        ),
        trackRadius,
      );
      canvas.drawRRect(activeRect, activePaint);
    }

    // 3. 晶体 Seek 滑块 (悬停 7.5px, 拖拽 9.5px)
    final baseThumbRadius = 7.5 * hoverProgress;
    final thumbRadius = isDragging ? 9.5 : baseThumbRadius;

    if (thumbRadius > 0.5) {
      final thumbCenter = Offset(progressX, centerY);

      // 外发光
      final outerGlowPaint = Paint()
        ..color = colorScheme.primary
            .withValues(alpha: isDragging ? 0.65 : 0.40 * hoverProgress)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          isDragging ? 14.0 : 10.0,
        );
      canvas.drawCircle(thumbCenter, thumbRadius + (isDragging ? 3.0 : 1.5), outerGlowPaint);

      // 白光晶体实体
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, thumbRadius * 0.75, corePaint);

      // 主色环圈
      final ringPaint = Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(thumbCenter, thumbRadius * 0.75, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualLayerTopTrackPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.colorScheme != colorScheme;
  }
}
