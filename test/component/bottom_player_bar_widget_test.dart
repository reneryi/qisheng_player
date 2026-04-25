import 'package:coriander_player/component/bottom_player_bar.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/play_service/desktop_lyric_service.dart';
import 'package:coriander_player/play_service/lyric_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('BottomPlayerBar stays stable on wide layout', (tester) async {
    final audio = TestAudio(
      title: 'Wide Song',
      artist: 'Wide Artist',
      album: 'Wide Album',
      path: r'E:\Music\wide.flac',
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: audio,
          queue: [audio, ...buildLongQueue()],
        ),
        lyricController: FakeLyricController(
          Lrc(buildLongLrcLines(), LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 1360,
            child: BottomPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Wide Song'), findsOneWidget);
    expect(find.byTooltip('打开播放队列'), findsOneWidget);
  });

  testWidgets('BottomPlayerBar stays stable on dense layout', (tester) async {
    final audio = TestAudio(
      title: 'Dense Song',
      artist: 'Dense Artist',
      album: 'Dense Album',
      path: r'E:\Music\dense.flac',
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: audio,
          queue: [audio, ...buildLongQueue()],
        ),
        lyricController: FakeLyricController(
          Lrc(buildLongLrcLines(), LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 920,
            child: BottomPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('打开播放队列'), findsOneWidget);
  });

  testWidgets('BottomPlayerBar survives volume slider width collapse',
      (tester) async {
    final audio = TestAudio(
      title: 'Resize Song',
      artist: 'Resize Artist',
      album: 'Resize Album',
      path: r'E:\Music\resize.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );
    final desktopLyric = FakeDesktopLyricController();

    Widget buildFrame(double width) {
      return buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: desktopLyric,
        child: Center(
          child: SizedBox(
            width: width,
            child: const BottomPlayerBar(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildFrame(1360));
    await tester.pump();
    expect(find.byType(Slider), findsWidgets);

    await tester.pumpWidget(buildFrame(920));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 260));

    expect(tester.takeException(), isNull);
  });

  testWidgets('BottomPlayerBar stays stable without Scaffold ancestor',
      (tester) async {
    final audio = TestAudio(
      title: 'Overlay Song',
      artist: 'Overlay Artist',
      album: 'Overlay Album',
      path: r'E:\Music\overlay.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );
    final desktopLyric = FakeDesktopLyricController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaybackController>.value(value: playback),
          ChangeNotifierProvider<LyricController>.value(value: lyric),
          ChangeNotifierProvider<DesktopLyricController>.value(
            value: desktopLyric,
          ),
        ],
        child: MaterialApp(
          theme: buildTestTheme(),
          home: const Center(
            child: SizedBox(
              width: 1280,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Overlay Song'), findsOneWidget);
  });
}
