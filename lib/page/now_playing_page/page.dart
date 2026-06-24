// ignore_for_file: camel_case_types, unused_element

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/component/ui/app_surface.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/component/window_drag_region.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:qisheng_player/page/now_playing_page/component/vertical_lyric_view.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

part 'small_page.dart';
part 'large_page.dart';
part 'component_views.dart';
part 'content_view.dart';
part 'top_actions.dart';

enum NowPlayingViewMode {
  onlyMain,
  withLyric,
  withPlaylist;

  static NowPlayingViewMode? fromString(String nowPlayingViewMode) {
    for (var value in NowPlayingViewMode.values) {
      if (value.name == nowPlayingViewMode) return value;
    }
    return null;
  }
}

final NOW_PLAYING_VIEW_MODE = ValueNotifier(
  AppPreference.instance.nowPlayingPagePref.nowPlayingViewMode,
);

class NowPlayingRouteTransitionScope
    extends InheritedNotifier<Animation<double>> {
  const NowPlayingRouteTransitionScope({
    super.key,
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NowPlayingRouteTransitionScope>()
        ?.notifier;
  }
}

Animation<double> _nowPlayingRouteStageAnimation(
  BuildContext context, {
  required double begin,
  required double end,
  Curve curve = Curves.easeOutCubic,
  Curve reverseCurve = Curves.easeInCubic,
}) {
  final routeAnimation = NowPlayingRouteTransitionScope.maybeOf(context);
  if (routeAnimation == null) {
    return const AlwaysStoppedAnimation(1);
  }
  return CurvedAnimation(
    parent: routeAnimation,
    curve: Interval(begin, end, curve: curve),
    reverseCurve: Interval(begin, end, curve: reverseCurve),
  );
}

class _NowPlayingStagedReveal extends StatelessWidget {
  const _NowPlayingStagedReveal({
    required this.begin,
    required this.end,
    required this.child,
    this.beginOffset = const Offset(0, 0.04),
    this.beginScale = 1.0,
  });

  final double begin;
  final double end;
  final Widget child;
  final Offset beginOffset;
  final double beginScale;

  @override
  Widget build(BuildContext context) {
    final routeAnimation = NowPlayingRouteTransitionScope.maybeOf(context);
    if (routeAnimation == null) return child;

    final staged = _nowPlayingRouteStageAnimation(
      context,
      begin: begin,
      end: end,
    );

    return FadeTransition(
      opacity: staged,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(staged),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: beginScale,
            end: 1,
          ).animate(staged),
          child: child,
        ),
      ),
    );
  }
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  @override
  void initState() {
    super.initState();
    // 页面初始化时，标记播放详情页处于活跃状态。使用 addPostFrameCallback 避开当前 build 周期调用 notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigationState.instance.setNowPlayingPageActive(true);
    });
  }

  @override
  void dispose() {
    // 页面销毁时，还原播放详情页活跃状态。同样使用 addPostFrameCallback 避开 build 周期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigationState.instance.setNowPlayingPageActive(false);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    NOW_PLAYING_VIEW_MODE.value =
        AppPreference.instance.nowPlayingPagePref.nowPlayingViewMode;
    return MainLayoutFrame(
      titleBar: const _NowPlayingAppBar(),
      overlay: const _AutoHideBottomPlayerBar(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1040 ||
              MediaQuery.sizeOf(context).height < 760;
          return compact
              ? const _NowPlayingPage_Small()
              : const _NowPlayingPage_Large();
        },
      ),
    );
  }
}

class _AutoHideBottomPlayerBar extends StatefulWidget {
  const _AutoHideBottomPlayerBar();

  @override
  State<_AutoHideBottomPlayerBar> createState() =>
      _AutoHideBottomPlayerBarState();
}

class _AutoHideBottomPlayerBarState extends State<_AutoHideBottomPlayerBar> {
  static const _hideDelay = Duration(seconds: 5);
  static const _entranceRevealThreshold = 0.82;

  Timer? _hideTimer;
  Animation<double>? _routeAnimation;
  bool _entranceCompleted = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  void _showAndKeepAlive() {
    if (!_entranceCompleted) return;
    if (!_visible) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  void _handleRouteAnimationTick() {
    final shouldReveal = _routeAnimation == null ||
        _routeAnimation!.value >= _entranceRevealThreshold;
    if (shouldReveal == _entranceCompleted) return;

    _entranceCompleted = shouldReveal;
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _visible = shouldReveal);
    if (shouldReveal) {
      _scheduleHide();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAnimation = NowPlayingRouteTransitionScope.maybeOf(context);
    if (!identical(nextAnimation, _routeAnimation)) {
      _routeAnimation?.removeListener(_handleRouteAnimationTick);
      _routeAnimation = nextAnimation;
      _routeAnimation?.addListener(_handleRouteAnimationTick);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleRouteAnimationTick();
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _routeAnimation?.removeListener(_handleRouteAnimationTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return SizedBox(
      height: context.chrome.dockHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: !_entranceCompleted,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _showAndKeepAlive,
              child: const SizedBox.expand(),
            ),
          ),
          IgnorePointer(
            ignoring: !_visible || !_entranceCompleted,
            child: Listener(
              onPointerDown: (_) => _showAndKeepAlive(),
              onPointerMove: (_) => _showAndKeepAlive(),
              onPointerSignal: (_) => _showAndKeepAlive(),
              child: MouseRegion(
                onEnter: (_) => _showAndKeepAlive(),
                onHover: (_) => _showAndKeepAlive(),
                child: AnimatedSlide(
                  duration: motion.panelTransitionDuration,
                  curve: motion.normal,
                  offset: _visible ? Offset.zero : const Offset(0, 0.24),
                  child: AnimatedOpacity(
                    duration: motion.controlTransitionDuration,
                    curve: motion.fast,
                    opacity: _visible ? 1 : 0,
                    child: const BottomPlayerBar(
                      transparent: true,
                      disableHero: true, // 在播放详情页内的控制栏禁用 Hero 动画，防止与中央大封面产生重复 Hero 标签冲突
                    ), // 传入 transparent: true，隐藏底栏毛玻璃背景
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingAppBar extends StatelessWidget {
  const _NowPlayingAppBar();

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    return _NowPlayingStagedReveal(
      begin: 0.12,
      end: 0.48,
      beginOffset: const Offset(0, -0.035),
      beginScale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // 替换 AppSurface 为 Padding，实现顶栏完全透明悬浮
        child: SizedBox(
          height: chrome.titleBarHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return const Row(
                children: [
                  _NowPlayingBackBtn(),
                  SizedBox(width: 10),
                  Expanded(
                    child: WindowDragRegion(
                      child: SizedBox.expand(),
                    ),
                  ),
                  SizedBox(width: 8),
                  NowPlayingMoreMenuAction(),
                  SizedBox(width: 8),
                  WindowControlls(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NowPlayingBackBtn extends StatelessWidget {
  const _NowPlayingBackBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      enableFeedback: false,
      tooltip: '返回',
      onPressed: () {
        final navigation = AppNavigationState.instance;
        navigation.closeNowPlaying(context,
            fallback: navigation.lastShellLocation);
      },
      icon: const Icon(Symbols.navigate_before),
      // 重构：定义沉浸式 Style，彻底移除默认状态及交互时的物理背景底色和描边
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        side: BorderSide.none,
        elevation: 0,
        shadowColor: Colors.transparent,
      ).copyWith(
        // 通过状态属性动态控制图标前景色透明度和高亮颜色，实现无背景圆底的交互效果
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.34);
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary; // 按下时高亮品牌色
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.onSurface; // 悬停时高亮至 100% 不透明
          }
          return scheme.onSurface.withValues(alpha: 0.62); // 默认显示为半透明
        }),
      ),
    );
  }
}

class _NowPlayingMoreAction extends StatelessWidget {
  const _NowPlayingMoreAction();

  @override
  Widget build(BuildContext context) {
    final playbackService = context.watch<PlaybackController>();
    final nowPlaying = playbackService.nowPlaying;
    final scheme = Theme.of(context).colorScheme;

    if (nowPlaying == null) {
      return IconButton(
        enableFeedback: false,
        tooltip: '更多操作',
        onPressed: null,
        icon: const Icon(Symbols.more_vert),
        color: scheme.onSecondaryContainer,
      );
    }

    return MenuAnchor(
      menuChildren: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () async {
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('新建歌单'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '歌单名称',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) => Navigator.pop(context, value),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text),
                        child: const Text('创建'),
                      ),
                    ],
                  ),
                );
                final trimmed = name?.trim();
                if (trimmed == null || trimmed.isEmpty) return;
                if (PLAYLISTS.any((item) => item.name == trimmed)) {
                  showTextOnSnackBar('歌单“$trimmed”已存在');
                  return;
                }
                final playlist = Playlist(trimmed, {});
                playlist.addAudio(nowPlaying);
                PLAYLISTS.add(playlist);
                scheduleSavePlaylists();
                showTextOnSnackBar('已创建歌单“$trimmed”并添加当前歌曲');
              },
              leadingIcon: const Icon(Symbols.add),
              child: const Text('新建歌单并添加'),
            ),
            if (PLAYLISTS.isEmpty)
              const MenuItemButton(
                onPressed: null,
                child: Text('暂无歌单'),
              )
            else
              ...List.generate(
                PLAYLISTS.length,
                (i) => MenuItemButton(
                  onPressed: () {
                    final added = PLAYLISTS[i].addAudio(nowPlaying);
                    if (!added) {
                      showTextOnSnackBar('歌曲“${nowPlaying.title}”已在歌单中');
                      return;
                    }
                    showTextOnSnackBar(
                      '已添加“${nowPlaying.title}”到歌单“${PLAYLISTS[i].name}”',
                    );
                  },
                  leadingIcon: const Icon(Symbols.queue_music),
                  child: Text(PLAYLISTS[i].name),
                ),
              ),
          ],
          leadingIcon: const Icon(Symbols.queue_music),
          child: const Text('添加到歌单'),
        ),
        SubmenuButton(
          menuChildren: List.generate(
            nowPlaying.splitedArtists.length,
            (i) => MenuItemButton(
              onPressed: () {
                final Artist artist = AudioLibrary
                    .instance.artistCollection[nowPlaying.splitedArtists[i]]!;
                context.pushReplacement(
                  app_paths.ARTIST_DETAIL_PAGE,
                  extra: artist,
                );
              },
              leadingIcon: const Icon(Symbols.people),
              child: Text(nowPlaying.splitedArtists[i]),
            ),
          ),
          child: const Text('艺术家'),
        ),
        MenuItemButton(
          onPressed: () {
            final Album album =
                AudioLibrary.instance.albumCollection[nowPlaying.album]!;
            context.pushReplacement(app_paths.ALBUM_DETAIL_PAGE, extra: album);
          },
          leadingIcon: const Icon(Symbols.album),
          child: Text(nowPlaying.album),
        ),
        MenuItemButton(
          onPressed: () {
            context.pushReplacement(app_paths.AUDIO_DETAIL_PAGE,
                extra: nowPlaying);
          },
          leadingIcon: const Icon(Symbols.info),
          child: const Text('歌曲详情'),
        ),
        MenuItemButton(
          onPressed: () async {
            if (nowPlaying.isCueTrack) {
              showTextOnSnackBar('CUE 分轨不支持直接删除，请删除源文件　');
              return;
            }
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('删除歌曲'),
                content: Text('确定要删除“${nowPlaying.title}”吗？该操作不可撤销。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirm != true) return;

            try {
              final file = File(nowPlaying.mediaPath);
              if (file.existsSync()) {
                await file.delete();
              }
              AudioLibrary.instance.removeAudioByPath(nowPlaying.path);
              OnlineCoverStore.instance.removeByPath(nowPlaying.path);
              removeAudioFromAllPlaylistsByPath(nowPlaying.path);
              playbackService.removeAudioFromPlaylistByPath(nowPlaying.path);
              showTextOnSnackBar('已删除“${nowPlaying.title}”');
            } catch (err) {
              showTextOnSnackBar('删除失败：$err');
            }
          },
          leadingIcon: const Icon(Symbols.delete),
          child: const Text('删除歌曲'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        enableFeedback: false,
        tooltip: '更多操作',
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Symbols.more_vert),
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _DesktopLyricSwitch extends StatelessWidget {
  const _DesktopLyricSwitch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<DesktopLyricController>(
      builder: (context, desktopLyricService, _) {
        return FutureBuilder(
          future: desktopLyricService.desktopLyric,
          builder: (context, snapshot) => IconButton(
            enableFeedback: false,
            tooltip: '桌面歌词${snapshot.data == null ? "已关闭" : "已开启"}',
            onPressed: !desktopLyricService.isStarting &&
                    snapshot.connectionState == ConnectionState.done
                ? snapshot.data == null
                    ? desktopLyricService.startDesktopLyric
                    : desktopLyricService.isLocked
                        ? desktopLyricService.sendUnlockMessage
                        : desktopLyricService.killDesktopLyric
                : null,
            icon: !desktopLyricService.isStarting &&
                    snapshot.connectionState == ConnectionState.done
                ? Icon(
                    desktopLyricService.isLocked ? Symbols.lock : Symbols.toast,
                    fill: snapshot.data == null ? 0 : 1,
                  )
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  ),
            color: scheme.onSecondaryContainer,
          ),
        );
      },
    );
  }
}

class _MarqueeText extends StatelessWidget {
  const _MarqueeText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  String _sanitizeText(String value) {
    final cleaned = value
        // 移除控制字符、BOM銆佹浛浠ｅ瓧绗︼紝閬垮厤婊氬姩鏂囨湰鍑虹幇寮傚父鍗犱綅鍥惧舰
        .replaceAll(
          RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\uFEFF\uFFFD]'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? " " : cleaned;
  }

  double _measureTextWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayText = _sanitizeText(text);
        if (!constraints.hasBoundedWidth) {
          return Text(displayText, maxLines: 1, style: style);
        }
        final textWidth = _measureTextWidth(context, displayText);
        final availableWidth = constraints.maxWidth;
        if (textWidth <= availableWidth) {
          return Text(displayText, maxLines: 1, style: style);
        }

        return _MarqueeTextScrollable(
          text: displayText,
          style: style,
          textWidth: textWidth,
          gap: 56.0,
          minDuration: const Duration(milliseconds: 4200),
        );
      },
    );
  }
}

class _MarqueeTextScrollable extends StatefulWidget {
  const _MarqueeTextScrollable({
    required this.text,
    required this.style,
    required this.textWidth,
    required this.gap,
    required this.minDuration,
  });

  final String text;
  final TextStyle style;
  final double textWidth;
  final double gap;
  final Duration minDuration;

  @override
  State<_MarqueeTextScrollable> createState() => _MarqueeTextScrollableState();
}

class _MarqueeTextScrollableState extends State<_MarqueeTextScrollable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Duration? _lastDuration;

  Duration _resolveDuration() {
    final distance = widget.textWidth + widget.gap;
    final bySpeed = Duration(milliseconds: (distance * 45).round());
    if (bySpeed > widget.minDuration) {
      return bySpeed;
    }
    return widget.minDuration;
  }

  void _ensureAnimation() {
    final duration = _resolveDuration();
    if (_lastDuration == duration && _controller.isAnimating) return;
    _lastDuration = duration;
    _controller
      ..duration = duration
      ..repeat();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _ensureAnimation();
  }

  @override
  void didUpdateWidget(covariant _MarqueeTextScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final distance = widget.textWidth + widget.gap;
          return Transform.translate(
            offset: Offset(-distance * _controller.value, 0),
            child: IgnorePointer(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.text, style: widget.style, maxLines: 1),
                    SizedBox(width: widget.gap),
                    Text(widget.text, style: widget.style, maxLines: 1),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
