import 'dart:ui' show lerpDouble;

import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/responsive_builder.dart';

import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class SideNavTransitionScope extends InheritedWidget {
  const SideNavTransitionScope({
    super.key,
    required this.expansionProgress,
    required this.widthDelta,
    this.collapsing = false,
    required super.child,
  })  : assert(expansionProgress >= 0 && expansionProgress <= 1),
        assert(widthDelta >= 0);

  final double expansionProgress;
  final double widthDelta;
  final bool collapsing;

  static SideNavTransitionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SideNavTransitionScope>();
  }

  static SideNavTransitionScope? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<SideNavTransitionScope>();
  }

  @override
  bool updateShouldNotify(SideNavTransitionScope oldWidget) {
    return expansionProgress != oldWidget.expansionProgress ||
        widthDelta != oldWidget.widthDelta ||
        collapsing != oldWidget.collapsing;
  }
}

class DestinationDesc {
  const DestinationDesc(this.icon, this.label, this.desPath);

  final IconData icon;
  final String label;
  final String desPath;
}

const destinations = <DestinationDesc>[
  DestinationDesc(Symbols.library_music, '音乐', app_paths.AUDIOS_PAGE),
  DestinationDesc(Symbols.artist, '艺术家', app_paths.ARTISTS_PAGE),
  DestinationDesc(Symbols.album, '专辑', app_paths.ALBUMS_PAGE),
  DestinationDesc(Symbols.folder, '文件夹', app_paths.FOLDERS_PAGE),
  DestinationDesc(Symbols.list, '歌单', app_paths.PLAYLISTS_PAGE),
  DestinationDesc(Symbols.settings, '设置', app_paths.SETTINGS_PAGE),
];

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    this.collapsed = false,
    this.expansionProgress,
    this.onToggleCollapsed,
  });

  final bool collapsed;
  final double? expansionProgress;
  final ValueChanged<bool>? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selected = destinations.indexWhere(
      (desc) => location.startsWith(desc.desPath),
    );

    void onDestinationSelected(int value) {
      if (value == selected) return;

      context.go(destinations[value].desPath);

      final scaffold = Scaffold.maybeOf(context);
      if (scaffold?.hasDrawer ?? false) {
        scaffold?.closeDrawer();
      }
    }

    return ResponsiveBuilder(
      builder: (context, screenType) {
        switch (screenType) {
          case ScreenType.small:
            return Drawer(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _SideNavShell(
                    collapsed: false,
                    expansionProgress: 1,
                    selected: selected,
                    onDestinationSelected: onDestinationSelected,
                    onToggleCollapsed: null,
                  ),
                ),
              ),
            );
          case ScreenType.medium || ScreenType.large:
            final progress =
                (expansionProgress ?? (collapsed ? 0.0 : 1.0)).clamp(0.0, 1.0);
            return SizedBox(
              key: const ValueKey('side-nav-large'),
              width: lerpDouble(
                context.chrome.sideNavCollapsedWidth,
                context.chrome.sideNavExpandedWidth,
                progress,
              ),
              child: _SideNavShell(
                collapsed: collapsed,
                expansionProgress: progress,
                selected: selected,
                onDestinationSelected: onDestinationSelected,
                onToggleCollapsed: onToggleCollapsed,
              ),
            );
        }
      },
    );
  }
}

class _SideNavShell extends StatelessWidget {
  const _SideNavShell({
    required this.collapsed,
    required this.expansionProgress,
    required this.selected,
    required this.onDestinationSelected,
    required this.onToggleCollapsed,
  });

  final bool collapsed;
  final double expansionProgress;
  final int selected;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<bool>? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accents = context.accents;

    // 拆除外层胶囊背景，改为通透、纯透悬浮设计，只保留最外层的 SafeArea 与 Padding
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          8,
          24,
          8,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SideNavBrand(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    // 统一管理的物理连续滑行药丸胶囊与指示条：切换项时平滑上下滑行并产生丝滑柔和吸附
                    if (selected >= 0 && selected < destinations.length) ...[
                      // 背景滑动药丸
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                        left: 0,
                        right: 0,
                        top: selected * (48.0 + 6.0),
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      // 左侧吸附发光线
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                        left: 0,
                        top: selected * (48.0 + 6.0) + 15.0,
                        width: 3,
                        height: 18,
                        child: Container(
                          key: const ValueKey('side-nav-active-indicator'),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: accents.accent,
                            boxShadow: [
                              BoxShadow(
                                color: accents.accentGlow.withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Column(
                      children: [
                        for (int index = 0;
                            index < destinations.length;
                            index++) ...[
                          _SideNavItem(
                            collapsed: collapsed,
                            expansionProgress: expansionProgress,
                            selected: index == selected,
                            destination: destinations[index],
                            onTap: () => onDestinationSelected(index),
                          ),
                          const SizedBox(height: 6), // 间距
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onToggleCollapsed != null) ...[
              const SizedBox(height: 8),
              _SideNavItem(
                collapsed: true,
                expansionProgress: expansionProgress,
                centerIcon: true,
                selected: false,
                destination: DestinationDesc(
                  collapsed
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                  collapsed ? '展开侧栏' : '收起侧栏',
                  '',
                ),
                onTap: () => onToggleCollapsed!(!collapsed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SideNavBrand extends StatelessWidget {
  const _SideNavBrand();

  @override
  Widget build(BuildContext context) {
    final accents = context.accents;
    // 极简主义品牌标志：去掉金属光泽和复杂的渐变，仅保留一颗精致的呼吸图标
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.graphic_eq,
            color: accents.accent,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _MetalNavIcon extends StatelessWidget {
  const _MetalNavIcon({
    super.key,
    required this.icon,
    required this.selected,
    this.hovered = false,
  });

  final IconData icon;
  final bool selected;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final targetColor = selected
        ? accents.accent
        : (hovered
            ? scheme.onSurface
            : scheme.onSurface.withValues(alpha: 0.55));

    // 使用颜色补间实现选中与未选中、悬停时的丝滑柔和色彩呼吸过渡
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: ColorTween(end: targetColor),
      builder: (context, color, _) {
        return Icon(
          icon,
          size: 21,
          color: color,
        );
      },
    );
  }
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.collapsed,
    required this.expansionProgress,
    required this.selected,
    required this.destination,
    required this.onTap,
    this.centerIcon = false,
  });

  final bool collapsed;
  final double expansionProgress;
  final bool selected;
  final DestinationDesc destination;
  final VoidCallback onTap;
  final bool centerIcon;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final isDark = scheme.brightness == Brightness.dark;

    // 悬浮与选中色彩交互：选中项的背景由外层连续滑行药丸呈现，自身在非选中且悬浮时呈现微光高亮
    final highlightColor = (!widget.selected && (_hovered || _focused))
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035))
        : Colors.transparent;

    // 悬浮与选中文字颜色：平滑联动
    final targetTextColor = widget.selected
        ? accents.accent
        : (_hovered || _focused
            ? scheme.onSurface
            : scheme.onSurface.withValues(alpha: 0.72));

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          // 彻底去除悬停时的放大（scale 1.02 是导致文字亚像素颤动和边界抖动的元凶）
          // 仅在真实按下时给予极细腻自然的物理触觉微缩放（0.985）
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48, // 简洁干练的 48px 高度
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: highlightColor,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: FocusableActionDetector(
                onShowFocusHighlight: (value) {
                  if (_focused == value) return;
                  setState(() => _focused = value);
                },
                child: InkWell(
                  enableFeedback: false,
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onTap,
                  child: _SideNavItemContent(
                    expansionProgress: widget.expansionProgress,
                    selected: widget.selected,
                    hovered: _hovered || _focused,
                    icon: widget.destination.icon,
                    label: widget.destination.label,
                    iconKey: widget.destination.desPath,
                    centerIcon: widget.centerIcon,
                    textColor: targetTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.collapsed) return tile;
    return Tooltip(message: widget.destination.label, child: tile);
  }
}

class _SideNavItemContent extends StatelessWidget {
  const _SideNavItemContent({
    required this.expansionProgress,
    required this.selected,
    required this.icon,
    required this.label,
    required this.iconKey,
    required this.centerIcon,
    required this.textColor,
    this.hovered = false,
  });

  final double expansionProgress;
  final bool selected;
  final IconData icon;
  final String label;
  final String iconKey;
  final bool centerIcon;
  final Color textColor;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    if (centerIcon) {
      return Center(
        child: AnimatedSwitcher(
          duration: context.motion.microInteractionDuration,
          switchInCurve: context.motion.fast,
          switchOutCurve: context.motion.fast,
          child: _MetalNavIcon(
            key: ValueKey(icon),
            icon: icon,
            selected: selected,
            hovered: hovered,
          ),
        ),
      );
    }

    final labelOpacity = const Interval(0.15, 0.85).transform(
      expansionProgress.clamp(0.0, 1.0),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: _MetalNavIcon(
              key: ValueKey('side-nav-icon-$iconKey'),
              icon: icon,
              selected: selected,
              hovered: hovered,
            ),
          ),
        ),
        Positioned(
          left: 52,
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: labelOpacity < 0.98,
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    key: ValueKey('side-nav-label-$iconKey'),
                    opacity: labelOpacity,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
