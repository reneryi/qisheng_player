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
}
