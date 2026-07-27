import 'package:flutter/material.dart';

/// Displays a single line of text and scrolls it only when it does not fit.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.left,
    this.gap = 56,
    this.minDuration = const Duration(milliseconds: 4200),
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final double gap;
  final Duration minDuration;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  bool _scrolling = false;

  String get _text => widget.text.trim().isEmpty ? ' ' : widget.text.trim();

  double _lineHeight() {
    final height = widget.style.height ?? 1.2;
    return (widget.style.fontSize ?? 14) * height + 2;
  }

  void _measure(BoxConstraints constraints) {
    final painter = TextPainter(
      text: TextSpan(text: _text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final shouldScroll = constraints.hasBoundedWidth &&
        constraints.maxWidth > 0 &&
        _text.length > 18 &&
        painter.width > constraints.maxWidth + 0.5;
    _textWidth = painter.width;
    if (shouldScroll != _scrolling) {
      _scrolling = shouldScroll;
      if (_scrolling) {
        final distance = _textWidth + widget.gap;
        final duration = Duration(
          milliseconds: (distance * 45).round(),
        );
        _controller
          ..duration =
              duration > widget.minDuration ? duration : widget.minDuration
          ..repeat();
      } else {
        _controller
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _scrolling = false;
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints);
        final height = _lineHeight();
        final canFit = constraints.hasBoundedWidth &&
            _textWidth <= constraints.maxWidth + 0.5;
        if (!_scrolling || canFit) {
          return SizedBox(
            height: height,
            child: Align(
              alignment: widget.textAlign == TextAlign.center
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: Text(
                _text,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: widget.textAlign,
                style: widget.style,
              ),
            ),
          );
        }

        return SizedBox(
          height: height,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final distance = _textWidth + widget.gap;
                return Transform.translate(
                  offset: Offset(-distance * _controller.value, 0),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: distance * 2,
                    maxWidth: distance * 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_text, maxLines: 1, style: widget.style),
                        SizedBox(width: widget.gap),
                        Text(_text, maxLines: 1, style: widget.style),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
