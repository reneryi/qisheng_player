import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

class ExpandableSearchAction extends StatefulWidget {
  const ExpandableSearchAction({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<ExpandableSearchAction> createState() => _ExpandableSearchActionState();
}

class _ExpandableSearchActionState extends State<ExpandableSearchAction> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  bool expanded = false;

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded(bool value) {
    if (expanded == value) return;
    setState(() {
      expanded = value;
    });
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    } else {
      focusNode.unfocus();
    }
  }

  void _clearAndCollapse() {
    controller.clear();
    widget.onChanged('');
    _toggleExpanded(false);
  }

  double _expandedWidth(ScreenType screenType, AppChromeTokens chrome) {
    return switch (screenType) {
      ScreenType.small => MediaQuery.sizeOf(context).width - 104,
      ScreenType.medium => chrome.searchBarExpandedWidthMedium,
      ScreenType.large => chrome.searchBarExpandedWidthLarge,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = context.chrome;
    final motion = context.motion;
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final targetWidth =
            expanded ? _expandedWidth(screenType, chrome) : 48.0;

        return AnimatedContainer(
          duration: motion.searchExpandDuration,
          curve: motion.emphasized,
          width: targetWidth,
          child: AppSurface(
            variant:
                expanded ? AppSurfaceVariant.inset : AppSurfaceVariant.raised,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
              },
              child: Actions(
                actions: {
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      _clearAndCollapse();
                      return null;
                    },
                  ),
                },
                child: AnimatedSwitcher(
                  duration: motion.searchExpandDuration,
                  switchInCurve: motion.emphasized,
                  switchOutCurve: motion.fast,
                  child: expanded
                      ? LayoutBuilder(
                          key: const ValueKey('expanded-search'),
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 80) {
                              return Align(
                                alignment: Alignment.center,
                                child: IconButton(
                                  tooltip: '关闭搜索',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: controller.text.isEmpty
                                      ? () => _toggleExpanded(false)
                                      : _clearAndCollapse,
                                  icon: Icon(
                                    controller.text.isEmpty
                                        ? Symbols.close
                                        : Symbols.close_small,
                                    size: 18,
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.72),
                                  ),
                                ),
                              );
                            }

                            final compact = constraints.maxWidth < 120;

                            return Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: compact ? 4 : 8,
                                    right: compact ? 4 : 10,
                                  ),
                                  child: const Icon(Symbols.search),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText:
                                          compact ? null : widget.hintText,
                                      border: InputBorder.none,
                                      filled: false,
                                      isDense: compact,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onTapOutside: (_) {
                                      if (controller.text.isEmpty) {
                                        _toggleExpanded(false);
                                      }
                                    },
                                    onChanged: (value) {
                                      setState(() {});
                                      widget.onChanged(value);
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: '清空搜索',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints.tightFor(
                                    width: compact ? 36 : 44,
                                    height: compact ? 36 : 44,
                                  ),
                                  visualDensity: compact
                                      ? VisualDensity.compact
                                      : VisualDensity.standard,
                                  onPressed: controller.text.isEmpty
                                      ? () => _toggleExpanded(false)
                                      : _clearAndCollapse,
                                  icon: Icon(
                                    controller.text.isEmpty
                                        ? Symbols.close
                                        : Symbols.close_small,
                                    size: compact ? 18 : 24,
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.72),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : Center(
                          key: const ValueKey('collapsed-search'),
                          child: IconButton(
                            tooltip: '搜索当前页面',
                            onPressed: () => _toggleExpanded(true),
                            icon: const Icon(Symbols.search),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
