import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/component/ui/modern_dropdown.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/theme_provider.dart';

class ScaleOption {
  const ScaleOption({
    required this.scale,
    required this.label,
    required this.description,
    this.isRecommended = false,
  });

  final double scale;
  final String label;
  final String description;
  final bool isRecommended;
}

const List<ScaleOption> uiScaleOptions = [
  ScaleOption(scale: 0.80, label: '80%', description: '紧凑 / 小屏幕视口'),
  ScaleOption(scale: 0.90, label: '90%', description: '轻量显示'),
  ScaleOption(scale: 1.00, label: '100% (标准)', description: '标准默认比例'),
  ScaleOption(scale: 1.05, label: '105%', description: '微幅放大'),
  ScaleOption(scale: 1.10, label: '110%', description: '适度放大'),
  ScaleOption(
    scale: 1.15,
    label: '115% (推荐)',
    description: '1080p 标准显示屏推荐',
    isRecommended: true,
  ),
  ScaleOption(scale: 1.20, label: '120%', description: '舒适大字'),
  ScaleOption(
    scale: 1.25,
    label: '125% (推荐)',
    description: '1080p 清晰大字体验推荐',
    isRecommended: true,
  ),
  ScaleOption(scale: 1.30, label: '130%', description: '大字号模式'),
  ScaleOption(scale: 1.40, label: '140%', description: '超大字号模式'),
  ScaleOption(
    scale: 1.50,
    label: '150% (高分屏)',
    description: '2K / 4K 高分辨率屏幕推荐',
    isRecommended: true,
  ),
];

/// 调起全局界面缩放设置现代毛玻璃对话框
Future<void> showUiScaleDialog(BuildContext context) {
  return showModernDialog<void>(
    context: context,
    builder: (context) => const UiScaleDialog(),
  );
}

/// 界面缩放现代毛玻璃对话框组件
/// 视觉与交互规范深度对齐自定义字体（_FontSelector）与音乐编辑（AudioEditDialog）
class UiScaleDialog extends StatelessWidget {
  const UiScaleDialog({
    super.key,
    this.isEmbedded = false,
  });

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final currentScale = theme.uiScale;

    final matchedOption = uiScaleOptions.firstWhere(
      (opt) => (opt.scale - currentScale).abs() < 0.005,
      orElse: () => ScaleOption(
        scale: currentScale,
        label: '${(currentScale * 100).round()}%',
        description: '自定义比例',
      ),
    );

    final content = _UiScaleDialogBody(
      currentScale: currentScale,
      matchedOption: matchedOption,
      isEmbedded: isEmbedded,
    );

    if (isEmbedded) {
      return content;
    }

    return ModernDialogFrame(
      maxWidth: 520,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: content,
    );
  }
}

class _UiScaleDialogBody extends StatelessWidget {
  const _UiScaleDialogBody({
    required this.currentScale,
    required this.matchedOption,
    required this.isEmbedded,
  });

  final double currentScale;
  final ScaleOption matchedOption;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final availableOptions = uiScaleOptions.any(
            (opt) => (opt.scale - currentScale).abs() < 0.005)
        ? uiScaleOptions
        : [matchedOption, ...uiScaleOptions];

    final selectedScale = matchedOption.scale;

    final isDefaultScale = (currentScale - 1.0).abs() < 0.005;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isEmbedded) ...[
            // 头部：现代毛玻璃弹窗品牌徽章与标题区域，与音乐编辑和自定义字体保持一致
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.20),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    Symbols.aspect_ratio_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '界面缩放 / UI Scale',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '当前比例：${matchedOption.label} · ${matchedOption.description}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: isDark ? 0.82 : 0.90,
                          ),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: Icon(
                    Symbols.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ] else ...[
            Text(
              '当前比例：${matchedOption.label} · ${matchedOption.description}',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 现代风格下拉选择菜单（彻底移除生硬原生下拉黑色浮层与弹窗遮罩）
          ModernDropdown<double>(
            key: ValueKey(selectedScale),
            value: selectedScale,
            labelText: '选择缩放比例',
            prefixIcon: const Icon(Symbols.aspect_ratio_rounded),
            items: availableOptions.map((opt) {
              final isSelected = (opt.scale - selectedScale).abs() < 0.005;
              return ModernDropdownItem<double>(
                value: opt.scale,
                label: opt.label,
                description: opt.description,
                isRecommended: opt.isRecommended,
                tag: opt.isRecommended ? (opt.scale >= 1.5 ? '高分屏' : '推荐') : null,
                leading: Container(
                  width: 48,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.18)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.5)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.08)),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${(opt.scale * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? scheme.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: (newVal) async {
              if (newVal == null) return;
              await ThemeProvider.instance.applyUiScale(newVal);
            },
          ),
          const SizedBox(height: 16),

          // 常用推荐档位
          Row(
            children: [
              Text(
                '常用推荐档位',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: uiScaleOptions
                .where((opt) => opt.isRecommended || opt.scale == 1.0)
                .map((opt) {
              final isSelected = (currentScale - opt.scale).abs() < 0.005;
              return ChoiceChip(
                label: Text(opt.label),
                selected: isSelected,
                visualDensity: VisualDensity.compact,
                onSelected: (selected) async {
                  if (!selected || isSelected) return;
                  await ThemeProvider.instance.applyUiScale(opt.scale);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 显示适配指引卡片
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.40 : 0.60,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.lightbulb_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '显示适配指引',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 1080p 标准屏幕：推荐 110% 或 115%，舒适无疲劳\n'
                  '• 2K / 4K 高分屏：推荐 125% 或 150%，字体饱满笔画扎实\n'
                  '• 界面各视口自适应断点保护已全局生效',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: scheme.onSurface.withValues(
                      alpha: isDark ? 0.85 : 0.92,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 底部操作按钮栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Symbols.restart_alt_rounded, size: 16),
                label: const Text('恢复 100%'),
                onPressed: isDefaultScale
                    ? null
                    : () async {
                        await ThemeProvider.instance.applyUiScale(1.0);
                      },
              ),
              if (!isEmbedded)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 保留二级路由页面入口作为降级兼容承载
class SettingsUiScalePage extends StatelessWidget {
  const SettingsUiScalePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '界面缩放 / UI Scale',
      subtitle: '调整全局界面元素与文本显示缩放比例，优化高分屏与各视口尺寸视觉体验。',
      titleAction: IconButton(
        tooltip: '返回设置',
        icon: const Icon(Symbols.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/settings');
          }
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 48),
            child: UiScaleDialog(isEmbedded: true),
          ),
        ),
      ),
    );
  }
}
