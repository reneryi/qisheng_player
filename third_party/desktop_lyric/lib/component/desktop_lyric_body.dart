import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class DesktopLyricBody extends StatefulWidget {
  const DesktopLyricBody({super.key});

  @override
  State<DesktopLyricBody> createState() => DesktopLyricBodyState();
}

class DesktopLyricBodyState extends State<DesktopLyricBody> {
  bool isHovering = false;
  bool _lastDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _lastDialogOpen = isDialogOpen.value;
    isDialogOpen.addListener(_onDialogOpenChanged);
  }

  @override
  void dispose() {
    isDialogOpen.removeListener(_onDialogOpenChanged);
    super.dispose();
  }

  void _onDialogOpenChanged() {
    if (!mounted) return;
    final nowOpen = isDialogOpen.value;
    if (nowOpen) {
      if (isHovering) {
        setState(() {
          isHovering = false;
        });
      }
    } else if (_lastDialogOpen && !nowOpen) {
      // 弹窗退出时仅在必要时兜底恢复（尺寸下限 142px + 屏幕工作区坐标安全钳制）
      restoreLyricWindowSizeAndPositionIfNeeded();
    }
    _lastDialogOpen = nowOpen;
  }

  @visibleForTesting
  void setHoveringForTest(bool hovering) {
    setState(() {
      isHovering = hovering;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeChangedMessage>();
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        DesktopLyricController.instance.isDarkMode.value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<bool>(
        valueListenable: isDialogOpen,
        builder: (context, dialogOpen, child) {
          final effectiveHover = isHovering && !dialogOpen;
          return MouseRegion(
            onEnter: (_) {
              if (dialogOpen) return;
              setState(() {
                isHovering = true;
              });
            },
            onExit: (_) {
              setState(() {
                isHovering = false;
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                if (dialogOpen) return;
                windowManager.startDragging();
              },
              child: AnimatedContainer(
                duration: dialogOpen
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: effectiveHover
                      ? (isDark
                          ? Color.alphaBlend(
                              Color(theme.primary).withValues(alpha: 0.10),
                              const Color(0xFF141923)
                                  .withValues(alpha: 0.78),
                            )
                          : Color.alphaBlend(
                              Color(theme.primary).withValues(alpha: 0.05),
                              Colors.white.withValues(alpha: 0.82),
                            ))
                      : Colors.transparent,
                  gradient: effectiveHover
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white
                                .withValues(alpha: isDark ? 0.08 : 0.70),
                            Colors.transparent,
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(
                    color: effectiveHover
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.08))
                        : Colors.transparent,
                    width: 1.0,
                  ),
                  boxShadow: effectiveHover
                      ? [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.32 : 0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: Color(theme.primary)
                                .withValues(alpha: isDark ? 0.20 : 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 2),
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.0),
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: dialogOpen ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: DesktopLyricForeground(isHovering: effectiveHover),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
