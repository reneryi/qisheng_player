import 'dart:math' as math;
import 'dart:ui' show ImageFilter; // 引入 ImageFilter 支持气泡毛玻璃滤镜
import 'package:qisheng_player/utils.dart'; // 引入 utils 以使用 duration 格式化扩展
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

const int waveformBarCount = 52;
const double waveformBarWidth = 3.5;
const double waveformBarGap = 2.0;

double waveformSliderPaintWidth() {
  return waveformBarCount * waveformBarWidth +
      (waveformBarCount - 1) * waveformBarGap;
}

double resolveWaveformInteractionWidth(double availableWidth) {
  if (!availableWidth.isFinite || availableWidth <= 0) return 0;
  return math.min(availableWidth, waveformSliderPaintWidth());
}

/// 仿真果冻波形进度条组件
/// 使用 Canvas 绘制 52 根柱状声波，播放时伴随正弦波动；鼠标悬停时产生局部物理吸附隆起；
/// 拖拽时呈现高斯果冻受力扁平化和弹簧物理回弹效果；并在光标处叠置毛玻璃时间气泡提示。
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
  final double max; // 音频总时长 (秒)
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool isPlaying; // 是否播放中，用以驱动正弦律动
  final double height; // 绘制总高度

  @override
  State<WaveformSlider> createState() => _WaveformSliderState();
}

class _WaveformSliderState extends State<WaveformSlider>
    with TickerProviderStateMixin {
  // 拖动时果冻受力挤压动画控制器 (0.0 -> 1.0)
  late final AnimationController _dragController;
  // 悬停时引力形变动画控制器 (0.0 -> 1.0)
  late final AnimationController _hoverController;

  bool _isDragging = false;
  double _dragPercent = 0.0; // 当前手指拖拽所在的百分比位置 (0.0 到 1.0)

  bool _isHovering = false;
  double _hoverPercent = 0.0; // 鼠标当前悬停的百分比位置

  @override
  void initState() {
    super.initState();
    // 拖拽阻尼过渡：按下时以 curves.easeOut 变扁，松开时用物理弹簧效果进行回弹
    // 由 CustomPainter(repaint: ...) 直接驱动，彻底告别在每帧触发全局 setState
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // 悬停引力过渡：悬停淡入 150ms，移出淡出 150ms，以防柱子形变瞬间闪现
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    _hoverController.dispose(); // 销毁悬停控制器
    super.dispose();
  }

  // 鼠标移入或在其上移动时，计算悬停百分比位置并淡入形变
  void _handleHover(double localX, double totalWidth) {
    if (widget.max <= 0 || totalWidth <= 0) return;
    setState(() {
      _hoverPercent = (localX / totalWidth).clamp(0.0, 1.0);
      _isHovering = true;
    });
    _hoverController.animateTo(1.0, curve: Curves.easeOut);
  }

  // 鼠标移出进度条区域，淡出形变效果
  void _handleHoverExit() {
    setState(() {
      _isHovering = false;
    });
    _hoverController.animateTo(0.0, curve: Curves.easeIn);
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
      mass: 0.8, // 质量：控制惯性
      stiffness: 140, // 刚度：控制频率
      damping: 10, // 阻尼：控制衰减速度
    );
    final simulation =
        SpringSimulation(spring, _dragController.value, 0.0, 0.0);
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
        final totalWidth =
            resolveWaveformInteractionWidth(constraints.maxWidth);
        // 计算是否展示时间气泡提示，以及该气泡对应的时间数值
        final showTooltip = (_isHovering || _isDragging) && widget.max > 0;
        final tooltipPercent = _isDragging ? _dragPercent : _hoverPercent;
        final tooltipValue = tooltipPercent * widget.max;

        return Center(
          child: SizedBox(
            width: totalWidth,
            child: Stack(
              clipBehavior: Clip.none, // 允许气泡提示浮在波形外面而不被截断
              children: [
                GestureDetector(
                  onHorizontalDragStart: (details) =>
                      _handleDragStart(details.localPosition.dx, totalWidth),
                  onHorizontalDragUpdate: (details) =>
                      _handleDragUpdate(details.localPosition.dx, totalWidth),
                  onHorizontalDragEnd: (_) => _handleDragEnd(),
                  onHorizontalDragCancel: () => _handleDragEnd(),
                  onTapDown: (details) =>
                      _handleDragStart(details.localPosition.dx, totalWidth),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onHover: (details) =>
                        _handleHover(details.localPosition.dx, totalWidth),
                    onExit: (_) => _handleHoverExit(),
                    child: CustomPaint(
                      size: Size(totalWidth, widget.height),
                      painter: _WaveformSliderPainter(
                        percent: currentPercent,
                        isDragging: _isDragging,
                        dragPercent: _dragPercent,
                        dragAnimation: _dragController,
                        isHovering: _isHovering,
                        hoverPercent: _hoverPercent,
                        hoverAnimation: _hoverController,
                        colorScheme: Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
                // 精致毛玻璃预览时间气泡
                if (showTooltip)
                  Positioned(
                    // 气泡水平居中对齐当前光标物理位置，并且加 clamp 进行边界溢出保护，防止裁切
                    left: (tooltipPercent * totalWidth - 32.0)
                        .clamp(0.0, math.max(0.0, totalWidth - 64.0)),
                    bottom: widget.height + 6.0,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 8, sigmaY: 8), // 毛玻璃滤镜
                          child: Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer
                                  .withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 10,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Text(
                              Duration(
                                      milliseconds:
                                          (tooltipValue * 1000).round())
                                  .toStringHMMSS(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
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

/// 自定义绘制波形进度条的 Painter
class _WaveformSliderPainter extends CustomPainter {
  _WaveformSliderPainter({
    required this.percent,
    required this.isDragging,
    required this.dragPercent,
    required this.dragAnimation,
    required this.isHovering,
    required this.hoverPercent,
    required this.hoverAnimation,
    required this.colorScheme,
  }) : super(repaint: Listenable.merge([dragAnimation, hoverAnimation]));

  final double percent; // 激活的长度占比 (0.0 到 1.0)
  final bool isDragging; // 是否正在被拖拽
  final double dragPercent; // 拖拽焦点百分比 (0.0 到 1.0)
  final Animation<double> dragAnimation; // 果冻受力物理形变动画
  final bool isHovering; // 鼠标当前是否处于悬停状态
  final double hoverPercent; // 悬停焦点百分比 (0.0 到 1.0)
  final Animation<double> hoverAnimation; // 悬停引力物理动画
  final ColorScheme colorScheme;

  static const int _barCount = 52; // 精细波形柱子总数
  static const double _barWidth = 3.5; // 柱子宽度
  static const double _gap = 2.0; // 柱子间距
  static const double _minHeight = 4.0; // 柱子最低高度

  // 预计算静态高斯声波基础高度（中间高、两边低），避免每帧 52 次三角函数与浮点幂开销
  static final List<double> _baseBarHeights = List<double>.generate(_barCount, (i) {
    final double normalizedIdx = i / (_barCount - 1);
    final double centerFactor = 1.0 - (normalizedIdx - 0.5).abs() * 2.0;
    return _minHeight +
        20.0 * math.sin(normalizedIdx * math.pi) * (0.6 + 0.4 * centerFactor);
  });

  // 预计算柱子相对 X 偏移量
  static final List<double> _barXOffsets = List<double>.generate(
    _barCount,
    (i) => i * (_barWidth + _gap),
  );

  // 复用 Paint 绘制对象，杜绝每帧 GC 内存分配
  final Paint _activePaint = Paint()..style = PaintingStyle.fill;
  final Paint _inactivePaint = Paint()..style = PaintingStyle.fill;
  final Paint _focusPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  @override
  void paint(Canvas canvas, Size size) {
    final double availableWidth = size.width;
    final double centerY = size.height / 2;

    // 计算实际总绘制宽度与起点，确保波形整体居中对齐
    const double totalPaintWidth =
        _barCount * _barWidth + (_barCount - 1) * _gap;
    final double startX = (availableWidth - totalPaintWidth) / 2;

    // 已播放主色画笔 (高饱和激活主色)
    _activePaint.color = colorScheme.primary;

    // 未播放背景色画笔 (半透明高雅灰色)
    _inactivePaint.color = colorScheme.onSurface.withValues(alpha: 0.18);

    // 拖拽触点高亮标记画笔
    _focusPaint.color = colorScheme.secondary.withValues(alpha: 0.4);

    // 从动画控制器中实时获取权重，0 Widget Rebuild
    final double dragWeight = dragAnimation.value;
    final double hoverWeight = hoverAnimation.value * 0.45;

    // 确定当前的物理形变中心与形变权重 (拖动时以拖拽焦点的果冻效果为主，悬停时则展示引力微澜)
    final double activeWeight = isDragging ? dragWeight : hoverWeight;
    final double activePercent = isDragging ? dragPercent : hoverPercent;
    final double dragIndex = activePercent * _barCount;

    // 逐根绘制波形柱
    for (int i = 0; i < _barCount; i++) {
      // 1. 读取预计算高斯声波高矮轮廓
      double barHeight = _baseBarHeights[i];

      // Continuous audio movement is drawn by LiquidAudioVisualizer. This
      // control only reacts to direct hover and drag input.
      if (activeWeight > 0) {
        final double d = (i - dragIndex).abs();
        // 触点正下方高斯受力形变范围
        final double squishForce = math.exp(-d * d / 20.0);
        final double stretchForce = math.exp(-(d - 4.5) * (d - 4.5) / 10.0);

        // 应用受力物理混合
        double scale = 1.0;
        if (isDragging) {
          // 正在被拖拽：手指下方受力向下压扁，左右两侧隆起
          scale -= 0.55 * squishForce * activeWeight;
          scale += 0.32 * stretchForce * activeWeight;
        } else {
          // 仅鼠标悬停：受物理吸附吸引，光标下方柱子微微隆起，给用户极佳的探索反馈
          scale += 0.26 * squishForce * activeWeight;
        }
        barHeight *= scale;
      }

      // 确保高度越界安全
      barHeight = barHeight.clamp(_minHeight, size.height - 2.0);

      // 4. 计算当前柱子的 X 轴物理渲染坐标
      final double x = startX + _barXOffsets[i];

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
          _focusPaint,
        );
      }

      canvas.drawRRect(rect, isActive ? _activePaint : _inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformSliderPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.dragPercent != dragPercent ||
        oldDelegate.dragAnimation != dragAnimation ||
        oldDelegate.isHovering != isHovering ||
        oldDelegate.hoverPercent != hoverPercent ||
        oldDelegate.hoverAnimation != hoverAnimation ||
        oldDelegate.colorScheme != colorScheme;
  }
}
