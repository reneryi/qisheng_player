import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 封面交错淡入组件（1.4 新增）。
///
/// - 图片加载完成前显示占位（broken_image）
/// - 加载完成后 220ms easeOutCubic 淡入
/// - 交错延迟 `min(index * 25, 200)`ms，消除整页齐刷的“瀑布感”
/// - 缓存命中（同步解码）时直接显示，快速滚动回滚不闪烁
///
/// 复用现有 ImageProvider 缓存（不做二次解码），仅负责 UI 层淡入。
class CoverFadeImage extends StatefulWidget {
  const CoverFadeImage({
    super.key,
    required this.provider,
    required this.index,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final ImageProvider? provider;
  final int index;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<CoverFadeImage> createState() => _CoverFadeImageState();
}

class _CoverFadeImageState extends State<CoverFadeImage>
    with SingleTickerProviderStateMixin {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  late final AnimationController _controller;
  Timer? _staggerTimer;

  /// 交错延迟已结束（允许展示内容）。
  bool _ready = false;

  /// 图片加载失败（显示占位）。
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_imageStream == null) {
      _resolveOrScheduleLoad();
    }
  }

  @override
  void didUpdateWidget(covariant CoverFadeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider == widget.provider) return;
    _disposeStream();
    _resolveOrScheduleLoad();
  }

  void _resolveOrScheduleLoad() {
    _staggerTimer?.cancel();
    final provider = widget.provider;
    if (provider == null) {
      _ready = false;
      _failed = false;
      _controller.value = 0;
      _schedulePlaceholderDelay();
      return;
    }

    final configuration = createLocalImageConfiguration(context);
    final stream = provider.resolve(configuration);
    _imageStream = stream;

    bool synchronous = true;
    _listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!mounted) return;
        final isSync = synchronousCall || synchronous;
        if (isSync) {
          _ready = true;
          _failed = false;
          _controller.value = 1;
        } else {
          setState(() {
            _ready = true;
            _failed = false;
          });
          _controller.forward(from: 0);
        }
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _failed = true;
        });
        _controller.value = 1;
      },
    );

    stream.addListener(_listener!);
    synchronous = false;

    if (!_ready) {
      _controller.value = 0;
    }
  }

  void _schedulePlaceholderDelay() {
    _staggerTimer?.cancel();
    final delay = Duration(milliseconds: math.min(widget.index * 25, 200));
    _staggerTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    });
  }

  void _disposeStream() {
    final stream = _imageStream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _listener = null;
    _imageStream = null;
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _disposeStream();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 占位图标尺寸：对非有限尺寸（如网格卡片中的 infinity）做容错
    final iconSize = (math.min(widget.width ?? 48, widget.height ?? 48) * 0.5)
        .clamp(8.0, 96.0);
    final placeholder = widget.placeholder ??
        Container(
          color: scheme.surfaceContainerHigh,
          child: Icon(
            Symbols.broken_image,
            size: iconSize,
            color: scheme.onSurface.withValues(alpha: 0.4),
          ),
        );

    final showImage = _ready && !_failed && widget.provider != null;
    final content = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: showImage
            ? FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                ),
                child: Image(
                  image: widget.provider!,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
              )
            : placeholder,
      ),
    );

    return SizedBox(width: widget.width, height: widget.height, child: content);
  }
}
