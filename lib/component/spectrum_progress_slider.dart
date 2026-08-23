import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 导入系统服务库用于键盘按键事件判断与 LogicalKeyboardKey 定义
import 'package:qisheng_player/utils.dart';

const double spectrumProgressMaxWidth = 284;

double resolveSpectrumProgressWidth(double availableWidth) {
  if (!availableWidth.isFinite || availableWidth <= 0) return 0;
  return math.min(availableWidth, spectrumProgressMaxWidth);
}

class SpectrumProgressSlider extends StatefulWidget {
  const SpectrumProgressSlider({
    super.key,
    required this.spectrum,
    required this.value,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.spectrumActive = false,
    this.height = 20,
  });

  final ValueListenable<List<double>> spectrum;
  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool spectrumActive;
  final double height;

  @override
  State<SpectrumProgressSlider> createState() => _SpectrumProgressSliderState();
}

class _SpectrumProgressSliderState extends State<SpectrumProgressSlider> {
  bool _dragging = false;
  bool _hovering = false;
  double _pointerPercent = 0;
  // 声明 FocusNode 以支持桌面端全键盘导航与快捷寻道
  late final FocusNode _focusNode;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'spectrum-progress-slider');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // 键盘快捷寻道处理：左/右方向键步进 5 秒，Home/End 键直达首尾
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_enabled || event is! KeyDownEvent) return KeyEventResult.ignored;

    const seekStep = 5.0; // 步进 5 秒
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final target = (widget.value - seekStep).clamp(0.0, widget.max);
      widget.onChanged?.call(target);
      widget.onChangeEnd?.call(target);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final target = (widget.value + seekStep).clamp(0.0, widget.max);
      widget.onChanged?.call(target);
      widget.onChangeEnd?.call(target);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.onChanged?.call(0.0);
      widget.onChangeEnd?.call(0.0);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      widget.onChanged?.call(widget.max);
      widget.onChangeEnd?.call(widget.max);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  double _percentAt(double localX, double width) {
    if (width <= 0) return 0;
    return (localX / width).clamp(0.0, 1.0);
  }

  void _updatePointer(double localX, double width, {bool notify = true}) {
    final percent = _percentAt(localX, width);
    setState(() => _pointerPercent = percent);
    if (notify) widget.onChanged?.call(percent * widget.max);
  }

  void _handleDragStart(DragStartDetails details, double width) {
    if (!_enabled) return;
    setState(() => _dragging = true);
    _updatePointer(details.localPosition.dx, width);
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    if (!_dragging) return;
    _updatePointer(details.localPosition.dx, width);
  }

  void _handleDragEnd() {
    if (!_dragging) return;
    final value = _pointerPercent * widget.max;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(value);
  }

  void _handleTap(TapUpDetails details, double width) {
    if (!_enabled) return;
    final percent = _percentAt(details.localPosition.dx, width);
    setState(() => _pointerPercent = percent);
    final value = percent * widget.max;
    widget.onChanged?.call(value);
    widget.onChangeEnd?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.max.isFinite && widget.max > 0 ? widget.max : 1.0;
    final progress = _dragging
        ? _pointerPercent
        : (widget.value / max).clamp(0.0, 1.0).toDouble();
    final showTooltip = (_hovering || _dragging) && widget.max > 0;
    final tooltipValue = _pointerPercent * widget.max;
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = resolveSpectrumProgressWidth(constraints.maxWidth);
        if (width <= 0) return const SizedBox.shrink();

        return Center(
          child: SizedBox(
            width: width,
            height: widget.height,
            child: Semantics(
              slider: true,
              enabled: _enabled,
              value: Duration(
                milliseconds: (widget.value * 1000).round(),
              ).toStringHMMSS(),
              // 包裹 Focus 节点以支持键盘焦点聚焦与键盘快捷键交互
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: Stack(
                  clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: _enabled
                        ? (details) => _handleDragStart(details, width)
                        : null,
                    onHorizontalDragUpdate: _enabled
                        ? (details) => _handleDragUpdate(details, width)
                        : null,
                    onHorizontalDragEnd:
                        _enabled ? (_) => _handleDragEnd() : null,
                    onHorizontalDragCancel: _enabled ? _handleDragEnd : null,
                    onTapUp: _enabled
                        ? (details) => _handleTap(details, width)
                        : null,
                    child: MouseRegion(
                      cursor: _enabled
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      onHover: (details) {
                        final percent =
                            _percentAt(details.localPosition.dx, width);
                        if (!_hovering || percent != _pointerPercent) {
                          setState(() {
                            _hovering = true;
                            _pointerPercent = percent;
                          });
                        }
                      },
                      onExit: (_) => setState(() => _hovering = false),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size(width, widget.height),
                          isComplex: true,
                          willChange: widget.spectrumActive,
                          painter: SpectrumProgressPainter(
                            spectrum: widget.spectrum,
                            progress: progress,
                            spectrumActive: widget.spectrumActive &&
                                !MediaQuery.disableAnimationsOf(context),
                            pointerPercent: _pointerPercent,
                            emphasizePointer: _dragging,
                            activeColor: scheme.primary,
                            inactiveColor:
                                scheme.onSurface.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showTooltip)
                    Positioned(
                      left: (_pointerPercent * width - 32)
                          .clamp(0.0, math.max(0.0, width - 64)),
                      bottom: widget.height + 6,
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer.withValues(
                                  alpha: 0.82,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: SizedBox(
                                width: 64,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    Duration(
                                      milliseconds:
                                          (tooltipValue * 1000).round(),
                                    ).toStringHMMSS(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
          ),
        ),
      );
      },
    );
  }
}

class SpectrumProgressPainter extends CustomPainter {
  SpectrumProgressPainter({
    required this.spectrum,
    required this.progress,
    required this.spectrumActive,
    required this.pointerPercent,
    required this.emphasizePointer,
    required this.activeColor,
    required this.inactiveColor,
  }) : super(repaint: spectrum);

  final ValueListenable<List<double>> spectrum;
  final double progress;
  final bool spectrumActive;
  final double pointerPercent;
  final bool emphasizePointer;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final values = spectrum.value;
    final hasSpectrum = spectrumActive &&
        values.isNotEmpty &&
        values.any((value) => value.isFinite && value > 0.003);
    if (!hasSpectrum) {
      _paintTrack(canvas, size, normalizedProgress);
      return;
    }

    final rail = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: 2,
      ),
      const Radius.circular(1),
    );
    canvas.drawRRect(rail, Paint()..color = inactiveColor);

    const gap = 1.5;
    final maxBars = math.max(1, ((size.width + gap) / 3.5).floor());
    final barCount = math.min(values.length, maxBars);
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;
    final centerY = size.height / 2;
    final maxHeight = math.max(2.0, size.height - 2);
    final pointerIndex = pointerPercent * math.max(1, barCount - 1);

    for (var index = 0; index < barCount; index++) {
      final sourcePosition =
          barCount == 1 ? 0.0 : index * (values.length - 1) / (barCount - 1);
      final magnitude = _interpolate(values, sourcePosition);
      var height = 2 + math.sqrt(magnitude) * (maxHeight - 2);
      if (emphasizePointer) {
        final distance = index - pointerIndex;
        height *= 1 + 0.14 * math.exp(-(distance * distance) / 10);
      }
      height = height.clamp(2.0, maxHeight);
      final x = index * (barWidth + gap);
      final barProgress = barCount == 1 ? 0.0 : index / (barCount - 1);
      final color =
          barProgress <= normalizedProgress ? activeColor : inactiveColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - height / 2, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        Paint()..color = color,
      );
    }
  }

  void _paintTrack(Canvas canvas, Size size, double normalizedProgress) {
    final track = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: 2,
      ),
      const Radius.circular(1),
    );
    canvas.drawRRect(track, Paint()..color = inactiveColor);
    if (normalizedProgress <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0,
          size.height / 2 - 1,
          size.width * normalizedProgress,
          2,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = activeColor,
    );
  }

  double _interpolate(List<double> values, double position) {
    final left = position.floor().clamp(0, values.length - 1);
    final right = position.ceil().clamp(0, values.length - 1);
    final t = position - left;
    final leftValue = _normalized(values[left]);
    final rightValue = _normalized(values[right]);
    return leftValue + (rightValue - leftValue) * t;
  }

  double _normalized(double value) {
    if (!value.isFinite) return 0;
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  bool shouldRepaint(covariant SpectrumProgressPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum ||
        oldDelegate.progress != progress ||
        oldDelegate.spectrumActive != spectrumActive ||
        oldDelegate.pointerPercent != pointerPercent ||
        oldDelegate.emphasizePointer != emphasizePointer ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
