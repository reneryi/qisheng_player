import 'dart:async';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';

import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/component/responsive_builder.dart';
import 'package:qisheng_player/component/side_nav.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
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
              titleBar: const SizedBox.shrink(), // 移除外层独立的顶栏
              overlay: null, // 移除外层独立的底栏
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
    // 窄屏模式下，重新启用带有毛玻璃的 CpSurface 面板，使主内容区域形成半透悬浮质感
    // 重构：将透明顶栏和底栏以垂直列排版装入面板中
    return CpSurface(
      tone: CpSurfaceTone.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          const TitleBar(transparent: true), // 嵌入透明顶栏
          const SizedBox(height: 12),
          Expanded(
            child: _ShellPageTransition(
              pageIdentity: pageIdentity,
              child: page,
            ),
          ),
          const SizedBox(height: 12),
          const BottomPlayerBar(transparent: true), // 嵌入透明底栏
        ],
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
        // 还原左右分栏间的 shellGap 空隙，产生呼吸感，突出悬浮效果
        SizedBox(width: chrome.shellGap),
        Expanded(
          // 还原主内容区域的 CpSurface 磨砂玻璃气泡框，悬浮于底色之上
          // 重构：将透明顶栏和底栏以垂直列的形式，整体包在右侧的 CpSurface 画板大卡片里
          child: CpSurface(
            tone: CpSurfaceTone.panel,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              children: [
                const TitleBar(transparent: true), // 嵌入透明顶栏
                const SizedBox(height: 12),
                Expanded(
                  child: _ShellPageTransition(
                     pageIdentity: pageIdentity,
                     child: page,
                  ),
                ),
                const SizedBox(height: 12),
                const BottomPlayerBar(transparent: true), // 嵌入透明底栏
              ],
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
        // 获取当前的横向滑入滑动方向（1 为自右向左，-1 为自左向右）
        final direction = AppNavigationState.instance.slideDirection;
        final offsetX = (1 - fade) * 20.0 * direction;
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            // 将原有的垂直位移变更为配合方向判定的水平横向滑入淡出
            offset: Offset(offsetX, 0),
            child: transitionedChild,
          ),
        );
      },
    );
  }
}
