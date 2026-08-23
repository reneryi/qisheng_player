import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/animated_menu_content.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/utils.dart' as rust_utils;
import 'package:qisheng_player/utils.dart';

class AlbumContextMenu extends StatelessWidget {
  const AlbumContextMenu({
    super.key,
    required this.album,
    required this.builder,
  });

  final Album album;
  final MenuAnchorChildBuilder builder;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: animatedMenuChildren(
        context,
        buildAlbumContextMenuChildren(context, album: album),
      ),
      builder: builder,
    );
  }
}

List<Widget> buildAlbumContextMenuChildren(
  BuildContext context, {
  required Album album,
}) {
  final works = orderedAlbumWorks(album);
  return [
    MenuItemButton(
      onPressed: works.isEmpty
          ? null
          : () => PlayService.instance.playbackService.play(0, works),
      leadingIcon: const Icon(Symbols.play_arrow),
      child: const Text('播放专辑'),
    ),
    MenuItemButton(
      onPressed: works.isEmpty
          ? null
          : () {
              // addToNext 总是插入当前曲目之后，因此反向插入才能保留专辑顺序。
              final playback = PlayService.instance.playbackService;
              for (final audio in works.reversed) {
                playback.addToNext(audio);
              }
            },
      leadingIcon: const Icon(Symbols.plus_one),
      child: const Text('下一首播放'),
    ),
    MenuItemButton(
      onPressed: works.isEmpty
          ? null
          : () {
              final playback = PlayService.instance.playbackService;
              for (final audio in works) {
                playback.addToQueue(audio);
              }
              showTextOnSnackBar('已追加专辑「${album.name}」到队列');
            },
      leadingIcon: const Icon(Symbols.playlist_add),
      child: const Text('追加到队列'),
    ),
    SubmenuButton(
      menuChildren: [
        if (works.isEmpty || PLAYLISTS.isEmpty)
          MenuItemButton(
            onPressed: null,
            child: Text(works.isEmpty ? '暂无歌曲' : '暂无歌单'),
          )
        else
          ...PLAYLISTS.map(
            (playlist) => MenuItemButton(
              onPressed: () {
                var added = 0;
                for (final audio in works) {
                  if (playlist.addAudio(audio)) added++;
                }
                showTextOnSnackBar(
                  added == 0
                      ? '专辑歌曲已全部在歌单「${playlist.name}」中'
                      : '已添加 $added 首歌曲到歌单「${playlist.name}」',
                );
              },
              leadingIcon: const Icon(Symbols.queue_music),
              child: Text(playlist.name),
            ),
          ),
      ],
      child: const Text('添加到歌单'),
    ),
    MenuItemButton(
      onPressed: () => context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album),
      leadingIcon: const Icon(Symbols.album),
      child: const Text('查看专辑详情'),
    ),
    if (album.artistsMap.isNotEmpty)
      SubmenuButton(
        menuChildren: album.artistsMap.values
            .map(
              (artist) => MenuItemButton(
                onPressed: () => context.push(
                  app_paths.ARTIST_DETAIL_PAGE,
                  extra: artist,
                ),
                leadingIcon: const Icon(Symbols.artist),
                child: Text(artist.name),
              ),
            )
            .toList(),
        child: const Text('艺术家'),
      ),
    MenuItemButton(
      onPressed: works.isEmpty
          ? null
          : () async {
              final opened = await rust_utils.showInExplorer(
                path: works.first.mediaPath,
              );
              if (!opened) {
                showTextOnSnackBar('无法在资源管理器中定位专辑文件');
              }
            },
      leadingIcon: const Icon(Symbols.folder_open),
      child: const Text('定位首曲文件'),
    ),
  ];
}

List<Audio> orderedAlbumWorks(Album album) {
  return List<Audio>.from(album.works)
    ..sort((left, right) {
      final disc = left.disc.compareTo(right.disc);
      if (disc != 0) return disc;
      final track = left.track.compareTo(right.track);
      if (track != 0) return track;
      return left.displayTitle.compareTo(right.displayTitle);
    });
}
