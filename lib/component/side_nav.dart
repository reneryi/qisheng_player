import 'dart:ui' show lerpDouble;

import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/responsive_builder.dart';

import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

const _sideNavTransitionDuration = Duration(milliseconds: 280);
const _sideNavTransitionCurve = Curves.easeInOutCubic;

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
    this.onToggleCollapsed,
  });

  final bool collapsed;
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
                    selected: selected,
                    onDestinationSelected: onDestinationSelected,
                    onToggleCollapsed: null,
                  ),
                ),
              ),
            );
          case ScreenType.medium:
            return SizedBox(
              key: const ValueKey('side-nav-large'),
              width: context.chrome.sideNavCollapsedWidth,
              child: _SideNavShell(
                collapsed: true,
                selected: selected,
                onDestinationSelected: onDestinationSelected,
                onToggleCollapsed: null,
              ),
            );
          case ScreenType.large:
            return AnimatedContainer(
              key: const ValueKey('side-nav-large'),
              duration: _sideNavTransitionDuration,
              curve: _sideNavTransitionCurve,
              width: collapsed
                  ? context.chrome.sideNavCollapsedWidth
                  : context.chrome.sideNavExpandedWidth,
              child: _SideNavShell(
                collapsed: collapsed,
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
    required this.selected,
    required this.onDestinationSelected,
    required this.onToggleCollapsed,
  });

  final bool collapsed;
  final int selected;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<bool>? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    // 拆除外层胶囊背景，改为通透、纯透悬浮设计，只保留最外层的 SafeArea 与 Padding
    return SafeArea(
      bottom: false,
      child: AnimatedPadding(
        duration: _sideNavTransitionDuration,
        curve: _sideNavTransitionCurve,
        padding: EdgeInsets.fromLTRB(
          collapsed ? 8 : 12,
          24, // 增加顶部 Padding 使得整体布局更加优雅
          collapsed ? 8 : 12,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SideNavBrand(),
            SizedBox(height: collapsed ? 12 : 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int index = 0;
                        index < destinations.length;
                        index++) ...[
                      _SideNavItem(
                        collapsed: collapsed,
                        selected: index == selected,
                        destination: destinations[index],
                        onTap: () => onDestinationSelected(index),
                      ),
                      const SizedBox(height: 6), // 稍微缩小间距
                    ],
                  ],
                ),
              ),
            ),
            if (onToggleCollapsed != null) ...[
              const SizedBox(height: 8),
              _SideNavItem(
                collapsed: true,
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
    required this.icon,
    required this.selected,
    this.size = 21, // 调大至 21 像素以与新字号平衡
  });

  final IconData icon;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    // 极简图标设计：直接根据选中状态输出纯色，去除了渐变遮罩和大面积光晕
    return Icon(
      icon,
      size: size,
      color: selected
          ? accents.accent
          : scheme.onSurface.withValues(alpha: 0.52),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.collapsed,
    required this.selected,
    required this.destination,
    required this.onTap,
  });

  final bool collapsed;
  final bool selected;
  final DestinationDesc destination;
  final VoidCallback onTap;

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
    final motion = context.motion;
    final isDark = scheme.brightness == Brightness.dark;

    // 极简高亮逻辑：在无边框背景下，使用纯粹低饱和度的灰度背景色做悬浮与选中过渡
    final highlightColor = widget.selected
        ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))
        : (_hovered || _focused)
            ? (isDark ? Colors.white.withValues(alpha: 0.035) : Colors.black.withValues(alpha: 0.02))
            : Colors.transparent;

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
          scale: _pressed ? 0.985 : 1.0,
          duration: motion.microInteractionDuration,
          curve: motion.fast,
          child: AnimatedContainer(
            duration: _sideNavTransitionDuration,
            curve: _sideNavTransitionCurve,
            height: 48, // 从 58 调矮至 48，更加简洁干练
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // 更加挺拔的 12px 圆角
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
                  child: Stack(
                    children: [
                      // 极简侧边指示条：一条纤细的、无阴影的选中滑块
                      AnimatedPositioned(
                        duration: _sideNavTransitionDuration,
                        curve: _sideNavTransitionCurve,
                        left: 0,
                        top: widget.selected ? 15 : 24,
                        child: AnimatedContainer(
                          key: widget.selected
                              ? const ValueKey('side-nav-active-indicator')
                              : null,
                          duration: _sideNavTransitionDuration,
                          curve: _sideNavTransitionCurve,
                          width: 3,
                          height: widget.selected ? 18 : 0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: accents.accent,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: _SideNavItemContent(
                          collapsed: widget.collapsed,
                          selected: widget.selected,
                          icon: widget.destination.icon,
                          label: widget.destination.label,
                          textColor: widget.selected ? accents.accent : scheme.onSurface,
                        ),
                      ),
                    ],
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
    required this.collapsed,
    required this.selected,
    required this.icon,
    required this.label,
    required this.textColor,
  });

  final bool collapsed;
  final bool selected;
  final IconData icon;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 0 : 1),
      duration: _sideNavTransitionDuration,
      curve: _sideNavTransitionCurve,
      builder: (context, progress, _) {
        final resolvedProgress = Curves.easeOutCubic.transform(progress);
        final horizontalPadding = lerpDouble(10, 12, progress) ?? 12;
        final labelSlide = 8 * (1 - resolvedProgress);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.lerp(
                      Alignment.center,
                      Alignment.centerLeft,
                      resolvedProgress,
                    ) ??
                    Alignment.centerLeft,
                child: _MetalNavIcon(
                  icon: icon,
                  selected: selected,
                  size: 21, // 显式传参以修复 analyzer 警告
                ),
              ),
              IgnorePointer(
                ignoring: resolvedProgress < 0.98,
                child: ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: Offset(labelSlide, 0),
                        child: Opacity(
                          opacity: resolvedProgress,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
