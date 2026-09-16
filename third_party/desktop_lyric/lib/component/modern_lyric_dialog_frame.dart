import 'dart:math' as math;
import 'dart:ui';

import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// 桌面歌词专属现代毛玻璃卡片容器基座（深度对齐主播放器 ModernDialogFrame 设计规范）
class ModernLyricDialogFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsetsGeometry padding;

  const ModernLyricDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 840.0,
    this.maxHeight = 700.0,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        DesktopLyricController.instance.isDarkMode.value;
    final theme = context.watch<ThemeChangedMessage>();
    final primary = Color(theme.primary);

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: primary.withValues(alpha: isDark ? 0.16 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24.0),
                      color: isDark
                          ? Color.alphaBlend(
                              primary.withValues(alpha: 0.08),
                              const Color(0xFF131822).withValues(alpha: 0.82),
                            )
                          : Color.alphaBlend(
                              primary.withValues(alpha: 0.04),
                              Colors.white.withValues(alpha: 0.88),
                            ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withValues(alpha: 0.06),
                                primary.withValues(alpha: 0.03),
                                Colors.transparent,
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.65),
                                const Color(0xFFF1F5F9).withValues(alpha: 0.40),
                              ],
                        stops: isDark ? const [0.0, 0.45, 1.0] : null,
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: padding,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 保持对旧代码与测试的 100% 兼容类型别名
typedef ModernLyricDialogCard = ModernLyricDialogFrame;

/// 计算并限制展开后的窗口位置，防止窗口向屏幕外部（如下方任务栏）溢出遮挡操作按钮
Future<Offset> calculateSafeWindowPosition({
  required Offset originPos,
  required Size originSize,
  required double targetWidth,
  required double targetHeight,
}) async {
  var newX = originPos.dx - (targetWidth - originSize.width) / 2;
  var newY = originPos.dy - (targetHeight - originSize.height) / 2;

  try {
    final displays = await screenRetriever.getAllDisplays().timeout(
          const Duration(milliseconds: 120),
        );
    Display? targetDisplay;
    final center = Offset(
      originPos.dx + originSize.width / 2,
      originPos.dy + originSize.height / 2,
    );
    for (final d in displays) {
      final pos = d.visiblePosition ?? Offset.zero;
      final sz = d.visibleSize ?? d.size;
      final rect = Rect.fromLTWH(pos.dx, pos.dy, sz.width, sz.height);
      if (rect.contains(center)) {
        targetDisplay = d;
        break;
      }
    }
    targetDisplay ??= displays.isNotEmpty ? displays.first : null;

    if (targetDisplay != null) {
      final visibleSize = targetDisplay.visibleSize ?? targetDisplay.size;
      final visiblePos = targetDisplay.visiblePosition ?? Offset.zero;

      final minX = visiblePos.dx + 8.0;
      final maxX = visiblePos.dx + visibleSize.width - targetWidth - 8.0;
      final minY = visiblePos.dy + 8.0;
      final maxY = visiblePos.dy + visibleSize.height - targetHeight - 8.0;

      if (maxX >= minX) {
        newX = math.max(minX, math.min(newX, maxX));
      }
      if (maxY >= minY) {
        newY = math.max(minY, math.min(newY, maxY));
      }
    }
  } catch (_) {
    // 无头测试或插件不可用时保持居中位移，不强行钳制至原点（避免多屏负坐标跨屏错位）
  }

  return Offset(newX, newY);
}
