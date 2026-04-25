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
}
