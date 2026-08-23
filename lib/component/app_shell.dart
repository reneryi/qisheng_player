import 'dart:async';
import 'dart:math' as math;

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';

import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/component/responsive_builder.dart';
import 'package:qisheng_player/component/side_nav.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/window_controls.dart';
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

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  bool largeSidebarCollapsed = AppPreference.instance.sidebarCollapsedLarge;
  late final AnimationController _largeSidebarController;

  @override
  void initState() {
    super.initState();
    _largeSidebarController = AnimationController(
      vsync: this,
      value: largeSidebarCollapsed ? 0 : 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _largeSidebarController.duration = context.motion.navCollapseDuration;
  }

  void _toggleLargeSidebar(bool collapsed) {
    if (largeSidebarCollapsed == collapsed) return;
    setState(() {
      largeSidebarCollapsed = collapsed;
    });
    _animateLargeSidebar(collapsed ? 0.0 : 1.0);
    AppPreference.instance.sidebarCollapsedLarge = collapsed;
    unawaited(AppPreference.instance.save());
  }

  void _animateLargeSidebar(double target) {
    final current = _largeSidebarController.value;
    final distance = (target - current).abs().clamp(0.0, 1.0).toDouble();
    if (distance == 0) return;

    // Animate the visual progress itself. Applying the themed curve to the
    // segment (instead of transforming a value that is later reversed) keeps
    // collapsing responsive at the beginning and soft at the end.
    final baseDuration = context.motion.navCollapseDuration;
    final duration = Duration(
      microseconds: math.max(
        1,
        (baseDuration.inMicroseconds * distance).round(),
      ),
    );
    final curve =
        target < current ? Curves.easeInOutCubic : context.motion.emphasized;
    _largeSidebarController.animateTo(
      target,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void dispose() {
    _largeSidebarController.dispose();
    super.dispose();
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
              // 采用经典稳定的桌面架构：顶部 TitleBar 和底部 BottomPlayerBar 作为全局通栏
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
                    sideNavAnimation: _largeSidebarController,
                    sideNavCollapsed: largeSidebarCollapsed,
                    onToggleCollapsed: _toggleLargeSidebar,
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
    // 窄屏模式下直接呈现页面内容，去除多层卡片背景包裹
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    this.sideNav,
    this.sideNavAnimation,
    this.sideNavCollapsed,
    this.onToggleCollapsed,
  });

  final Widget page;
  final String pageIdentity;
  final Widget? sideNav;
  final Animation<double>? sideNavAnimation;
  final bool? sideNavCollapsed;
  final ValueChanged<bool>? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final isAnimated = sideNavAnimation != null;
    final widthDelta = isAnimated
        ? context.chrome.sideNavExpandedWidth -
            context.chrome.sideNavCollapsedWidth
        : 0.0;
    // 宽屏模式下主页面内容直接平铺在底层单层背景上，彻底消除多层胶囊框与背景割裂
    final pageContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _ShellPageTransition(
        pageIdentity: pageIdentity,
        child: page,
      ),
    );

    return ValueListenableBuilder<WindowLayoutMode>(
      valueListenable: WindowControls.layoutMode,
      builder: (context, _, __) => AnimatedBuilder(
        animation: sideNavAnimation ?? kAlwaysCompleteAnimation,
        child: pageContent,
        builder: (context, child) {
          final progress = isAnimated ? sideNavAnimation!.value : 0.0;
          final resolvedSideNav = isAnimated
              ? SideNav(
                  collapsed: sideNavCollapsed!,
                  expansionProgress: progress,
                  onToggleCollapsed: onToggleCollapsed,
                )
              : sideNav!;
          final resolvedPanel = isAnimated
              ? SideNavTransitionScope(
                  expansionProgress: progress,
                  widthDelta: widthDelta,
                  collapsing: sideNavCollapsed!,
                  child: child!,
                )
              : child!;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              resolvedSideNav,
              const SizedBox(width: 8.0),
              Expanded(child: resolvedPanel),
            ],
          );
        },
      ),
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
