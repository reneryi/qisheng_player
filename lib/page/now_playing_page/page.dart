// ignore_for_file: camel_case_types

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/title_bar.dart';
import 'package:coriander_player/utils.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/online_cover_store.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:coriander_player/page/now_playing_page/component/filled_icon_button_style.dart';
import 'package:coriander_player/page/now_playing_page/component/vertical_lyric_view.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

part 'small_page.dart';
part 'large_page.dart';

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
final NOW_PLAYING_CONTROLS_VISIBLE = ValueNotifier(true);

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final playbackService = PlayService.instance.playbackService;
  ImageProvider<Object>? nowPlayingCover;
  Timer? _hideControlsTimer;

  void updateCover() {
    playbackService.nowPlaying?.cover.then((cover) {
      if (mounted) {
        setState(() {
          nowPlayingCover = cover;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    playbackService.addListener(updateCover);
    updateCover();
    _onUserInteracted();
  }

  void _onUserInteracted() {
    NOW_PLAYING_CONTROLS_VISIBLE.value = true;
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      NOW_PLAYING_CONTROLS_VISIBLE.value = false;
    });
  }

  @override
  void dispose() {
    playbackService.removeListener(updateCover);
    _hideControlsTimer?.cancel();
    NOW_PLAYING_CONTROLS_VISIBLE.value = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56.0),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              NavBackBtn(),
              Expanded(child: DragToMoveArea(child: SizedBox.expand())),
              WindowControlls(),
            ],
          ),
        ),
      ),
      backgroundColor: scheme.secondaryContainer,
      body: Stack(
        fit: StackFit.expand,
        alignment: AlignmentDirectional.center,
        children: [
          if (nowPlayingCover != null) ...[
            Image(
              image: nowPlayingCover!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            switch (brightness) {
              Brightness.dark => const ColoredBox(color: Colors.black45),
              Brightness.light => const ColoredBox(color: Colors.white54),
            },
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 250, sigmaY: 250),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ],
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _onUserInteracted(),
            onPointerMove: (_) => _onUserInteracted(),
            child: ChangeNotifierProvider.value(
              value: PlayService.instance.playbackService,
              builder: (context, _) {
                return ResponsiveBuilder2(builder: (context, screenType) {
                  switch (screenType) {
                    case ScreenType.small:
                      return const _NowPlayingPage_Small();
                    case ScreenType.medium:
                    case ScreenType.large:
                      return const _NowPlayingPage_Large();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExclusiveModeSwitch extends StatelessWidget {
  const _ExclusiveModeSwitch();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: PlayService.instance.playbackService.wasapiExclusive,
      builder: (context, exclusive, _) => IconButton(
        tooltip: "独占模式；现在：${exclusive ? "启用" : "禁用"}",
        onPressed: () {
          PlayService.instance.playbackService.useExclusiveMode(!exclusive);
        },
        icon: Center(
          child: Text(
            exclusive ? "Excl" : "Shrd",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingMoreAction extends StatelessWidget {
  const _NowPlayingMoreAction();

  @override
  Widget build(BuildContext context) {
    final playbackService = context.watch<PlaybackService>();
    final nowPlaying = playbackService.nowPlaying;
    final scheme = Theme.of(context).colorScheme;

    if (nowPlaying == null) {
      return IconButton(
        tooltip: "更多",
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
                    title: const Text("新建歌单"),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: "歌单名称",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        Navigator.pop(context, value);
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("取消"),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context, controller.text);
                        },
                        child: const Text("创建"),
                      ),
                    ],
                  ),
                );
                final trimmed = name?.trim();
                if (trimmed == null || trimmed.isEmpty) return;
                if (PLAYLISTS.any((item) => item.name == trimmed)) {
                  showTextOnSnackBar("歌单“$trimmed”已存在");
                  return;
                }
                final playlist = Playlist(trimmed, {});
                playlist.addAudio(nowPlaying);
                PLAYLISTS.add(playlist);
                scheduleSavePlaylists();
                showTextOnSnackBar("已创建歌单“$trimmed”并添加当前歌曲");
              },
              leadingIcon: const Icon(Symbols.add),
              child: const Text("新建歌单并添加"),
            ),
            if (PLAYLISTS.isEmpty)
              const MenuItemButton(
                onPressed: null,
                child: Text("暂无歌单"),
              )
            else
              ...List.generate(
                PLAYLISTS.length,
                (i) => MenuItemButton(
                  onPressed: () {
                    final added = PLAYLISTS[i].addAudio(nowPlaying);
                    if (!added) {
                      showTextOnSnackBar("歌曲“${nowPlaying.title}”已在歌单中");
                      return;
                    }
                    showTextOnSnackBar(
                      "已添加“${nowPlaying.title}”到歌单“${PLAYLISTS[i].name}”",
                    );
                  },
                  leadingIcon: const Icon(Symbols.queue_music),
                  child: Text(PLAYLISTS[i].name),
                ),
              ),
          ],
          leadingIcon: const Icon(Symbols.queue_music),
          child: const Text("添加到歌单"),
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
          child: const Text("艺术家"),
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
          child: const Text("详细信息"),
        ),
        MenuItemButton(
          onPressed: () async {
            if (nowPlaying.isCueTrack) {
              showTextOnSnackBar("CUE 分轨不支持直接删除，请删除源文件。");
              return;
            }
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("删除歌曲"),
                content: Text("确定删除“${nowPlaying.title}”？该操作会删除本地文件。"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("取消"),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("删除"),
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
              showTextOnSnackBar("已删除“${nowPlaying.title}”");
            } catch (err) {
              showTextOnSnackBar("删除失败：$err");
            }
          },
          leadingIcon: const Icon(Symbols.delete),
          child: const Text("删除歌曲"),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: "更多",
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
    return ListenableBuilder(
      listenable: PlayService.instance.desktopLyricService,
      builder: (context, _) {
        final desktopLyricService = PlayService.instance.desktopLyricService;
        return FutureBuilder(
          future: desktopLyricService.desktopLyric,
          builder: (context, snapshot) => IconButton(
            tooltip: "桌面歌词；现在：${snapshot.data == null ? "禁用" : "启用"}",
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

class _NowPlayingVolDspSlider extends StatefulWidget {
  const _NowPlayingVolDspSlider();

  @override
  State<_NowPlayingVolDspSlider> createState() =>
      _NowPlayingVolDspSliderState();
}

class _NowPlayingVolDspSliderState extends State<_NowPlayingVolDspSlider> {
  final playbackService = PlayService.instance.playbackService;
  final dragVolDsp = ValueNotifier(
    AppPreference.instance.playbackPref.volumeDsp,
  );
  bool isDragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      menuChildren: [
        SliderTheme(
          data: const SliderThemeData(
            showValueIndicator: ShowValueIndicator.onDrag,
          ),
          child: ValueListenableBuilder(
            valueListenable: dragVolDsp,
            builder: (context, dragVolDspValue, _) => Slider(
              thumbColor: scheme.primary,
              activeColor: scheme.primary,
              inactiveColor: scheme.outline,
              min: 0.0,
              max: 1.0,
              value: isDragging ? dragVolDspValue : playbackService.volumeDsp,
              label: "${(dragVolDspValue * 100).toInt()}",
              onChangeStart: (value) {
                isDragging = true;
                dragVolDsp.value = value;
                playbackService.setVolumeDsp(value);
              },
              onChanged: (value) {
                dragVolDsp.value = value;
                playbackService.setVolumeDsp(value);
              },
              onChangeEnd: (value) {
                isDragging = false;
                dragVolDsp.value = value;
                playbackService.setVolumeDsp(value);
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: "音量",
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Symbols.volume_up),
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _NowPlayingPlayModeSwitch extends StatelessWidget {
  const _NowPlayingPlayModeSwitch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return ValueListenableBuilder(
      valueListenable: playbackService.playMode,
      builder: (context, playMode, _) {
        late IconData result;
        if (playMode == PlayMode.forward) {
          result = Symbols.repeat;
        } else if (playMode == PlayMode.loop) {
          result = Symbols.repeat_on;
        } else {
          result = Symbols.repeat_one_on;
        }

        return IconButton(
          tooltip: "播放模式；现在：${switch (playMode) {
            PlayMode.forward => "顺序播放",
            PlayMode.loop => "列表循环",
            PlayMode.singleLoop => "单曲循环",
          }}",
          onPressed: () {
            if (playMode == PlayMode.forward) {
              playbackService.setPlayMode(PlayMode.loop);
            } else if (playMode == PlayMode.loop) {
              playbackService.setPlayMode(PlayMode.singleLoop);
            } else {
              playbackService.setPlayMode(PlayMode.forward);
            }
          },
          icon: Icon(result),
          color: scheme.onSecondaryContainer,
        );
      },
    );
  }
}

class _NowPlayingShuffleSwitch extends StatelessWidget {
  const _NowPlayingShuffleSwitch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return ValueListenableBuilder(
      valueListenable: playbackService.shuffle,
      builder: (context, shuffle, _) => IconButton(
        tooltip: "随机；现在：${shuffle ? "启用" : "禁用"}",
        onPressed: () {
          playbackService.useShuffle(!shuffle);
        },
        icon: Icon(shuffle ? Symbols.shuffle_on : Symbols.shuffle),
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

/// previous audio, pause/resume, next audio
class _NowPlayingMainControls extends StatelessWidget {
  const _NowPlayingMainControls();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: "上一曲",
          onPressed: playbackService.lastAudio,
          icon: const Icon(Symbols.skip_previous),
          style: LargeFilledIconButtonStyle(primary: false, scheme: scheme),
        ),
        const SizedBox(width: 16),
        StreamBuilder(
          stream: playbackService.playerStateStream,
          initialData: playbackService.playerState,
          builder: (context, snapshot) {
            final playerState = snapshot.data!;
            late void Function() onTap;
            if (playerState == PlayerState.playing) {
              onTap = playbackService.pause;
            } else if (playerState == PlayerState.completed) {
              onTap = playbackService.playAgain;
            } else {
              onTap = playbackService.start;
            }

            return IconButton(
              tooltip: playerState == PlayerState.playing ? "暂停" : "播放",
              onPressed: onTap,
              icon: Icon(
                playerState == PlayerState.playing
                    ? Symbols.pause
                    : Symbols.play_arrow,
              ),
              style: LargeFilledIconButtonStyle(primary: true, scheme: scheme),
            );
          },
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: "下一曲",
          onPressed: playbackService.nextAudio,
          icon: const Icon(Symbols.skip_next),
          style: LargeFilledIconButtonStyle(primary: false, scheme: scheme),
        ),
      ],
    );
  }
}

/// suiggly slider, position and length
class _NowPlayingSlider extends StatefulWidget {
  const _NowPlayingSlider();

  @override
  State<_NowPlayingSlider> createState() => _NowPlayingSliderState();
}

class _NowPlayingSliderState extends State<_NowPlayingSlider> {
  final dragPosition = ValueNotifier(0.0);
  bool isDragging = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = context.watch<PlaybackService>();
    final nowPlayingLength = playbackService.length;

    return Column(
      children: [
        SliderTheme(
          data: const SliderThemeData(
            showValueIndicator: ShowValueIndicator.onDrag,
          ),
          child: StreamBuilder(
            stream: playbackService.playerStateStream,
            initialData: playbackService.playerState,
            builder: (context, playerStateSnapshot) => ListenableBuilder(
              listenable: dragPosition,
              builder: (context, _) => StreamBuilder(
                stream: playbackService.positionStream,
                initialData: playbackService.position,
                builder: (context, positionSnapshot) => Slider(
                  thumbColor: scheme.primary,
                  activeColor: scheme.primary,
                  inactiveColor: scheme.outline,
                  min: 0.0,
                  max: nowPlayingLength,
                  value: isDragging
                      ? dragPosition.value
                      : positionSnapshot.data! > nowPlayingLength
                          ? nowPlayingLength
                          : positionSnapshot.data!,
                  label: Duration(
                    milliseconds: (dragPosition.value * 1000).toInt(),
                  ).toStringHMMSS(),
                  onChangeStart: (value) {
                    isDragging = true;
                    dragPosition.value = value;
                  },
                  onChanged: (value) {
                    dragPosition.value = value;
                  },
                  onChangeEnd: (value) {
                    isDragging = false;
                    playbackService.seek(value);
                  },
                ),
                // builder: (context, positionSnapshot) => SquigglySlider(
                //   thumbColor: scheme.primary,
                //   activeColor: scheme.primary,
                //   inactiveColor: scheme.outline,
                //   useLineThumb: true,
                //   squiggleAmplitude:
                //       playerStateSnapshot.data == PlayerState.playing ? 6.0 : 0,
                //   squiggleWavelength: 10.0,
                //   squiggleSpeed: 0.08,
                //   min: 0.0,
                //   max: nowPlayingLength,
                //   value: isDragging
                //       ? dragPosition.value
                //       : positionSnapshot.data! > nowPlayingLength
                //           ? nowPlayingLength
                //           : positionSnapshot.data!,
                //   label: Duration(
                //     milliseconds: (dragPosition.value * 1000).toInt(),
                //   ).toStringHMMSS(),
                //   onChangeStart: (value) {
                //     isDragging = true;
                //     dragPosition.value = value;
                //   },
                //   onChanged: (value) {
                //     dragPosition.value = value;
                //   },
                //   onChangeEnd: (value) {
                //     isDragging = false;
                //     playbackService.seek(value);
                //   },
                // ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder(
                stream: playbackService.positionStream,
                initialData: playbackService.position,
                builder: (context, snapshot) {
                  final pos = snapshot.data!;
                  return Text(
                    Duration(
                      milliseconds: (pos * 1000).toInt(),
                    ).toStringHMMSS(),
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  );
                },
              ),
              Text(
                Duration(
                  milliseconds: (nowPlayingLength * 1000).toInt(),
                ).toStringHMMSS(),
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ],
          ),
        )
      ],
    );
  }
}

/// title, artist, album, cover
class _NowPlayingInfo extends StatefulWidget {
  const _NowPlayingInfo();

  @override
  State<_NowPlayingInfo> createState() => __NowPlayingInfoState();
}

class __NowPlayingInfoState extends State<_NowPlayingInfo> {
  final playbackService = PlayService.instance.playbackService;
  Future<ImageProvider<Object>?>? nowPlayingCover;

  void updateCover() {
    setState(() {
      nowPlayingCover = playbackService.nowPlaying?.largeCover;
    });
  }

  @override
  void initState() {
    super.initState();
    playbackService.addListener(updateCover);
    nowPlayingCover = playbackService.nowPlaying?.largeCover;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nowPlaying = playbackService.nowPlaying;

    final placeholder = FittedBox(
      child: Icon(
        Symbols.broken_image,
        size: 400.0,
        color: scheme.onSecondaryContainer,
      ),
    );

    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );

    return Center(
      child: SizedBox(
        width: 400.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MarqueeText(
              text: nowPlaying == null ? "Coriander Music" : nowPlaying.title,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            _MarqueeText(
              text: nowPlaying == null
                  ? "Enjoy Music"
                  : "${nowPlaying.artist} - ${nowPlaying.album}",
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            if (nowPlaying != null)
              Text(
                nowPlaying.qualitySummary,
                style: TextStyle(
                  color: scheme.onSecondaryContainer.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  child: nowPlayingCover == null
                      ? placeholder
                      : FutureBuilder(
                          future: nowPlayingCover,
                          builder: (context, snapshot) =>
                              switch (snapshot.connectionState) {
                            ConnectionState.done => snapshot.data == null
                                ? placeholder
                                : FittedBox(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image(
                                        image: snapshot.data!,
                                        width: 400.0,
                                        height: 400.0,
                                        errorBuilder: (_, __, ___) =>
                                            placeholder,
                                      ),
                                    ),
                                  ),
                            _ => loadingWidget,
                          },
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    playbackService.removeListener(updateCover);
    super.dispose();
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
