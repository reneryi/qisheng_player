part of 'page.dart';

class NowPlayingMoreMenuAction extends StatelessWidget {
  const NowPlayingMoreMenuAction({super.key});

  @override
  Widget build(BuildContext context) {
    final playbackService = context.watch<PlaybackController>();
    final nowPlaying = playbackService.nowPlaying;
    final scheme = Theme.of(context).colorScheme;

    if (nowPlaying == null) {
      return IconButton(
        tooltip: '更多',
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
                final artist = AudioLibrary
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
            final album =
                AudioLibrary.instance.albumCollection[nowPlaying.album]!;
            context.pushReplacement(app_paths.ALBUM_DETAIL_PAGE, extra: album);
          },
          leadingIcon: const Icon(Symbols.album),
          child: const Text("专辑"),
        ),
        MenuItemButton(
          onPressed: () {
            context.pushReplacement(app_paths.AUDIO_DETAIL_PAGE, extra: nowPlaying);
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
        tooltip: '更多',
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

class NowPlayingDesktopLyricAction extends StatelessWidget {
  const NowPlayingDesktopLyricAction({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<DesktopLyricController>(
      builder: (context, desktopLyricService, _) {
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
