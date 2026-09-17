import 'package:music_api/music_api.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/music_matcher.dart';

String normalizeEntityName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class MetadataCandidate {
  const MetadataCandidate(
      {required this.source,
      required this.id,
      required this.name,
      required this.kind,
      this.imageUrl,
      this.artist = '',
      this.evidence = false});
  final ResultSource source;
  final String id, name, kind, artist;
  final String? imageUrl;
  final bool evidence;
  String get identity => '${source.name}:$kind:$id';
  Map<String, dynamic> toJson() => {
        'source': source.name,
        'id': id,
        'name': name,
        'kind': kind,
        'artist': artist,
        'url': imageUrl
      };
  factory MetadataCandidate.fromJson(Map m) => MetadataCandidate(
      source: ResultSource.values.byName(m['source']),
      id: m['id'],
      name: m['name'],
      kind: m['kind'],
      artist: m['artist'] ?? '',
      imageUrl: m['url']);
}

abstract interface class MetadataProvider {
  ResultSource get source;
  Future<List<SongSearchResult>> searchSongs(String query, Audio witness);
  Future<List<MetadataCandidate>> searchEntities(String query, String kind,
      {String albumArtist = ''});
  Future<MetadataCandidate> detail(MetadataCandidate candidate);
}

class PlatformMetadataProvider implements MetadataProvider {
  const PlatformMetadataProvider(this.source);
  @override
  final ResultSource source;
  static const timeout = Duration(seconds: 15);

  @override
  Future<List<SongSearchResult>> searchSongs(
      String query, Audio witness) async {
    if (source == ResultSource.netease) {
      final answer =
          await Netease.search(keyWord: query, size: 20).timeout(timeout);
      final List items = answer.data['result']?['songs'] ?? [];
      return [
        for (final item in items)
          SongSearchResult.fromNeteaseSearchResult(item, witness)
      ];
    }
    final answer = await QQ.search(keyWord: query, size: 20).timeout(timeout);
    final List items = answer.data['req']?['data']?['body']?['item_song'] ?? [];
    return [
      for (final item in items)
        SongSearchResult.fromQQSearchResult(item, witness)
    ];
  }

  @override
  Future<List<MetadataCandidate>> searchEntities(String query, String kind,
      {String albumArtist = ''}) async {
    if (query.trim().isEmpty) return [];
    try {
      if (source == ResultSource.netease) {
        if (kind == 'artist') {
          final answer =
              await Netease.searchPc(keyWord: query, type: 100, size: 10)
                  .timeout(timeout);
          final List items = answer.data['result']?['artists'] ?? [];
          return [
            for (final item in items)
              if (item['id'] != null)
                MetadataCandidate(
                  source: ResultSource.netease,
                  id: item['id'].toString(),
                  name: item['name']?.toString() ?? '',
                  kind: 'artist',
                  imageUrl: (item['img1v1Url'] ?? item['picUrl'])?.toString(),
                  evidence: true,
                )
          ];
        } else {
          final answer =
              await Netease.searchPc(keyWord: query, type: 10, size: 10)
                  .timeout(timeout);
          final List items = answer.data['result']?['albums'] ?? [];
          return [
            for (final item in items)
              if (item['id'] != null)
                MetadataCandidate(
                  source: ResultSource.netease,
                  id: item['id'].toString(),
                  name: item['name']?.toString() ?? '',
                  kind: 'album',
                  artist: item['artist']?['name']?.toString() ?? '',
                  imageUrl: item['picUrl']?.toString(),
                  evidence: true,
                )
          ];
        }
      } else if (source == ResultSource.qq) {
        if (kind == 'artist') {
          final answer = await QQ.search(keyWord: query, type: 1, size: 10)
              .timeout(timeout);
          final body = answer.data['req']?['data']?['body'];
          final List items = body?['item_singer'] ??
              body?['singer_list'] ??
              answer.data['data']?['singer']?['list'] ??
              [];
          return [
            for (final item in items)
              if ((item['singer_mid'] ?? item['mid'] ?? item['singerMID']) !=
                  null)
                MetadataCandidate(
                  source: ResultSource.qq,
                  id: (item['singer_mid'] ?? item['mid'] ?? item['singerMID'])
                      .toString(),
                  name:
                      (item['singer_name'] ?? item['name'])?.toString() ?? '',
                  kind: 'artist',
                  imageUrl:
                      'https://y.qq.com/music/photo_new/T001R800x800M000${item['singer_mid'] ?? item['mid'] ?? item['singerMID']}.jpg',
                  evidence: true,
                )
          ];
        } else {
          final answer = await QQ.search(keyWord: query, type: 2, size: 10)
              .timeout(timeout);
          final body = answer.data['req']?['data']?['body'];
          final List items = body?['item_album'] ??
              body?['album_list'] ??
              answer.data['data']?['album']?['list'] ??
              [];
          return [
            for (final item in items)
              if ((item['album_mid'] ?? item['mid'] ?? item['albumMID']) !=
                  null)
                MetadataCandidate(
                  source: ResultSource.qq,
                  id: (item['album_mid'] ?? item['mid'] ?? item['albumMID'])
                      .toString(),
                  name: (item['album_name'] ?? item['name'])?.toString() ?? '',
                  kind: 'album',
                  artist: (item['singer_name'] ?? item['singer']?['name'])
                          ?.toString() ??
                      '',
                  imageUrl:
                      'https://y.qq.com/music/photo_new/T002R800x800M000${item['album_mid'] ?? item['mid'] ?? item['albumMID']}.jpg',
                  evidence: true,
                )
          ];
        }
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<MetadataCandidate> detail(MetadataCandidate c) async {
    // 若已包含高分辨率图片地址，直接返回，避免额外的网络往返与反查失败
    if (c.imageUrl != null && c.imageUrl!.trim().isNotEmpty) {
      return c;
    }
    String? image;
    String name = c.name;
    if (source == ResultSource.netease) {
      final answer = c.kind == 'artist'
          ? await Netease.api('/artists', params: {'id': c.id}).timeout(timeout)
          : await Netease.albumInfo(id: c.id).timeout(timeout);
      final Map? entity = answer.data[c.kind];
      if (entity == null || entity['id']?.toString() != c.id) {
        throw const FormatException('详情返回的实体身份不匹配');
      }
      name = entity['name']?.toString() ?? name;
      image = (c.kind == 'artist'
              ? entity['img1v1Url'] ?? entity['picUrl']
              : entity['picUrl'])
          ?.toString();
    } else if (source == ResultSource.qq) {
      if (c.kind == 'artist') {
        final answer = await QQ.singerInfo(singerMid: c.id).timeout(timeout);
        final List singers =
            answer.data['detail']?['data']?['singer_list'] ?? [];
        final matches = singers
            .where((s) => s['basic_info']?['singer_mid']?.toString() == c.id);
        if (matches.isNotEmpty) {
          final basic = matches.first['basic_info'];
          name = basic['name']?.toString() ?? name;
        }
        image = 'https://y.qq.com/music/photo_new/T001R800x800M000${c.id}.jpg';
      } else {
        final answer = await QQ.albumInfo(albumMid: c.id).timeout(timeout);
        final Map? data = answer.data['albumInfo']?['data'];
        final Map? basic = data?['basicInfo'];
        if (basic != null && basic['albumMid']?.toString() == c.id) {
          name = basic['albumName']?.toString() ?? name;
        }
        image = 'https://y.qq.com/music/photo_new/T002R800x800M000${c.id}.jpg';
      }
    } else if (source == ResultSource.kugou) {
      if (c.kind == 'artist') {
        try {
          final answer = await KuGou.singerInfo(id: c.id).timeout(timeout);
          final data = answer.data['data'];
          image = data?['imgurl']?.toString().replaceAll('{size}', '800');
          name = data?['author_name']?.toString() ?? name;
        } catch (_) {}
      } else {
        try {
          final answer = await KuGou.albumInfo(albumId: c.id).timeout(timeout);
          final data = answer.data['data'];
          image = data?['imgurl']?.toString().replaceAll('{size}', '800');
          name = data?['album_name']?.toString() ?? name;
        } catch (_) {}
      }
    }
    if (image == null || image.isEmpty) throw const FormatException('该资料没有图片');
    return MetadataCandidate(
        source: source,
        id: c.id,
        name: name,
        kind: c.kind,
        artist: c.artist,
        imageUrl: image,
        evidence: c.evidence);
  }
}

/// Automatic linking is deliberately exact and within a single platform.
MetadataCandidate? selectAutomaticEntity(List<MetadataCandidate> candidates,
    String name, String kind, String albumArtist) {
  for (final source in [ResultSource.netease, ResultSource.qq]) {
    final matches = candidates
        .where((c) =>
            c.source == source &&
            c.kind == kind &&
            normalizeEntityName(c.name) == normalizeEntityName(name))
        .toList();
    if (matches.length != 1) continue;
    final c = matches.single;
    if (!c.evidence) continue;
    if (kind == 'album' &&
        (albumArtist.isEmpty ||
            normalizeEntityName(c.artist) !=
                normalizeEntityName(albumArtist))) {
      continue;
    }
    return c;
  }
  return null;
}
