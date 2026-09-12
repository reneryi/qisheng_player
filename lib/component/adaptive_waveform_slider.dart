import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/utils.dart';

/// 宽度自适应几何计算函数
/// 首根柱左边缘对齐 0，末根柱右边缘对齐 W
({int count, double barWidth, double gap}) calculateAdaptiveWaveformGeometry(
  double totalWidth, {
  double targetBarWidth = 3.8,
  double targetGap = 1.8,
  double gapRatio = 0.47,
  int minBars = 24,
  int maxBars = 240,
}) {
  if (!totalWidth.isFinite || totalWidth <= 0) {
    return (count: 0, barWidth: 0.0, gap: 0.0);
  }
  final n = ((totalWidth + targetGap) / (targetBarWidth + targetGap))
      .round()
      .clamp(minBars, maxBars);
  if (n <= 1) {
    return (count: 1, barWidth: totalWidth, gap: 0.0);
  }
  final barWidth = totalWidth / (n + gapRatio * (n - 1));
  final gap = gapRatio * barWidth;
  return (count: n, barWidth: barWidth, gap: gap);
}

/// 32位 FNV-1a 哈希，依据曲目元数据计算确定性种子
int generateAudioWaveformSeed(Audio? audio) {
  if (audio == null) return 0x811c9dc5;
  int hash = 0x811c9dc5;
  void mix(String s) {
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
  }

  mix(audio.path);
  mix(audio.duration.toString());
  mix(audio.title);
  mix(audio.artist);
  mix(audio.album);
  return hash;
}

/// 差异化平滑波形高度生成器 (512 点查找表)
class AudioWaveformCache {
  static final Map<int, Float32List> _cache = {};

  static Float32List getWaveformLut(int seed) {
    final existing = _cache[seed];
    if (existing != null) return existing;

    final lut = Float32List(512);
    // 从种子中派生伪随机参数
    int rngState = seed;
    double nextRand() {
      rngState = (rngState * 1664525 + 1013904223) & 0xFFFFFFFF;
      return (rngState >> 16) / 65535.0;
    }

    final f1 = 3.0 + nextRand() * 6.0; // 宏观中频 3~9
    final f2 = 10.0 + nextRand() * 10.0; // 活跃中高频 10~20
    final f3 = 22.0 + nextRand() * 14.0; // 微观起伏 22~36
    final phi1 = nextRand() * 2 * math.pi;
    final phi2 = nextRand() * 2 * math.pi;
    final phi3 = nextRand() * 2 * math.pi;

    for (int i = 0; i < 512; i++) {
      final t = i / 511.0;
      // 1. 宏观乐章包络 (首尾缓入缓出，中部开阔)
      final macro = math.pow(math.sin(t * math.pi), 0.38).toDouble() *
          (0.70 + 0.30 * math.sin(t * 3.0 * math.pi + phi1));

      // 2. 中频旋律与节奏起伏
      final melody = 0.48 * math.sin(2 * math.pi * f1 * t + phi1) +
          0.34 * math.cos(2 * math.pi * f2 * t + phi2) +
          0.18 * math.sin(2 * math.pi * f3 * t + phi3);

      // 3. 归一化起伏并映射至 [0.12, 1.0]
      final raw = (macro * (0.62 + 0.38 * (melody + 1.0) / 2.0));
      lut[i] = raw.clamp(0.12, 1.0);
    }

    if (_cache.length > 64) {
      _cache.remove(_cache.keys.first);
    }
    _cache[seed] = lut;
    return lut;
  }
}

/// 自适应动态果冻声波轨 (Adaptive Jelly Waveform Slider)
///
/// 特性：
/// 1. 宽度自适应严丝合缝两端对齐，首根柱左边缘对齐 0，末根柱右边缘对齐 W；
/// 2. 物理果冻手感：
///    - 悬停高斯引力隆起（G_hover 磁性吸附聚焦）；
///    - 拖拽泊松受力挤压扁平与两侧微澜隆起；
///    - 松手欠阻尼 SpringSimulation 回弹振荡（使用 unbounded 控制器防止负数过冲断言崩溃）；
/// 3. 基于曲目特征生成确定性差异化波形（512 维 LUT 预计算，$O(N)$ 零 GC 快速绘制）；
/// 4. 播放点处绘制高对比度发光寻道光针与外层呼吸光晕；
/// 5. 滚轮 5 秒步进微调与浮动毛玻璃时间气泡。
class AdaptiveWaveformSlider extends StatefulWidget {
  const AdaptiveWaveformSlider({
    super.key,
    required this.value,
    required this.max,
    this.audio,
    this.isPlaying = false,
    this.spectrum,
    this.spectrumActive = false,
    this.onChanged,
    this.onChangeEnd,
    this.height = 20.0,
  });

  final double value;
  final double max;
  final Audio? audio;
  final bool isPlaying;
  final ValueListenable<List<double>>? spectrum;
  final bool spectrumActive;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;

  @override
  State<AdaptiveWaveformSlider> createState() => _AdaptiveWaveformSliderState();
}

class _AdaptiveWaveformSliderState extends State<AdaptiveWaveformSlider>
    with TickerProviderStateMixin {
  late final AnimationController _hoverController;
  // 必须使用 unbounded 控制器，防止欠阻尼弹簧过冲振荡到负数时触发 assertion 报错
  late final AnimationController _dragController;
  late final AnimationController _rhythmController;

  bool _isHovering = false;
  double _hoverPercent = 0.0;

  bool _isDragging = false;
  double _dragPercent = 0.0;

  Timer? _wheelThrottleTimer;
  double? _pendingWheelSeek;

  double _smoothedConfidence = 0.0;

  @visibleForTesting
  bool get isRhythmAnimating => _rhythmController.isAnimating;

  @visibleForTesting
  double get smoothedConfidence => _smoothedConfidence;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _dragController = AnimationController.unbounded(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dragController.value = 0.0;
    _rhythmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.spectrumActive) {
      _rhythmController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveWaveformSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spectrumActive && !_rhythmController.isAnimating) {
      _rhythmController.repeat();
    }
  }

  @override
  void dispose() {
    _wheelThrottleTimer?.cancel();
    _hoverController.dispose();
    _dragController.dispose();
    _rhythmController.dispose();
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
    _hoverController.animateTo(1.0, curve: Curves.easeOut);
  }

  void _handleHoverExit() {
    if (_isHovering) {
      setState(() => _isHovering = false);
      _hoverController.animateTo(0.0, curve: Curves.easeIn);
    }
  }

  void _handleDragStart(double localX, double totalWidth) {
    if (!widget.max.isFinite || widget.max <= 0 || !totalWidth.isFinite || totalWidth <= 0 || !localX.isFinite) return;
    final percent = (localX / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _dragPercent = percent;
    });
    _dragController.animateTo(1.0, curve: Curves.easeOutCubic);
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

    // 松手时，触发欠阻尼物理弹簧振荡 (mass: 1.0, stiffness: 180.0, damping: 12.0)
    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 180.0,
      damping: 12.0,
    );
    final simulation = SpringSimulation(
      spring,
      _dragController.value,
      0.0,
      0.0,
    );
    _dragController.animateWith(simulation);
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
        final seed = generateAudioWaveformSeed(widget.audio);
        final lut = AudioWaveformCache.getWaveformLut(seed);

        return Listener(
          onPointerSignal: (signal) => _handlePointerSignal(signal, totalWidth),
          child: SizedBox(
            width: totalWidth,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
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
                      onHover: (d) => _handleHover(d.localPosition.dx, totalWidth),
                      onExit: (_) => _handleHoverExit(),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _hoverController,
                          _dragController,
                          _rhythmController,
                          if (widget.spectrum != null) widget.spectrum!,
                        ]),
                        builder: (context, _) {
                          // 1. 150ms 一阶阻尼低通滤波器与置信度平滑滤波 (随 60fps 帧推进实时计算)
                          final targetConfidence = widget.spectrumActive ? 1.0 : 0.0;
                          final step = targetConfidence > _smoothedConfidence ? 0.16 : 0.12;
                          _smoothedConfidence += (targetConfidence - _smoothedConfidence) * step;
                          if (targetConfidence == 0.0) {
                            // 线性底垫确保在 200ms (约 12-14 帧) 内彻底归零，杜绝渐近线长尾挂起
                            _smoothedConfidence = math.max(0.0, _smoothedConfidence - 0.04);
                          }

                          if (targetConfidence == 0.0 && _smoothedConfidence <= 0.005) {
                            _smoothedConfidence = 0.0;
                            if (_rhythmController.isAnimating) {
                              _rhythmController.stop();
                            }
                          } else if (widget.spectrumActive && !_rhythmController.isAnimating) {
                            _rhythmController.repeat();
                          }

                          // 2. 实时频谱能量提取与多频段加权
                          double effectiveBass = 0.0;
                          double effectiveMid = 0.0;
                          double effectiveTreble = 0.0;

                          final bins = widget.spectrumActive ? widget.spectrum?.value : null;
                          if (_smoothedConfidence > 0.0 && bins != null && bins.isNotEmpty) {
                            final len = bins.length;
                            final bEnd = math.min(12, len);
                            double bassSum = 0.0;
                            for (int i = 0; i < bEnd; i++) {
                              final v = bins[i];
                              if (v.isFinite && v > 0) {
                                bassSum += math.pow(v.clamp(0.0, 1.0), 1.2);
                              }
                            }
                            final bassRaw = bEnd > 0 ? (bassSum / bEnd).clamp(0.0, 1.0) : 0.0;

                            final mStart = math.min(12, len);
                            final mEnd = math.min(38, len);
                            double midSum = 0.0;
                            for (int i = mStart; i < mEnd; i++) {
                              final v = bins[i];
                              if (v.isFinite && v > 0) midSum += v.clamp(0.0, 1.0);
                            }
                            final midRaw = (mEnd - mStart) > 0 ? (midSum / (mEnd - mStart)).clamp(0.0, 1.0) : 0.0;

                            final tStart = math.min(38, len);
                            final tEnd = math.min(64, len);
                            double trebleSum = 0.0;
                            for (int i = tStart; i < tEnd; i++) {
                              final v = bins[i];
                              if (v.isFinite && v > 0) trebleSum += v.clamp(0.0, 1.0);
                            }
                            final trebleRaw = (tEnd - tStart) > 0 ? (trebleSum / (tEnd - tStart)).clamp(0.0, 1.0) : 0.0;

                            effectiveBass = bassRaw * _smoothedConfidence;
                            effectiveMid = midRaw * _smoothedConfidence;
                            effectiveTreble = trebleRaw * _smoothedConfidence;
                          }

                          return RepaintBoundary(
                            child: ExcludeSemantics(
                              child: CustomPaint(
                                size: Size(totalWidth, widget.height),
                                painter: _AdaptiveWaveformPainter(
                                  percent: currentPercent,
                                  hoverPercent: _hoverPercent,
                                  hoverAlpha: _hoverController.value,
                                  dragPercent: _dragPercent,
                                  dragAlpha: _dragController.value,
                                  isDragging: _isDragging,
                                  lut: lut,
                                  colorScheme: colorScheme,
                                  effectiveBass: effectiveBass,
                                  effectiveMid: effectiveMid,
                                  effectiveTreble: effectiveTreble,
                                  rhythmPhase: _rhythmController.value,
                                  bins: bins,
                                  smoothedConfidence: _smoothedConfidence,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

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

class _AdaptiveWaveformPainter extends CustomPainter {
  _AdaptiveWaveformPainter({
    required this.percent,
    required this.hoverPercent,
    required this.hoverAlpha,
    required this.dragPercent,
    required this.dragAlpha,
    required this.isDragging,
    required this.lut,
    required this.colorScheme,
    required this.effectiveBass,
    required this.effectiveMid,
    required this.effectiveTreble,
    required this.rhythmPhase,
    this.bins,
    this.smoothedConfidence = 1.0,
  });

  final double percent;
  final double hoverPercent;
  final double hoverAlpha;
  final double dragPercent;
  final double dragAlpha;
  final bool isDragging;
  final Float32List lut;
  final ColorScheme colorScheme;
  final double effectiveBass;
  final double effectiveMid;
  final double effectiveTreble;
  final double rhythmPhase;
  final List<double>? bins;
  final double smoothedConfidence;

  // 类级静态复用 Paint，60fps 零 GC
  static final Paint _activePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _inactivePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint = Paint();
  static final Paint _needlePaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0 || !width.isFinite || !height.isFinite) return;

    final geo = calculateAdaptiveWaveformGeometry(width);
    final count = geo.count;
    final barWidth = geo.barWidth;
    final gap = geo.gap;
    if (count <= 0 || barWidth <= 0) return;

    final centerY = height / 2.0;
    const minBarHeight = 4.5;
    final maxBarHeight = math.max(minBarHeight, height - 2.0);

    final seekX = (percent * width).clamp(0.0, width);
    final hoverIndex = hoverPercent * (count - 1);
    final dragIndex = dragPercent * (count - 1);

    _activePaint.color = colorScheme.primary;
    _inactivePaint.color = colorScheme.onSurface.withValues(alpha: 0.16);

    final barRadius = Radius.circular(barWidth / 2.0);

    final uPlay = percent.clamp(0.0, 1.0);
    final phi = rhythmPhase * 2 * math.pi;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final centerBarX = x + barWidth / 2.0;
      final u = i / math.max(1, count - 1);

      // 1. 从 512 维 LUT 线性插值出基础音轨包络
      final lutPos = u * 511.0;
      final lutIdx = lutPos.floor().clamp(0, 510);
      final lutFract = lutPos - lutIdx;
      final baseNorm = lut[lutIdx] * (1.0 - lutFract) + lut[lutIdx + 1] * lutFract;

      // 2. 真实音频节拍冲程与多频段能量律动 (8px~26px 澎湃起伏跳跃)
      // u: 0.0 (最左低频) -> 1.0 (最右高频)
      final bassWeight = (1.0 - 0.25 * u).clamp(0.0, 1.0);
      // 强节拍鼓点冲程 (重低音爆发)
      final beatKick = effectiveBass * 1.85 * bassWeight;

      // 局部真实频段跳动 (对齐 64 频段实时 FFT)
      double localFft = 0.0;
      if (bins != null && bins!.isNotEmpty) {
        final binIdx = (u * (bins!.length - 1)).round().clamp(0, bins!.length - 1);
        final rawBin = bins![binIdx];
        if (rawBin.isFinite && rawBin > 0) {
          localFft = rawBin.clamp(0.0, 1.0) * 1.25;
        }
      }

      // 连续周期流动波 (无缝 2*pi 倍数，消除相位跳变，并提供基准律动呼吸)
      final travelWave = (0.35 * math.sin(2.0 * phi - 3.0 * u * math.pi) +
                          0.22 * math.cos(3.0 * phi + 4.0 * u * math.pi)) *
                          (0.40 + 0.90 * math.max(effectiveMid, effectiveBass));

      // 播放点附近声波伴随光冕微波 (Playhead Corona)
      final dPlay = (u - uPlay).abs();
      final gCorona = math.exp(-(dPlay * dPlay) / (2 * 0.08 * 0.08));
      final coronaWave = gCorona * (0.50 * effectiveMid + 0.35 * effectiveTreble);

      // 综合跳动能量 (在播放时显著跃升，暂停时平滑降为 0)
      final totalRhythm = (beatKick + localFft + travelWave + coronaWave) * smoothedConfidence;
      final rhythmStroke = totalRhythm.clamp(0.0, 2.2);

      // 3. 悬停高斯引力吸附隆起 (Hover Attraction Well)
      double hoverScale = 1.0;
      if (hoverAlpha > 0.001) {
        final dHover = (i - hoverIndex).abs();
        final gHover = math.exp(-(dHover * dHover) / (2 * 2.8 * 2.8));
        hoverScale = 1.0 + 0.42 * gHover * hoverAlpha;
      }

      // 4. 拖拽受力挤压扁平感与泊松体积守恒 (Drag Squish & Bulge)
      double dragScale = 1.0;
      if (dragAlpha.abs() > 0.001) {
        final dDrag = (i - dragIndex).abs();
        final squish = math.exp(-(dDrag * dDrag) / (2 * 2.0 * 2.0));
        final bulge = math.exp(-((dDrag - 4.5) * (dDrag - 4.5)) / (2 * 2.2 * 2.2));
        dragScale = 1.0 - 0.60 * squish * dragAlpha + 0.35 * bulge * dragAlpha;
      }

      // 5. 动态高度合成：基础包络 + 显著可视的跳跃冲程
      final dynamicNorm = ((baseNorm * (0.85 + 0.85 * rhythmStroke) + 0.55 * rhythmStroke) * hoverScale * dragScale).clamp(0.08, 1.65);
      final barHeight = (minBarHeight + dynamicNorm * (maxBarHeight - minBarHeight))
          .clamp(minBarHeight, height);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          centerY - barHeight / 2.0,
          barWidth,
          barHeight,
        ),
        barRadius,
      );

      final isPlayed = centerBarX <= seekX;
      canvas.drawRRect(rrect, isPlayed ? _activePaint : _inactivePaint);
    }

    // 5. 播放点发光寻道光针与呼吸光晕 (w=8.0px, 拖拽 9.0px)
    if (seekX >= 0) {
      final needleCenter = Offset(seekX, centerY);

      // 外层高斯呼吸光晕
      _glowPaint
        ..color = colorScheme.primary.withValues(alpha: isDragging ? 0.65 : 0.38)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          isDragging ? 8.0 : 4.0,
        );
      final glowRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: needleCenter,
          width: isDragging ? 9.0 : 8.0,
          height: height,
        ),
        const Radius.circular(3.0),
      );
      canvas.drawRRect(glowRect, _glowPaint);

      // 高亮实体光针
      final needleColor = Color.lerp(colorScheme.primary, Colors.white, 0.75)!;
      _needlePaint.color = needleColor;
      final needleRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: needleCenter,
          width: 2.5,
          height: height,
        ),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(needleRect, _needlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AdaptiveWaveformPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.hoverPercent != hoverPercent ||
        oldDelegate.hoverAlpha != hoverAlpha ||
        oldDelegate.dragPercent != dragPercent ||
        oldDelegate.dragAlpha != dragAlpha ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.lut != lut ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.effectiveBass != effectiveBass ||
        oldDelegate.effectiveMid != effectiveMid ||
        oldDelegate.effectiveTreble != effectiveTreble ||
        oldDelegate.rhythmPhase != rhythmPhase;
  }
}
