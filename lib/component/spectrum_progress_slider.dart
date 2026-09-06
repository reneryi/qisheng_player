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
  late final ValueNotifier<double> _pointerNotifier;
  late final ValueNotifier<bool> _hoverNotifier;
  // 声明 FocusNode 以支持桌面端全键盘导航与快捷寻道
  late final FocusNode _focusNode;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _pointerNotifier = ValueNotifier<double>(0.0);
    _hoverNotifier = ValueNotifier<bool>(false);
    _focusNode = FocusNode(debugLabel: 'spectrum-progress-slider');
  }

  @override
  void dispose() {
    _pointerNotifier.dispose();
    _hoverNotifier.dispose();
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
    _pointerNotifier.value = percent;
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
    final value = _pointerNotifier.value * widget.max;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(value);
  }

  void _handleTap(TapUpDetails details, double width) {
    if (!_enabled) return;
    final percent = _percentAt(details.localPosition.dx, width);
    _pointerNotifier.value = percent;
    final value = percent * widget.max;
    widget.onChanged?.call(value);
    widget.onChangeEnd?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.max.isFinite && widget.max > 0 ? widget.max : 1.0;
    final progress = (widget.value / max).clamp(0.0, 1.0).toDouble();
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
                          _hoverNotifier.value = true;
                          _pointerNotifier.value = percent;
                        },
                        onExit: (_) => _hoverNotifier.value = false,
                        child: RepaintBoundary(
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              _pointerNotifier,
                              _hoverNotifier,
                            ]),
                            builder: (context, _) {
                              return CustomPaint(
                                size: Size(width, widget.height),
                                isComplex: true,
                                willChange: widget.spectrumActive,
                                painter: SpectrumProgressPainter(
                                  spectrum: widget.spectrum,
                                  progress: _dragging
                                      ? _pointerNotifier.value
                                      : progress,
                                  spectrumActive: widget.spectrumActive &&
                                      !MediaQuery.disableAnimationsOf(context),
                                  pointerPercent: _pointerNotifier.value,
                                  emphasizePointer: _dragging,
                                  activeColor: scheme.primary,
                                  inactiveColor:
                                      scheme.onSurface.withValues(alpha: 0.18),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _hoverNotifier,
                        _pointerNotifier,
                      ]),
                      builder: (context, _) {
                        final showTooltip =
                            (_hoverNotifier.value || _dragging) &&
                                widget.max > 0;
                        if (!showTooltip) return const SizedBox.shrink();

                        final pointerPercent = _pointerNotifier.value;
                        final tooltipValue = pointerPercent * widget.max;

                        return Positioned(
                          left: (pointerPercent * width - 32)
                              .clamp(0.0, math.max(0.0, width - 64)),
                          bottom: widget.height + 6,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
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
                        );
                      },
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

  // 复用 Paint 实例，消除每一帧（60fps）内部循环创建数十个 Paint 造成的严重 GC 颠簸
  final Paint _activePaint = Paint();
  final Paint _inactivePaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _activePaint.color = activeColor;
    _inactivePaint.color = inactiveColor;

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
    canvas.drawRRect(rail, _inactivePaint);

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
      final paint =
          barProgress <= normalizedProgress ? _activePaint : _inactivePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - height / 2, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
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
    canvas.drawRRect(track, _inactivePaint);
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
      _activePaint,
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
