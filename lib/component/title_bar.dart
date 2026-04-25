import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/horizontal_lyric_view.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    this.largeSidebarCollapsed = false,
  });

  final bool largeSidebarCollapsed;

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        chrome.shellGap,
        12,
        chrome.shellGap,
        0,
      ),
      child: ResponsiveBuilder(
        builder: (context, screenType) {
          return AppSurface(
            variant: AppSurfaceVariant.glass,
            radius: context.surfaces.radiusXxl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: chrome.titleBarHeight,
              child: switch (screenType) {
                ScreenType.small => const _TitleBarSmall(),
                ScreenType.medium => const _TitleBarMedium(),
                ScreenType.large => _TitleBarLarge(
                    largeSidebarCollapsed: largeSidebarCollapsed,
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _TitleBarSmall extends StatelessWidget {
  const _TitleBarSmall();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const _OpenDrawerBtn(),
        const SizedBox(width: 4),
        const NavBackBtn(),
        Expanded(
          child: DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Coriander Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const WindowControlls(),
      ],
    );
  }
}

class _TitleBarMedium extends StatelessWidget {
  const _TitleBarMedium();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const NavBackBtn(),
        const SizedBox(width: 8),
        SizedBox(
          width: 180,
          child: DragToMoveArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Coriander Player',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: DragToMoveArea(
            child: HorizontalLyricView(),
          ),
        ),
        const SizedBox(width: 12),
        const WindowControlls(),
      ],
    );
  }
}

class _TitleBarLarge extends StatelessWidget {
  const _TitleBarLarge({required this.largeSidebarCollapsed});

  final bool largeSidebarCollapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = context.chrome;
    return Row(
      children: [
        const NavBackBtn(),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: context.motion.navCollapseDuration,
          curve: context.motion.emphasized,
          width: largeSidebarCollapsed
              ? chrome.sideNavCollapsedWidth - 12
              : chrome.sideNavExpandedWidth - 12,
          child: DragToMoveArea(
            child: Row(
              children: [
                Image.asset('app_icon.ico', width: 26, height: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Coriander Player',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: DragToMoveArea(
            child: HorizontalLyricView(),
          ),
        ),
        const SizedBox(width: 12),
        const WindowControlls(),
      ],
    );
  }
}

class _OpenDrawerBtn extends StatelessWidget {
  const _OpenDrawerBtn();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => IconButton(
        tooltip: '打开导航栏',
        onPressed: () => Scaffold.of(context).openDrawer(),
        icon: const Icon(Symbols.side_navigation),
      ),
    );
  }
}

class NavBackBtn extends StatelessWidget {
  const NavBackBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: context.canPop() ? () => context.pop() : null,
      icon: const Icon(Symbols.navigate_before),
    );
  }
}

class WindowControlls extends StatefulWidget {
  const WindowControlls({super.key});

  @override
  State<WindowControlls> createState() => _WindowControllsState();
}

class _WindowControllsState extends State<WindowControlls> with WindowListener {
  bool _isFullScreen = false;
  bool _isMaximized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateWindowStates();
  }

  Future<void> _updateWindowStates() async {
    final isFullScreen = await windowManager.isFullScreen();
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isFullScreen = isFullScreen;
        _isMaximized = isMaximized;
        _isProcessing = false;
      });
    }
  }

  Future<void> _toggleFullScreen() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await windowManager.setFullScreen(!_isFullScreen);
    } finally {
      if (mounted) {
        await _updateWindowStates();
      }
    }
  }

  Future<void> _toggleMaximized() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } finally {
      if (mounted) {
        await _updateWindowStates();
      }
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    _updateWindowStates();
    AppSettings.instance.saveSettings();
  }

  @override
  void onWindowUnmaximize() {
    _updateWindowStates();
    AppSettings.instance.saveSettings();
  }

  @override
  void onWindowRestore() {
    _updateWindowStates();
    AppSettings.instance.saveSettings();
  }

  @override
  void onWindowEnterFullScreen() {
    super.onWindowEnterFullScreen();
    _updateWindowStates();
    AppSettings.instance.saveSettings();
  }

  @override
  void onWindowLeaveFullScreen() {
    super.onWindowLeaveFullScreen();
    _updateWindowStates();
    AppSettings.instance.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      variant: AppSurfaceVariant.inset,
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowButton(
            tooltip: _isFullScreen ? '退出全屏' : '全屏',
            onPressed: _isProcessing ? null : _toggleFullScreen,
            icon:
                _isFullScreen ? Symbols.close_fullscreen : Symbols.open_in_full,
          ),
          _WindowButton(
            tooltip: '最小化',
            onPressed: windowManager.minimize,
            icon: Symbols.remove,
          ),
          _WindowButton(
            tooltip: _isFullScreen ? '全屏模式下不可用' : (_isMaximized ? '还原' : '最大化'),
            onPressed: _isFullScreen || _isProcessing ? null : _toggleMaximized,
            icon: _isMaximized ? Symbols.fullscreen_exit : Symbols.fullscreen,
          ),
          _WindowButton(
            tooltip: '退出',
            onPressed: () => windowManager.close(),
            icon: Symbols.close,
            color: scheme.error,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );
  }
}
