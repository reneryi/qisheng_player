import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 仿真果冻波形进度条组件
/// 使用 Canvas 绘制 50 根柱状波形，在播放时正弦律动，拖拽时呈物理果冻状受力挤压和回弹
class WaveformSlider extends StatefulWidget {
  const WaveformSlider({
    super.key,
    required this.value,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.isPlaying = false,
    this.height = 36.0, // 新增高度配置，默认 36 像素，用于适配底部紧凑面板防溢出
  });

  final double value; // 当前播放进度 (秒)
  final double max;   // 音频总时长 (秒)
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool isPlaying; // 是否播放中，用以驱动正弦律动
  final double height; // 绘制总高度

  @override
  State<WaveformSlider> createState() => _WaveformSliderState();
}

class _WaveformSliderState extends State<WaveformSlider> with TickerProviderStateMixin {
  // 持续播放律动动画控制器
  late final AnimationController _waveController;
  // 拖动时果冻受力挤压动画控制器 (0.0 -> 1.0)
  late final AnimationController _dragController;

  bool _isDragging = false;
  double _dragPercent = 0.0; // 当前手指拖拽所在的百分比位置 (0.0 到 1.0)
  double _dragWeight = 0.0;  // 果冻变形权重 (手势按下时平滑到 1.0，松开时回弹到 0)

  @override
  void initState() {
    super.initState();
    // 持续不断的播放微幅律动，频率为 1.5 秒一个周期
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isPlaying) {
      _waveController.repeat();
    }

    // 拖拽阻尼过渡：按下时以 curves.easeOut 变扁，松开时用物理弹簧效果进行回弹
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {
          _dragWeight = _dragController.value;
        });
      });
  }

  @override
  void didUpdateWidget(covariant WaveformSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  void _handleDragStart(double localX, double totalWidth) {
    if (widget.max <= 0 || totalWidth <= 0) return;
    setState(() {
      _isDragging = true;
      _dragPercent = (localX / totalWidth).clamp(0.0, 1.0);
    });
    // 手指按下，平滑加载果冻挤压权重 (0.0 -> 1.0)
    _dragController.animateTo(1.0, curve: Curves.easeOutCubic);
    
    final targetValue = _dragPercent * widget.max;
    widget.onChanged?.call(targetValue);
  }

  void _handleDragUpdate(double localX, double totalWidth) {
    if (widget.max <= 0 || totalWidth <= 0) return;
    setState(() {
      _dragPercent = (localX / totalWidth).clamp(0.0, 1.0);
    });
    final targetValue = _dragPercent * widget.max;
    widget.onChanged?.call(targetValue);
  }

  void _handleDragEnd() {
    if (!_isDragging) return;
    final targetValue = _dragPercent * widget.max;
    widget.onChangeEnd?.call(targetValue);

    setState(() {
      _isDragging = false;
    });

    // 松手时，应用物理弹簧模型 (SpringSimulation) 产生类似果冻剧烈抖动后归于平静的回弹效果
    const spring = SpringDescription(
      mass: 0.8,      // 质量：控制惯性
      stiffness: 140, // 刚度：控制频率
      damping: 10,    // 阻尼：控制衰减速度
    );
    final simulation = SpringSimulation(spring, _dragWeight, 0.0, 0.0);
    _dragController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final clampedDuration = widget.max > 0 ? widget.max : 1.0;
    // 拖拽时进度以拖拽百分比为准，平时以当前播放进度为准
    final double currentPercent = _isDragging 
        ? _dragPercent 
        : (widget.value / clampedDuration).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragStart: (details) => _handleDragStart(details.localPosition.dx, totalWidth),
          onHorizontalDragUpdate: (details) => _handleDragUpdate(details.localPosition.dx, totalWidth),
          onHorizontalDragEnd: (_) => _handleDragEnd(),
          onHorizontalDragCancel: () => _handleDragEnd(),
          onTapDown: (details) => _handleDragStart(details.localPosition.dx, totalWidth),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(totalWidth, widget.height), // 根据高度属性进行自适应绘制
                  painter: _WaveformSliderPainter(
                    percent: currentPercent,
                    wavePhase: _waveController.value * math.pi * 2,
                    isDragging: _isDragging,
                    dragPercent: _dragPercent,
                    dragWeight: _dragWeight,
                    isPlaying: widget.isPlaying,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// 自定义绘制波形进度条的 Painter
class _WaveformSliderPainter extends CustomPainter {
  const _WaveformSliderPainter({
    required this.percent,
    required this.wavePhase,
    required this.isDragging,
    required this.dragPercent,
    required this.dragWeight,
    required this.isPlaying,
    required this.colorScheme,
  });

  final double percent;        // 激活的长度占比 (0.0 到 1.0)
  final double wavePhase;      // 播放时波形的运动相位
  final bool isDragging;       // 是否正在被拖拽
  final double dragPercent;    // 拖拽焦点百分比 (0.0 到 1.0)
  final double dragWeight;     // 果冻受力物理形变系数 (0.0 -> 1.0)
  final bool isPlaying;        // 是否播放中
  final ColorScheme colorScheme;

  static const int _barCount = 52; // 精细波形柱子总数
  static const double _barWidth = 3.5; // 柱子宽度
  static const double _gap = 2.0;      // 柱子间距
  static const double _minHeight = 4.0; // 柱子最低高度

  @override
  void paint(Canvas canvas, Size size) {
    final double availableWidth = size.width;
    final double centerY = size.height / 2;

    // 计算实际总绘制宽度与起点，确保波形整体居中对齐
    final double totalPaintWidth = _barCount * _barWidth + (_barCount - 1) * _gap;
    final double startX = (availableWidth - totalPaintWidth) / 2;

    // 已播放主色画笔 (高饱和激活主色)
    final activePaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill; // 修正为 PaintingStyle

    // 未播放背景色画笔 (半透明高雅灰色)
    final inactivePaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.18) // 修正并优化为 withValues
      ..style = PaintingStyle.fill; // 修正为 PaintingStyle

    // 拖拽触点高亮标记画笔
    final focusPaint = Paint()
      ..color = colorScheme.secondary.withValues(alpha: 0.4) // 修正并优化为 withValues
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final double dragIndex = dragPercent * _barCount;

    // 逐根绘制波形柱
    for (int i = 0; i < _barCount; i++) {
      // 1. 生成经典高斯声波高矮轮廓 (中间高、两边低)
      final double normalizedIdx = i / (_barCount - 1);
      final double centerFactor = 1.0 - (normalizedIdx - 0.5).abs() * 2.0;
      double barHeight = _minHeight + 20.0 * math.sin(normalizedIdx * math.pi) * (0.6 + 0.4 * centerFactor);

      // 2. 仿真播放微幅正弦律动 (暂停时缓缓平息)
      if (isPlaying) {
        final double sineWave = math.sin(wavePhase + i * 0.22) * 3.5;
        barHeight += sineWave;
      }

      // 3. 极具生命力的【果冻挤压拉伸】物理仿真算法
      if (dragWeight > 0) {
        final double d = (i - dragIndex).abs();
        // 触点正下方高斯受力下凹系数 (中心受力向下压扁)
        final double squishForce = math.exp(-d * d / 20.0);
        // 触点左右两侧正弦隆起系数 (边缘隆起挤高)
        final double stretchForce = math.exp(-(d - 4.5) * (d - 4.5) / 10.0);

        // 应用受力物理混合
        double scale = 1.0 - 0.55 * squishForce * dragWeight; // 触点下方压缩
        scale += 0.32 * stretchForce * dragWeight;            // 两侧隆起
        barHeight *= scale;
      }

      // 确保高度越界安全
      barHeight = barHeight.clamp(_minHeight, size.height - 2.0);

      // 4. 计算当前柱子的 X 轴物理渲染坐标
      final double x = startX + i * (_barWidth + _gap);

      // 5. 确定当前柱子是否处于已播放的激活状态
      final bool isActive = (i / (_barCount - 1)) <= percent;

      // 6. 绘制圆角声波柱
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          centerY - barHeight / 2,
          _barWidth,
          barHeight,
        ),
        const Radius.circular(999), // 绘制为顶底端全圆角胶囊状
      );

      // 在触点焦点下方绘制光斑以提升质感
      if (isDragging && (i - dragIndex).abs() < 1.8) {
        canvas.drawRRect(
          rect.inflate(3),
          focusPaint,
        );
      }

      canvas.drawRRect(rect, isActive ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformSliderPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.dragPercent != dragPercent ||
        oldDelegate.dragWeight != dragWeight ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.colorScheme != colorScheme;
  }
}
