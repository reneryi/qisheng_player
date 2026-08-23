import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/music_matcher.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  test('online cover cache keys stay fixed length for long Windows paths', () {
    final longPath = r'E:\音乐\' + ('很长的目录名' * 80) + r'\封面歌曲.flac';
    final key = onlineCoverCacheKey(longPath);

    expect(key, hasLength(64));
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      onlineCoverCacheKey(r'E:/MUSIC/Song.flac'),
      onlineCoverCacheKey(r'e:\music\song.flac'),
    );
  });

  test('online cover responses require an image MIME type', () {
    expect(
        isSupportedOnlineCoverContentType(ContentType('image', 'png')), true);
    expect(isSupportedOnlineCoverContentType(ContentType.text), false);
    expect(isSupportedOnlineCoverContentType(null), false);
  });

  test('online cover response reader rejects oversized bodies', () async {
    final response = Stream<List<int>>.fromIterable([
      [1, 2, 3],
      [4, 5, 6],
    ]);

    await expectLater(
      readBoundedCoverBytes(response, maxBytes: 5),
      throwsA(isA<FormatException>()),
    );
  });

  test('online cover response reader enforces a total timeout', () async {
    final response = Stream<List<int>>.periodic(
      const Duration(milliseconds: 5),
      (_) => const [1],
    ).take(20);

    await expectLater(
      readBoundedCoverBytes(
        response,
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('OnlineCoverStore deduplicates concurrent searches for one path',
      () async {
    final searchCompleter = Completer<List<SongSearchResult>>();
    var searchCount = 0;
    final store = OnlineCoverStore.forTesting(
      persistFailures: (_) async {},
      search: (_) {
        searchCount++;
        return searchCompleter.future;
      },
    );
    final audio = TestAudio(
      title: 'Cover Song',
      artist: 'Cover Artist',
      album: 'Cover Album',
      path: r'E:\Music\cover.flac',
    );

    final first = store.getCover(audio);
    final second = store.getCover(audio);
    await Future<void>.delayed(Duration.zero);

    expect(searchCount, 1);
    searchCompleter.complete(const []);
    expect(await Future.wait([first, second]), [null, null]);
  });

  test('OnlineCoverStore skips recent failures within the TTL', () async {
    const now = 2000000000000;
    var searchCount = 0;
    final audio = TestAudio(
      title: 'Recent Failure',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\recent.flac',
    );
    final store = OnlineCoverStore.forTesting(
      nowMilliseconds: () => now,
      failedPaths: {
        audio.path: now - const Duration(days: 2).inMilliseconds,
      },
      persistFailures: (_) async {},
      search: (_) async {
        searchCount++;
        return const [];
      },
    );

    expect(await store.getCover(audio), isNull);
    expect(searchCount, 0);
  });

  test('OnlineCoverStore retries and refreshes an expired failure', () async {
    const now = 2000000000000;
    var searchCount = 0;
    final persisted = <Map<String, int>>[];
    final audio = TestAudio(
      title: 'Expired Failure',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\expired.flac',
    );
    final store = OnlineCoverStore.forTesting(
      nowMilliseconds: () => now,
      failedPaths: {
        audio.path: now - const Duration(days: 8).inMilliseconds,
      },
      persistFailures: (failures) async => persisted.add(failures),
      search: (_) async {
        searchCount++;
        return const [];
      },
    );

    expect(await store.getCover(audio), isNull);
    expect(searchCount, 1);
    expect(persisted.last[audio.path], now);
  });

  test('retainRecentCoverFailures removes entries older than seven days', () {
    const now = 2000000000000;
    final result = retainRecentCoverFailures({
      'recent': now - const Duration(days: 7).inMilliseconds,
      'expired': now - const Duration(days: 7, milliseconds: 1).inMilliseconds,
    }, now);

    expect(result, {'recent': now - const Duration(days: 7).inMilliseconds});
  });
}
