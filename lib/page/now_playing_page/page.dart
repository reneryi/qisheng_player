// ignore_for_file: camel_case_types, unused_element

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/bottom_player_bar.dart';
import 'package:coriander_player/component/main_layout_frame.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/component/title_bar.dart';
import 'package:coriander_player/utils.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/online_cover_store.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/navigation_state.dart';
import 'package:coriander_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:coriander_player/page/now_playing_page/component/vertical_lyric_view.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/play_service/desktop_lyric_service.dart';
import 'package:coriander_player/play_service/lyric_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

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

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    NOW_PLAYING_VIEW_MODE.value =
        AppPreference.instance.nowPlayingPagePref.nowPlayingViewMode;
    return MainLayoutFrame(
      titleBar: const _NowPlayingAppBar(),
      overlay: const BottomPlayerBar(),
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

class _NowPlayingAppBar extends StatelessWidget {
  const _NowPlayingAppBar();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      variant: AppSurfaceVariant.glass,
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scheme = Theme.of(context).colorScheme;

          return Row(
            children: [
              const _NowPlayingBackBtn(),
              const SizedBox(width: 10),
              Expanded(
                child: DragToMoveArea(
                  child: Selector<PlaybackController, Audio?>(
                    selector: (_, playbackService) =>
                        playbackService.nowPlaying,
                    builder: (context, nowPlaying, _) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nowPlaying?.title ?? 'Now Playing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nowPlaying == null
                                ? 'Coriander Player'
                                : '${nowPlaying.artist} - ${nowPlaying.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const NowPlayingDesktopLyricAction(),
              const SizedBox(width: 4),
              const NowPlayingMoreMenuAction(),
              const SizedBox(width: 8),
              const WindowControlls(),
            ],
          );
        },
      ),
    );
  }
}

class _NowPlayingBackBtn extends StatelessWidget {
  const _NowPlayingBackBtn();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: () {
        final fallback = AppNavigationState.instance.lastShellLocation;
        if (fallback.isNotEmpty && fallback != app_paths.NOW_PLAYING_PAGE) {
          context.go(fallback);
          return;
        }
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go(app_paths.AUDIOS_PAGE);
      },
      icon: const Icon(Symbols.navigate_before),
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
              showTextOnSnackBar('CUE 分轨不支持直接删除，请删除源文件。');
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
            tooltip: '桌面歌词：${snapshot.data == null ? '已关闭' : '已开启'}',
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
        // 移除控制字符、BOM、替代字符，避免滚动文本出现异常占位图形
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
