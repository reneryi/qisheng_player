import 'package:music_api/music_api.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/music_matcher.dart';

String normalizeEntityName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String formatNeteaseImageUrl(String? url, {int size = 1024}) {
  if (url == null || url.trim().isEmpty) return '';
  var trimmed = url.trim();
  if (trimmed.startsWith('http://')) {
    trimmed = 'https://${trimmed.substring(7)}';
  }
  if (!trimmed.contains('126.net')) return trimmed;
  if (trimmed.contains('param=')) return trimmed;
  final separator = trimmed.contains('?') ? '&' : '?';
  return '$trimmed${separator}param=${size}y$size';
}


String _formatQQImageUrl(String? rawPic, String mid, {required bool isArtist}) {
  if (rawPic != null && rawPic.trim().isNotEmpty) {
    var pic = rawPic.trim().replaceFirst('http://', 'https://');
    pic = pic.replaceAll(RegExp(r'\d+x\d+'), '800x800');
    return pic;
  }
  final prefix = isArtist ? 'T001' : 'T002';
  return 'https://y.gtimg.cn/music/photo_new/${prefix}R800x800M000$mid.jpg';
}

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
                  imageUrl: formatNeteaseImageUrl(
                      (item['img1v1Url'] ?? item['picUrl'])?.toString()),
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
                  imageUrl:
                      formatNeteaseImageUrl(item['picUrl']?.toString()),
                  evidence: true,
                )
          ];
        }
      } else if (source == ResultSource.qq) {
        if (kind == 'artist') {
          final answer = await QQ.search(keyWord: query, type: 1, size: 10)
              .timeout(timeout);
          final body = answer.data['req']?['data']?['body'];
          final List items = (body?['item_singer'] ??
                  body?['singer_list'] ??
                  body?['singer'] ??
                  answer.data['data']?['singer']?['list'] ??
                  []) as List;
          return [
            for (final item in items)
              if ((item['singer_mid'] ??
                      item['mid'] ??
                      item['singerMID'] ??
                      item['singermid']) !=
                  null)
                MetadataCandidate(
                  source: ResultSource.qq,
                  id: (item['singer_mid'] ??
                          item['mid'] ??
                          item['singerMID'] ??
                          item['singermid'])
                      .toString(),
                  name: (item['singer_name'] ??
                          item['name'] ??
                          item['singerName'])
                          ?.toString() ??
                      '',
                  kind: 'artist',
                  imageUrl: _formatQQImageUrl(
                    item['singerPic']?.toString(),
                    (item['singer_mid'] ??
                            item['mid'] ??
                            item['singerMID'] ??
                            item['singermid'])
                        .toString(),
                    isArtist: true,
                  ),
                  evidence: true,
                )
          ];
        } else {
          final answer = await QQ.search(keyWord: query, type: 2, size: 10)
              .timeout(timeout);
          final body = answer.data['req']?['data']?['body'];
          final List items = (body?['item_album'] ??
                  body?['album_list'] ??
                  body?['album'] ??
                  answer.data['data']?['album']?['list'] ??
                  []) as List;
          return [
            for (final item in items)
              if ((item['album_mid'] ??
                      item['mid'] ??
                      item['albumMID'] ??
                      item['albummid']) !=
                  null)
                MetadataCandidate(
                  source: ResultSource.qq,
                  id: (item['album_mid'] ??
                          item['mid'] ??
                          item['albumMID'] ??
                          item['albummid'])
                      .toString(),
                  name: (item['album_name'] ??
                          item['name'] ??
                          item['albumName'])
                          ?.toString() ??
                      '',
                  kind: 'album',
                  artist: (item['singer_name'] ??
                          (item['singer'] is String
                              ? item['singer']
                              : item['singer']?['name']) ??
                          (item['singer_list'] as List?)?.firstOrNull?['name'])
                          ?.toString() ??
                      '',
                  imageUrl: _formatQQImageUrl(
                    item['pic']?.toString(),
                    (item['pmid'] ??
                            item['album_mid'] ??
                            item['mid'] ??
                            item['albumMID'] ??
                            item['albummid'])
                        .toString(),
                    isArtist: false,
                  ),
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
      final rawImage = (c.kind == 'artist'
              ? entity['img1v1Url'] ?? entity['picUrl']
              : entity['picUrl'])
          ?.toString();
      image = formatNeteaseImageUrl(rawImage, size: 1024);
    } else if (source == ResultSource.qq) {
      if (c.kind == 'artist') {
        final answer = await QQ.singerInfo(singerMid: c.id).timeout(timeout);
        final data = answer.data['detail']?['data'] ?? answer.data['data'];
        final List singers =
            (data?['singer_list'] ?? data?['singer'] ?? []) as List;
        final matches = singers.where((s) =>
            (s['basic_info']?['singer_mid'] ??
                    s['singer_mid'] ??
                    s['singerMID'])
                ?.toString() ==
            c.id);
        if (matches.isNotEmpty) {
          final target = matches.first;
          final basic = target['basic_info'] ?? target;
          name = (basic['name'] ?? basic['singer_name'])?.toString() ?? name;
          final picObj = target['pic'];
          final picUrl = picObj is Map
              ? (picObj['pic'] ?? picObj['big_white'] ?? picObj['big_black'])
                  ?.toString()
              : target['singerPic']?.toString();
          if (picUrl != null && picUrl.isNotEmpty) {
            image = _formatQQImageUrl(picUrl, c.id, isArtist: true);
          }
        }
        image ??=
            'https://y.gtimg.cn/music/photo_new/T001R800x800M000${c.id}.jpg';
      } else {
        final answer = await QQ.albumInfo(albumMid: c.id).timeout(timeout);
        final Map? data =
            answer.data['albumInfo']?['data'] ?? answer.data['data'];
        final Map? basic =
            (data?['basicInfo'] ?? data?['basic_info']) as Map?;
        final pmid = (data?['pmid'] ?? basic?['pmid'] ?? c.id).toString();
        if (basic != null) {
          name = (basic['albumName'] ??
                  basic['album_name'] ??
                  basic['name'])
                  ?.toString() ??
              name;
        }
        final picUrl = (data?['pic'] ?? basic?['pic'])?.toString();
        if (picUrl != null && picUrl.isNotEmpty) {
          image = _formatQQImageUrl(picUrl, pmid, isArtist: false);
        }
        image ??=
            'https://y.gtimg.cn/music/photo_new/T002R800x800M000$pmid.jpg';
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
