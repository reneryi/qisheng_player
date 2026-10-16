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
        enableFeedback: false,
        tooltip: '更多',
        onPressed: null,
        icon: const Icon(Symbols.more_vert),
        // 重构：定义沉浸式 Style，在不可用状态下同样彻底移除灰色圆底和描边边框
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          iconColor: WidgetStateProperty.resolveWith((states) {
            return scheme.onSurface.withValues(alpha: 0.34);
          }),
        ),
      );
    }

    return MenuAnchor(
      menuChildren: animatedMenuChildren(context, [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () async {
                final existingNames = PLAYLISTS.map((e) => e.name).toList();
                final name = await showModernDialog<String>(
                  context: context,
                  builder: (context) =>
                      NewPlaylistDialog(existingNames: existingNames),
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
                final artistName = nowPlaying.splitedArtists[i];
                final artist =
                    AudioLibrary.instance.artistCollection[artistName] ??
                        (Artist(name: artistName)..works.add(nowPlaying));
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
                AudioLibrary.instance.albumCollection[nowPlaying.albumKey] ??
                    (Album(name: nowPlaying.album)..works.add(nowPlaying));
            context.pushReplacement(app_paths.ALBUM_DETAIL_PAGE, extra: album);
          },
          leadingIcon: const Icon(Symbols.album),
          child: const Text("专辑"),
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
            final confirm = await showModernDialog<bool>(
              context: context,
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                final isDark = scheme.brightness == Brightness.dark;

                return ModernDialogFrame(
                  maxWidth: 400,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: scheme.error.withValues(alpha: isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scheme.error.withValues(alpha: isDark ? 0.35 : 0.22),
                                width: 1.0,
                              ),
                            ),
                            child: Icon(
                              Symbols.delete_forever_rounded,
                              color: scheme.error,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "删除歌曲",
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 17.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "此操作将永久删除本地音频源文件",
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: isDark ? 0.82 : 0.90,
                                    ),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: "关闭",
                            icon: Icon(
                              Symbols.close_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "确定删除“${nowPlaying.title}”？",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: isDark ? 0.28 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          nowPlaying.mediaPath,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("取消"),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Symbols.delete_rounded, size: 18),
                            label: const Text("永久删除"),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
            if (confirm != true) return;
            try {
              if (nowPlaying.isCueTrack) {
                showTextOnSnackBar("CUE 分轨不支持直接删除，请删除源文件。");
                return;
              }
              final file = File(nowPlaying.mediaPath);
              if (file.existsSync()) {
                await file.delete();
              }
              AudioLibrary.instance.removeAudioByPath(nowPlaying.path);
              removeLyricSourceByPath(nowPlaying.path);
              OnlineCoverStore.instance.removeByPath(nowPlaying.mediaPath);
              if (nowPlaying.path != nowPlaying.mediaPath) {
                OnlineCoverStore.instance.removeByPath(nowPlaying.path);
                removeLyricSourceByPath(nowPlaying.mediaPath);
              }
              removeAudioFromAllPlaylistsByPath(nowPlaying.path);
              playbackService.removeAudioFromPlaylistByPath(nowPlaying.path);
              showTextOnSnackBar("已删除“${nowPlaying.title}”");
            } catch (e) {
              showTextOnSnackBar("删除失败：$e");
            }
          },
          leadingIcon: Icon(Symbols.delete, color: scheme.error),
          child: Text("删除", style: TextStyle(color: scheme.error)),
        ),
      ]),
      builder: (context, controller, _) => IconButton(
        enableFeedback: false,
        tooltip: '更多',
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Symbols.more_vert),
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
      ),
    );
  }
}
