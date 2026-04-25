import 'package:coriander_player/component/horizontal_lyric_view.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('HorizontalLyricView ignores out-of-range lyric indices',
      (tester) async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines().take(2).toList(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const SizedBox(
          width: 400,
          height: 48,
          child: HorizontalLyricView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    lyric.emitLine(56);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('HorizontalLyricView handles rapid lyric line changes',
      (tester) async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\rapid.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines().take(5).toList(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const SizedBox(
          width: 400,
          height: 48,
          child: HorizontalLyricView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    lyric
      ..emitLine(1)
      ..emitLine(3)
      ..emitLine(2)
      ..emitLine(99);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
  });
}
