import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/page/now_playing_page/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets(
      'NowPlayingContentView immersive mode handles long lyrics without overflow',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Immersive Song',
      artist: 'Immersive Artist',
      album: 'Immersive Album',
      path: r'E:\Music\immersive.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
  });

  testWidgets(
      'NowPlayingContentView immersive compact mode handles long lyrics without overflow',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(980, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Compact Song',
      artist: 'Compact Artist',
      album: 'Compact Album',
      composer:
          'Joe Hisaishi / Alexandre Desplat / Hans Zimmer / Yoko Kanno / Ryuichi Sakamoto',
      arranger:
          'Yvan Cassar / Quincy Jones / Vince Mendoza / David Campbell / Teddy Riley',
      path: r'E:\Music\compact.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const NowPlayingContentView(
          compact: true,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
  });

  testWidgets('NowPlayingContentView handles rapid lyric line changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Rapid Song',
      artist: 'Rapid Artist',
      album: 'Rapid Album',
      path: r'E:\Music\rapid-now-playing.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    lyric
      ..emitLine(3)
      ..emitLine(12)
      ..emitLine(8)
      ..emitLine(200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
