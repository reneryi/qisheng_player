import 'dart:async';
import 'dart:math' as math;

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';

import 'package:qisheng_player/component/main_layout_frame.dart';
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

  /// 保留该参数以兼容需要标识当前 Shell 路由的调用方。
  /// 现在由路由页面自身负责转场，不再围绕嵌套 Navigator 驱动第二套动画。
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
                  ),
                ScreenType.medium || ScreenType.large => _ShellWideContent(
                    page: widget.page,
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
  });

  final Widget page;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final motion = context.motion;
    final isCardMode = surfaces.pagePanelAlpha > 0.0;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && focus.hasFocus) {
            focus.unfocus();
          }
        },
        child: AnimatedContainer(
          duration: motion.controlTransitionDuration,
          curve: motion.emphasized,
          decoration: BoxDecoration(
            color: isCardMode
                ? surfaces.surfaceRaised.withValues(alpha: surfaces.panelAlpha)
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(isCardMode ? surfaces.radiusXl : 0),
            border: isCardMode
                ? Border.all(
                    color: surfaces.strokeSubtle
                        .withValues(alpha: isDark ? 0.35 : 0.45),
                    width: 0.5,
                  )
                : null,
            boxShadow: isCardMode
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(isCardMode ? surfaces.radiusXl : 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: page,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellWideContent extends StatelessWidget {
  const _ShellWideContent({
    required this.page,
    required this.sideNavAnimation,
    required this.sideNavCollapsed,
    required this.onToggleCollapsed,
  });

  final Widget page;
  final Animation<double> sideNavAnimation;
  final bool sideNavCollapsed;
  final ValueChanged<bool> onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final widthDelta = context.chrome.sideNavExpandedWidth -
        context.chrome.sideNavCollapsedWidth;
    // 页面主内容区域保持 100% 通透悬浮
    final pageContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: page,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && focus.hasFocus) {
            focus.unfocus();
          }
        },
        child: ValueListenableBuilder<WindowLayoutMode>(
          valueListenable: WindowControls.layoutMode,
          builder: (context, _, __) => AnimatedBuilder(
            animation: sideNavAnimation,
            child: pageContent,
            builder: (context, child) {
              final progress = sideNavAnimation.value;
              final resolvedSideNav = SideNav(
                collapsed: sideNavCollapsed,
                expansionProgress: progress,
                onToggleCollapsed: onToggleCollapsed,
              );
              final resolvedPanel = SideNavTransitionScope(
                expansionProgress: progress,
                widthDelta: widthDelta,
                collapsing: sideNavCollapsed,
                child: child!,
              );
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
        ),
      ),
    );
  }
}
