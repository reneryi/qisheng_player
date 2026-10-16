import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinyin/pinyin.dart';

final Map<String, String> _pinyinInitialsCache = <String, String>{};

class UnionSearchResult {
  String query;

  List<Audio> audios = [];
  List<Artist> artists = [];
  List<Album> album = [];

  UnionSearchResult(this.query);

  /// 提取中文字符的拼音首字母与英文字符首字母缩写（带缓存），支持如 "zjl" -> "周杰伦"
  static String toPinyinInitials(String input) {
    final cached = _pinyinInitialsCache[input];
    if (cached != null) return cached;

    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      _pinyinInitialsCache[input] = '';
      return '';
    }

    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (ChineseHelper.isChinese(char)) {
        final py = PinyinHelper.convertToPinyinArray(
          char,
          PinyinFormat.WITHOUT_TONE,
        ).firstOrNull;
        if (py != null && py.isNotEmpty) {
          buffer.write(py[0].toLowerCase());
        }
      } else {
        final code = char.codeUnitAt(0);
        final isAlphaNum = (code >= 48 && code <= 57) ||
            (code >= 65 && code <= 90) ||
            (code >= 97 && code <= 122);
        if (isAlphaNum) {
          buffer.write(char.toLowerCase());
        }
      }
    }

    final result = buffer.toString();
    _pinyinInitialsCache[input] = result;
    return result;
  }

  static final RegExp _asciiAlphaNumPattern = RegExp(r'^[a-z0-9\s]+$');

  static bool matchesField(
    String fieldValue,
    String queryLower,
    String queryCompactAlphaNum,
  ) {
    if (fieldValue.isEmpty || queryLower.isEmpty) return false;
    if (fieldValue.toLowerCase().contains(queryLower)) return true;

    // 当输入为纯字母/数字时，启用全拼与拼音首字母缩写模糊匹配
    if (queryCompactAlphaNum.isNotEmpty) {
      final fullPinyin = fieldValue.toLocaleSortKey();
      if (fullPinyin.contains(queryCompactAlphaNum)) return true;

      final initials = toPinyinInitials(fieldValue);
      if (initials.contains(queryCompactAlphaNum)) return true;
    }
    return false;
  }

  static UnionSearchResult search(String query) {
    final trimmed = query.trim();
    final result = UnionSearchResult(trimmed);
    if (trimmed.isEmpty) return result;

    final queryInLowerCase = trimmed.toLowerCase();
    final queryCompactAlphaNum = _asciiAlphaNumPattern.hasMatch(queryInLowerCase)
        ? queryInLowerCase.replaceAll(RegExp(r'\s+'), '')
        : '';

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
      if (albumKeys.add(album.id)) {
        result.album.add(album);
      }
    }

    for (int i = 0; i < library.audioCollection.length; i++) {
      final audio = library.audioCollection[i];
      final titleMatched = matchesField(
        audio.title,
        queryInLowerCase,
        queryCompactAlphaNum,
      );
      final artistMatched = matchesField(
        audio.artist,
        queryInLowerCase,
        queryCompactAlphaNum,
      );
      final albumMatched = matchesField(
        audio.album,
        queryInLowerCase,
        queryCompactAlphaNum,
      );

      if (titleMatched || artistMatched || albumMatched) {
        addAudio(audio);
      }
    }

    for (Artist item in library.artistCollection.values) {
      if (matchesField(item.name, queryInLowerCase, queryCompactAlphaNum)) {
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
      if (matchesField(item.name, queryInLowerCase, queryCompactAlphaNum)) {
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
      final album = library.albumCollection[audio.albumKey];
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "搜索",
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "支持歌名、艺术家、专辑名以及全拼/拼音首字母缩写检索",
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 420,
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
                      hintText: "搜索歌曲、艺术家、专辑（支持拼音缩写）",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (String query) {
                      final trimmed = query.trim();
                      if (trimmed.isEmpty) return;
                      context.push(
                        app_paths.buildSearchResultLocation(trimmed),
                        extra: UnionSearchResult.search(trimmed),
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
