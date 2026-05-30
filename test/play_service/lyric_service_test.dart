import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  Lrc lyricWithLine(String content) => Lrc(
        [
          LrcLine(
            Duration.zero,
            content,
            isBlank: false,
            length: const Duration(seconds: 5),
          ),
        ],
        LrcSource.local,
      );

  Lrc lyricWithLines(List<String> contents) => Lrc(
        List.generate(
          contents.length,
          (index) => LrcLine(
            Duration(seconds: index * 5),
            contents[index],
            isBlank: false,
            length: const Duration(seconds: 5),
          ),
        ),
        LrcSource.local,
      );

  test('LyricService ignores stale lyric loads after switching songs',
      () async {
    final firstAudio = TestAudio(
      title: 'First',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\first.flac',
    );
    final secondAudio = TestAudio(
      title: 'Second',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\second.flac',
    );
    final playback = FakePlaybackController(
      audio: firstAudio,
      queue: [firstAudio, secondAudio],
    );
    final desktopLyric = FakeDesktopLyricController();
    final firstCompleter = Completer<Lyric?>();
    final secondCompleter = Completer<Lyric?>();
    final service = LyricService.forTest(
      playbackService: playback,
      desktopLyricService: desktopLyric,
      getDefaultLyric: (audio, _) {
        if (audio.path == firstAudio.path) return firstCompleter.future;
        if (audio.path == secondAudio.path) return secondCompleter.future;
        return Future.value(null);
      },
    );

    addTearDown(service.dispose);
    addTearDown(playback.dispose);

    service.updateLyric();
    playback.setNowPlaying(secondAudio, queue: [firstAudio, secondAudio]);
    service.updateLyric();

    firstCompleter.complete(lyricWithLine('old lyric'));
    await Future<void>.delayed(Duration.zero);
    expect(desktopLyric.sentLyricLines, isEmpty);

    secondCompleter.complete(lyricWithLine('new lyric'));
    await Future<void>.delayed(Duration.zero);

    expect(desktopLyric.sentLyricLines, hasLength(1));
    expect(
        (desktopLyric.sentLyricLines.single as LrcLine).content, 'new lyric');
  });

  test('LyricService refresh sends current line after now playing clears lyric',
      () async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final desktopLyric = FakeDesktopLyricController();
    final service = LyricService.forTest(
      playbackService: playback,
      desktopLyricService: desktopLyric,
      getDefaultLyric: (_, __) => Future.value(lyricWithLine('current lyric')),
    );

    addTearDown(service.dispose);
    addTearDown(playback.dispose);

    service.updateLyric();
    await Future<void>.delayed(Duration.zero);
    desktopLyric.sentLyricLines.clear();

    desktopLyric.sendNowPlayingMessage(audio);
    service.refreshCurrentLyricLine();
    await Future<void>.delayed(Duration.zero);

    expect(desktopLyric.sentNowPlaying.single, audio);
    expect(desktopLyric.sentLyricLines, hasLength(1));
    expect(
      (desktopLyric.sentLyricLines.single as LrcLine).content,
      'current lyric',
    );
  });

  test(
      'LyricService resends current line after auto next now playing clears desktop lyric',
      () async {
    final firstAudio = TestAudio(
      title: 'First',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\first.flac',
    );
    final secondAudio = TestAudio(
      title: 'Second',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\second.flac',
    );
    final playback = FakePlaybackController(
      audio: firstAudio,
      queue: [firstAudio, secondAudio],
    );
    final desktopLyric = FakeDesktopLyricController();
    final service = LyricService.forTest(
      playbackService: playback,
      desktopLyricService: desktopLyric,
      getDefaultLyric: (audio, _) => Future.value(
        lyricWithLine('${audio.title} lyric'),
      ),
    );

    addTearDown(service.dispose);
    addTearDown(playback.dispose);

    playback.setNowPlaying(secondAudio, queue: [firstAudio, secondAudio]);
    service.updateLyric();
    await Future<void>.delayed(Duration.zero);

    desktopLyric.sendNowPlayingMessage(secondAudio);
    service.refreshCurrentLyricLine();
    await Future<void>.delayed(Duration.zero);

    expect(desktopLyric.sentMessages, hasLength(3));
    expect(desktopLyric.sentMessages[0], isA<LrcLine>());
    expect(
      (desktopLyric.sentMessages[0] as LrcLine).content,
      'Second lyric',
    );
    expect(desktopLyric.sentMessages[1], secondAudio);
    expect(desktopLyric.sentMessages[2], isA<LrcLine>());
    expect(
      (desktopLyric.sentMessages[2] as LrcLine).content,
      'Second lyric',
    );
  });

  test(
      'LyricService corrects current line when playback position moves backward',
      () async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\rewind.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final desktopLyric = FakeDesktopLyricController();
    final service = LyricService.forTest(
      playbackService: playback,
      desktopLyricService: desktopLyric,
      getDefaultLyric: (_, __) => Future.value(
        lyricWithLines(['first line', 'second line', 'third line']),
      ),
    );

    addTearDown(service.dispose);
    addTearDown(playback.dispose);

    service.updateLyric();
    await Future<void>.delayed(Duration.zero);
    desktopLyric.sentLyricLines.clear();

    playback.seek(13);
    await Future<void>.delayed(Duration.zero);
    expect(
      (desktopLyric.sentLyricLines.last as LrcLine).content,
      'third line',
    );

    playback.seek(2);
    await Future<void>.delayed(Duration.zero);
    expect(
      (desktopLyric.sentLyricLines.last as LrcLine).content,
      'first line',
    );
  });
}
