import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

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

      context.push(destinations[value].desPath);

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
              duration: context.motion.navCollapseDuration,
              curve: context.motion.emphasized,
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
    return AppSurface(
      variant: AppSurfaceVariant.glass,
      glassDensity: AppSurfaceGlassDensity.low,
      radius: 24,
      padding: EdgeInsets.fromLTRB(
        collapsed ? 10 : 14,
        16,
        collapsed ? 10 : 14,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideNavBrand(collapsed: collapsed),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int index = 0; index < destinations.length; index++) ...[
                    _SideNavItem(
                      collapsed: collapsed,
                      selected: index == selected,
                      destination: destinations[index],
                      onTap: () => onDestinationSelected(index),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          if (onToggleCollapsed != null) ...[
            const SizedBox(height: 8),
            _SideNavItem(
              collapsed: collapsed,
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
    );
  }
}

class _SideNavBrand extends StatelessWidget {
  const _SideNavBrand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel = !collapsed && constraints.maxWidth >= 132;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment:
                showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (showLabel) const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                child: Icon(Symbols.graphic_eq, color: scheme.onSurface),
              ),
              if (showLabel) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coriander',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Local Music',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.58),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    final highlight = widget.selected
        ? accents.selectionTint.withValues(alpha: 0.9)
        : (_hovered || _focused)
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.transparent;

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: motion.navCollapseDuration,
        curve: motion.emphasized,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: highlight,
          border: Border.all(
            color: widget.selected
                ? accents.accent.withValues(alpha: 0.14)
                : _focused
                    ? accents.accentFocusRing.withValues(alpha: 0.28)
                    : Colors.transparent,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: FocusableActionDetector(
            onShowFocusHighlight: (value) {
              if (_focused == value) return;
              setState(() => _focused = value);
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: motion.navCollapseDuration,
                    curve: motion.emphasized,
                    left: 0,
                    top: widget.selected ? 16 : 28,
                    child: AnimatedContainer(
                      key: widget.selected
                          ? const ValueKey('side-nav-active-indicator')
                          : null,
                      duration: motion.navCollapseDuration,
                      curve: motion.emphasized,
                      width: 4,
                      height: widget.selected ? 24 : 0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: accents.accent,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showLabel =
                            !widget.collapsed && constraints.maxWidth >= 104;
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: showLabel ? 14 : 0,
                          ),
                          child: Row(
                            mainAxisAlignment: showLabel
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.destination.icon,
                                color: scheme.onSurface,
                              ),
                              if (showLabel) ...[
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    widget.destination.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: widget.selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
