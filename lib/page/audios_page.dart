import 'dart:async';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/audio_lyric_preview_panel.dart';
import 'package:qisheng_player/component/audio_grid_tile.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/editorial_bento_header.dart';
import 'package:qisheng_player/component/ui/modern_tooltip.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/page/uni_page_components.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/utils.dart';
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
  LibraryFocusDimension _activeFocus = LibraryFocusDimension.all;

  @override
  void dispose() {
    multiSelectController.dispose();
    super.dispose();
  }

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

  String _buildSubtitle(int totalCount) {
    return formatMusicCount(totalCount);
  }

  bool get _showLyricPreview =>
      AppPreference.instance.audiosPagePref.showLyricPreview;

  void _toggleLyricPreview() {
    setState(() {
      AppPreference.instance.audiosPagePref.showLyricPreview =
          !_showLyricPreview;
    });
    unawaited(AppPreference.instance.save());
  }

  @override
  Widget build(BuildContext context) {
    final sourceList = List<Audio>.from(AudioLibrary.instance.audioCollection);
    final contentList = _activeFocus == LibraryFocusDimension.all
        ? List<Audio>.from(sourceList)
        : sourceList
            .where((a) => matchesLibraryFocus(a, _activeFocus))
            .toList();

    return UniPage<Audio>(
      pref: AppPreference.instance.audiosPagePref,
      title: "音乐",
      subtitle: _buildSubtitle(contentList.length),
      topBanner: (sourceList.length >= 4 || _activeFocus != LibraryFocusDimension.all)
          ? LibraryFocusFilterBar(
              allAudios: sourceList,
              activeFocus: _activeFocus,
              onFocusChanged: (next) {
                if (_activeFocus != next) {
                  setState(() => _activeFocus = next);
                }
              },
            )
          : null,
      contentList: contentList,
      contentRevision: Object.hash(AudioLibrary.revision.value, _activeFocus),
      contentBuilder: (context, item, i, multiSelectController) => AudioTile(
        key: ValueKey('${item.path}_$i'),
        audioIndex: i,
        playlist: contentList,
        focus: item == widget.locateTo,
        multiSelectController: multiSelectController,
      ),
      gridBuilder: (context, item, i, multiSelectController) => AudioGridTile(
        key: ValueKey('${item.path}_$i'),
        audioIndex: i,
        playlist: contentList,
        focus: item == widget.locateTo,
        multiSelectController: multiSelectController,
      ),
      enableShufflePlay: true,
      enableSortMethod: true,
      enableSortOrder: true,
      enableContentViewSwitch: true,
      locateTo: widget.locateTo,
      sideIndexLabels: _letters,
      sideIndexResolver: _resolveByLetter,
      locateIndexResolver: (list) {
        final nowPlaying = PlayService.instance.playbackService.nowPlaying;
        if (nowPlaying != null) {
          final currentIndex =
              list.indexWhere((item) => item.path == nowPlaying.path);
          if (currentIndex >= 0) return currentIndex;
        }
        if (widget.locateTo != null) {
          final targetIndex = list.indexOf(widget.locateTo!);
          if (targetIndex >= 0) return targetIndex;
        }
        return null;
      },
      extraActions: [
        CpIconButton(
          key: const ValueKey('toggle-lyric-preview'),
          variant: CpButtonVariant.immersive,
          selected: _showLyricPreview,
          tooltip: _showLyricPreview ? '隐藏歌词预览' : '显示歌词预览',
          tooltipDirection: ModernTooltipDirection.bottom,
          onPressed: _toggleLyricPreview,
          icon: const Icon(Symbols.lyrics_rounded),
        ),
      ],
      rightPaneBuilder: (_) => const AudioLyricPreviewPanel(),
      showRightPane: _showLyricPreview,
      rightPaneWidth: 332,
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
      sortMethods: [
        SortMethodDesc(
          icon: Symbols.title_rounded,
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
          icon: Symbols.artist_rounded,
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
          icon: Symbols.album_rounded,
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
          icon: Symbols.add_rounded,
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
          icon: Symbols.edit_rounded,
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
        SortMethodDesc(
          icon: Symbols.local_fire_department_rounded,
          name: "播放次数",
          method: (list, order) {
            final store = PlayCountStore.instance;
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) {
                  final cmp = store.get(a).compareTo(store.get(b));
                  if (cmp != 0) return cmp;
                  return a.title.localeCompareTo(b.title);
                });
                break;
              case SortOrder.descending:
                list.sort((a, b) {
                  final cmp = store.get(b).compareTo(store.get(a));
                  if (cmp != 0) return cmp;
                  return a.title.localeCompareTo(b.title);
                });
                break;
            }
          },
        ),
      ],
    );
  }
}
