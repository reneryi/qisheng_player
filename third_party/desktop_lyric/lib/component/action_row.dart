import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:desktop_lyric/component/desktop_lyric_config_launcher.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart' as win32;

/// 桌面歌词主播放/暂停核心控制键
///
/// 遵循 GEMINI.md 核心视觉与动效规范：
/// - 饱满圆球实体质感（38px 直径圆球）
/// - 斜向光感双层渐变（LinearGradient）
/// - 微高光半透明描边（Border.all 0.8px）
/// - 双层动态发光光晕与暗部投影（BoxShadow）
/// - 独立控制器解耦缩放（_pressController 与 _hoverController）
/// - 触控微弹簧回弹与最小按下时长保障（_releaseTimer 65ms）
/// - 图标切换平滑旋转、缩放与淡入动效（AnimatedSwitcher）
/// - 严格禁止包裹 Tooltip
class DesktopLyricPrimaryPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final Color primaryColor;
  final Color onPrimaryColor;
  final bool isDark;

  const DesktopLyricPrimaryPlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.isDark,
  });

  @override
  State<DesktopLyricPrimaryPlayButton> createState() =>
      _DesktopLyricPrimaryPlayButtonState();
}

class _DesktopLyricPrimaryPlayButtonState
    extends State<DesktopLyricPrimaryPlayButton>
    with TickerProviderStateMixin {
  AnimationController? _pressController;
  AnimationController? _hoverController;
  late Animation<double> _pressScaleAnimation;
  late Animation<double> _hoverScaleAnimation;
  Timer? _releaseTimer;
  DateTime? _tapDownTime;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
  }

  void _initAnimations() {
    if (_pressController == null) {
      _pressController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 240),
      );
      _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.91).animate(
        CurvedAnimation(
          parent: _pressController!,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
    }
    if (_hoverController == null) {
      _hoverController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 160),
        reverseDuration: const Duration(milliseconds: 160),
      );
      _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _hoverController!, curve: Curves.easeOutCubic),
      );
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _pressController?.dispose();
    _hoverController?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _initAnimations();
    _releaseTimer?.cancel();
    _tapDownTime = DateTime.now();
    _pressController?.forward();
  }

  void _handleRelease() {
    final elapsed = _tapDownTime != null
        ? DateTime.now().difference(_tapDownTime!).inMilliseconds
        : 90;
    final remaining = (65 - elapsed).clamp(0, 65);
    _releaseTimer?.cancel();
    if (remaining > 0) {
      _releaseTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) _pressController?.reverse();
      });
    } else {
      _pressController?.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
    final isPlay = !widget.isPlaying;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController?.forward(),
      onExit: (_) {
        _handleRelease();
        _hoverController?.reverse();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: (_) => _handleRelease(),
        onTapCancel: _handleRelease,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController!, _hoverController!]),
          builder: (context, child) {
            final combinedScale =
                _pressScaleAnimation.value * _hoverScaleAnimation.value;
            final hoverT = _hoverController?.value ?? 0.0;
            final dynamicGlowAlpha = lerpDouble(
              widget.isPlaying ? 0.35 : 0.22,
              0.45,
              hoverT,
            )!;
            final dynamicBlurRadius = lerpDouble(8.0, 12.0, hoverT)!;
            final dynamicSpreadRadius = widget.isPlaying ? 1.0 : 0.0;

            return Transform.scale(
              scale: combinedScale,
              child: Container(
                width: 38.0,
                height: 38.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        widget.primaryColor,
                        Colors.white,
                        widget.isDark ? 0.24 : 0.18,
                      )!,
                      widget.primaryColor,
                      Color.lerp(
                        widget.primaryColor,
                        Colors.black,
                        0.12,
                      )!,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor
                          .withValues(alpha: dynamicGlowAlpha),
                      blurRadius: dynamicBlurRadius,
                      spreadRadius: dynamicSpreadRadius,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: widget.isDark ? 0.24 : 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 80),
                    reverseDuration: const Duration(milliseconds: 80),
                    switchInCurve: Curves.linear,
                    switchOutCurve: Curves.linear,
                    transitionBuilder: (child, animation) {
                      final isPlayTarget =
                          (child.key as ValueKey?)?.value == true;
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
                        ),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.68, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: RotationTransition(
                            turns: Tween<double>(
                              begin: isPlayTarget ? -0.08 : 0.08,
                              end: 0.0,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Transform.translate(
                      key: ValueKey<bool>(isPlay),
                      offset: Offset(isPlay ? 1.0 : 0.0, 0.0),
                      child: Icon(
                        widget.isPlaying
                            ? Symbols.pause_rounded
                            : Symbols.play_arrow_rounded,
                        color: widget.onPrimaryColor,
                        size: 22.0,
                        fill: 1.0,
                        weight: 700,
                        grade: 0.25,
                        opticalSize: 24,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 播放切歌方向微冲量枚举
enum TransportDirection { left, right }

/// 桌面歌词切歌控键（上一首 / 下一首）
///
/// 遵循 GEMINI.md 微动量规范：
/// - 上一首点击向左微冲量（-2.5px），下一首向右微冲量（+2.5px）
/// - 释放带 Curves.easeOutBack 微弹簧回弹
/// - 饱满圆润底纹与高光描边（32px 直径圆球）
/// - 独立 hover/press 控制器平滑插值与 _releaseTimer 保护
/// - 严格禁止包裹 Tooltip
class DesktopLyricTransportButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final bool isDark;
  final TransportDirection direction;

  const DesktopLyricTransportButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.iconColor,
    required this.isDark,
    required this.direction,
  });

  @override
  State<DesktopLyricTransportButton> createState() =>
      _DesktopLyricTransportButtonState();
}

class _DesktopLyricTransportButtonState
    extends State<DesktopLyricTransportButton>
    with TickerProviderStateMixin {
  AnimationController? _pressController;
  AnimationController? _hoverController;
  late Animation<double> _pressScaleAnimation;
  late Animation<double> _hoverScaleAnimation;
  late Animation<double> _directionalOffsetAnimation;
  Timer? _releaseTimer;
  DateTime? _tapDownTime;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
  }

  void _initAnimations() {
    if (_pressController == null) {
      _pressController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 240),
      );
      _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(
          parent: _pressController!,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
      final targetOffset =
          widget.direction == TransportDirection.left ? -2.5 : 2.5;
      _directionalOffsetAnimation =
          Tween<double>(begin: 0.0, end: targetOffset).animate(
        CurvedAnimation(
          parent: _pressController!,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
    }
    if (_hoverController == null) {
      _hoverController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 160),
        reverseDuration: const Duration(milliseconds: 160),
      );
      _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _hoverController!, curve: Curves.easeOutCubic),
      );
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _pressController?.dispose();
    _hoverController?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _initAnimations();
    _releaseTimer?.cancel();
    _tapDownTime = DateTime.now();
    _pressController?.forward();
  }

  void _handleRelease() {
    final elapsed = _tapDownTime != null
        ? DateTime.now().difference(_tapDownTime!).inMilliseconds
        : 90;
    final remaining = (65 - elapsed).clamp(0, 65);
    _releaseTimer?.cancel();
    if (remaining > 0) {
      _releaseTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) _pressController?.reverse();
      });
    } else {
      _pressController?.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController?.forward(),
      onExit: (_) {
        _handleRelease();
        _hoverController?.reverse();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: (_) => _handleRelease(),
        onTapCancel: _handleRelease,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController!, _hoverController!]),
          builder: (context, child) {
            final combinedScale =
                _pressScaleAnimation.value * _hoverScaleAnimation.value;
            final xOffset = _directionalOffsetAnimation.value;
            final hoverT = _hoverController?.value ?? 0.0;

            final unhoveredBg = widget.isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.04);
            final hoveredBg = widget.isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.10);
            final baseBg = Color.lerp(unhoveredBg, hoveredBg, hoverT)!;

            final unhoveredBorder = widget.isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08);
            final hoveredBorder = widget.isDark
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.16);
            final borderColor =
                Color.lerp(unhoveredBorder, hoveredBorder, hoverT)!;

            return Transform.translate(
              offset: Offset(xOffset, 0),
              child: Transform.scale(
                scale: combinedScale,
                child: Container(
                  width: 32.0,
                  height: 32.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseBg,
                    border: Border.all(color: borderColor, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: widget.isDark ? 0.18 : 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 19.0,
                      fill: 1.0,
                      weight: 600,
                      grade: 0.25,
                      opticalSize: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 桌面歌词次级操作圆润按钮（A+、A-、字体A选择、调色盘、关闭、锁定）
///
/// 遵循 GEMINI.md 图标与圆润造型规范：
/// - 饱满圆润底纹（圆形或圆角胶囊方框）
/// - 高光内描边与微环境阴影
/// - 平滑悬停呼吸缩放与触控回弹（带 _releaseTimer 保护与 Curves.easeOutBack 弹簧反馈）
/// - 实心高质感 Material Symbols Rounded
class DesktopLyricActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final bool isDark;
  final String? tooltip;
  final BorderRadius? borderRadius;
  final bool isDestructive;

  const DesktopLyricActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.iconColor,
    required this.isDark,
    this.tooltip,
    this.borderRadius,
    this.isDestructive = false,
  });

  @override
  State<DesktopLyricActionButton> createState() =>
      _DesktopLyricActionButtonState();
}

class _DesktopLyricActionButtonState extends State<DesktopLyricActionButton>
    with TickerProviderStateMixin {
  AnimationController? _pressController;
  AnimationController? _hoverController;
  late Animation<double> _pressScaleAnimation;
  late Animation<double> _hoverScaleAnimation;
  Timer? _releaseTimer;
  DateTime? _tapDownTime;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
  }

  void _initAnimations() {
    if (_pressController == null) {
      _pressController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 240),
      );
      _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(
          parent: _pressController!,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
    }
    if (_hoverController == null) {
      _hoverController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 160),
        reverseDuration: const Duration(milliseconds: 160),
      );
      _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _hoverController!, curve: Curves.easeOutCubic),
      );
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _pressController?.dispose();
    _hoverController?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _initAnimations();
    _releaseTimer?.cancel();
    _tapDownTime = DateTime.now();
    _pressController?.forward();
  }

  void _handleRelease() {
    final elapsed = _tapDownTime != null
        ? DateTime.now().difference(_tapDownTime!).inMilliseconds
        : 90;
    final remaining = (65 - elapsed).clamp(0, 65);
    _releaseTimer?.cancel();
    if (remaining > 0) {
      _releaseTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) _pressController?.reverse();
      });
    } else {
      _pressController?.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
    final radius = widget.borderRadius ?? BorderRadius.circular(16.0);

    Widget content = AnimatedBuilder(
      animation: Listenable.merge([_pressController!, _hoverController!]),
      builder: (context, child) {
        final combinedScale =
            _pressScaleAnimation.value * _hoverScaleAnimation.value;
        final hoverT = _hoverController?.value ?? 0.0;

        Color baseBg;
        Color borderColor;
        Color effectiveIconColor = widget.iconColor;

        if (widget.isDestructive) {
          final unhoveredBg = widget.isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.04);
          final hoveredBg = widget.isDark
              ? Colors.redAccent.withValues(alpha: 0.22)
              : Colors.redAccent.withValues(alpha: 0.14);
          baseBg = Color.lerp(unhoveredBg, hoveredBg, hoverT)!;

          final unhoveredBorder = widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08);
          final hoveredBorder = Colors.redAccent.withValues(alpha: 0.35);
          borderColor = Color.lerp(unhoveredBorder, hoveredBorder, hoverT)!;

          final hoveredIconColor = widget.isDark
              ? const Color(0xFFFF8A80)
              : const Color(0xFFD32F2F);
          effectiveIconColor =
              Color.lerp(widget.iconColor, hoveredIconColor, hoverT)!;
        } else {
          final unhoveredBg = widget.isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.04);
          final hoveredBg = widget.isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.10);
          baseBg = Color.lerp(unhoveredBg, hoveredBg, hoverT)!;

          final unhoveredBorder = widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08);
          final hoveredBorder = widget.isDark
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.black.withValues(alpha: 0.16);
          borderColor = Color.lerp(unhoveredBorder, hoveredBorder, hoverT)!;
        }

        return Transform.scale(
          scale: combinedScale,
          child: Container(
            width: 32.0,
            height: 32.0,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: baseBg,
              border: Border.all(color: borderColor, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: widget.isDark ? 0.18 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: effectiveIconColor,
                size: 18.0,
                fill: 1.0,
                weight: 600,
                grade: 0.25,
                opticalSize: 24,
              ),
            ),
          ),
        );
      },
    );

    Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController?.forward(),
      onExit: (_) {
        _handleRelease();
        _hoverController?.reverse();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: (_) => _handleRelease(),
        onTapCancel: _handleRelease,
        onTap: widget.onPressed,
        child: content,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: button,
      );
    }

    return button;
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeChangedMessage>();
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        DesktopLyricController.instance.isDarkMode.value;
    final onSurfaceColor = Color(theme.onSurface);
    final iconColor = isDark
        ? (onSurfaceColor.computeLuminance() > 0.4
            ? onSurfaceColor
            : Colors.white)
        : (onSurfaceColor.computeLuminance() < 0.6
            ? onSurfaceColor
            : const Color(0xFF0F172A));

    final primaryColor = Color(theme.primary);
    final onPrimaryColor = primaryColor.computeLuminance() > 0.5
        ? const Color(0xFF0F172A)
        : Colors.white;

    final textDisplayController = context.read<TextDisplayController>();

    return ValueListenableBuilder<String?>(
      valueListenable: DesktopLyricController.instance.currentFontFamily,
      builder: (context, currentFontFromPlayer, _) {
        textDisplayController.initializeFontFamilyFromPlayer(
          currentFontFromPlayer,
        );
        return SizedBox(
          height: 44.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 锁定按钮置于右侧（带平滑圆润底纹与鼠标穿透逻辑）
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: DesktopLyricActionButton(
                    icon: Symbols.lock_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    tooltip: "锁定歌词",
                    onPressed: () async {
                      await DesktopLyricConfigLauncher.closeActiveConfig();
                      hWnd = win32.GetForegroundWindow();

                      if (hWnd != null) {
                        final exStyle = win32.GetWindowLongPtr(
                          hWnd!,
                          win32.GWL_EXSTYLE,
                        );

                        win32.SetWindowLongPtr(
                          hWnd!,
                          win32.GWL_EXSTYLE,
                          exStyle |
                              win32.WS_EX_LAYERED |
                              win32.WS_EX_TRANSPARENT,
                        );

                        stdout.write(
                          "${const ControlEventMessage(ControlEvent.lock).buildMessageJson()}\n",
                        );
                      }
                    },
                  ),
                ),
              ),
              // 居中核心操作栏：字体控制簇、播放控制簇、辅助操作簇
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. 字体控制簇 (A+, A-, 字体A图标)
                  DesktopLyricActionButton(
                    icon: Symbols.text_increase_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    tooltip: "增大字号",
                    onPressed: textDisplayController.increaseLyricFontSize,
                  ),
                  const SizedBox(width: 6.0),
                  DesktopLyricActionButton(
                    icon: Symbols.text_decrease_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    tooltip: "缩小字号",
                    onPressed: textDisplayController.decreaseLyricFontSize,
                  ),
                  const SizedBox(width: 6.0),
                  DesktopLyricActionButton(
                    icon: Symbols.font_download_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    borderRadius: BorderRadius.circular(10.0),
                    tooltip: "歌词字体",
                    onPressed: () => DesktopLyricConfigLauncher.open(
                      context,
                      LyricConfigType.font,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  // 2. 播放控制簇 (上一首、主播放控键、下一首)
                  DesktopLyricTransportButton(
                    icon: Symbols.skip_previous_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    direction: TransportDirection.left,
                    onPressed: () {
                      stdout.write(
                        "${const ControlEventMessage(ControlEvent.previousAudio).buildMessageJson()}\n",
                      );
                    },
                  ),
                  const SizedBox(width: 10.0),
                  ValueListenableBuilder<bool>(
                    valueListenable: DesktopLyricController.instance.isPlaying,
                    builder: (context, isPlaying, _) =>
                        DesktopLyricPrimaryPlayButton(
                      isPlaying: isPlaying,
                      primaryColor: primaryColor,
                      onPrimaryColor: onPrimaryColor,
                      isDark: isDark,
                      onPressed: () {
                        stdout.write(
                          "${ControlEventMessage(isPlaying ? ControlEvent.pause : ControlEvent.start).buildMessageJson()}\n",
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  DesktopLyricTransportButton(
                    icon: Symbols.skip_next_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    direction: TransportDirection.right,
                    onPressed: () {
                      stdout.write(
                        "${const ControlEventMessage(ControlEvent.nextAudio).buildMessageJson()}\n",
                      );
                    },
                  ),
                  const SizedBox(width: 14.0),
                  // 3. 辅助控制簇 (调色盘、关闭)
                  DesktopLyricActionButton(
                    icon: Symbols.palette_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    tooltip: "歌词颜色",
                    onPressed: () => DesktopLyricConfigLauncher.open(
                      context,
                      LyricConfigType.color,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  DesktopLyricActionButton(
                    icon: Symbols.close_rounded,
                    iconColor: iconColor,
                    isDark: isDark,
                    isDestructive: true,
                    tooltip: "关闭歌词",
                    onPressed: () async {
                      await DesktopLyricConfigLauncher.closeActiveConfig();
                      try {
                        stdout.write(
                          "${const ControlEventMessage(ControlEvent.close).buildMessageJson()}\n",
                        );
                        await stdout.flush();
                      } catch (_) {}
                      exit(0);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
