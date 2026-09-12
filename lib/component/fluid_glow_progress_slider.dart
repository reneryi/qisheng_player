import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qisheng_player/utils.dart';

/// 全宽流体微光交互轨 (Fluid Ambient Glow Slider)
///
/// 特性：
/// 1. 弹性撑满可用视口宽度，彻底消除 284px 死区；
/// 2. 三态微交互：
///    - 常态：2.5px 极简细轨，无滑块；
///    - 悬停：180ms 平滑展开至 4.5px，浮现 r=6px 双层发光 Thumb 与毛玻璃时间气泡；
///    - 拖拽：Thumb 强化放大至 7.5px，高亮微动效；
/// 3. 桌面滚轮微调：拦截 PointerScrollEvent，实现 5 秒步进微调与节流防抖；
/// 4. 浮动气泡使用 Stack(clipBehavior: Clip.none) 悬空，宿主高度严格约束在 14~20px，杜绝 RenderFlex overflow。
class FluidGlowProgressSlider extends StatefulWidget {
  const FluidGlowProgressSlider({
    super.key,
    required this.value,
    required this.max,
    this.buffered,
    this.onChanged,
    this.onChangeEnd,
    this.height = 20.0,
  });

  final double value;
  final double max;
  final double? buffered;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;

  @override
  State<FluidGlowProgressSlider> createState() => _FluidGlowProgressSliderState();
}

class _FluidGlowProgressSliderState extends State<FluidGlowProgressSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _hoverAnimation;

  bool _isHovering = false;
  double _hoverX = 0.0;

  bool _isDragging = false;
  double _dragPercent = 0.0;

  Timer? _wheelThrottleTimer;
  double? _pendingWheelSeek;

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
  }

  @override
  void dispose() {
    _wheelThrottleTimer?.cancel();
    _hoverController.dispose();
    super.dispose();
  }

  void _handleHover(double localX, double totalWidth) {
    if (!widget.max.isFinite || widget.max <= 0 || !totalWidth.isFinite || totalWidth <= 0 || !localX.isFinite) {
      if (_isHovering) _handleHoverExit();
      return;
    }
    _hoverX = localX.clamp(0.0, totalWidth);
    if (!_isHovering) {
      setState(() => _isHovering = true);
      _hoverController.forward();
    } else {
      setState(() {});
    }
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

    // 向上滚动快进 5s，向下滚动快退 5s
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
        final tooltipPercent = _isDragging
            ? _dragPercent
            : (totalWidth > 0 ? (_hoverX / totalWidth).clamp(0.0, 1.0) : 0.0);
        final tooltipSeconds = showTooltip ? tooltipPercent * widget.max : 0.0;
        final activeX = tooltipPercent * totalWidth;
        const bubbleWidth = 72.0;
        final bubbleLeft = (activeX - bubbleWidth / 2.0).clamp(
          0.0,
          math.max<double>(0.0, totalWidth - bubbleWidth),
        );

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Listener(
          onPointerSignal: (signal) => _handlePointerSignal(signal, totalWidth),
          child: SizedBox(
            width: totalWidth,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 轨道与滑块绘制层
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
                        animation: _hoverAnimation,
                        builder: (context, _) {
                          return RepaintBoundary(
                            child: CustomPaint(
                              size: Size(totalWidth, widget.height),
                              painter: _FluidGlowSliderPainter(
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

                // 悬空时间预览气泡 (采用 Stack(clipBehavior: Clip.none) 绝不引起高度溢出)
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

class _FluidGlowSliderPainter extends CustomPainter {
  _FluidGlowSliderPainter({
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

    // 1. 轨道粗细三态计算 (等比例放大提升体量感，常态平直 5.5px -> 悬停展开 7.5px -> 拖拽 8.0px)
    const normalTrackHeight = 5.5;
    const hoveredTrackHeight = 7.5;
    const draggingTrackHeight = 8.0;

    final currentTrackHeight = isDragging
        ? draggingTrackHeight
        : (normalTrackHeight + (hoveredTrackHeight - normalTrackHeight) * hoverProgress);

    final trackRadius = Radius.circular(currentTrackHeight / 2.0);
    final trackTop = centerY - currentTrackHeight / 2.0;

    // 2. 绘制背景凹槽底轨 (Dark Translucent Trench)
    final bgPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, width, currentTrackHeight),
      trackRadius,
    );
    canvas.drawRRect(bgRect, bgPaint);

    final progressX = (percent * width).clamp(0.0, width);
    if (progressX <= 0.001) return;

    // 3. 绘制基础已播轨道 (Base Played Track - 柔和半透明基底，为向左激光束提供强烈对比明暗衬托)
    final activeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, progressX, currentTrackHeight),
      trackRadius,
    );

    final baseActivePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          colorScheme.primary.withValues(alpha: 0.28),
          colorScheme.primary.withValues(alpha: 0.42),
        ],
      ).createShader(Rect.fromLTWH(0, trackTop, progressX, currentTrackHeight))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(activeRect, baseActivePaint);

    // 4. 绘制流体激光束向左衰减拖尾 (Beam / Comet Trail Effect)
    // 扩展光束有效照射长度至 130px，呈现显著的向左强光照照射效果
    const maxBeamLength = 130.0;
    final beamLength = math.min(maxBeamLength, progressX);

    if (beamLength > 2.0) {
      final beamStartX = progressX - beamLength;
      final beamRect = Rect.fromLTWH(beamStartX, trackTop, beamLength, currentTrackHeight);

      // 4.1 纵向外溢发散光芒 (Beam Bloom Glow) - 投射向左的强激光外溢辉光
      final beamBloomAlpha = (1.0 - hoverProgress * 0.75).clamp(0.0, 1.0);
      if (beamBloomAlpha > 0.05) {
        const bloomHeight = 14.0;
        final bloomRect = Rect.fromLTWH(
          beamStartX,
          centerY - bloomHeight / 2.0,
          beamLength + 2.0,
          bloomHeight,
        );
        final bloomPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.45, 0.80, 1.0],
            colors: [
              colorScheme.primary.withValues(alpha: 0.0),
              colorScheme.primary.withValues(alpha: 0.18 * beamBloomAlpha),
              Color.lerp(colorScheme.primary, Colors.white, 0.45)!
                  .withValues(alpha: 0.50 * beamBloomAlpha),
              Colors.white.withValues(alpha: 0.78 * beamBloomAlpha),
            ],
          ).createShader(bloomRect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

        canvas.drawPath(
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                bloomRect,
                const Radius.circular(bloomHeight / 2.0),
              ),
            ),
          bloomPaint,
        );
      }

      // 4.2 核心激光高能流束：5 段强烈能量渐变，头端极高亮
      final beamShader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0.0, 0.35, 0.70, 0.88, 1.0],
        colors: [
          colorScheme.primary.withValues(alpha: 0.0), // 尾端自然过渡
          colorScheme.primary.withValues(alpha: 0.45), // 远端光子束
          colorScheme.primary.withValues(alpha: 0.90), // 主激光流
          Color.lerp(colorScheme.primary, Colors.white, 0.65)!
              .withValues(alpha: 0.98), // 高能电光
          Colors.white.withValues(alpha: 1.0), // 头端焦点高光
        ],
      ).createShader(beamRect);

      final beamPaint = Paint()
        ..shader = beamShader
        ..style = PaintingStyle.fill;

      // 裁剪在已播轨道圆角内，确保平齐闭合
      canvas.save();
      canvas.clipRRect(activeRect);
      canvas.drawRect(beamRect, beamPaint);
      canvas.restore();
    }

    // 5. 常态高亮聚焦点 (Focus Core)
    // 未悬停常态：纯平直无任何圆圈凸起，使用纯白胶囊光核锁定播放头位置
    final normalCoreAlpha = (1.0 - hoverProgress).clamp(0.0, 1.0);
    if (normalCoreAlpha > 0.05) {
      const coreWidth = 3.2;
      final coreLeft = (progressX - coreWidth).clamp(0.0, width);
      final coreRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(coreLeft, trackTop, coreWidth, currentTrackHeight),
        Radius.circular(currentTrackHeight / 2.0),
      );

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.98 * normalCoreAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(coreRect, corePaint);
    }

    // 6. 悬停与拖拽态发光圆圈 Thumb 滑块
    // 常态 hoverProgress = 0 时隐藏；悬停时优雅浮现 (r = 6.5px)，拖拽时强化至 8.0px
    final baseThumbRadius = 6.5 * hoverProgress;
    final thumbRadius = isDragging ? 8.0 : baseThumbRadius;

    if (thumbRadius > 0.5) {
      final thumbCenter = Offset(progressX, centerY);

      // 6.1 外层高斯漫射光晕
      final outerAlpha = isDragging ? 0.50 : (0.35 * hoverProgress);
      final outerGlowPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: outerAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDragging ? 16.0 : 12.0);
      canvas.drawCircle(thumbCenter, thumbRadius + (isDragging ? 3.5 : 2.0), outerGlowPaint);

      // 6.2 内层致密凝聚光晕
      final innerAlpha = isDragging ? 0.85 : (0.70 * hoverProgress);
      final innerGlowPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: innerAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(thumbCenter, thumbRadius, innerGlowPaint);

      // 6.3 核心高对比纯白晶体
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, thumbRadius * 0.70, corePaint);

      // 6.4 高清外轮廓描边
      final ringPaint = Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(thumbCenter, thumbRadius * 0.70, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FluidGlowSliderPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.colorScheme != colorScheme;
  }
}
