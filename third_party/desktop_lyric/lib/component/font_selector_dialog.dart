import 'dart:math' as math;

import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/component/modern_lyric_dialog_frame.dart';
export 'package:desktop_lyric/component/modern_lyric_dialog_frame.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

/// 字体规格字重映射模型
class LyricFontVariant {
  final String fullName;
  final String familyName;
  final String styleName;
  final int weight;
  final bool isItalic;
  final bool isImported;

  const LyricFontVariant({
    required this.fullName,
    required this.familyName,
    required this.styleName,
    required this.weight,
    this.isItalic = false,
    this.isImported = false,
  });

  FontWeight get fontWeight {
    final lower = styleName.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
    if (lower == 'regular' ||
        lower == 'normal' ||
        lower == 'book' ||
        lower == '常规') {
      return FontWeight.w400;
    }
    if (lower == 'thin' || lower == 'hairline' || lower == '极细') {
      return FontWeight.w100;
    }
    if (lower == 'extralight' || lower == 'ultralight' || lower == '特细') {
      return FontWeight.w200;
    }
    if (lower == 'light' || lower == '细体') {
      return FontWeight.w300;
    }
    if (lower == 'medium' || lower == '中黑') {
      return FontWeight.w500;
    }
    if (lower == 'semibold' || lower == 'demibold' || lower == '半粗') {
      return FontWeight.w600;
    }
    if (lower == 'bold' || lower == '粗体') {
      return FontWeight.w700;
    }
    if (lower == 'extrabold' || lower == 'ultrabold' || lower == '特粗') {
      return FontWeight.w800;
    }
    if (lower == 'black' || lower == 'heavy' || lower == '黑体') {
      return FontWeight.w900;
    }

    if (weight <= 150) return FontWeight.w100;
    if (weight <= 250) return FontWeight.w200;
    if (weight <= 350) return FontWeight.w300;
    if (weight <= 450) return FontWeight.w400;
    if (weight <= 550) return FontWeight.w500;
    if (weight <= 650) return FontWeight.w600;
    if (weight <= 750) return FontWeight.w700;
    if (weight <= 850) return FontWeight.w800;
    return FontWeight.w900;
  }

  String get displayStyleName {
    final s = styleName.trim();
    if (s.isEmpty) {
      return _weightToLabel(weight, isItalic);
    }
    final lower = s.toLowerCase();
    if (lower == 'regular') return '常规 Regular';
    if (lower == 'bold') return '粗体 Bold';
    if (lower == 'italic') return '斜体 Italic';
    if (lower == 'bold italic') return '粗斜体 Bold Italic';
    if (lower == 'light') return '细体 Light';
    if (lower == 'extralight' ||
        lower == 'extra light' ||
        lower == 'extra-light') {
      return '特细 ExtraLight';
    }
    if (lower == 'thin') return '极细 Thin';
    if (lower == 'medium') return '中黑 Medium';
    if (lower == 'semibold' || lower == 'semi bold' || lower == 'semi-bold') {
      return '半粗 SemiBold';
    }
    if (lower == 'extrabold' ||
        lower == 'extra bold' ||
        lower == 'extra-bold') {
      return '特粗 ExtraBold';
    }
    if (lower == 'black' || lower == 'heavy') return '黑体 Heavy';
    return s;
  }

  static String _weightToLabel(int weight, bool isItalic) {
    String label;
    if (weight <= 150) {
      label = '极细 Thin';
    } else if (weight <= 250) {
      label = '特细 ExtraLight';
    } else if (weight <= 350) {
      label = '细体 Light';
    } else if (weight <= 450) {
      label = '常规 Regular';
    } else if (weight <= 550) {
      label = '中黑 Medium';
    } else if (weight <= 650) {
      label = '半粗 SemiBold';
    } else if (weight <= 750) {
      label = '粗体 Bold';
    } else if (weight <= 850) {
      label = '特粗 ExtraBold';
    } else {
      label = '黑体 Heavy';
    }
    return isItalic ? '$label 斜体' : label;
  }
}

/// 字体家族分组模型
class LyricFontFamilyGroup {
  final String familyName;
  final List<LyricFontVariant> variants;
  final bool isImported;

  const LyricFontFamilyGroup({
    required this.familyName,
    required this.variants,
    this.isImported = false,
  });

  bool get hasMultipleWeights => variants.length > 1;

  LyricFontVariant get primaryVariant {
    for (final v in variants) {
      if (!v.isItalic) {
        final s = v.styleName.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
        if (s == 'regular' || s == 'normal' || s == 'book' || s == '常规') {
          return v;
        }
      }
    }
    for (final v in variants) {
      if (!v.isItalic &&
          (v.fontWeight == FontWeight.w400 ||
              (v.weight >= 350 && v.weight <= 450))) {
        return v;
      }
    }
    for (final v in variants) {
      if (!v.isItalic) return v;
    }
    return variants.first;
  }
}

String _extractFamilyFallback(String fullName) {
  final patterns = [
    RegExp(
      r'\s+(Regular|Bold\s+Italic|Bold|Italic|Light|Medium|Black|Heavy|Thin|SemiBold|ExtraLight|ExtraBold|DemiBold|常规|粗体|细体|粗斜体)$',
      caseSensitive: false,
    ),
  ];
  for (final p in patterns) {
    if (p.hasMatch(fullName)) {
      final stripped = fullName.replaceAll(p, '').trim();
      if (stripped.isNotEmpty) return stripped;
    }
  }
  return fullName;
}

String _extractStyleFallback(String fullName) {
  final lower = fullName.toLowerCase();
  if (lower.contains('bold italic') || lower.contains('粗斜体')) return 'Bold Italic';
  if (lower.contains('semibold italic') || lower.contains('semi bold italic')) {
    return 'SemiBold Italic';
  }
  if (lower.contains('extrabold') ||
      lower.contains('extra bold') ||
      lower.contains('ultrabold') ||
      lower.contains('特粗')) {
    return 'ExtraBold';
  }
  if (lower.contains('semibold') ||
      lower.contains('semi bold') ||
      lower.contains('demibold') ||
      lower.contains('半粗')) {
    return 'SemiBold';
  }
  if (lower.contains('bold') || lower.contains('粗体')) return 'Bold';
  if (lower.contains('extralight') ||
      lower.contains('extra light') ||
      lower.contains('ultralight') ||
      lower.contains('特细')) {
    return 'ExtraLight';
  }
  if (lower.contains('light') || lower.contains('细体')) return 'Light';
  if (lower.contains('thin') || lower.contains('hairline') || lower.contains('极细')) {
    return 'Thin';
  }
  if (lower.contains('medium') || lower.contains('中黑')) return 'Medium';
  if (lower.contains('black') || lower.contains('heavy') || lower.contains('黑体')) {
    return 'Heavy';
  }
  if (lower.contains('italic') || lower.contains('斜体')) return 'Italic';
  return 'Regular';
}

int _extractWeightFallback(String fullName, String style) {
  final combined = '$fullName $style'.toLowerCase();
  if (combined.contains('thin') || combined.contains('极细')) return 100;
  if (combined.contains('extralight') ||
      combined.contains('extra light') ||
      combined.contains('特细')) {
    return 200;
  }
  if (combined.contains('light') || combined.contains('细体')) return 300;
  if (combined.contains('medium') || combined.contains('中黑')) return 500;
  if (combined.contains('semibold') ||
      combined.contains('semi bold') ||
      combined.contains('半粗')) {
    return 600;
  }
  if (combined.contains('extrabold') ||
      combined.contains('extra bold') ||
      combined.contains('特粗')) {
    return 800;
  }
  if (combined.contains('black') ||
      combined.contains('heavy') ||
      combined.contains('黑体')) {
    return 900;
  }
  if (combined.contains('bold') || combined.contains('粗体')) return 700;
  return 400;
}

List<LyricFontFamilyGroup> parseFontFamilyGroups(
  List<String> rawFontNames, {
  Set<String>? importedFontNames,
}) {
  final groupMap = <String, List<LyricFontVariant>>{};
  final importedLower =
      importedFontNames?.map((e) => e.toLowerCase()).toSet() ?? const {};

  for (final raw in rawFontNames) {
    final name = raw.trim();
    if (name.isEmpty) continue;

    final family = _extractFamilyFallback(name);
    final style = _extractStyleFallback(name);
    final weight = _extractWeightFallback(name, style);
    final isItalic = name.toLowerCase().contains('italic') ||
        name.toLowerCase().contains('斜体');
    final isImported = importedLower.contains(name.toLowerCase()) ||
        importedLower.contains(family.toLowerCase()) ||
        name.startsWith('[已导入]') ||
        name.startsWith('imported:');

    final variant = LyricFontVariant(
      fullName: name,
      familyName: family,
      styleName: style,
      weight: weight,
      isItalic: isItalic,
      isImported: isImported,
    );

    final key = family.toLowerCase();
    groupMap.putIfAbsent(key, () => []).add(variant);
  }

  final groups = <LyricFontFamilyGroup>[];
  for (final entry in groupMap.entries) {
    final variants = entry.value
      ..sort((a, b) {
        if (a.weight != b.weight) return a.weight.compareTo(b.weight);
        if (a.isItalic != b.isItalic) return a.isItalic ? 1 : -1;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
    final canonicalFamily = variants.first.familyName;
    final isGroupImported = variants.any((v) => v.isImported);
    groups.add(LyricFontFamilyGroup(
      familyName: canonicalFamily,
      variants: variants,
      isImported: isGroupImported,
    ));
  }

  groups.sort((a, b) =>
      a.familyName.toLowerCase().compareTo(b.familyName.toLowerCase()));
  return groups;
}

/// 弹出桌面歌词字体选择弹窗
Future<void> showLyricFontSelectorDialog(BuildContext context) async {
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
      final targetHeight = math.max(originSize.height, 620.0);
      final targetWidth = math.max(originSize.width, 600.0);
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
      builder: (context) => const LyricFontSelectorDialog(),
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

/// 现代毛玻璃桌面歌词字体选择面板（完全对齐播放器 _FontSelector 风格与交互）
class LyricFontSelectorDialog extends StatefulWidget {
  const LyricFontSelectorDialog({super.key});

  @override
  State<LyricFontSelectorDialog> createState() =>
      _LyricFontSelectorDialogState();
}

class _LyricFontSelectorDialogState extends State<LyricFontSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';
  LyricFontFamilyGroup? _activeFamily;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeChangedMessage>();
    final primary = Color(theme.primary);
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        DesktopLyricController.instance.isDarkMode.value;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final onSurfaceSecondary = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF475569);

    return PopScope(
      canPop: _activeFamily == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_activeFamily != null) {
          setState(() => _activeFamily = null);
        }
      },
      child: ModernLyricDialogFrame(
        maxWidth: 540.0,
        maxHeight: 560.0,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Consumer<TextDisplayController>(
          builder: (context, controller, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: DesktopLyricController.instance.currentFontFamily,
              builder: (context, playerFont, _) {
                if (_activeFamily != null) {
                  return _buildSecondaryMenu(
                    context,
                    controller: controller,
                    family: _activeFamily!,
                    primary: primary,
                    onSurface: onSurface,
                    onSurfaceSecondary: onSurfaceSecondary,
                    isDark: isDark,
                  );
                }

                return _buildPrimaryMenu(
                  context,
                  controller: controller,
                  playerFont: playerFont,
                  primary: primary,
                  onSurface: onSurface,
                  onSurfaceSecondary: onSurfaceSecondary,
                  isDark: isDark,
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 一级主菜单：Header、搜索框、系统默认/跟随播放器置顶卡片、字体族列表
  Widget _buildPrimaryMenu(
    BuildContext context, {
    required TextDisplayController controller,
    required String? playerFont,
    required Color primary,
    required Color onSurface,
    required Color onSurfaceSecondary,
    required bool isDark,
  }) {
    final activeDisplayName = controller.followPlayerFont
        ? "跟随主播放器 (${playerFont ?? '系统默认'})"
        : (controller.preferenceLyricFontFamily == null
            ? "系统默认"
            : controller.preferenceLyricFontFamily!);

    final isDefault = !controller.followPlayerFont &&
        controller.preferenceLyricFontFamily == null;
    final isFollow = controller.followPlayerFont;

    final activeAccentColor = isDark
        ? (primary.computeLuminance() > 0.35 ? primary : const Color(0xFF38BDF8))
        : (primary.computeLuminance() < 0.65 ? primary : const Color(0xFF0284C7));

    final themedSurfaceInset = isDark
        ? Color.alphaBlend(
            primary.withValues(alpha: 0.06),
            const Color(0xFF1E2533).withValues(alpha: 0.45),
          )
        : Color.alphaBlend(
            primary.withValues(alpha: 0.04),
            const Color(0xFFF1F5F9).withValues(alpha: 0.70),
          );
    final themedItemBg = isDark
        ? Color.alphaBlend(
            primary.withValues(alpha: 0.05),
            const Color(0xFF1E2533).withValues(alpha: 0.35),
          )
        : Color.alphaBlend(
            primary.withValues(alpha: 0.03),
            const Color(0xFFF1F5F9).withValues(alpha: 0.60),
          );
    final themedItemBorder = Color.alphaBlend(
      primary.withValues(alpha: isDark ? 0.12 : 0.08),
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
    );
    final themedSurfaceChip = isDark
        ? Color.alphaBlend(
            primary.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.10),
          )
        : Color.alphaBlend(
            primary.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.06),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header 对齐主播放器弹窗规范（44x44 图标徽标、标准间距与圆角）
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: primary.withValues(alpha: isDark ? 0.28 : 0.20),
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.text_fields_rounded,
                size: 24,
                color: primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "选择字体",
                    semanticsLabel: "桌面歌词字体",
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "当前字体：$activeDisplayName · 仅作用于桌面歌词",
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      color: onSurfaceSecondary,
                      letterSpacing: 0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: onSurfaceSecondary,
              ),
              tooltip: "关闭",
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // 2. 搜索框（现代半透圆角边框风格，动态混色填充底座）
        TextField(
          controller: _searchController,
          style: TextStyle(fontSize: 14.5, color: onSurface),
          cursorColor: primary,
          decoration: InputDecoration(
            hintText: "搜索字体...",
            hintStyle: TextStyle(
              fontSize: 13.5,
              color: onSurfaceSecondary.withValues(alpha: 0.8),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: onSurfaceSecondary,
            ),
            suffixIcon: _filter.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: onSurfaceSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _filter = '');
                    },
                  )
                : null,
            isDense: true,
            filled: true,
            fillColor: themedSurfaceInset,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: themedItemBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: themedItemBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: primary,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (val) {
            setState(() => _filter = val);
          },
        ),
        const SizedBox(height: 12.0),

        // 3. 列表区域
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              type: MaterialType.transparency,
              child: ValueListenableBuilder<List<String>>(
                valueListenable:
                    DesktopLyricController.instance.installedFonts,
                builder: (context, fontNames, _) {
                  if (fontNames.isEmpty) {
                    return Center(
                      child: Text(
                        "正在同步系统字体列表...",
                        style: TextStyle(
                          fontSize: 13.5,
                          color: onSurfaceSecondary,
                        ),
                      ),
                    );
                  }

                  final groups = parseFontFamilyGroups(fontNames);
                  final query = _filter.trim().toLowerCase();

                  final filteredGroups = query.isEmpty
                      ? groups
                      : groups.where((g) {
                          if (g.familyName.toLowerCase().contains(query)) {
                            return true;
                          }
                          return g.variants.any((v) =>
                              v.fullName.toLowerCase().contains(query) ||
                              v.styleName.toLowerCase().contains(query) ||
                              v.displayStyleName.toLowerCase().contains(query) ||
                              v.weight.toString().contains(query));
                        }).toList();

                  final importedGroups =
                      filteredGroups.where((g) => g.isImported).toList();
                  final systemGroups =
                      filteredGroups.where((g) => !g.isImported).toList();

                  return CustomScrollView(
                    slivers: [
                      if (query.isEmpty)
                        SliverToBoxAdapter(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 置顶项 1: 跟随主播放器字体
                              _buildPinnedOptionTile(
                                context,
                                icon: Icons.sync_rounded,
                                title: "跟随主播放器字体",
                                subtitle: "当前播放器字体：${playerFont ?? '系统默认'}",
                                isSelected: isFollow,
                                onTap: () {
                                  controller.applyFont(
                                    family: null,
                                    followPlayer: true,
                                  );
                                  Navigator.of(context).pop();
                                },
                                primary: primary,
                                onSurface: onSurface,
                                onSurfaceSecondary: onSurfaceSecondary,
                                isDark: isDark,
                                activeAccentColor: activeAccentColor,
                                themedItemBg: themedItemBg,
                                themedItemBorder: themedItemBorder,
                              ),
                              const SizedBox(height: 6),
                              // 置顶项 2: 系统默认字体
                              _buildPinnedOptionTile(
                                context,
                                icon: Icons.font_download_rounded,
                                title: "系统默认字体",
                                subtitle: "恢复使用系统与播放器默认字体",
                                isSelected: isDefault,
                                onTap: () {
                                  controller.applyFont(
                                    family: null,
                                    followPlayer: false,
                                  );
                                  Navigator.of(context).pop();
                                },
                                primary: primary,
                                onSurface: onSurface,
                                onSurfaceSecondary: onSurfaceSecondary,
                                isDark: isDark,
                                activeAccentColor: activeAccentColor,
                                themedItemBg: themedItemBg,
                                themedItemBorder: themedItemBorder,
                              ),
                              const Divider(height: 16),
                            ],
                          ),
                        ),

                      // 分组 1: 项目字体库（若有导入字体）
                      if (importedGroups.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                            child: Text(
                              "项目字体库（已导入 ${importedGroups.length} 组）",
                              style: TextStyle(
                                color: primary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SliverList.builder(
                          itemCount: importedGroups.length,
                          itemBuilder: (context, index) {
                            return _buildFamilyGroupTile(
                              context,
                              family: importedGroups[index],
                              controller: controller,
                              isFollow: isFollow,
                              primary: primary,
                              onSurface: onSurface,
                              onSurfaceSecondary: onSurfaceSecondary,
                              isDark: isDark,
                              activeAccentColor: activeAccentColor,
                              themedItemBg: themedItemBg,
                              themedItemBorder: themedItemBorder,
                              themedSurfaceChip: themedSurfaceChip,
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: Divider(height: 16)),
                      ],

                      // 分组 2: 系统已有字体
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Text(
                            "系统已有字体（${systemGroups.length} 组）",
                            style: TextStyle(
                              color: onSurfaceSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: systemGroups.length,
                        itemBuilder: (context, index) {
                          return _buildFamilyGroupTile(
                            context,
                            family: systemGroups[index],
                            controller: controller,
                            isFollow: isFollow,
                            primary: primary,
                            onSurface: onSurface,
                            onSurfaceSecondary: onSurfaceSecondary,
                            isDark: isDark,
                            activeAccentColor: activeAccentColor,
                            themedItemBg: themedItemBg,
                            themedItemBorder: themedItemBorder,
                            themedSurfaceChip: themedSurfaceChip,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),

        // 4. 一级页面底部取消操作栏
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
          ],
        ),
      ],
    );
  }

  /// 置顶选项列表项（跟随播放器字体 / 系统默认字体）
  Widget _buildPinnedOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primary,
    required Color onSurface,
    required Color onSurfaceSecondary,
    required bool isDark,
    required Color activeAccentColor,
    required Color themedItemBg,
    required Color themedItemBorder,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? activeAccentColor.withValues(alpha: isDark ? 0.20 : 0.12)
                : themedItemBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeAccentColor.withValues(alpha: 0.85)
                  : themedItemBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeAccentColor.withValues(alpha: isDark ? 0.28 : 0.18)
                      : onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDark
                      ? Colors.white
                      : (isSelected ? activeAccentColor : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: onSurfaceSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: activeAccentColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 字体族列表项（支持单规格直选与多规格折叠展开）
  Widget _buildFamilyGroupTile(
    BuildContext context, {
    required LyricFontFamilyGroup family,
    required TextDisplayController controller,
    required bool isFollow,
    required Color primary,
    required Color onSurface,
    required Color onSurfaceSecondary,
    required bool isDark,
    required Color activeAccentColor,
    required Color themedItemBg,
    required Color themedItemBorder,
    required Color themedSurfaceChip,
  }) {
    final isCurrentFamily = !isFollow &&
        family.variants.any((v) =>
            v.fullName == controller.preferenceLyricFontFamily);
    final activeVariant = isCurrentFamily
        ? family.variants.firstWhere((v) =>
            v.fullName == controller.preferenceLyricFontFamily)
        : null;

    String subtitleText;
    if (family.hasMultipleWeights) {
      if (isCurrentFamily && activeVariant != null) {
        subtitleText =
            "当前已选：${activeVariant.displayStyleName} · 共 ${family.variants.length} 种粗细规格";
      } else {
        subtitleText =
            "共 ${family.variants.length} 种粗细规格 · 点击展开选择粗细";
      }
    } else {
      subtitleText = "AaBbCc 永和九年 岁在癸丑 123";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrentFamily
            ? activeAccentColor.withValues(alpha: isDark ? 0.16 : 0.10)
            : themedItemBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentFamily
              ? activeAccentColor.withValues(alpha: 0.70)
              : themedItemBorder,
          width: isCurrentFamily ? 1.4 : 1.0,
        ),
      ),
      child: ListTile(
        enableFeedback: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        title: Text(
          family.familyName,
          style: TextStyle(
            fontFamily: family.primaryVariant.fullName,
            color: isDark
                ? Colors.white
                : (isCurrentFamily
                    ? (primary.computeLuminance() < 0.6
                        ? primary
                        : const Color(0xFF0F172A))
                    : const Color(0xFF0F172A)),
            fontSize: 15.5,
            fontWeight: isCurrentFamily
                ? FontWeight.bold
                : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(
            fontFamily: family.primaryVariant.fullName,
            color: onSurfaceSecondary,
            fontSize: family.hasMultipleWeights ? 12.5 : 13.5,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentFamily && !family.hasMultipleWeights)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: activeAccentColor,
              ),
            if (family.hasMultipleWeights) ...[
              if (isCurrentFamily) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: activeAccentColor,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: themedSurfaceChip,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${family.variants.length} 种粗细",
                  style: TextStyle(
                    fontSize: 12.0,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: onSurfaceSecondary.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
        onTap: () {
          if (family.hasMultipleWeights) {
            setState(() => _activeFamily = family);
          } else {
            controller.applyFont(
              family: family.primaryVariant.fullName,
              followPlayer: false,
            );
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  /// 二级多规格字重选择菜单（完全对齐播放器 _buildSecondaryMenu）
  Widget _buildSecondaryMenu(
    BuildContext context, {
    required TextDisplayController controller,
    required LyricFontFamilyGroup family,
    required Color primary,
    required Color onSurface,
    required Color onSurfaceSecondary,
    required bool isDark,
  }) {
    final isFollow = controller.followPlayerFont;
    final activeAccentColor = isDark
        ? (primary.computeLuminance() > 0.4 ? primary : const Color(0xFF38BDF8))
        : primary;

    final themedItemBg = isDark
        ? Color.alphaBlend(
            primary.withValues(alpha: 0.05),
            const Color(0xFF1E2533).withValues(alpha: 0.35),
          )
        : Color.alphaBlend(
            primary.withValues(alpha: 0.03),
            const Color(0xFFF1F5F9).withValues(alpha: 0.60),
          );
    final themedItemBorder = Color.alphaBlend(
      primary.withValues(alpha: isDark ? 0.12 : 0.08),
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 二级 Header 对齐主播放器规范
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: primary.withValues(alpha: isDark ? 0.28 : 0.20),
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.text_fields_rounded,
                size: 24,
                color: primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    family.familyName,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "选择粗细字重规格（共 ${family.variants.length} 种）",
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
              tooltip: "关闭",
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: onSurfaceSecondary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // 规格列表
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              type: MaterialType.transparency,
              child: ListView.separated(
                itemCount: family.variants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final variant = family.variants[index];
                  final isCurrent = !isFollow &&
                      variant.fullName == controller.preferenceLyricFontFamily;

                  return Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? activeAccentColor.withValues(alpha: isDark ? 0.16 : 0.10)
                          : themedItemBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? activeAccentColor.withValues(alpha: 0.70)
                            : themedItemBorder,
                        width: isCurrent ? 1.4 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      enableFeedback: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      leading: Container(
                        width: 46,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? activeAccentColor.withValues(alpha: 0.20)
                              : onSurface.withValues(alpha: isDark ? 0.10 : 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: isCurrent
                              ? Border.all(color: activeAccentColor, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            "${variant.weight}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? (isDark ? Colors.white : activeAccentColor)
                                  : onSurfaceSecondary,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            variant.displayStyleName,
                            style: TextStyle(
                              fontFamily: variant.fullName,
                              fontWeight: variant.fontWeight,
                              fontStyle: variant.isItalic ? FontStyle.italic : FontStyle.normal,
                              fontSize: 15.5,
                              color: isDark
                                  ? Colors.white
                                  : (isCurrent ? activeAccentColor : const Color(0xFF0F172A)),
                            ),
                          ),
                          if (variant.isItalic) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: onSurface.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "斜体",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: onSurfaceSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        "AaBbCc 永和九年 岁在癸丑 123",
                        style: TextStyle(
                          fontFamily: variant.fullName,
                          fontWeight: variant.fontWeight,
                          fontStyle: variant.isItalic ? FontStyle.italic : FontStyle.normal,
                          fontSize: 13.0,
                          color: onSurfaceSecondary,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: activeAccentColor,
                            )
                          : null,
                      onTap: () {
                        controller.applyFont(
                          family: variant.fullName,
                          followPlayer: false,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),

        // 底部操作栏（对齐播放器规范，提供返回、应用全字重家族与取消选项）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text("返回字体列表"),
              style: TextButton.styleFrom(
                foregroundColor: onSurfaceSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => setState(() => _activeFamily = null),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text("应用全字重家族"),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: primary.computeLuminance() > 0.45
                        ? const Color(0xFF0F172A)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    controller.applyFont(
                      family: family.familyName,
                      followPlayer: false,
                    );
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
              ],
            ),
          ],
        ),
      ],
    );
  }
}
