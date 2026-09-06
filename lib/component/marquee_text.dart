import 'package:flutter/material.dart';

/// 单行文本跑马灯组件：仅在文字超出容器约束宽度时启动平滑呼吸式滚动
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.left,
    this.gap = 48,
    this.minDuration = const Duration(milliseconds: 4000),
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

    // 纯粹依据几何宽度判断是否需要滚动，彻底移除字符串长度硬编码限制
    final shouldScroll = constraints.hasBoundedWidth &&
        constraints.maxWidth > 0 &&
        painter.width > (constraints.maxWidth + 1.0);

    _textWidth = painter.width;
    if (shouldScroll != _scrolling) {
      _scrolling = shouldScroll;
      if (_scrolling) {
        final distance = _textWidth + widget.gap;
        // 每滚动 1 像素约需 32ms，加上首尾停留 3000ms
        final scrollMs = (distance * 32).round();
        final totalDuration = Duration(
          milliseconds: (scrollMs + 3000).clamp(widget.minDuration.inMilliseconds, 30000),
        );
        _controller
          ..duration = totalDuration
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
            _textWidth <= constraints.maxWidth + 1.0;

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

        final distance = _textWidth + widget.gap;
        final cachedContent = OverflowBox(
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
        );

        return SizedBox(
          height: height,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.04, 0.96, 1.0],
              ).createShader(bounds);
            },
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;

                  // 呼吸式停顿曲线：
                  // 0.0 ~ 0.20 (前 20% 时间)：停留在起点，方便阅读歌名开头
                  // 0.20 ~ 0.80 (中间 60% 时间)：平滑匀速滚动到末尾
                  // 0.80 ~ 1.00 (后 20% 时间)：停留在循环接合点
                  double scrollProgress;
                  if (t < 0.20) {
                    scrollProgress = 0.0;
                  } else if (t < 0.80) {
                    scrollProgress = (t - 0.20) / 0.60;
                  } else {
                    scrollProgress = 1.0;
                  }

                  return Transform.translate(
                    offset: Offset(-distance * scrollProgress, 0),
                    child: child,
                  );
                },
                child: cachedContent,
              ),
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
