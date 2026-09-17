import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/utils.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestAudio audio({
    String title = 'Hello',
    String artist = 'Test Artist',
    String album = 'Test Album',
  }) {
    return TestAudio(
      title: title,
      artist: artist,
      album: album,
      path: r'E:\Music\match.flac',
    );
  }

  test('normalizeForMatch removes case punctuation and common suffixes', () {
    expect(normalizeForMatch('  HELLO! (Live) '), 'hello');
    expect(normalizeForMatch('Song - Remix 2024'), 'song');
    expect(normalizeForMatch('中文・歌曲【现场】'), '中文歌曲');
  });

  test('normalizedSimilarity uses normalized edit distance', () {
    expect(normalizedSimilarity('Hello', 'HELLO (Live)'), 1.0);
    expect(normalizedSimilarity('ABC', 'BAC'), closeTo(1 / 3, 0.0001));
    expect(normalizedSimilarity('Hello', 'Hello World Hello World'),
        lessThan(0.3));
  });

  test('computeMusicMatchScore applies title artist and album weights', () {
    final source = audio();
    expect(
      computeMusicMatchScore(
        source,
        'HELLO (Live)',
        'Test Artist!',
        'Test Album',
      ),
      1.0,
    );
    expect(
      computeMusicMatchScore(source, 'Different', 'Other', 'Elsewhere'),
      lessThan(minimumOnlineLyricMatchScore),
    );
  });

  test('buildMusicSearchQuery includes known artist and limits runes', () {
    expect(buildMusicSearchQuery(audio()), 'Hello Test Artist');
    expect(
      buildMusicSearchQuery(audio(artist: '未知艺术家')),
      'Hello',
    );
    expect(
      buildMusicSearchQuery(
        audio(title: List.filled(60, '歌').join()),
        maxRunes: 50,
      ).runes.length,
      50,
    );
  });

  test('searchMusicSources starts all providers concurrently and sorts',
      () async {
    final started = <String>[];
    final kugou = Completer<List<SongSearchResult>>();
    final netease = Completer<List<SongSearchResult>>();
    final qq = Completer<List<SongSearchResult>>();
    final source = audio();

    final future = searchMusicSources(
      source,
      kugou: (query, audio) {
        started.add('kugou:$query');
        return kugou.future;
      },
      netease: (query, audio) {
        started.add('netease:$query');
        return netease.future;
      },
      qq: (query, audio) {
        started.add('qq:$query');
        return qq.future;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(started, hasLength(3));

    kugou.complete([SongSearchResult(ResultSource.kugou, 'a', 'a', 'a', 0.4)]);
    netease
        .complete([SongSearchResult(ResultSource.netease, 'b', 'b', 'b', 0.9)]);
    qq.complete([SongSearchResult(ResultSource.qq, 'c', 'c', 'c', 0.6)]);
    final result = await future;

    expect(result.map((item) => item.score), [0.9, 0.6, 0.4]);
  });

  test('searchMusicSources isolates a provider failure', () async {
    final result = await searchMusicSources(
      audio(),
      kugou: (_, __) async => throw StateError('offline'),
      netease: (_, __) async => [
        SongSearchResult(ResultSource.netease, 'ok', 'ok', 'ok', 0.8),
      ],
      qq: (_, __) async => const [],
    );

    expect(result, hasLength(1));
    expect(result.single.source, ResultSource.netease);
  });

  test('selectMatchedResult rejects candidates below the lyric threshold', () {
    final low = SongSearchResult(ResultSource.qq, 'low', '', '', 0.59);
    final accepted = SongSearchResult(ResultSource.qq, 'high', '', '', 0.6);

    expect(selectMatchedResult([low]), isNull);
    expect(selectMatchedResult([accepted]), same(accepted));
  });

  group('fromNeteaseSearchResult', () {
    test('parses cloudsearch format with al.picUrl, ar artists, dt duration', () {
      final source = audio(title: '海阔天空', artist: 'Beyond', album: '乐与怒');
      final raw = {
        'id': 347230,
        'name': '海阔天空',
        'ar': [
          {'id': 11127, 'name': 'Beyond'}
        ],
        'al': {
          'id': 34209,
          'name': '乐与怒',
          'picUrl': 'http://p1.music.126.net/q6cm6Pk70YArijk1_QDoEg==/109951163984013003.jpg'
        },
        'dt': 324000
      };

      final result = SongSearchResult.fromNeteaseSearchResult(raw, source);

      expect(result.source, ResultSource.netease);
      expect(result.title, '海阔天空');
      expect(result.artists, 'Beyond');
      expect(result.album, '乐与怒');
      expect(result.coverUrl,
          'http://p1.music.126.net/q6cm6Pk70YArijk1_QDoEg==/109951163984013003.jpg');
      expect(result.albumId, '34209');
      expect(result.neteaseSongId, '347230');
      expect(result.durationMs, 324000);
      expect(result.artistRefs.single.id, '11127');
      expect(result.score, 1.0);
    });

    test('supports legacy format with album.picUrl and artists', () {
      final source = audio();
      final raw = {
        'id': 123,
        'name': 'Hello',
        'artists': [
          {'id': 456, 'name': 'Test Artist'}
        ],
        'album': {
          'id': 789,
          'name': 'Test Album',
          'picUrl': 'https://example.com/cover.jpg'
        },
        'duration': 180000
      };

      final result = SongSearchResult.fromNeteaseSearchResult(raw, source);

      expect(result.coverUrl, 'https://example.com/cover.jpg');
      expect(result.durationMs, 180000);
      expect(result.albumId, '789');
    });
  });

  group('fromKugouSearchResult', () {
    test('extracts union_cover and replaces {size} with 800', () {
      final source = audio(title: 'LOVE 2000', artist: '遠野ひかる', album: 'LOVE 2000');
      final raw = {
        'hash': '31f776a095c8a596301166f4642e1769',
        'songname': 'LOVE 2000',
        'singername': '遠野ひかる',
        'album_name': 'LOVE 2000',
        'album_id': '98852971',
        'duration': 263,
        'trans_param': {
          'union_cover': 'http://imge.kugou.com/stdmusic/{size}/20220510/20220510154611248287.jpg'
        }
      };

      final result = SongSearchResult.fromKugouSearchResult(raw, source);

      expect(result.source, ResultSource.kugou);
      expect(result.title, 'LOVE 2000');
      expect(result.artists, '遠野ひかる');
      expect(result.album, 'LOVE 2000');
      expect(result.coverUrl,
          'http://imge.kugou.com/stdmusic/800/20220510/20220510154611248287.jpg');
      expect(result.kugouSongHash, '31f776a095c8a596301166f4642e1769');
      expect(result.albumId, '98852971');
      expect(result.durationMs, 263000);
      expect(result.score, 1.0);
    });

    test('falls back to imgurl and replaces {size} with 800', () {
      final source = audio();
      final raw = {
        'hash': 'abc',
        'songname': 'Hello',
        'singername': 'Test Artist',
        'album_name': 'Test Album',
        'imgurl': 'http://imge.kugou.com/stdmusic/{size}/test.jpg',
        'duration': 120
      };

      final result = SongSearchResult.fromKugouSearchResult(raw, source);
      expect(result.coverUrl, 'http://imge.kugou.com/stdmusic/800/test.jpg');
      expect(result.durationMs, 120000);
    });
  });

  group('fromQQSearchResult', () {
    test('handles valid mid and generates 800x800 cover url', () {
      final source = audio(title: '晴天', artist: '周杰伦', album: '叶惠美');
      final raw = {
        'id': 107192078,
        'name': '晴天',
        'singer': [
          {'name': '周杰伦', 'mid': '0025NhlN2yWrP4'}
        ],
        'album': {
          'title': '叶惠美',
          'mid': '000MkMni19ClKG'
        },
        'interval': 269
      };

      final result = SongSearchResult.fromQQSearchResult(raw, source);

      expect(result.source, ResultSource.qq);
      expect(result.title, '晴天');
      expect(result.artists, '周杰伦');
      expect(result.album, '叶惠美');
      expect(result.coverUrl,
          'https://y.qq.com/music/photo_new/T002R800x800M000000MkMni19ClKG.jpg');
      expect(result.albumId, '000MkMni19ClKG');
      expect(result.durationMs, 269000);
      expect(result.score, 1.0);
    });

    test('guards against empty or whitespace mid preventing 404 fake url', () {
      final source = audio(title: 'Live Song', artist: 'Live Artist', album: '');
      final rawEmptyMid = {
        'id': 9999,
        'name': 'Live Song',
        'singer': [
          {'name': 'Live Artist', 'mid': '00112233'}
        ],
        'album': {
          'title': '',
          'mid': ''
        },
        'interval': 200
      };

      final result = SongSearchResult.fromQQSearchResult(rawEmptyMid, source);

      expect(result.coverUrl, isNull);
      expect(result.albumId, isNull);

      final rawWhitespaceMid = {
        'id': 9998,
        'name': 'Live Song',
        'singer': [
          {'name': 'Live Artist', 'mid': '00112233'}
        ],
        'album': {
          'title': '',
          'mid': '   '
        },
        'interval': 200
      };

      final resultWs = SongSearchResult.fromQQSearchResult(rawWhitespaceMid, source);
      expect(resultWs.coverUrl, isNull);
      expect(resultWs.albumId, isNull);
    });
  });
}
