import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/page/now_playing_page/page.dart';
import 'package:coriander_player/play_service/desktop_lyric_service.dart';
import 'package:coriander_player/play_service/lyric_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets(
      'NowPlayingContentView stays stable without Scaffold ancestor',
      (tester) async {
    final audio = TestAudio(
      title: 'Overlay Song',
      artist: 'Overlay Artist',
      album: 'Overlay Album',
      path: r'E:\Music\overlay_now_playing.flac',
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
          home: const NowPlayingContentView(
            compact: false,
            styleMode: NowPlayingStyleMode.immersive,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
  });
}
