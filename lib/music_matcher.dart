import 'dart:convert';

import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/krc.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/qrc.dart';
import 'package:qisheng_player/utils.dart';
import 'package:music_api/music_api.dart';

enum ResultSource { qq, kugou, netease }

const double minimumOnlineLyricMatchScore = 0.6;

double computeMusicMatchScore(
  Audio audio,
  String title,
  String artists,
  String album,
) {
  final titleSimilarity = normalizedSimilarity(audio.title, title);
  final artistSimilarity = normalizedSimilarity(audio.artist, artists);
  final albumSimilarity = normalizedSimilarity(audio.album, album);
  return titleSimilarity * 0.5 + artistSimilarity * 0.3 + albumSimilarity * 0.2;
}

String buildMusicSearchQuery(Audio audio, {int maxRunes = 50}) {
  final query = audio.hasKnownArtist
      ? '${audio.title} ${audio.artist}'.trim()
      : audio.title.trim();
  return String.fromCharCodes(query.runes.take(maxRunes));
}

class SongSearchResult {
  ResultSource source;
  String title;
  String artists;
  String album;
  double score;

  /// for qq result
  int? qqSongId;

  /// for netease result
  String? neteaseSongId;

  /// for kugou result
  String? kugouSongHash;

  String? coverUrl;

  SongSearchResult(
    this.source,
    this.title,
    this.artists,
    this.album,
    this.score, {
    this.qqSongId,
    this.neteaseSongId,
    this.kugouSongHash,
    this.coverUrl,
  });

  @override
  String toString() {
    return json.encode({
      "source": source.toString(),
      "title": title,
      "artists": artists,
      "album": album,
      "score": score,
    });
  }

  static SongSearchResult fromQQSearchResult(Map itemSong, Audio audio) {
    final List singer = itemSong["singer"];
    final buffer = StringBuffer(singer.first["name"]);
    for (int i = 1; i < singer.length; ++i) {
      buffer.write(" / ${singer[i]["name"]}");
    }

    final title = itemSong["name"] ?? "";
    final album = itemSong["album"]["title"] ?? "";
    final artists = buffer.toString();

    return SongSearchResult(
      ResultSource.qq,
      title,
      artists,
      album,
      computeMusicMatchScore(audio, title, artists, album),
      qqSongId: itemSong["id"],
      coverUrl: itemSong["album"]?["mid"] == null
          ? null
          : "https://y.qq.com/music/photo_new/T002R800x800M000${itemSong["album"]["mid"]}.jpg",
    );
  }

  static SongSearchResult fromNeteaseSearchResult(Map song, Audio audio) {
    final title = song["name"] ?? "";

    final List artistList = song["artists"];
    final buffer = StringBuffer(artistList.first["name"]);
    for (int i = 1; i < artistList.length; ++i) {
      buffer.write(" / ${artistList[i]["name"]}");
    }
    final artists = buffer.toString();

    final album = song["album"]["name"] ?? "";

    return SongSearchResult(
      ResultSource.netease,
      title,
      artists,
      album,
      computeMusicMatchScore(audio, title, artists, album),
      neteaseSongId: song["id"].toString(),
      coverUrl: song["album"]?["picUrl"]?.toString(),
    );
  }

  static SongSearchResult fromKugouSearchResult(Map info, Audio audio) {
    final title = info["songname"];
    final album = info["album_name"];
    final artists = info["singername"];

    return SongSearchResult(
      ResultSource.kugou,
      title,
      artists,
      album,
      computeMusicMatchScore(audio, title, artists, album),
      kugouSongHash: info["hash"],
      coverUrl: info["imgurl"]?.toString().replaceAll("{size}", "480"),
    );
  }
}

typedef MusicSearchProvider = Future<List<SongSearchResult>> Function(
  String query,
  Audio audio,
);

Future<List<SongSearchResult>> _searchKugou(
  String query,
  Audio audio,
) async {
  final Map answer = (await KuGou.searchSong(keyword: query)).data;
  final List? items = answer['data']?['info'];
  if (items == null) return const [];
  return items
      .take(5)
      .map((item) => SongSearchResult.fromKugouSearchResult(item, audio))
      .toList(growable: false);
}

Future<List<SongSearchResult>> _searchNetease(
  String query,
  Audio audio,
) async {
  final Map answer = (await Netease.search(keyWord: query)).data;
  final List? items = answer['result']?['songs'];
  if (items == null) return const [];
  return items
      .take(5)
      .map((item) => SongSearchResult.fromNeteaseSearchResult(item, audio))
      .toList(growable: false);
}

Future<List<SongSearchResult>> _searchQQ(
  String query,
  Audio audio,
) async {
  final Map answer = (await QQ.search(keyWord: query)).data;
  final List? items = answer['req']?['data']?['body']?['item_song'];
  if (items == null) return const [];
  return items
      .take(5)
      .map((item) => SongSearchResult.fromQQSearchResult(item, audio))
      .toList(growable: false);
}

Future<List<SongSearchResult>> _safeSearch(
  String source,
  String query,
  Audio audio,
  MusicSearchProvider provider,
) async {
  try {
    return await provider(query, audio);
  } catch (err, trace) {
    LOGGER.e('$source 搜索失败 query: $query', error: err, stackTrace: trace);
    return const [];
  }
}

Future<List<SongSearchResult>> searchMusicSources(
  Audio audio, {
  required MusicSearchProvider kugou,
  required MusicSearchProvider netease,
  required MusicSearchProvider qq,
}) async {
  final query = buildMusicSearchQuery(audio);
  final sourceResults = await Future.wait([
    _safeSearch('酷狗', query, audio, kugou),
    _safeSearch('网易云', query, audio, netease),
    _safeSearch('QQ音乐', query, audio, qq),
  ]);
  final result = sourceResults.expand((items) => items).toList();
  result.sort((first, second) => second.score.compareTo(first.score));
  return result;
}

Future<List<SongSearchResult>> uniSearch(Audio audio) => searchMusicSources(
      audio,
      kugou: _searchKugou,
      netease: _searchNetease,
      qq: _searchQQ,
    );

SongSearchResult? selectMatchedResult(
  List<SongSearchResult> results, {
  double minimumScore = minimumOnlineLyricMatchScore,
}) {
  if (results.isEmpty || results.first.score < minimumScore) return null;
  return results.first;
}

Future<Lrc?> _getNeteaseUnsyncLyric(String neteaseSongId) async {
  try {
    final answer = await Netease.lyric(id: neteaseSongId);
    final lrcText = answer.data["lrc"]["lyric"];
    if (lrcText is String) {
      final lrcTrans = answer.data["tlyric"]["lyric"];
      return Lrc.fromLrcText(
        lrcText + lrcTrans,
        LrcSource.web,
        separator: " | ",
      );
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }

  return null;
}

Future<Qrc?> _getQQSyncLyric(int qqSongId) async {
  try {
    final answer = await QQ.songLyric3(songId: qqSongId);
    final qrcText = answer.data["lyric"];
    if (qrcText is String) {
      final qrcTransRawStr = answer.data["trans"];
      if (qrcTransRawStr is String) {
        return Qrc.fromQrcText(qrcText, qrcTransRawStr);
      }
      return Qrc.fromQrcText(qrcText);
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }

  return null;
}

Future<Krc?> _getKugouSyncLyric(String kugouSongHash) async {
  try {
    final answer = await KuGou.krc(hash: kugouSongHash);
    final krcText = answer.data["lyric"];
    if (krcText is String) {
      return Krc.fromKrcText(krcText);
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }

  return null;
}

Future<Lyric?> getOnlineLyric({
  int? qqSongId,
  String? kugouSongHash,
  String? neteaseSongId,
}) async {
  Lyric? lyric;
  if (qqSongId != null) {
    lyric = await _getQQSyncLyric(qqSongId);
  } else if (kugouSongHash != null) {
    lyric = await _getKugouSyncLyric(kugouSongHash);
  } else if (neteaseSongId != null) {
    lyric = await _getNeteaseUnsyncLyric(neteaseSongId);
  }
  return lyric;
}

Future<Lyric?> getMostMatchedLyric(Audio audio) async {
  final unisearchResult = await uniSearch(audio);
  if (unisearchResult.isEmpty) return null;

  final mostMatch = selectMatchedResult(unisearchResult);
  if (mostMatch == null) {
    final candidate = unisearchResult.first;
    LOGGER.i(
      '[getMostMatchedLyric] 低于阈值: ${audio.title} -> '
      '${candidate.title} (${candidate.score})',
    );
    return null;
  }

  return switch (mostMatch.source) {
    ResultSource.qq => getOnlineLyric(qqSongId: mostMatch.qqSongId),
    ResultSource.kugou =>
      getOnlineLyric(kugouSongHash: mostMatch.kugouSongHash),
    ResultSource.netease =>
      getOnlineLyric(neteaseSongId: mostMatch.neteaseSongId),
  };
}
