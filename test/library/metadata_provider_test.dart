import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/metadata_provider.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/music_matcher.dart';

MetadataCandidate candidate(ResultSource source, String id, String name,
        {String kind = 'artist', String artist = '', bool evidence = true}) =>
    MetadataCandidate(
        source: source,
        id: id,
        name: name,
        kind: kind,
        artist: artist,
        evidence: evidence);

void main() {
  test('automatic artist matching rejects ambiguity on one platform', () {
    final result = selectAutomaticEntity([
      candidate(ResultSource.netease, '1', 'Same Artist'),
      candidate(ResultSource.netease, '2', 'Same Artist'),
    ], 'same artist', 'artist', '');
    expect(result, isNull);
  });

  test('automatic matching uses a single platform and requires evidence', () {
    final result = selectAutomaticEntity([
      candidate(ResultSource.netease, '1', 'Artist', evidence: false),
      candidate(ResultSource.qq, '2', 'Artist'),
    ], 'Artist', 'artist', '');
    expect(result?.source, ResultSource.qq);
    expect(result?.id, '2');
  });

  test('album matching requires exact album artist', () {
    final candidates = [
      candidate(ResultSource.netease, '1', 'Live',
          kind: 'album', artist: 'Singer A'),
    ];
    expect(selectAutomaticEntity(candidates, 'Live', 'album', ''), isNull);
    expect(
        selectAutomaticEntity(candidates, 'Live', 'album', 'Singer B'), isNull);
    expect(selectAutomaticEntity(candidates, 'Live', 'album', 'singer a')?.id,
        '1');
  });

  test('detail returns candidate directly if imageUrl is already present',
      () async {
    const provider = PlatformMetadataProvider(ResultSource.netease);
    final c = candidate(ResultSource.netease, '100', 'Artist Name')
        .toJson();
    c['url'] = 'https://example.com/avatar.jpg';
    final parsed = MetadataCandidate.fromJson(c);

    final detail = await provider.detail(parsed);
    expect(detail.imageUrl, 'https://example.com/avatar.jpg');
    expect(detail.id, '100');
  });

  test('formatNeteaseImageUrl appends param correctly', () {
    expect(
        formatNeteaseImageUrl('https://p1.music.126.net/abc/123.jpg'),
        'https://p1.music.126.net/abc/123.jpg?param=1024y1024');
    expect(
        formatNeteaseImageUrl('https://p1.music.126.net/abc/123.jpg?foo=bar'),
        'https://p1.music.126.net/abc/123.jpg?foo=bar&param=1024y1024');
    expect(
        formatNeteaseImageUrl('https://p1.music.126.net/abc/123.jpg?param=500y500'),
        'https://p1.music.126.net/abc/123.jpg?param=500y500');
    expect(
        formatNeteaseImageUrl('https://example.com/other.jpg'),
        'https://example.com/other.jpg');
    expect(formatNeteaseImageUrl(''), '');
    expect(formatNeteaseImageUrl(null), '');
  });

  test('searchEntities returns empty list for empty query', () async {
    const provider = PlatformMetadataProvider(ResultSource.netease);
    final results = await provider.searchEntities('   ', 'artist');
    expect(results, isEmpty);
  });

  test('searchEntities for 李乃文 downloads and validates without pixel or size errors', () async {
    const provider = PlatformMetadataProvider(ResultSource.netease);
    final results = await provider.searchEntities('李乃文', 'artist');
    expect(results, isNotEmpty);
    final first = results.first;
    expect(first.name, '李乃文');
    expect(first.imageUrl, contains('param=1024y1024'));

    final bytes = await ArtworkStore.download(first.imageUrl!);
    expect(bytes, isNotEmpty);
    expect(detectCoverExtension(bytes), isNotNull);
  });

  test('ArtworkStore.download raw 8493x8493 and large image succeeds and validates', () async {
    // Raw URL without parameters
    const rawUrl =
        'https://p2.music.126.net/VMwi2nUhK3l0FW520ONf4Q==/109951173797685174.jpg';
    final bytes = await ArtworkStore.download(rawUrl);
    expect(bytes, isNotEmpty);
    expect(detectCoverExtension(bytes), isNotNull);
  });

  test('searchEntities for QQ music artist and album succeeds', () async {
    const provider = PlatformMetadataProvider(ResultSource.qq);
    final artists = await provider.searchEntities('周杰伦', 'artist');
    expect(artists, isNotEmpty);
    final firstArtist = artists.first;
    expect(firstArtist.name, contains('周杰伦'));
    expect(firstArtist.imageUrl, isNotNull);
    final artistBytes = await ArtworkStore.download(firstArtist.imageUrl!);
    expect(artistBytes, isNotEmpty);
    expect(detectCoverExtension(artistBytes), isNotNull);

    final albums = await provider.searchEntities('范特西', 'album');
    expect(albums, isNotEmpty);
    final firstAlbum = albums.first;
    expect(firstAlbum.name, contains('范特西'));
    expect(firstAlbum.imageUrl, isNotNull);
    final albumBytes = await ArtworkStore.download(firstAlbum.imageUrl!);
    expect(albumBytes, isNotEmpty);
    expect(detectCoverExtension(albumBytes), isNotNull);
  });
}

