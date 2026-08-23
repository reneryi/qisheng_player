import 'package:qisheng_player/component/app_shell.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/app_preference.dart';
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

class _StatefulShellProbe extends StatefulWidget {
  const _StatefulShellProbe();

  @override
  State<_StatefulShellProbe> createState() => _StatefulShellProbeState();
}

class _StatefulShellProbeState extends State<_StatefulShellProbe> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('probe-$count'),
        TextButton(
          onPressed: () => setState(() => count++),
          child: const Text('increment-probe'),
        ),
      ],
    );
  }
}

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

  testWidgets(
    'AppShell reverses sidebar animation without rebuilding page state',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final originalCollapsed = AppPreference.instance.sidebarCollapsedLarge;
      AppPreference.instance.sidebarCollapsedLarge = false;
      addTearDown(() {
        AppPreference.instance.sidebarCollapsedLarge = originalCollapsed;
      });

      final audio = TestAudio(
        title: 'Animation Song',
        artist: 'Animation Artist',
        album: 'Animation Album',
        path: r'E:\Music\animation.flac',
      );
      final router = GoRouter(
        initialLocation: '/audios',
        routes: [
          GoRoute(
            path: '/audios',
            builder: (context, state) => const AppShell(
              page: _StatefulShellProbe(),
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

      await tester.tap(find.text('increment-probe'));
      await tester.pump();
      expect(find.text('probe-1'), findsOneWidget);

      final sideNav = find.byKey(const ValueKey('side-nav-large'));
      expect(tester.getSize(sideNav).width, 160);

      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));
      await tester.pump();
      expect(find.byTooltip('展开侧栏'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final collapsingWidth = tester.getSize(sideNav).width;
      expect(collapsingWidth, greaterThan(76));
      expect(collapsingWidth, lessThan(160));

      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right_rounded));
      await tester.pump();
      expect(find.byTooltip('收起侧栏'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getSize(sideNav).width, greaterThan(collapsingWidth));

      await tester.pumpAndSettle();
      expect(tester.getSize(sideNav).width, 160);
      expect(find.text('probe-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
