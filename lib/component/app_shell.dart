import 'dart:async';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/bottom_player_bar.dart';
import 'package:coriander_player/component/cp/cp_components.dart';
import 'package:coriander_player/component/main_layout_frame.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/side_nav.dart';
import 'package:coriander_player/component/title_bar.dart';
import 'package:coriander_player/hotkeys_helper.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.page});

  final Widget page;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool largeSidebarCollapsed = AppPreference.instance.sidebarCollapsedLarge;

  void _toggleLargeSidebar(bool collapsed) {
    if (largeSidebarCollapsed == collapsed) return;
    setState(() {
      largeSidebarCollapsed = collapsed;
    });
    AppPreference.instance.sidebarCollapsedLarge = collapsed;
    unawaited(AppPreference.instance.save());
  }

  @override
  Widget build(BuildContext context) {
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    return Listener(
      onPointerDown: HotkeysHelper.handlePointerDown,
      child: ResponsiveBuilder(
        builder: (context, screenType) {
          final useDrawer = screenType == ScreenType.small;
          return Scaffold(
            backgroundColor: Colors.transparent,
            drawer: useDrawer ? const SideNav() : null,
            drawerScrimColor: Theme.of(context).colorScheme.scrim,
            body: MainLayoutFrame(
              titleBar: routeIsCurrent
                  ? TitleBar(
                      largeSidebarCollapsed: screenType == ScreenType.large &&
                          largeSidebarCollapsed,
                    )
                  : const SizedBox.shrink(),
              overlay: routeIsCurrent ? const BottomPlayerBar() : null,
              child: switch (screenType) {
                ScreenType.small => _ShellPagePanel(page: widget.page),
                ScreenType.medium => _ShellWideContent(
                    page: widget.page,
                    sideNav: const SideNav(),
                  ),
                ScreenType.large => _ShellWideContent(
                    page: widget.page,
                    sideNav: SideNav(
                      collapsed: largeSidebarCollapsed,
                      onToggleCollapsed: _toggleLargeSidebar,
                    ),
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _ShellPagePanel extends StatelessWidget {
  const _ShellPagePanel({required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return CpSurface(
      tone: CpSurfaceTone.panel,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: page,
    )
        .animate()
        .fadeIn(duration: motion.panelTransitionDuration, curve: motion.normal)
        .scale(
          begin: const Offset(0.996, 0.996),
          end: const Offset(1, 1),
          duration: motion.panelTransitionDuration,
          curve: motion.normal,
        );
  }
}

class _ShellWideContent extends StatelessWidget {
  const _ShellWideContent({
    required this.page,
    required this.sideNav,
  });

  final Widget page;
  final Widget sideNav;

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    final motion = context.motion;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sideNav
            .animate()
            .fadeIn(
                duration: motion.panelTransitionDuration, curve: motion.normal)
            .scale(
              begin: const Offset(0.996, 0.996),
              end: const Offset(1, 1),
              duration: motion.panelTransitionDuration,
              curve: motion.normal,
            ),
        SizedBox(width: chrome.shellGap),
        Expanded(
          child: CpSurface(
            tone: CpSurfaceTone.panel,
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: page,
          )
              .animate(delay: const Duration(milliseconds: 48))
              .fadeIn(
                  duration: motion.panelTransitionDuration,
                  curve: motion.normal)
              .scale(
                begin: const Offset(0.996, 0.996),
                end: const Offset(1, 1),
                duration: motion.panelTransitionDuration,
                curve: motion.normal,
              ),
        ),
      ],
    );
  }
}
