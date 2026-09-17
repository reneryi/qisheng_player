import 'package:qisheng_player/component/entity_artwork_actions.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/album_artwork_hero.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/page/uni_detail_page.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class AlbumDetailPage extends StatefulWidget {
  const AlbumDetailPage({super.key, required this.album});

  final Album album;

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final multiSelectController = MultiSelectController<Audio>();
  late final bool _trackedByLibrary;

  Album get album {
    if (!_trackedByLibrary) return widget.album;
    return AudioLibrary.instance.albumCollection.values
            .where((item) => item.id == widget.album.id)
            .firstOrNull ??
        Album(name: widget.album.name, id: widget.album.id);
  }

  @override
  void initState() {
    super.initState();
    _trackedByLibrary = AudioLibrary.instance.albumCollection.values
        .any((item) => item.id == widget.album.id);
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

  @override
  Widget build(BuildContext context) {
    if (album.works.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('该分类已无歌曲'),
        TextButton(onPressed: () => context.pop(), child: const Text('返回'))
      ]));
    }
    final seen = <String>{};
    final secondaryContent = <Audio>[];
    for (final audio in album.works) {
      if (seen.add(audio.path)) {
        secondaryContent.add(audio);
      }
    }
    int compareByDiscTrack(Audio a, Audio b) {
      final discCompare = a.disc.compareTo(b.disc);
      if (discCompare != 0) return discCompare;
      final trackCompare = a.track.compareTo(b.track);
      if (trackCompare != 0) return trackCompare;
      return a.title.localeCompareTo(b.title);
    }

    return UniDetailPage<Album, Audio, Artist>(
      pref: AppPreference.instance.albumDetailPagePref,
      primaryContent: album,
      artworkActions: [
        EntityArtworkActions(
            id: album.id,
            name: album.name,
            kind: 'album',
            works: album.works,
            albumArtist: album.effectiveArtist,
            album: album)
      ],
      primaryPic: album.cover,
      primaryPicHeroTag: albumArtworkHeroTag(album),
      backgroundPic: album.cover,
      picShape: PicShape.rrect,
      title: album.name,
      subtitle: formatWorkCount(album.works.length),
      secondaryContent: secondaryContent,
      secondaryContentRevision: AudioLibrary.revision.value,
      secondaryContentBuilder: (context, audio, i, multiSelectController) =>
          AudioTile(
        leading: Text(
          audio.disc > 0
              ? "${audio.disc.toString().padLeft(2, "0")}-${audio.track.toString().padLeft(2, "0")}"
              : audio.track.toString().padLeft(2, "0"),
        ),
        audioIndex: i,
        playlist: secondaryContent,
        multiSelectController: multiSelectController,
      ),
      tertiaryContentTitle: "艺术家",
      tertiaryContent: album.artistsMap.values.toList(),
      tertiaryContentBuilder: (context, artist, i, multiSelectController) =>
          CpListTile(
        onTap: () => context.push(app_paths.ARTIST_DETAIL_PAGE, extra: artist),
        title: Text(artist.name),
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
          icon: Symbols.art_track,
          name: "音轨",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort(compareByDiscTrack);
                break;
              case SortOrder.descending:
                list.sort((a, b) => compareByDiscTrack(b, a));
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
    );
  }
}
