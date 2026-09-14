import 'dart:math' as math;

import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/component/modern_lyric_dialog_frame.dart';
export 'package:desktop_lyric/component/modern_lyric_dialog_frame.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

/// 颜色转换为大写 6 位十六进制字符串（如 #00F5D4）
String toRGBHexString(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// 兼容测试与旧命名的辅助函数
String colorToHex(Color color) => toRGBHexString(color);

int colorChannel(Color color, int shift) => (color.toARGB32() >> shift) & 0xFF;

Color? fromRGBHexString(String rgbHexStr) {
  var s = rgbHexStr.trim();
  if (s.startsWith("#")) {
    s = s.substring(1);
  }
  if (s.length == 6) {
    final val = int.tryParse(s, radix: 16);
    if (val != null) {
      return Color(0xFF000000 | val);
    }
  }
  return null;
}

/// 歌词预设配色模型
class LyricColorPreset {
  final String name;
  final Color color;
  final String hex;

  const LyricColorPreset({
    required this.name,
    required this.color,
    required this.hex,
  });
}

/// 现代高质感歌词预设色彩方案
const List<LyricColorPreset> kCuratedColorPresets = [
  LyricColorPreset(name: '极光青', color: Color(0xFF00F5D4), hex: '#00F5D4'),
  LyricColorPreset(name: '流光银', color: Color(0xFFE2E8F0), hex: '#E2E8F0'),
  LyricColorPreset(name: '霓虹紫', color: Color(0xFFB388FF), hex: '#B388FF'),
  LyricColorPreset(name: '落日橙', color: Color(0xFFFF7043), hex: '#FF7043'),
  LyricColorPreset(name: '晨曦金', color: Color(0xFFFFD166), hex: '#FFD166'),
  LyricColorPreset(name: '纯净白', color: Color(0xFFFFFFFF), hex: '#FFFFFF'),
  LyricColorPreset(name: '樱落粉', color: Color(0xFFFF80AB), hex: '#FF80AB'),
  LyricColorPreset(name: '薄荷绿', color: Color(0xFF69F0AE), hex: '#69F0AE'),
  LyricColorPreset(name: '晴空蓝', color: Color(0xFF40C4FF), hex: '#40C4FF'),
];

/// 弹出现代毛玻璃桌面歌词色彩选择面板（完全对齐播放器弹窗规范风格）
Future<void> showDesktopLyricColorDialog(BuildContext context) async {
  isDialogOpen.value = true;
  Offset? originPos;
  try {
    try {
      final originSize = await windowManager.getSize().timeout(
        const Duration(milliseconds: 100),
      );
      originPos = await windowManager.getPosition().timeout(
        const Duration(milliseconds: 100),
      );
      final targetHeight = math.max(originSize.height, 550.0);
      final targetWidth = math.max(originSize.width, 700.0);
      if (targetHeight > originSize.height || targetWidth > originSize.width) {
        final safePos = await calculateSafeWindowPosition(
          originPos: originPos,
          originSize: originSize,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
        await windowManager.setPosition(safePos);
        await windowManager.setSize(Size(targetWidth, targetHeight)).timeout(
          const Duration(milliseconds: 100),
        );
      }
    } catch (_) {
      // Window manager not available in test environment
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (context) => const DesktopLyricColorDialog(),
    );
  } finally {
    isDialogOpen.value = false;
    try {
      if (originPos != null) {
        await windowManager.setPosition(originPos);
      }
      resizeWithForegroundSize();
    } catch (_) {}
  }
}

/// 一体化现代毛玻璃色彩选择面板（对齐播放器 ThemePickerDialog 风格）
class DesktopLyricColorDialog extends StatefulWidget {
  const DesktopLyricColorDialog({super.key});

  @override
  State<DesktopLyricColorDialog> createState() =>
      _DesktopLyricColorDialogState();
}

class _DesktopLyricColorDialogState extends State<DesktopLyricColorDialog> {
  late Color _selectedColor;
  late bool _isFollowingTheme;
  String? _selectedPresetName;

  late bool _initialHasSpecifiedColor;
  late Color _initialSpecifiedColor;

  late final TextEditingController _rgbHexTextEditingController;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    final textDisplayController = context.read<TextDisplayController>();
    final theme = context.read<ThemeChangedMessage>();

    _initialHasSpecifiedColor = textDisplayController.hasSpecifiedColor;
    _initialSpecifiedColor = textDisplayController.specifiedColor;

    if (_initialHasSpecifiedColor) {
      _selectedColor = _initialSpecifiedColor;
      _isFollowingTheme = false;
      for (final p in kCuratedColorPresets) {
        if (p.color == _selectedColor) {
          _selectedPresetName = p.name;
          break;
        }
      }
    } else {
      _selectedColor = Color(theme.primary);
      _isFollowingTheme = true;
    }

    _rgbHexTextEditingController = TextEditingController(
      text: toRGBHexString(_selectedColor),
    );
  }

  @override
  void dispose() {
    _rgbHexTextEditingController.dispose();
    super.dispose();
  }

  void _rollback() {
    final controller = context.read<TextDisplayController>();
    if (_initialHasSpecifiedColor) {
      controller.spcifiyColor(_initialSpecifiedColor);
    } else {
      controller.usePlayerTheme();
    }
  }

  void _onCancel(BuildContext context) {
    _applied = true;
    _rollback();
    Navigator.of(context).pop();
  }

  void _onApply(BuildContext context) {
    _applied = true;
    final controller = context.read<TextDisplayController>();
    if (_isFollowingTheme) {
      controller.usePlayerTheme();
    } else {
      controller.spcifiyColor(_selectedColor);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeChangedMessage>();
    final textDisplayController = context.watch<TextDisplayController>();
    final playerPrimary = Color(theme.primary);
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        DesktopLyricController.instance.isDarkMode.value;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final onSurfaceSecondary = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF475569);

    final themedContainerBg = isDark
        ? Color.alphaBlend(
            playerPrimary.withValues(alpha: 0.06),
            const Color(0xFF1E2533).withValues(alpha: 0.45),
          )
        : Color.alphaBlend(
            playerPrimary.withValues(alpha: 0.04),
            const Color(0xFFF1F5F9).withValues(alpha: 0.70),
          );

    final themedBorder = Color.alphaBlend(
      playerPrimary.withValues(alpha: isDark ? 0.15 : 0.10),
      isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );

    final themedTagBg = isDark
        ? Color.alphaBlend(
            playerPrimary.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.08),
          )
        : Color.alphaBlend(
            playerPrimary.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.04),
          );

    final themedInsetBg = isDark
        ? Color.alphaBlend(
            playerPrimary.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.20),
          )
        : Color.alphaBlend(
            playerPrimary.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.60),
          );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_applied) {
          _rollback();
        }
      },
      child: ModernLyricDialogCard(
        maxWidth: 660,
        maxHeight: 510,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header 对齐主播放器弹窗规范（44x44 图标徽标、标准间距与圆角）
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: playerPrimary.withValues(alpha: isDark ? 0.16 : 0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: playerPrimary.withValues(alpha: isDark ? 0.28 : 0.20),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      size: 24,
                      color: playerPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "桌面歌词颜色",
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isFollowingTheme
                              ? "当前跟随主播放器主题色 · 实时预览"
                              : (_selectedPresetName != null
                                  ? "$_selectedPresetName (${toRGBHexString(_selectedColor)}) · 实时预览"
                                  : "自定义颜色：${toRGBHexString(_selectedColor)} · 实时预览"),
                          style: TextStyle(
                            color: onSurfaceSecondary,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _onCancel(context),
                    tooltip: "关闭",
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: onSurfaceSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // 2. 双列内容排版（无须滚动条，紧凑且清晰）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧列：歌词实时渲染预览 + 跟随主播放器主题色快捷操作 + 推荐预设配色
                Expanded(
                  flex: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 歌词实时渲染预览 Banner
                      Container(
                        key: const Key('preview_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: themedContainerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themedBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              key: const Key('preview_banner_tag'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: themedTagBg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                "正在播放：七声音乐 - 歌词大样",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              key: const Key('preview_banner_main_lyric'),
                              DesktopLyricController.instance.lyricLine.value.content.isNotEmpty
                                  ? DesktopLyricController.instance.lyricLine.value.content
                                  : "让音乐点亮此刻的生活",
                              style: TextStyle(
                                color: _selectedColor,
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                fontFamily: textDisplayController.lyricFontFamily,
                                shadows: [
                                  Shadow(
                                    color: _selectedColor.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (DesktopLyricController.instance.lyricLine.value.translation != null &&
                                DesktopLyricController.instance.lyricLine.value.translation!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                key: const Key('preview_banner_trans_lyric'),
                                DesktopLyricController.instance.lyricLine.value.translation!,
                                style: TextStyle(
                                  color: _selectedColor.withValues(alpha: 0.75),
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: textDisplayController.lyricFontFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 跟随播放器主题色快捷卡片（直接呈现在界面排版内，无需滚动）
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: const Key('follow_player_theme_card'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _isFollowingTheme = true;
                              _selectedPresetName = null;
                              _selectedColor = playerPrimary;
                              _rgbHexTextEditingController.text = toRGBHexString(playerPrimary);
                            });
                            textDisplayController.usePlayerTheme();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _isFollowingTheme
                                  ? playerPrimary.withValues(alpha: isDark ? 0.18 : 0.12)
                                  : themedContainerBg,
                              border: Border.all(
                                color: _isFollowingTheme
                                    ? playerPrimary
                                    : themedBorder,
                                width: _isFollowingTheme ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: playerPrimary.withValues(alpha: isDark ? 0.22 : 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.sync_rounded,
                                    size: 16,
                                    color: playerPrimary,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "跟随主播放器主题色",
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: _isFollowingTheme
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: _isFollowingTheme
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        "颜色自动随播放器主题或封面变化",
                                        style: TextStyle(
                                          fontSize: 11.0,
                                          color: onSurfaceSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: playerPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? Colors.white24 : Colors.black12,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                if (_isFollowingTheme) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: playerPrimary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 预设推荐配色标题
                      Text(
                        "推荐预设配色",
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          color: onSurfaceSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 预设质感配色 Chip 网格
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: kCuratedColorPresets.map((preset) {
                          final isSelected = !_isFollowingTheme &&
                              toRGBHexString(_selectedColor) == preset.hex;
                          return Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              key: ValueKey('preset_${preset.name}'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                setState(() {
                                  _selectedColor = preset.color;
                                  _selectedPresetName = preset.name;
                                  _isFollowingTheme = false;
                                  _rgbHexTextEditingController.text = preset.hex;
                                });
                                textDisplayController.spcifiyColor(preset.color);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? preset.color.withValues(alpha: isDark ? 0.26 : 0.18)
                                      : themedContainerBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? preset.color
                                        : themedBorder,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: preset.color,
                                        shape: BoxShape.circle,
                                        border: preset.color == const Color(0xFFFFFFFF)
                                            ? Border.all(color: Colors.black26, width: 1)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      preset.name,
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // 右侧列：ColorWheelPicker 色轮选择器 + 十六进制 RGB 输入框
                Expanded(
                  flex: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ColorWheelPicker（色轮微调）
                      Center(
                        child: SizedBox(
                          height: 185,
                          width: 185,
                          child: ColorWheelPicker(
                            color: _selectedColor,
                            onChanged: (color) {
                              setState(() {
                                _selectedColor = color;
                                _selectedPresetName = null;
                                _isFollowingTheme = false;
                              });
                              _rgbHexTextEditingController.text = toRGBHexString(color);
                              textDisplayController.spcifiyColor(color);
                            },
                            onWheel: (isWheel) {},
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 十六进制 RGB 输入框
                      TextField(
                        key: const Key('hex_input'),
                        controller: _rgbHexTextEditingController,
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 13.5,
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (value) {
                          final c = fromRGBHexString(value);
                          if (c != null) {
                            setState(() {
                              _selectedColor = c;
                              _selectedPresetName = null;
                              _isFollowingTheme = false;
                            });
                            textDisplayController.spcifiyColor(c);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: "十六进制 RGB",
                          hintText: "#RRGGBB",
                          isDense: true,
                          labelStyle: TextStyle(
                            color: onSurfaceSecondary,
                            fontSize: 12.0,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 8),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, maxHeight: 20),
                          filled: true,
                          fillColor: themedInsetBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: themedBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: themedBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: playerPrimary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14.0),

            // 3. 底部操作栏
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('color_dialog_cancel_btn'),
                  onPressed: () => _onCancel(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    "取消",
                    style: TextStyle(
                      fontSize: 14,
                      color: onSurfaceSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                FilledButton(
                  key: const Key('color_dialog_apply_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: playerPrimary,
                    foregroundColor: playerPrimary.computeLuminance() > 0.45
                        ? const Color(0xFF0F172A)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _onApply(context),
                  child: const Text(
                    "确定",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
