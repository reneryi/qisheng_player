import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/hotkeys_helper.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class UnionSearchResult {
  String query;

  List<Audio> audios = [];
  List<Artist> artists = [];
  List<Album> album = [];

  UnionSearchResult(this.query);

  static UnionSearchResult search(String query) {
    final result = UnionSearchResult(query);

    final queryInLowerCase = query.toLowerCase();
    final library = AudioLibrary.instance;
    final audioKeys = <String>{};
    final artistKeys = <String>{};
    final albumKeys = <String>{};

    void addAudio(Audio audio) {
      if (audioKeys.add(audio.path)) {
        result.audios.add(audio);
      }
    }

    void addArtist(Artist artist) {
      if (artistKeys.add(artist.name)) {
        result.artists.add(artist);
      }
    }

    void addAlbum(Album album) {
      if (albumKeys.add(album.name)) {
        result.album.add(album);
      }
    }

    for (int i = 0; i < library.audioCollection.length; i++) {
      final audio = library.audioCollection[i];
      final titleMatched = audio.title.toLowerCase().contains(queryInLowerCase);
      final artistMatched =
          audio.artist.toLowerCase().contains(queryInLowerCase);
      final albumMatched = audio.album.toLowerCase().contains(queryInLowerCase);

      if (titleMatched || artistMatched || albumMatched) {
        addAudio(audio);
      }
    }

    for (Artist item in library.artistCollection.values) {
      if (item.name.toLowerCase().contains(queryInLowerCase)) {
        addArtist(item);
        for (final work in item.works) {
          addAudio(work);
        }
        for (final album in item.albumsMap.values) {
          addAlbum(album);
        }
      }
    }

    for (Album item in library.albumCollection.values) {
      if (item.name.toLowerCase().contains(queryInLowerCase)) {
        addAlbum(item);
        for (final work in item.works) {
          addAudio(work);
        }
        for (final artist in item.artistsMap.values) {
          addArtist(artist);
        }
      }
    }

    for (final audio in result.audios) {
      for (final artistName in audio.splitedArtists) {
        final artist = library.artistCollection[artistName];
        if (artist != null) {
          addArtist(artist);
        }
      }
      final album = library.albumCollection[audio.album];
      if (album != null) {
        addAlbum(album);
      }
    }

    return result;
  }
}

final SEARCH_BAR_KEY = GlobalKey();

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "搜索",
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 32.0)),
            SizedBox(
              width: 400,
              child: Focus(
                onFocusChange: HotkeysHelper.onFocusChanges,
                child: Hero(
                  tag: SEARCH_BAR_KEY,
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      suffixIcon: Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(Symbols.search),
                      ),
                      hintText: "搜索歌曲、艺术家、专辑",
                      border: OutlineInputBorder(),
                    ),

                    /// when 'enter' is pressed
                    onSubmitted: (String query) {
                      context.push(
                        app_paths.SEARCH_RESULT_PAGE,
                        extra: UnionSearchResult.search(query),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
