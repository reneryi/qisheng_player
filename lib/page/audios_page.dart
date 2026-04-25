import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/audio_tile.dart';
import 'package:coriander_player/component/ui/expandable_search_action.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/play_count_store.dart';
import 'package:coriander_player/page/uni_page.dart';
import 'package:coriander_player/page/uni_page_components.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AudiosPage extends StatefulWidget {
  final Audio? locateTo;
  const AudiosPage({super.key, this.locateTo});

  @override
  State<AudiosPage> createState() => _AudiosPageState();
}

class _AudiosPageState extends State<AudiosPage> {
  late final MultiSelectController<Audio> multiSelectController =
      MultiSelectController<Audio>();
  String query = '';

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

  List<Audio> _buildFilteredList(List<Audio> source) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return List<Audio>.from(source);

    return source.where((audio) {
      return audio.title.toLowerCase().contains(keyword) ||
          audio.artist.toLowerCase().contains(keyword) ||
          audio.album.toLowerCase().contains(keyword);
    }).toList();
  }

  String _buildSubtitle(int filteredCount, int totalCount) {
    if (query.trim().isEmpty) {
      return '$totalCount 首乐曲';
    }
    return '搜索结果 $filteredCount / 总数 $totalCount';
  }

  @override
  Widget build(BuildContext context) {
    final sourceList = List<Audio>.from(AudioLibrary.instance.audioCollection);
    final contentList = _buildFilteredList(sourceList);
    final searching = query.trim().isNotEmpty;

    return UniPage<Audio>(
      pref: AppPreference.instance.audiosPagePref,
      title: "音乐",
      subtitle: _buildSubtitle(contentList.length, sourceList.length),
      contentList: contentList,
      contentBuilder: (context, item, i, multiSelectController) => AudioTile(
        audioIndex: i,
        playlist: contentList,
        showPlayCount: AppPreference.instance.audiosPagePref.sortMethod == 5,
        focus: item == widget.locateTo,
        multiSelectController: multiSelectController,
      ),
      primaryAction: ExpandableSearchAction(
        hintText: '搜索歌曲、艺术家、专辑',
        onChanged: (value) {
          setState(() {
            query = value;
          });
        },
      ),
      enableShufflePlay: true,
      enableSortMethod: true,
      enableSortOrder: true,
      enableContentViewSwitch: true,
      locateTo: searching ? null : widget.locateTo,
      locateIndexResolver: searching
          ? null
          : (list) {
              final current = PlayService.instance.playbackService.nowPlaying;
              if (current == null) return null;
              final index =
                  list.indexWhere((audio) => audio.path == current.path);
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
      sideIndexLabels: searching ? null : _letters,
      sideIndexResolver: searching ? null : _resolveByLetter,
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
