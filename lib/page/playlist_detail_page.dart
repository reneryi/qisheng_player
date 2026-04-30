import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final multiSelectController = MultiSelectController<Audio>();
  late List<Audio> contentList;

  @override
  void initState() {
    super.initState();
    AppPreference.instance.playlistDetailPagePref.sortMethod = 0;
    contentList = widget.playlist.audios.values.toList();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist != widget.playlist) {
      contentList = widget.playlist.audios.values.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return UniPage<Audio>(
      pref: AppPreference.instance.playlistDetailPagePref,
      title: widget.playlist.name,
      subtitle: formatMusicCount(contentList.length),
      contentList: contentList,
      contentBuilder: (context, item, i, multiSelectController) => AudioTile(
        audioIndex: i,
        playlist: contentList,
        multiSelectController: multiSelectController,
      ),
      enableShufflePlay: true,
      enableSortMethod: true,
      enableSortOrder: true,
      enableContentViewSwitch: true,
      multiSelectController: multiSelectController,
      multiSelectViewActions: [
        IconButton.filled(
          tooltip: "移除选中歌曲",
          onPressed: () {
            setState(() {
              for (var item in multiSelectController.selected) {
                widget.playlist.removeAudioByPath(item.path);
                contentList.removeWhere((audio) => audio.path == item.path);
              }
              widget.playlist.applyCustomOrder(contentList);
            });
            multiSelectController.useMultiSelectView(false);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(scheme.error),
            foregroundColor: WidgetStatePropertyAll(scheme.onError),
          ),
          icon: const Icon(Symbols.delete),
        ),
        _MoveSelectionToPlaylistAction(
          currentPlaylist: widget.playlist,
          multiSelectController: multiSelectController,
          contentList: contentList,
        ),
        MultiSelectSelectOrClearAll(
          multiSelectController: multiSelectController,
          contentList: contentList,
        ),
        MultiSelectExit(multiSelectController: multiSelectController),
      ],
      sortMethods: [
        SortMethodDesc(
          icon: Symbols.drag_indicator,
          name: "自定义顺序",
          method: (list, order) {},
        ),
        SortMethodDesc(
          icon: Symbols.title,
          name: "标题",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.title.localeCompareTo(b.title));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.title.localeCompareTo(a.title));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.artist,
          name: "艺术家",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.artist.localeCompareTo(b.artist));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.artist.localeCompareTo(a.artist));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.album,
          name: "专辑",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.album.localeCompareTo(b.album));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.album.localeCompareTo(a.album));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.add,
          name: "创建时间",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.created.compareTo(b.created));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.created.compareTo(a.created));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.edit,
          name: "修改时间",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.modified.compareTo(b.modified));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.modified.compareTo(a.modified));
                break;
            }
          },
        ),
      ],
      onReorder: (list, oldIndex, newIndex) {
        final moved = list.removeAt(oldIndex);
        list.insert(newIndex, moved);
        widget.playlist.applyCustomOrder(list);
      },
      enableReorder: (_) =>
          AppPreference.instance.playlistDetailPagePref.sortMethod == 0,
    );
  }
}

class _MoveSelectionToPlaylistAction extends StatelessWidget {
  const _MoveSelectionToPlaylistAction({
    required this.currentPlaylist,
    required this.multiSelectController,
    required this.contentList,
  });

  final Playlist currentPlaylist;
  final MultiSelectController<Audio> multiSelectController;
  final List<Audio> contentList;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: PLAYLISTS
          .where((item) => item != currentPlaylist)
          .map(
            (targetPlaylist) => MenuItemButton(
              onPressed: () {
                if (multiSelectController.selected.isEmpty) return;
                for (final audio in multiSelectController.selected) {
                  targetPlaylist.addAudio(audio);
                  currentPlaylist.removeAudioByPath(audio.path);
                  contentList.removeWhere((item) => item.path == audio.path);
                }
                currentPlaylist.applyCustomOrder(contentList);
                showTextOnSnackBar(
                  "已移动 ${multiSelectController.selected.length} 首到“${targetPlaylist.name}”",
                );
                multiSelectController.useMultiSelectView(false);
              },
              child: Text(targetPlaylist.name),
            ),
          )
          .toList(),
      builder: (context, controller, _) => IconButton.filledTonal(
        tooltip: "移动到歌单",
        onPressed: PLAYLISTS.length <= 1
            ? null
            : () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
        icon: const Icon(Symbols.drive_file_move),
      ),
    );
  }
}
