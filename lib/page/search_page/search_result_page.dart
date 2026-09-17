import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/artist_tile.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/page/search_page/search_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class SearchResultPage extends StatelessWidget {
  const SearchResultPage({
    super.key,
    required this.initialQuery,
    this.initialResult,
  });

  final String initialQuery;
  final UnionSearchResult? initialResult;

  UnionSearchResult get resolvedResult =>
      UnionSearchResult.search(initialQuery);

  List<_SearchResultPageBody> _buildContent(UnionSearchResult result) {
    return [
      _SearchResultPageBody(result: result, filter: _SearchResultFilter.all),
      _SearchResultPageBody(result: result, filter: _SearchResultFilter.music),
      _SearchResultPageBody(result: result, filter: _SearchResultFilter.artist),
      _SearchResultPageBody(result: result, filter: _SearchResultFilter.album),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final result = resolvedResult;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                result.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            const Material(
              type: MaterialType.transparency,
              child: TabBar(
                tabs: [
                  Tab(text: _SearchResultFilter.allName),
                  Tab(text: _SearchResultFilter.musicName),
                  Tab(text: _SearchResultFilter.artistName),
                  Tab(text: _SearchResultFilter.albumName),
                ],
              ),
            ),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: TabBarView(
                  children: _buildContent(result),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SearchResultFilter {
  all(_SearchResultFilter.allName),
  music(_SearchResultFilter.musicName),
  artist(_SearchResultFilter.artistName),
  album(_SearchResultFilter.albumName);

  static const String allName = "所有";
  static const String musicName = "音乐";
  static const String artistName = "艺术家";
  static const String albumName = "专辑";

  const _SearchResultFilter(this.name);
  final String name;
}

class _SearchResultPageBody extends StatelessWidget {
  const _SearchResultPageBody({required this.result, required this.filter});

  final UnionSearchResult result;
  final _SearchResultFilter filter;

  Widget buildContentHeader(
    ColorScheme scheme,
    _SearchResultFilter contentType,
  ) {
    return SliverToBoxAdapter(
      child: filter == _SearchResultFilter.all
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                contentType.name,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const SizedBox(height: 8.0),
    );
  }

  List<Widget> buildMusicResultContent(ColorScheme scheme) {
    return [
      buildContentHeader(scheme, _SearchResultFilter.music),
      SliverList.builder(
        itemCount: result.audios.length,
        itemBuilder: (context, i) {
          final item = result.audios[i];
          return AudioTile(
            audioIndex: 0,
            playlist: [item],
            action: IconButton(
              onPressed: () {
                context.push(app_paths.AUDIOS_PAGE, extra: item);
              },
              icon: const Icon(Symbols.location_on),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> buildArtistResultContent(ColorScheme scheme) {
    return [
      buildContentHeader(scheme, _SearchResultFilter.artist),
      SliverList.builder(
        itemCount: result.artists.length,
        itemBuilder: (context, i) => ArtistTile(artist: result.artists[i]),
      ),
    ];
  }

  List<Widget> buildAlbumResultContent(ColorScheme scheme) {
    return [
      buildContentHeader(scheme, _SearchResultFilter.album),
      SliverList.builder(
        itemCount: result.album.length,
        itemBuilder: (context, i) => AlbumTile(album: result.album[i]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slivers = <Widget>[];
    switch (filter) {
      case _SearchResultFilter.all:
        if (result.audios.isNotEmpty) {
          slivers.addAll(buildMusicResultContent(scheme));
        }
        if (result.artists.isNotEmpty) {
          slivers.addAll(buildArtistResultContent(scheme));
        }
        if (result.album.isNotEmpty) {
          slivers.addAll(buildAlbumResultContent(scheme));
        }
        break;
      case _SearchResultFilter.music:
        slivers.addAll(buildMusicResultContent(scheme));
        break;
      case _SearchResultFilter.artist:
        slivers.addAll(buildArtistResultContent(scheme));
        break;
      case _SearchResultFilter.album:
        slivers.addAll(buildAlbumResultContent(scheme));
        break;
    }
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 96.0)));
    return CustomScrollView(slivers: slivers);
  }
}
