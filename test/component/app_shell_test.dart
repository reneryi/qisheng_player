import 'package:qisheng_player/component/app_shell.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('queue dialog keeps shell chrome visible', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Queue Song',
      artist: 'Queue Artist',
      album: 'Queue Album',
      path: r'E:\Music\queue.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );

    final router = GoRouter(
      initialLocation: '/audios',
      routes: [
        GoRoute(
          path: '/audios',
          builder: (context, state) => const AppShell(
            page: Center(child: Text('测试页面')),
            pageIdentity: '/audios',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(
            value: ThemeProvider.instance,
          ),
          ChangeNotifierProvider<PlaybackController>.value(value: playback),
          ChangeNotifierProvider<LyricController>.value(
            value: FakeLyricController(
              Lrc(buildLongLrcLines(), LrcSource.local),
            ),
          ),
          ChangeNotifierProvider<DesktopLyricController>.value(
            value: FakeDesktopLyricController(),
          ),
        ],
        child: MaterialApp.router(
          theme: buildTestTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TitleBar), findsOneWidget);
    expect(find.byType(BottomPlayerBar), findsOneWidget);

    await tester.tap(find.byTooltip('打开播放队列'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('播放队列'), findsOneWidget);
    expect(find.byType(TitleBar), findsOneWidget);
    expect(find.byType(BottomPlayerBar), findsOneWidget);
  });

  testWidgets('AppShell keeps page transition content visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Shell Song',
      artist: 'Shell Artist',
      album: 'Shell Album',
      path: r'E:\Music\shell.flac',
    );
    final router = GoRouter(
      initialLocation: '/audios',
      routes: [
        GoRoute(
          path: '/audios',
          builder: (context, state) => const AppShell(
            page: Center(child: Text('切页动画测试')),
            pageIdentity: '/audios',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(
            value: ThemeProvider.instance,
          ),
          ChangeNotifierProvider<PlaybackController>.value(
            value: FakePlaybackController(audio: audio, queue: [audio]),
          ),
          ChangeNotifierProvider<LyricController>.value(
            value: FakeLyricController(
              Lrc(buildLongLrcLines(), LrcSource.local),
            ),
          ),
          ChangeNotifierProvider<DesktopLyricController>.value(
            value: FakeDesktopLyricController(),
          ),
        ],
        child: MaterialApp.router(
          theme: buildTestTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('切页动画测试'), findsOneWidget);
  });
}
