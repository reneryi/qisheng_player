import 'dart:async';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/horizontal_lyric_view.dart';
import 'package:qisheng_player/component/responsive_builder.dart';
import 'package:qisheng_player/component/ui/app_surface.dart';
import 'package:qisheng_player/component/window_drag_region.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/search_page/search_page.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return AppSurface(
          variant: AppSurfaceVariant.glass,
          radius: context.surfaces.radiusXxl,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: SizedBox(
            height: chrome.titleBarHeight,
            child: switch (screenType) {
              ScreenType.small => const _TitleBarSmall(),
              ScreenType.medium => const _TitleBarMedium(),
              ScreenType.large => const _TitleBarLarge(),
            },
          ),
        );
      },
    );
  }
}

class _TitleBarSmall extends StatelessWidget {
  const _TitleBarSmall();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _OpenDrawerBtn(),
        SizedBox(width: 6),
        _TitleNavCluster(showLogo: false),
        SizedBox(width: 8),
        Expanded(child: _TitleLyricPill()),
        SizedBox(width: 8),
        WindowControlls(),
      ],
    );
  }
}

class _TitleBarMedium extends StatelessWidget {
  const _TitleBarMedium();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _TitleNavCluster(),
        SizedBox(width: 12),
        Expanded(child: _TitleLyricPill()),
        SizedBox(width: 12),
        WindowControlls(),
      ],
    );
  }
}

class _TitleBarLarge extends StatelessWidget {
  const _TitleBarLarge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _TitleNavCluster(),
        SizedBox(width: 14),
        Expanded(child: _TitleLyricPill()),
        SizedBox(width: 12),
        WindowControlls(),
      ],
    );
  }
}

class _TitleNavCluster extends StatelessWidget {
  const _TitleNavCluster({this.showLogo = true});

  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NavBackBtn(),
        const NavForwardBtn(),
        if (showLogo) ...[
          const SizedBox(width: 8),
          const _TitleLogo(),
        ],
      ],
    );
  }
}

class _TitleLogo extends StatelessWidget {
  const _TitleLogo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return WindowDragRegion(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.14),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: -3,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Image.asset('app_icon.ico', width: 24, height: 24),
      ),
    );
  }
}

class _TitleLyricPill extends StatefulWidget {
  const _TitleLyricPill();

  @override
  State<_TitleLyricPill> createState() => _TitleLyricPillState();
}

class _TitleLyricPillState extends State<_TitleLyricPill> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    if (_focusNode.hasFocus) {
      unawaited(HotkeysHelper.onFocusChanges(false));
    }
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    unawaited(HotkeysHelper.onFocusChanges(_focusNode.hasFocus));
  }

  void _toggleExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    } else {
      _focusNode.unfocus();
    }
  }

  void _submitSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    context.push(
      app_paths.buildSearchResultLocation(query),
      extra: UnionSearchResult.search(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    return Row(
      children: [
        Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _controller.clear();
                  _toggleExpanded(false);
                  return null;
                },
              ),
            },
            child: AnimatedContainer(
              duration: motion.searchExpandDuration,
              curve: motion.emphasized,
              width: _expanded ? 360 : 42,
              child: _expanded
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Symbols.search, size: 20),
                        suffixIcon: IconButton(
                          enableFeedback: false,
                          tooltip: '关闭搜索',
                          onPressed: () {
                            _controller.clear();
                            _toggleExpanded(false);
                          },
                          icon: const Icon(Symbols.close, size: 18),
                        ),
                        hintText: '搜索歌曲、艺术家、专辑',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 11),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submitSearch,
                      onTapOutside: (_) {
                        if (_controller.text.trim().isEmpty) {
                          _toggleExpanded(false);
                        }
                      },
                    )
                  : IconButton(
                      enableFeedback: false,
                      tooltip: '搜索',
                      onPressed: () => _toggleExpanded(true),
                      icon: Icon(
                        Symbols.search,
                        size: 20,
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: motion.searchExpandDuration,
          curve: motion.emphasized,
          width: _expanded ? 14 : 8,
        ),
        const Expanded(
          child: WindowDragRegion(
            child: HorizontalLyricView(),
          ),
        ),
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
        enableFeedback: false,
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
    final navigation = AppNavigationState.instance;
    return ListenableBuilder(
      listenable: navigation,
      builder: (context, _) {
        return IconButton(
          enableFeedback: false,
          tooltip: '返回',
          onPressed: context.canPop() || navigation.canGoBack
              ? () => navigation.navigateBack(context, fallback: '')
              : null,
          icon: const Icon(Symbols.navigate_before),
        );
      },
    );
  }
}

class NavForwardBtn extends StatelessWidget {
  const NavForwardBtn({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = AppNavigationState.instance;
    return ListenableBuilder(
      listenable: navigation,
      builder: (context, _) {
        return IconButton(
          enableFeedback: false,
          tooltip: '前进',
          onPressed: navigation.canGoForward
              ? () => navigation.navigateForward(context)
              : null,
          icon: const Icon(Symbols.navigate_next),
        );
      },
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          tooltip: _isFullScreen ? '退出全屏' : '全屏',
          onPressed: _isProcessing ? null : _toggleFullScreen,
          icon: _isFullScreen ? Symbols.close_fullscreen : Symbols.open_in_full,
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
      enableFeedback: false,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );
  }
}
