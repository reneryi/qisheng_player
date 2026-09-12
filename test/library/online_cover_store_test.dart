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

  test('OnlineCoverStore deduplicates searches for CUE tracks sharing sourcePath', () async {
    final searchCompleter = Completer<List<SongSearchResult>>();
    var searchCount = 0;
    final store = OnlineCoverStore.forTesting(
      persistFailures: (_) async {},
      search: (_) {
        searchCount++;
        return searchCompleter.future;
      },
    );
    final cueTrack1 = TestAudio(
      title: 'Track 1',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\album.cue#track1',
      sourcePath: r'E:\Music\album.flac',
    );
    final cueTrack2 = TestAudio(
      title: 'Track 2',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\album.cue#track2',
      sourcePath: r'E:\Music\album.flac',
    );

    final first = store.getCover(cueTrack1);
    final second = store.getCover(cueTrack2);
    await Future<void>.delayed(Duration.zero);

    expect(searchCount, 1);
    searchCompleter.complete(const []);
    expect(await Future.wait([first, second]), [null, null]);
  });

  test('OnlineCoverStore isolates CUE track search failure without blocking sibling tracks', () async {
    var track1SearchCount = 0;
    var track2SearchCount = 0;
    final cueTrack1 = TestAudio(
      title: 'Intro',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\album.cue#track1',
      sourcePath: r'E:\Music\album.flac',
    );
    final cueTrack2 = TestAudio(
      title: 'Hit Single',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\album.cue#track2',
      sourcePath: r'E:\Music\album.flac',
    );

    final store = OnlineCoverStore.forTesting(
      persistFailures: (_) async {},
      search: (audio) async {
        if (audio.path == cueTrack1.path) {
          track1SearchCount++;
          return const []; // 搜索失败
        }
        if (audio.path == cueTrack2.path) {
          track2SearchCount++;
          return [
            SongSearchResult(
              ResultSource.qq,
              'Hit Single',
              'Artist',
              'Album',
              200,
              coverUrl: 'https://example.com/cover.jpg',
            ),
          ];
        }
        return const [];
      },
    );

    // 1. 第 1 首搜索失败
    final result1 = await store.getCover(cueTrack1);
    expect(result1, isNull);
    expect(track1SearchCount, 1);
    expect(store.hasRecentFailureForTesting(cueTrack1.path), isTrue);
    expect(store.hasRecentFailureForTesting(cueTrack1.mediaPath), isFalse);

    // 2. 第 2 首请求封面，必须不被第 1 首的失败阻断，正常发起搜索
    await store.getCover(cueTrack2);
    expect(track2SearchCount, 1);
  });

  test('OnlineCoverStore.removeByPath removes cached entry and cleans failure records', () {
    const now = 2000000000000;
    final store = OnlineCoverStore.forTesting(
      nowMilliseconds: () => now,
      failedPaths: {
        r'E:\Music\test.flac': now,
        r'E:\Music\album.cue#track1': now,
      },
      persistFailures: (_) async {},
      search: (_) async => const [],
    );

    expect(store.hasRecentFailureForTesting(r'E:\Music\test.flac'), isTrue);
    store.removeByPath(r'E:\Music\test.flac');
    expect(store.hasRecentFailureForTesting(r'E:\Music\test.flac'), isFalse);

    expect(store.hasRecentFailureForTesting(r'E:\Music\album.cue#track1'), isTrue);
    store.removeByPath(r'E:\Music\album.cue#track1');
    expect(store.hasRecentFailureForTesting(r'E:\Music\album.cue#track1'), isFalse);
  });
}
