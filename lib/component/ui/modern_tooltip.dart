import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

/// 气泡指示箭头朝向
enum BubbleArrowDirection {
  none,
  down,
  up,
  left,
  right,
}

/// 气泡边框形状（绘制带指示小尖角三角形与圆角的现代气泡）
class BubbleShapeBorder extends ShapeBorder {
  const BubbleShapeBorder({
    this.arrowDirection = BubbleArrowDirection.down,
    this.arrowWidth = 12.0,
    this.arrowHeight = 6.0,
    this.borderRadius = 6.0,
    this.arrowOffset = 0.0,
    this.borderColor,
    this.borderWidth = 0.0,
  });

  final BubbleArrowDirection arrowDirection;
  final double arrowWidth;
  final double arrowHeight;
  final double borderRadius;
  final double arrowOffset;
  final Color? borderColor;
  final double borderWidth;

  @override
  EdgeInsetsGeometry get dimensions {
    return switch (arrowDirection) {
      BubbleArrowDirection.down => EdgeInsets.only(bottom: arrowHeight),
      BubbleArrowDirection.up => EdgeInsets.only(top: arrowHeight),
      BubbleArrowDirection.left => EdgeInsets.only(left: arrowHeight),
      BubbleArrowDirection.right => EdgeInsets.only(right: arrowHeight),
      BubbleArrowDirection.none => EdgeInsets.zero,
    };
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(borderWidth), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty || rect.width <= 0 || rect.height <= 0) {
      return Path();
    }
    Rect bodyRect;
    final Path arrowPath = Path();

    switch (arrowDirection) {
      case BubbleArrowDirection.down:
        bodyRect = Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width,
          (rect.height - arrowHeight).clamp(0.0, double.infinity),
        );
        final maxH = bodyRect.width - borderRadius * 2;
        final halfArrow = (maxH > arrowWidth ? arrowWidth : maxH.clamp(0.0, arrowWidth)) / 2;
        final cx = (bodyRect.left + bodyRect.width / 2 + arrowOffset).clamp(
          bodyRect.left + borderRadius + halfArrow,
          (bodyRect.right - borderRadius - halfArrow).clamp(bodyRect.left + borderRadius + halfArrow, double.infinity),
        );
        arrowPath
          ..moveTo(cx - halfArrow, bodyRect.bottom)
          ..lineTo(cx, rect.bottom)
          ..lineTo(cx + halfArrow, bodyRect.bottom)
          ..close();
        break;

      case BubbleArrowDirection.up:
        bodyRect = Rect.fromLTWH(
          rect.left,
          rect.top + arrowHeight,
          rect.width,
          (rect.height - arrowHeight).clamp(0.0, double.infinity),
        );
        final maxH = bodyRect.width - borderRadius * 2;
        final halfArrow = (maxH > arrowWidth ? arrowWidth : maxH.clamp(0.0, arrowWidth)) / 2;
        final cx = (bodyRect.left + bodyRect.width / 2 + arrowOffset).clamp(
          bodyRect.left + borderRadius + halfArrow,
          (bodyRect.right - borderRadius - halfArrow).clamp(bodyRect.left + borderRadius + halfArrow, double.infinity),
        );
        arrowPath
          ..moveTo(cx - halfArrow, bodyRect.top)
          ..lineTo(cx, rect.top)
          ..lineTo(cx + halfArrow, bodyRect.top)
          ..close();
        break;

      case BubbleArrowDirection.right:
        bodyRect = Rect.fromLTWH(
          rect.left,
          rect.top,
          (rect.width - arrowHeight).clamp(0.0, double.infinity),
          rect.height,
        );
        final maxV = bodyRect.height - borderRadius * 2;
        final halfArrow = (maxV > arrowWidth ? arrowWidth : maxV.clamp(0.0, arrowWidth)) / 2;
        final cy = (bodyRect.top + bodyRect.height / 2 + arrowOffset).clamp(
          bodyRect.top + borderRadius + halfArrow,
          (bodyRect.bottom - borderRadius - halfArrow).clamp(bodyRect.top + borderRadius + halfArrow, double.infinity),
        );
        arrowPath
          ..moveTo(bodyRect.right, cy - halfArrow)
          ..lineTo(rect.right, cy)
          ..lineTo(bodyRect.right, cy + halfArrow)
          ..close();
        break;

      case BubbleArrowDirection.left:
        bodyRect = Rect.fromLTWH(
          rect.left + arrowHeight,
          rect.top,
          (rect.width - arrowHeight).clamp(0.0, double.infinity),
          rect.height,
        );
        final maxV = bodyRect.height - borderRadius * 2;
        final halfArrow = (maxV > arrowWidth ? arrowWidth : maxV.clamp(0.0, arrowWidth)) / 2;
        final cy = (bodyRect.top + bodyRect.height / 2 + arrowOffset).clamp(
          bodyRect.top + borderRadius + halfArrow,
          (bodyRect.bottom - borderRadius - halfArrow).clamp(bodyRect.top + borderRadius + halfArrow, double.infinity),
        );
        arrowPath
          ..moveTo(bodyRect.left, cy - halfArrow)
          ..lineTo(rect.left, cy)
          ..lineTo(bodyRect.left, cy + halfArrow)
          ..close();
        break;

      case BubbleArrowDirection.none:
        bodyRect = rect;
        break;
    }

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(borderRadius)));

    if (arrowDirection != BubbleArrowDirection.none) {
      path.addPath(arrowPath, Offset.zero);
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (borderColor != null && borderWidth > 0) {
      final paint = Paint()
        ..color = borderColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// 提示气泡弹出方位
enum ModernTooltipDirection {
  auto,
  left,
  right,
  top,
  bottom,
}

/// 提示气泡可操控项接口
abstract interface class ModernTooltipEntry {
  void dismissImmediate();
}

/// 全局 ModernTooltip 管理器，协调跨组件的悬停接力交互：
/// - 当用户在工具条或相邻按钮间依次悬停浏览时，前一个提示气泡立即退场，新提示无缝即时展现；
/// - 杜绝多个气泡同时滞留、叠层阻挡和长延时顿挫；
/// - 具备热身（Warm）态感知，移出控件组 280ms 后自动冷却重置为初始延迟。
class ModernTooltipManager {
  ModernTooltipManager._();
  static final ModernTooltipManager instance = ModernTooltipManager._();

  ModernTooltipEntry? _activeEntry;
  Timer? _warmResetTimer;
  bool _isWarm = false;

  bool get isWarm => _isWarm;

  void onTooltipEnter(ModernTooltipEntry entry) {
    if (_activeEntry != null && _activeEntry != entry) {
      _activeEntry?.dismissImmediate();
    }
    _warmResetTimer?.cancel();
  }

  void onTooltipShown(ModernTooltipEntry entry) {
    _activeEntry = entry;
    _isWarm = true;
    _warmResetTimer?.cancel();
  }

  void onTooltipExit(ModernTooltipEntry entry) {
    _warmResetTimer?.cancel();
    _warmResetTimer = Timer(const Duration(milliseconds: 280), () {
      _isWarm = false;
    });
  }

  void onTooltipDismissed(ModernTooltipEntry entry) {
    if (_activeEntry == entry) {
      _activeEntry = null;
    }
  }

  void dismissAll() {
    _activeEntry?.dismissImmediate();
    _activeEntry = null;
    _isWarm = false;
    _warmResetTimer?.cancel();
  }
}

/// 栖声播放器现代风格气泡提示组件。
///
/// 沿用音量数值指示气泡的设计规范：
/// - 纯正强调色气泡与高对比度文字
/// 气泡位置与箭头偏移计算结果
class TooltipLayoutResult {
  const TooltipLayoutResult({
    required this.offset,
    required this.arrowOffset,
  });

  final Offset offset;
  final double arrowOffset;
}

/// - 带有指示箭头的圆角卡片
/// - 弹出时微弹簧缩放+渐显动画（0.82 -> 1.0）
/// - 穿透指针交互（IgnorePointer），杜绝遮挡临近交互按钮
/// - 支持自动与侧向弹出（解决纵向按钮悬停遮挡下一个按钮的交互缺陷）
/// - 接入 ModernTooltipManager 实现依次悬停浏览时的极速接力与即刻退场
class ModernTooltip extends StatefulWidget {
  const ModernTooltip({
    super.key,
    required this.message,
    required this.child,
    this.direction = ModernTooltipDirection.auto,
    this.waitDuration = const Duration(milliseconds: 220),
    this.exitDuration = const Duration(milliseconds: 100),
    this.enabled = true,
    this.fontSize = 13.5,
  });

  final String message;
  final Widget child;
  final ModernTooltipDirection direction;
  final Duration waitDuration;
  final Duration exitDuration;
  final bool enabled;
  final double fontSize;

  /// 计算气泡在 Overlay 中的放置坐标及动态箭头偏移量，确保尖角精准对齐目标中心
  static TooltipLayoutResult computePositionAndArrowOffset({
    required Offset targetCenter,
    required Size targetSize,
    required Size childSize,
    required Size overlaySize,
    required ModernTooltipDirection direction,
    double margin = 8.0,
    double gap = 6.0,
  }) {
    final targetLeft = targetCenter.dx - targetSize.width / 2;
    final targetRight = targetCenter.dx + targetSize.width / 2;
    final targetTop = targetCenter.dy - targetSize.height / 2;
    final targetBottom = targetCenter.dy + targetSize.height / 2;

    double x;
    double y;
    double arrowOffset = 0.0;

    switch (direction) {
      case ModernTooltipDirection.bottom:
        final maxRight = (overlaySize.width - childSize.width - margin)
            .clamp(margin, double.infinity);
        x = (targetCenter.dx - childSize.width / 2).clamp(margin, maxRight);
        y = targetBottom + gap;
        final bubbleCenterX = x + childSize.width / 2;
        arrowOffset = targetCenter.dx - bubbleCenterX;
        break;

      case ModernTooltipDirection.top || ModernTooltipDirection.auto:
        final maxRight = (overlaySize.width - childSize.width - margin)
            .clamp(margin, double.infinity);
        x = (targetCenter.dx - childSize.width / 2).clamp(margin, maxRight);
        y = targetTop - childSize.height - gap;
        final bubbleCenterX = x + childSize.width / 2;
        arrowOffset = targetCenter.dx - bubbleCenterX;
        break;

      case ModernTooltipDirection.left:
        x = targetLeft - childSize.width - gap;
        final maxBottom = (overlaySize.height - childSize.height - margin)
            .clamp(margin, double.infinity);
        y = (targetCenter.dy - childSize.height / 2).clamp(margin, maxBottom);
        final bubbleCenterY = y + childSize.height / 2;
        arrowOffset = targetCenter.dy - bubbleCenterY;
        break;

      case ModernTooltipDirection.right:
        x = targetRight + gap;
        final maxBottom = (overlaySize.height - childSize.height - margin)
            .clamp(margin, double.infinity);
        y = (targetCenter.dy - childSize.height / 2).clamp(margin, maxBottom);
        final bubbleCenterY = y + childSize.height / 2;
        arrowOffset = targetCenter.dy - bubbleCenterY;
        break;
    }

    return TooltipLayoutResult(
      offset: Offset(x, y),
      arrowOffset: arrowOffset,
    );
  }

  @override
  State<ModernTooltip> createState() => _ModernTooltipState();
}

class _ModernTooltipState extends State<ModernTooltip>
    with SingleTickerProviderStateMixin
    implements ModernTooltipEntry {
  final OverlayPortalController _overlayController = OverlayPortalController();
  late final AnimationController _animController;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: widget.exitDuration,
    );
  }

  @override
  void didUpdateWidget(covariant ModernTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.message.isEmpty) {
      if (_overlayController.isShowing) {
        dismissImmediate();
      }
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    ModernTooltipManager.instance.onTooltipDismissed(this);
    _animController.dispose();
    super.dispose();
  }

  void _onEnter() {
    if (!widget.enabled || widget.message.isEmpty) return;
    _hideTimer?.cancel();
    _showTimer?.cancel();

    ModernTooltipManager.instance.onTooltipEnter(this);

    if (ModernTooltipManager.instance.isWarm) {
      _show();
    } else {
      _showTimer = Timer(widget.waitDuration, _show);
    }
  }

  void _onExit() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    ModernTooltipManager.instance.onTooltipExit(this);
    _hideTimer = Timer(widget.exitDuration, _hide);
  }

  @override
  void dismissImmediate() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_overlayController.isShowing) {
      _animController.stop();
      _animController.value = 0.0;
      _overlayController.hide();
    }
    ModernTooltipManager.instance.onTooltipDismissed(this);
  }

  void _show() {
    if (!mounted || !widget.enabled || widget.message.isEmpty) return;
    if (!_overlayController.isShowing) {
      _overlayController.show();
      _animController.forward(from: 0.0);
    } else {
      _animController.forward();
    }
    ModernTooltipManager.instance.onTooltipShown(this);
  }

  void _hide() {
    if (!mounted) return;
    _animController.reverse().then((_) {
      if (mounted &&
          (_animController.status == AnimationStatus.dismissed ||
              _animController.value == 0) &&
          _overlayController.isShowing) {
        _overlayController.hide();
        ModernTooltipManager.instance.onTooltipDismissed(this);
      }
    }).catchError((_) {
      // 忽略因快速手势重入或提前终止导致的 TickerCanceled
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.message.isEmpty) {
      return widget.child;
    }

    final accentColor = Theme.of(context).extension<AppAccentTokens>()?.accent ??
        Theme.of(context).colorScheme.primary;
    final isLight = accentColor.computeLuminance() > 0.45;
    final textColor = isLight ? const Color(0xFF1C1B1F) : Colors.white;

    return RawTooltip(
      semanticsTooltip: widget.message,
      triggerMode: TooltipTriggerMode.manual,
      tooltipBuilder: (context, animation) => const SizedBox.shrink(),
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _overlayController,
        overlayChildBuilder: (context, layoutInfo) {
          if (layoutInfo.childPaintTransform.determinant() == 0.0) {
            return const SizedBox.shrink();
          }

          final targetCenter = MatrixUtils.transformPoint(
            layoutInfo.childPaintTransform,
            layoutInfo.childSize.center(Offset.zero),
          );
          final targetSize = layoutInfo.childSize;
          final screenSize = MediaQuery.sizeOf(context);

          final resolvedDirection = switch (widget.direction) {
            ModernTooltipDirection.auto => () {
                // 顶栏或靠近窗口顶部（spaceAbove 不足）：向下弹出，防止被窗口外边缘截断
                if (targetCenter.dy - targetSize.height / 2 < 100) {
                  return ModernTooltipDirection.bottom;
                }
                // 底栏或靠近窗口底部（spaceBelow 不足）：向上弹出
                if (targetCenter.dy + targetSize.height / 2 >
                    screenSize.height - 100) {
                  return ModernTooltipDirection.top;
                }
                // 右边缘区域：向左弹出
                if (targetCenter.dx + targetSize.width / 2 >
                    screenSize.width - 120) {
                  return ModernTooltipDirection.left;
                }
                return ModernTooltipDirection.top;
              }(),
            _ => widget.direction,
          };

          final arrowDirection = switch (resolvedDirection) {
            ModernTooltipDirection.bottom => BubbleArrowDirection.up,
            ModernTooltipDirection.top ||
            ModernTooltipDirection.auto =>
              BubbleArrowDirection.down,
            ModernTooltipDirection.left => BubbleArrowDirection.right,
            ModernTooltipDirection.right => BubbleArrowDirection.left,
          };

          final contentPadding = switch (arrowDirection) {
            BubbleArrowDirection.down =>
              const EdgeInsets.only(left: 11, right: 11, top: 5.5, bottom: 10.5),
            BubbleArrowDirection.up =>
              const EdgeInsets.only(left: 11, right: 11, top: 10.5, bottom: 5.5),
            BubbleArrowDirection.left =>
              const EdgeInsets.only(left: 12, right: 10, top: 6, bottom: 6),
            BubbleArrowDirection.right =>
              const EdgeInsets.only(left: 10, right: 12, top: 6, bottom: 6),
            BubbleArrowDirection.none =>
              const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          };

          const arrowHeight = 6.0;
          final shapeDimensions = switch (arrowDirection) {
            BubbleArrowDirection.down =>
              const EdgeInsets.only(bottom: arrowHeight),
            BubbleArrowDirection.up =>
              const EdgeInsets.only(top: arrowHeight),
            BubbleArrowDirection.left =>
              const EdgeInsets.only(left: arrowHeight),
            BubbleArrowDirection.right =>
              const EdgeInsets.only(right: arrowHeight),
            BubbleArrowDirection.none => EdgeInsets.zero,
          };
          final totalPadding = contentPadding.add(shapeDimensions);

          final textScaler =
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
          final textPainter = TextPainter(
            text: TextSpan(
              text: widget.message,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                decoration: TextDecoration.none,
              ),
            ),
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            textScaler: textScaler,
            maxLines: 1,
          )..layout();

          final estimatedChildSize = Size(
            (textPainter.width + totalPadding.horizontal).ceilToDouble(),
            (textPainter.height + totalPadding.vertical).ceilToDouble(),
          );

          final layoutResult = ModernTooltip.computePositionAndArrowOffset(
            targetCenter: targetCenter,
            targetSize: targetSize,
            childSize: estimatedChildSize,
            overlaySize: screenSize,
            direction: resolvedDirection,
          );

          final transformAlignment = switch (resolvedDirection) {
            ModernTooltipDirection.bottom => Alignment(
                estimatedChildSize.width > 0
                    ? (layoutResult.arrowOffset / (estimatedChildSize.width / 2))
                        .clamp(-1.0, 1.0)
                    : 0.0,
                -1.0,
              ),
            ModernTooltipDirection.top ||
            ModernTooltipDirection.auto =>
              Alignment(
                estimatedChildSize.width > 0
                    ? (layoutResult.arrowOffset / (estimatedChildSize.width / 2))
                        .clamp(-1.0, 1.0)
                    : 0.0,
                1.0,
              ),
            ModernTooltipDirection.left => Alignment(
                1.0,
                estimatedChildSize.height > 0
                    ? (layoutResult.arrowOffset / (estimatedChildSize.height / 2))
                        .clamp(-1.0, 1.0)
                    : 0.0,
              ),
            ModernTooltipDirection.right => Alignment(
                -1.0,
                estimatedChildSize.height > 0
                    ? (layoutResult.arrowOffset / (estimatedChildSize.height / 2))
                        .clamp(-1.0, 1.0)
                    : 0.0,
              ),
          };

          return Positioned.fill(
            child: IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _ModernTooltipPositionDelegate(
                  targetCenter: targetCenter,
                  targetSize: targetSize,
                  direction: resolvedDirection,
                ),
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final curved =
                        Curves.easeOutCubic.transform(_animController.value);
                    final scale = 0.82 + 0.18 * curved;
                    final opacity = _animController.value.clamp(0.0, 1.0);

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        alignment: transformAlignment,
                        child: Container(
                          decoration: ShapeDecoration(
                            color: accentColor,
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            shape: BubbleShapeBorder(
                              arrowDirection: arrowDirection,
                              borderRadius: 6.0,
                              arrowWidth: 11.0,
                              arrowHeight: 6.0,
                              arrowOffset: layoutResult.arrowOffset,
                            ),
                          ),
                          padding: contentPadding,
                          child: Text(
                            widget.message,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: textColor,
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
        child: MouseRegion(
          onEnter: (_) => _onEnter(),
          onExit: (_) => _onExit(),
          child: Listener(
            onPointerDown: (_) => dismissImmediate(),
            behavior: HitTestBehavior.translucent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ModernTooltipPositionDelegate extends SingleChildLayoutDelegate {
  _ModernTooltipPositionDelegate({
    required this.targetCenter,
    required this.targetSize,
    required this.direction,
  });

  final Offset targetCenter;
  final Size targetSize;
  final ModernTooltipDirection direction;

  static const double gap = 6.0;
  static const double margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return ModernTooltip.computePositionAndArrowOffset(
      targetCenter: targetCenter,
      targetSize: targetSize,
      childSize: childSize,
      overlaySize: size,
      direction: direction,
      margin: margin,
      gap: gap,
    ).offset;
  }

  @override
  bool shouldRelayout(covariant _ModernTooltipPositionDelegate oldDelegate) {
    return oldDelegate.targetCenter != targetCenter ||
        oldDelegate.targetSize != targetSize ||
        oldDelegate.direction != direction;
  }
}

