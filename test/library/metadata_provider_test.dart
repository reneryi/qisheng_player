import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/metadata_provider.dart';
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

  test('searchEntities returns empty list for empty query', () async {
    const provider = PlatformMetadataProvider(ResultSource.netease);
    final results = await provider.searchEntities('   ', 'artist');
    expect(results, isEmpty);
  });
}
