import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/audio_tile.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/play_count_store.dart';
import 'package:coriander_player/page/uni_page.dart';
import 'package:coriander_player/page/uni_page_components.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AudiosPage extends StatelessWidget {
  final Audio? locateTo;
  const AudiosPage({super.key, this.locateTo});

  static final List<String> _letters = [
    ...List.generate(26, (i) => String.fromCharCode(65 + i)),
    "#",
  ];

  String _resolveTitleLetter(String title) {
    final key = title.toLocaleSortKey();
    if (key.isEmpty) return "#";
    for (final rune in key.runes) {
      final char = String.fromCharCode(rune).toUpperCase();
      if (RegExp(r'^[A-Z]$').hasMatch(char)) {
        return char;
      }
    }
    return "#";
  }

  int? _resolveByLetter(List<Audio> list, String label) {
    for (int i = 0; i < list.length; i++) {
      final first = _resolveTitleLetter(list[i].title);
      if (label == "#") {
        if (!RegExp(r'^[A-Z]$').hasMatch(first)) {
          return i;
        }
      } else if (first == label) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final contentList = List<Audio>.from(AudioLibrary.instance.audioCollection);
    final multiSelectController = MultiSelectController<Audio>();

    return UniPage<Audio>(
      pref: AppPreference.instance.audiosPagePref,
      title: "音乐",
      subtitle: "${contentList.length} 首乐曲",
      contentList: contentList,
      contentBuilder: (context, item, i, multiSelectController) => AudioTile(
        audioIndex: i,
        playlist: contentList,
        showPlayCount: AppPreference.instance.audiosPagePref.sortMethod == 5,
        focus: item == locateTo,
        multiSelectController: multiSelectController,
      ),
      enableShufflePlay: true,
      enableSortMethod: true,
      enableSortOrder: true,
      enableContentViewSwitch: true,
      locateTo: locateTo,
      locateIndexResolver: (list) {
        final current = PlayService.instance.playbackService.nowPlaying;
        if (current == null) return null;
        final index = list.indexWhere((audio) => audio.path == current.path);
        return index >= 0 ? index : null;
      },
      multiSelectController: multiSelectController,
      multiSelectViewActions: [
        AddAllToPlaylist(multiSelectController: multiSelectController),
        DeleteSelectedAudios(
          multiSelectController: multiSelectController,
          contentList: contentList,
        ),
        MultiSelectSelectOrClearAll(
          multiSelectController: multiSelectController,
          contentList: contentList,
        ),
        MultiSelectExit(multiSelectController: multiSelectController),
      ],
      sideIndexLabels: _letters,
      sideIndexResolver: _resolveByLetter,
      sortMethods: [
        SortMethodDesc(
          icon: Symbols.title,
          name: "标题",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.title.localeCompareTo(b.title));
                break;
              case SortOrder.decending:
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
              case SortOrder.decending:
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
              case SortOrder.decending:
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
              case SortOrder.decending:
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
              case SortOrder.decending:
                list.sort((a, b) => b.modified.compareTo(a.modified));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.bar_chart,
          name: "播放次数",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort(
                  (a, b) => PlayCountStore.instance
                      .get(a)
                      .compareTo(PlayCountStore.instance.get(b)),
                );
                break;
              case SortOrder.decending:
                list.sort(
                  (a, b) => PlayCountStore.instance
                      .get(b)
                      .compareTo(PlayCountStore.instance.get(a)),
                );
                break;
            }
          },
        ),
      ],
    );
  }
}
