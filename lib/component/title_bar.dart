import 'dart:async';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/horizontal_lyric_view.dart';
import 'package:qisheng_player/component/responsive_builder.dart';
import 'package:qisheng_player/component/cp/cp_components.dart'; // 引入通用的 CpComponents 以支持沉浸式按钮
import 'package:qisheng_player/component/window_drag_region.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/search_page/search_page.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key, this.transparent = false});

  // 是否将背景透明化，用于在已有一体卡片内嵌套或者在沉浸页中悬浮时隐藏边框
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final childWidget = SizedBox(
          height: chrome.titleBarHeight,
          child: switch (screenType) {
            ScreenType.small => const _TitleBarSmall(),
            ScreenType.medium => const _TitleBarMedium(),
            ScreenType.large => const _TitleBarLarge(),
          },
        );

        // 沉浸式单层背景模式：直接去除外部的独立胶囊卡片框，让顶栏元素自然悬浮在流体背景顶部
        return Stack(
          children: [
            const Positioned.fill(
              child: AbsorbPointer(
                child: SizedBox.expand(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: childWidget,
            ),
          ],
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
    return WindowDragRegion(
      onDoubleTap: WindowControls.toggleMaximized,
      // 重构：移除原本 Container 的彩色背景与外发光阴影，将应用图标以极简纯粹的形式浮动显示
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Image.asset('app_icon.ico', width: 24, height: 24),
        ),
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
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();
  bool _expanded = false;
  UnionSearchResult? _liveResult;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
    _controller.addListener(_handleQueryChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    if (_focusNode.hasFocus) {
      unawaited(HotkeysHelper.onFocusChanges(false));
    }
    _focusNode.removeListener(_handleFocusChanged);
    _controller.removeListener(_handleQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (!isCtrl || isAlt || isShift) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyK ||
        event.logicalKey == LogicalKeyboardKey.keyF) {
      _toggleExpanded(true);
      return true;
    }
    return false;
  }

  void _handleFocusChanged() {
    unawaited(HotkeysHelper.onFocusChanges(_focusNode.hasFocus));
    _syncOverlayVisibility();
  }

  void _handleQueryChanged() {
    if (!mounted) return;
    final q = _controller.text.trim();
    if (q.isEmpty) {
      if (_liveResult != null) {
        setState(() => _liveResult = null);
      }
    } else {
      setState(() {
        _liveResult = UnionSearchResult.search(q);
      });
    }
    _syncOverlayVisibility();
  }

  void _syncOverlayVisibility() {
    if (!mounted) return;
    final shouldShow = _expanded &&
        _focusNode.hasFocus &&
        _controller.text.trim().isNotEmpty &&
        _liveResult != null;
    if (shouldShow && !_overlayController.isShowing) {
      _overlayController.show();
    } else if (!shouldShow && _overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  void _toggleExpanded(bool value) {
    if (_expanded == value) {
      if (value && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      return;
    }
    setState(() => _expanded = value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
          _syncOverlayVisibility();
        }
      });
    } else {
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
      _focusNode.unfocus();
    }
  }

  void _submitSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    context.push(
      app_paths.buildSearchResultLocation(query),
      extra: UnionSearchResult.search(query),
    );
  }

  Widget _buildLiveSuggestionsOverlay(BuildContext context) {
    final result = _liveResult;
    if (result == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final topAudios = result.audios.take(4).toList(growable: false);
    final topArtists = result.artists.take(2).toList(growable: false);
    final topAlbums = result.album.take(2).toList(growable: false);
    final hasAny =
        topAudios.isNotEmpty || topArtists.isNotEmpty || topAlbums.isNotEmpty;

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: const Offset(0, 44),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 380),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.96)
                  : scheme.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: !hasAny
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Text(
                      '未找到匹配“${result.query}”的曲目或歌手',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (topAudios.isNotEmpty) ...[
                          _SuggestionSectionHeader(
                            title: '单曲 (${result.audios.length})',
                          ),
                          for (final audio in topAudios)
                            _SuggestionRow(
                              icon: Symbols.music_note_rounded,
                              title: audio.title,
                              subtitle: '${audio.artist} · ${audio.album}',
                              onTap: () {
                                PlayService.instance.playbackService.play(
                                  0,
                                  [audio],
                                );
                                _toggleExpanded(false);
                              },
                            ),
                        ],
                        if (topArtists.isNotEmpty) ...[
                          _SuggestionSectionHeader(
                            title: '艺术家 (${result.artists.length})',
                          ),
                          for (final artist in topArtists)
                            _SuggestionRow(
                              icon: Symbols.person_rounded,
                              title: artist.name,
                              subtitle: '${artist.works.length} 首作品',
                              onTap: () {
                                _toggleExpanded(false);
                                context.push(
                                  app_paths.ARTIST_DETAIL_PAGE,
                                  extra: artist,
                                );
                              },
                            ),
                        ],
                        if (topAlbums.isNotEmpty) ...[
                          _SuggestionSectionHeader(
                            title: '专辑 (${result.album.length})',
                          ),
                          for (final album in topAlbums)
                            _SuggestionRow(
                              icon: Symbols.album_rounded,
                              title: album.name,
                              subtitle: '${album.works.length} 首作品',
                              onTap: () {
                                _toggleExpanded(false);
                                context.push(
                                  app_paths.ALBUM_DETAIL_PAGE,
                                  extra: album,
                                );
                              },
                            ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _submitSearch(result.query),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.search_rounded,
                                    size: 16,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '查看“${result.query}”的全部搜索结果 (Enter)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
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
            child: CompositedTransformTarget(
              link: _layerLink,
              child: OverlayPortal(
                controller: _overlayController,
                overlayChildBuilder: _buildLiveSuggestionsOverlay,
                child: AnimatedContainer(
                  duration: motion.searchExpandDuration,
                  curve: motion.emphasized,
                  width: _expanded ? 360 : 42,
                  child: _expanded
                      ? TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Symbols.search_rounded, size: 20),
                            suffixIcon: Semantics(
                              label: '关闭搜索',
                              button: true,
                              child: IconButton(
                                enableFeedback: false,
                                onPressed: () {
                                  _controller.clear();
                                  _toggleExpanded(false);
                                },
                                icon:
                                    const Icon(Symbols.close_rounded, size: 18),
                              ),
                            ),
                            hintText: '搜索歌曲、歌手、专辑 (支持拼音 / Ctrl+K)',
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
                            } else if (_overlayController.isShowing) {
                              _overlayController.hide();
                            }
                          },
                        )
                      : Semantics(
                          label: '搜索',
                          button: true,
                          child: IconButton(
                            enableFeedback: false,
                            onPressed: () => _toggleExpanded(true),
                            icon: Icon(
                              Symbols.search_rounded,
                              size: 20,
                              color: scheme.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                        ),
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
        Expanded(
          child: WindowDragRegion(
            onDoubleTap: WindowControls.toggleMaximized,
            child: AnimatedOpacity(
              duration: motion.controlTransitionDuration,
              curve: motion.normal,
              opacity: _expanded ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _expanded,
                child: const HorizontalLyricView(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionSectionHeader extends StatelessWidget {
  const _SuggestionSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        icon: const Icon(Symbols.side_navigation_rounded),
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
        final canPop = () {
          try {
            return context.canPop();
          } catch (_) {
            return false;
          }
        }();
        return CpIconButton(
          variant: CpButtonVariant.immersive,
          semanticsLabel: '返回',
          onPressed: canPop || navigation.canGoBack
              ? () => navigation.navigateBack(context, fallback: '')
              : null,
          icon: const Icon(Symbols.navigate_before_rounded),
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
        // 重构：使用沉浸式按钮变体 CpIconButton(variant: CpButtonVariant.immersive)
        return CpIconButton(
          variant: CpButtonVariant.immersive,
          semanticsLabel: '前进',
          onPressed: navigation.canGoForward
              ? () => navigation.navigateForward(context)
              : null,
          icon: const Icon(Symbols.navigate_next_rounded),
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
  final GlobalKey _maximizeButtonKey = GlobalKey();
  Rect? _lastReportedRect;
  double? _lastReportedDpr;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WindowControls.layoutMode.addListener(_onLayoutModeChanged);
    _updateWindowStates();
  }

  void _onLayoutModeChanged() {
    if (!mounted) return;
    final mode = WindowControls.layoutMode.value;
    setState(() {
      _isFullScreen = mode == WindowLayoutMode.fullscreen;
      _isMaximized = mode == WindowLayoutMode.maximized;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportMaximizeButtonRect();
    });
  }

  void _reportMaximizeButtonRect() {
    if (!mounted) return;
    final renderBox =
        _maximizeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final currentRect =
          Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
      if (_lastReportedRect != null &&
          _lastReportedDpr != null &&
          (_lastReportedDpr! - dpr).abs() < 0.001 &&
          (_lastReportedRect!.left - currentRect.left).abs() < 0.5 &&
          (_lastReportedRect!.top - currentRect.top).abs() < 0.5 &&
          (_lastReportedRect!.width - currentRect.width).abs() < 0.5 &&
          (_lastReportedRect!.height - currentRect.height).abs() < 0.5) {
        return;
      }
      _lastReportedRect = currentRect;
      _lastReportedDpr = dpr;
      unawaited(WindowControls.setMaximizeButtonRect(
        left: offset.dx,
        top: offset.dy,
        width: size.width,
        height: size.height,
        devicePixelRatio: dpr,
      ));
    } else {
      if (_lastReportedRect != Rect.zero) {
        _lastReportedRect = Rect.zero;
        _lastReportedDpr = 1.0;
        unawaited(WindowControls.setMaximizeButtonRect(
          left: 0,
          top: 0,
          width: 0,
          height: 0,
          devicePixelRatio: 1.0,
        ));
      }
    }
  }

  Future<void> _updateWindowStates() async {
    final isFullScreen = await WindowControls.isFullScreen();
    final isMaximized = await WindowControls.isMaximized();
    if (mounted) {
      setState(() {
        _isFullScreen = isFullScreen;
        _isMaximized = isMaximized;
        _isProcessing = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reportMaximizeButtonRect();
      });
    }
  }

  Future<void> _toggleFullScreen() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await WindowControls.toggleFullscreen();
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
      await WindowControls.toggleMaximized();
    } finally {
      if (mounted) {
        await _updateWindowStates();
      }
    }
  }

  @override
  void dispose() {
    WindowControls.layoutMode.removeListener(_onLayoutModeChanged);
    windowManager.removeListener(this);
    unawaited(WindowControls.setMaximizeButtonRect(
      left: 0,
      top: 0,
      width: 0,
      height: 0,
      devicePixelRatio: 1.0,
    ));
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    _updateWindowStates();
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  void onWindowUnmaximize() {
    _updateWindowStates();
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  void onWindowRestore() {
    _updateWindowStates();
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  void onWindowEnterFullScreen() {
    super.onWindowEnterFullScreen();
    _updateWindowStates();
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  void onWindowLeaveFullScreen() {
    super.onWindowLeaveFullScreen();
    _updateWindowStates();
    AppSettings.instance.scheduleSaveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportMaximizeButtonRect();
    });
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          semanticsLabel: _isFullScreen ? '退出全屏' : '全屏',
          onPressed: _isProcessing ? null : _toggleFullScreen,
          icon: _isFullScreen
              ? Symbols.close_fullscreen_rounded
              : Symbols.open_in_full_rounded,
        ),
        const _WindowButton(
          semanticsLabel: '最小化',
          onPressed: WindowControls.minimize,
          icon: Symbols.remove_rounded,
        ),
        _WindowButton(
          key: _maximizeButtonKey,
          semanticsLabel: _isFullScreen ? '全屏模式下不可用' : (_isMaximized ? '还原' : '最大化'),
          onPressed: _isFullScreen || _isProcessing ? null : _toggleMaximized,
          icon: _isMaximized
              ? Symbols.fullscreen_exit_rounded
              : Symbols.fullscreen_rounded,
        ),
        _WindowButton(
          semanticsLabel: '退出',
          // 点击关闭按钮时最小化到系统托盘，不中断播放
          onPressed: () => unawaited(WindowControls.close()),
          icon: Symbols.close_rounded,
          color: scheme.error,
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  final String semanticsLabel;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final defaultColor = color ?? scheme.onSurface;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: IconButton(
        enableFeedback: false,
        tooltip: null,
        onPressed: onPressed,
        icon: Icon(icon),
        // 重构：定义完全沉浸式的 ButtonStyle，消除默认与交互时的所有物理底色及描边边框
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          // 通过状态属性动态控制图标前景色透明度和高亮颜色，实现无圆底纯色悬停效果
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return defaultColor.withValues(alpha: 0.34);
            }
            if (states.contains(WidgetState.pressed)) {
              return color ??
                  scheme.primary; // 按下时非退出按钮显示强调色，退出按钮显示原色（如 error 红色）
            }
            if (states.contains(WidgetState.hovered)) {
              return defaultColor; // 悬停状态下图标呈现完全不透明高亮
            }
            return defaultColor.withValues(alpha: 0.62); // 默认状态显示为 62% 不透明度的半透明图标
          }),
        ),
      ),
    );
  }
}
