import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/animated_menu_content.dart';

/// 现代下拉菜单项数据模型。
class ModernDropdownItem<T> {
  const ModernDropdownItem({
    required this.value,
    required this.label,
    this.description,
    this.leading,
    this.trailing,
    this.tag,
    this.isRecommended = false,
  });

  /// 对应的数据值
  final T value;

  /// 主标题文本（例如 "115% (推荐)" 或 "系统默认字体"）
  final String label;

  /// 辅助说明副标题文本（例如 "1080p 标准显示屏推荐"）
  final String? description;

  /// 自定义左侧前缀部件（例如带底色的字重/比例角标）
  final Widget? leading;

  /// 自定义右侧后缀部件（例如特定操作图标）
  final Widget? trailing;

  /// 胶囊徽章文本（例如 "推荐"、"高分屏"）
  final String? tag;

  /// 是否为推荐项目（将显示高亮推荐徽章）
  final bool isRecommended;
}

/// 栖声播放器专属现代风格下拉选择菜单组件。
///
/// 视觉与交互规范深度对齐自定义字体选择器（_FontSelector）与音乐编辑对话框（AudioEditDialog）：
/// - 基于桌面专属 MenuAnchor 与 animatedMenuChildren 构建，杜绝原生生硬暗黑方正浮层
/// - 采用毛玻璃半透明容器、精修圆角与动态边框
/// - 高颜值项目列表项，支持徽章胶囊、推荐标签、选中态高亮与 Checkmark 反馈
class ModernDropdown<T> extends StatefulWidget {
  const ModernDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.maxHeight = 360.0,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  /// 当前选中的数值
  final T? value;

  /// 可选列表项集合
  final List<ModernDropdownItem<T>> items;

  /// 选中变更回调
  final ValueChanged<T?>? onChanged;

  /// 浮动标签提示语（例如 "选择缩放比例"）
  final String? labelText;

  /// 未选中时的占位文本
  final String? hintText;

  /// 左侧前缀图标部件
  final Widget? prefixIcon;

  /// 展开列表最大高度限制
  final double maxHeight;

  /// 触发器内边距
  final EdgeInsetsGeometry contentPadding;

  @override
  State<ModernDropdown<T>> createState() => _ModernDropdownState<T>();
}

class _ModernDropdownState<T> extends State<ModernDropdown<T>> {
  final MenuController _menuController = MenuController();
  final ValueNotifier<bool> _isOpenNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isOpenNotifier.dispose();
    super.dispose();
  }

  ModernDropdownItem<T>? _findSelectedItem() {
    for (final item in widget.items) {
      if (item.value == widget.value) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final selectedItem = _findSelectedItem();

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 280.0;

        return MenuAnchor(
          controller: _menuController,
          consumeOutsideTap: true,
          clipBehavior: Clip.antiAlias,
          onOpen: () => _isOpenNotifier.value = true,
          onClose: () => _isOpenNotifier.value = false,
          style: MenuStyle(
            minimumSize: WidgetStatePropertyAll(Size(anchorWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(math.max(anchorWidth, 320.0), widget.maxHeight),
            ),
            backgroundColor: WidgetStatePropertyAll(
              Color.alphaBlend(
                scheme.primary.withValues(alpha: isDark ? 0.10 : 0.05),
                isDark
                    ? const Color(0xFF141923).withValues(alpha: 0.96)
                    : Colors.white.withValues(alpha: 0.96),
              ),
            ),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.09),
                  width: 1.0,
                ),
              ),
            ),
            elevation: const WidgetStatePropertyAll(12),
            shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            ),
          ),
          menuChildren: animatedMenuChildren(
            context,
            widget.items.map((item) {
              final isSelected = item.value == widget.value;

              return MenuItemButton(
                style: ButtonStyle(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (isSelected) {
                      return scheme.primary.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      );
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return scheme.onSurface.withValues(
                        alpha: isDark ? 0.08 : 0.05,
                      );
                    }
                    return Colors.transparent;
                  }),
                ),
                leadingIcon: item.leading,
                trailingIcon: isSelected
                    ? Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: isDark ? 0.22 : 0.14,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      )
                    : item.trailing,
                onPressed: () {
                  if (widget.onChanged != null) {
                    widget.onChanged!(item.value);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : (item.isRecommended
                                      ? FontWeight.w600
                                      : FontWeight.w500),
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.tag != null || item.isRecommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(
                                alpha: isDark ? 0.20 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.tag ?? '推荐',
                              style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: isDark ? 0.80 : 0.90,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          builder: (context, controller, child) {
            Widget trigger = ValueListenableBuilder<bool>(
              valueListenable: _isOpenNotifier,
              builder: (context, isOpen, _) {
                final borderColor = isOpen
                    ? scheme.primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.09));

                final surfaceColor = isDark
                    ? scheme.surfaceContainerHighest.withValues(
                        alpha: isOpen ? 0.38 : 0.28,
                      )
                    : scheme.surfaceContainerHighest.withValues(
                        alpha: isOpen ? 0.58 : 0.48,
                      );

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: isOpen ? 1.5 : 1.0,
                    ),
                    boxShadow: isOpen
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(
                                alpha: isDark ? 0.16 : 0.08,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                      child: Padding(
                        padding: widget.contentPadding,
                        child: Row(
                          children: [
                            if (widget.prefixIcon != null) ...[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(
                                    alpha: isDark ? 0.16 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: IconTheme(
                                    data: IconThemeData(
                                      color: scheme.primary,
                                      size: 19,
                                    ),
                                    child: widget.prefixIcon!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.labelText != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2.0),
                                      child: Text(
                                        widget.labelText!,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isOpen
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant.withValues(
                                                  alpha: 0.85,
                                                ),
                                        ),
                                      ),
                                    ),
                                  if (selectedItem != null) ...[
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            selectedItem.label,
                                            style: TextStyle(
                                              fontSize: 14.0,
                                              fontWeight: selectedItem.isRecommended
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: scheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (selectedItem.tag != null ||
                                            selectedItem.isRecommended) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.primary.withValues(
                                                alpha: isDark ? 0.20 : 0.12,
                                              ),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: scheme.primary.withValues(
                                                  alpha: isDark ? 0.35 : 0.25,
                                                ),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              selectedItem.tag ?? '推荐',
                                              style: TextStyle(
                                                color: scheme.primary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (selectedItem.description != null &&
                                        selectedItem.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          selectedItem.description!,
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            color: scheme.onSurfaceVariant.withValues(
                                              alpha: isDark ? 0.82 : 0.90,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ] else
                                    Text(
                                      widget.hintText ?? '请选择',
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: scheme.onSurfaceVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: isOpen ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: Icon(
                                Symbols.keyboard_arrow_down_rounded,
                                size: 20,
                                color: isOpen
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );

            if (!constraints.maxWidth.isFinite) {
              trigger = SizedBox(width: anchorWidth, child: trigger);
            }

            return trigger;
          },
        );
      },
    );
  }
}
