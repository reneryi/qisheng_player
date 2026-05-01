import 'dart:async';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/component/responsive_builder.dart';
import 'package:qisheng_player/component/side_nav.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.page,
    required this.pageIdentity,
  });

  final Widget page;
  final String pageIdentity;

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
    return ValueListenableBuilder<int>(
      valueListenable: AudioLibrary.revision,
      builder: (context, _, __) => ResponsiveBuilder(
        builder: (context, screenType) {
          final useDrawer = screenType == ScreenType.small;
          return Scaffold(
            backgroundColor: Colors.transparent,
            drawer: useDrawer ? const SideNav() : null,
            drawerScrimColor: Theme.of(context).colorScheme.scrim,
            body: MainLayoutFrame(
              titleBar: const TitleBar(),
              overlay: const BottomPlayerBar(),
              child: switch (screenType) {
                ScreenType.small => _ShellPagePanel(
                    page: widget.page,
                    pageIdentity: widget.pageIdentity,
                  ),
                ScreenType.medium => _ShellWideContent(
                    page: widget.page,
                    pageIdentity: widget.pageIdentity,
                    sideNav: const SideNav(),
                  ),
                ScreenType.large => _ShellWideContent(
                    page: widget.page,
                    pageIdentity: widget.pageIdentity,
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
  const _ShellPagePanel({
    required this.page,
    required this.pageIdentity,
  });

  final Widget page;
  final String pageIdentity;

  @override
  Widget build(BuildContext context) {
    return CpSurface(
      tone: CpSurfaceTone.panel,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: _ShellPageTransition(
        pageIdentity: pageIdentity,
        child: page,
      ),
    );
  }
}

class _ShellWideContent extends StatelessWidget {
  const _ShellWideContent({
    required this.page,
    required this.pageIdentity,
    required this.sideNav,
  });

  final Widget page;
  final String pageIdentity;
  final Widget sideNav;

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sideNav,
        SizedBox(width: chrome.shellGap),
        Expanded(
          child: CpSurface(
            tone: CpSurfaceTone.panel,
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: _ShellPageTransition(
              pageIdentity: pageIdentity,
              child: page,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShellPageTransition extends StatelessWidget {
  const _ShellPageTransition({
    required this.pageIdentity,
    required this.child,
  });

  final String pageIdentity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return TweenAnimationBuilder<double>(
      key: ValueKey(pageIdentity),
      tween: Tween<double>(begin: 0, end: 1),
      duration: motion.pageTransitionDuration,
      curve: motion.emphasized,
      child: child,
      builder: (context, value, transitionedChild) {
        final fade = value.clamp(0.0, 1.0);
        final offsetY = (1 - fade) * 10;
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: transitionedChild,
          ),
        );
      },
    );
  }
}
