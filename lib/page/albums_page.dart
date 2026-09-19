import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/album_grid_tile.dart';
import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/batch_artwork_match_dialog.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AlbumsPage extends StatelessWidget {
  const AlbumsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final contentList = AudioLibrary.instance.albumCollection.values.toList();
    return UniPage<Album>(
      pref: AppPreference.instance.albumsPagePref,
      title: "专辑",
      subtitle: "${contentList.length} 张专辑",
      contentList: contentList,
      contentRevision: AudioLibrary.revision.value,
      contentBuilder: (context, item, i, multiSelectController) =>
          AlbumTile(
            album: item,
            enableHero: true,
            selected: multiSelectController?.selected.contains(item) ?? false,
            multiSelectController: multiSelectController,
          ),
      gridBuilder: (context, item, i, multiSelectController) => AlbumGridTile(
        album: item,
        enableHero: true,
      ),
      primaryAction: FilledButton.tonalIcon(
        icon: const Icon(Symbols.auto_awesome_rounded, size: 18),
        label: const Text('一键匹配封面'),
        onPressed: () => showBatchArtworkMatchDialog(
          context,
          kind: 'album',
          albums: contentList,
        ),
      ),
      enableShufflePlay: false,
      enableSortMethod: true,
      enableSortOrder: true,
      enableContentViewSwitch: true,
      sortMethods: [
        SortMethodDesc(
          icon: Symbols.title_rounded,
          name: "标题",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.name.localeCompareTo(b.name));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.name.localeCompareTo(a.name));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.music_note_rounded,
          name: "作品数量",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.works.length.compareTo(b.works.length));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.works.length.compareTo(a.works.length));
                break;
            }
          },
        ),
      ],
    );
  }
}
