import 'dart:math' as math;

import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/entity_artwork_actions.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/artist_artwork_hero.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/page/uni_detail_page.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class ArtistDetailPage extends StatefulWidget {
  const ArtistDetailPage({super.key, required this.artist});

  final Artist artist;

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  final multiSelectController = MultiSelectController<Audio>();
  late final bool _trackedByLibrary;

  Artist get artist {
    if (!_trackedByLibrary) return widget.artist;
    return AudioLibrary.instance.artistCollection.values
            .where((item) => item.id == widget.artist.id)
            .firstOrNull ??
        Artist(name: widget.artist.name);
  }

  @override
  void initState() {
    super.initState();
    _trackedByLibrary = AudioLibrary.instance.artistCollection.values
        .any((item) => item.id == widget.artist.id);
    AudioLibrary.revision.addListener(_refresh);
    ArtworkStore.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AudioLibrary.revision.removeListener(_refresh);
    ArtworkStore.instance.removeListener(_refresh);
    multiSelectController.dispose();
    super.dispose();
  }

  List<String> _buildArtistBadges(List<Audio> tracks) {
    final badges = <String>[];
    if (artist.albumsMap.isNotEmpty) {
      badges.add('${artist.albumsMap.length} 张收录专辑');
    }
    final totalSeconds =
        tracks.fold<int>(0, (sum, item) => sum + math.max(0, item.duration));
    if (totalSeconds > 0) {
      final minutes = (totalSeconds / 60).ceil();
      if (minutes >= 60) {
        badges.add('累计 ${minutes ~/ 60} 小时 ${minutes % 60} 分');
      } else {
        badges.add('累计 $minutes 分钟');
      }
    }
    int hiResCount = 0;
    for (final t in tracks) {
      if ((t.sampleRate ?? 0) >= 48000 || (t.bitrate ?? 0) > 1411) {
        hiResCount++;
      }
    }
    if (hiResCount > 0) {
      badges.add('Hi-Res $hiResCount 首');
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    if (artist.works.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('该分类已无歌曲'),
        TextButton(onPressed: () => context.pop(), child: const Text('返回'))
      ]));
    }
    final seen = <String>{};
    final secondaryContent = <Audio>[];
    for (final audio in artist.works) {
      if (seen.add(audio.path)) {
        secondaryContent.add(audio);
      }
    }

    return UniDetailPage<Artist, Audio, Album>(
      pref: AppPreference.instance.artistDetailPagePref,
      primaryContent: artist,
      artworkActions: [
        EntityArtworkActions(
            id: artist.id,
            name: artist.name,
            kind: 'artist',
            works: artist.works,
            artist: artist)
      ],
      primaryPic: artist.picture,
      primaryPicHeroTag: artistArtworkHeroTag(artist),
      backgroundPic: artist.picture,
      picShape: PicShape.oval,
      title: artist.name,
      subtitle: formatWorkCount(secondaryContent.length),
      headerBadges: _buildArtistBadges(secondaryContent),
      onPlayAll: secondaryContent.isEmpty
          ? null
          : () {
              PlayService.instance.playbackService.play(0, secondaryContent);
            },
      onShufflePlay: secondaryContent.isEmpty
          ? null
          : () {
              PlayService.instance.playbackService.shuffleAndPlay(
                secondaryContent,
              );
            },
      secondaryContent: secondaryContent,
      secondaryContentRevision: AudioLibrary.revision.value,
      secondaryContentBuilder: (context, audio, i, multiSelectController) =>
          AudioTile(
        audioIndex: i,
        playlist: secondaryContent,
        multiSelectController: multiSelectController,
      ),
      tertiaryContentTitle: "收录专辑",
      tertiaryContent: artist.albumsMap.values.toList(),
      tertiaryContentBuilder: (context, album, i, multiSelectController) =>
          AlbumTile(
        album: album,
      ),
      enableShufflePlay: true,
      enableSortMethod: true,
      enableSortOrder: true,
      enableSecondaryContentViewSwitch: true,
      multiSelectController: multiSelectController,
      multiSelectViewActions: [
        AddAllToPlaylist(multiSelectController: multiSelectController),
        DeleteSelectedAudios(
          multiSelectController: multiSelectController,
          contentList: secondaryContent,
        ),
        MultiSelectSelectOrClearAll(
          multiSelectController: multiSelectController,
          contentList: secondaryContent,
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
      ],
    );
  }
}
