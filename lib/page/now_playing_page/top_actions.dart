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
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
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
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("删除"),
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
              final file = File(nowPlaying.mediaPath);
              if (file.existsSync()) {
                await file.delete();
              }
              AudioLibrary.instance.removeAudioByPath(nowPlaying.path);
              OnlineCoverStore.instance.removeByPath(nowPlaying.mediaPath);
              if (nowPlaying.path != nowPlaying.mediaPath) {
                OnlineCoverStore.instance.removeByPath(nowPlaying.path);
              }
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
      ]),
      builder: (context, controller, _) => SpringScaleFeedback(
        child: IconButton(
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
          // 重构：定义沉浸式 Style，彻底消除默认和交互时的灰色圆底及描边，保持悬浮在流光背景上的纯净度
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            elevation: 0,
            shadowColor: Colors.transparent,
          ).copyWith(
            // 通过 WidgetStateProperty 动态管理不同状态下的图标颜色和透明度，以实现纯粹基于颜色的交互反馈
            iconColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return scheme.onSurface.withValues(alpha: 0.34);
              }
              if (states.contains(WidgetState.pressed)) {
                return scheme.primary; // 按下时高亮品牌色
              }
              if (states.contains(WidgetState.hovered)) {
                return scheme.onSurface; // 悬停时图标完全高亮
              }
              return scheme.onSurface.withValues(alpha: 0.62); // 默认状态显示为半透明
            }),
          ),
        ),
      ),
    );
  }
}
