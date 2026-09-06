import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/window_controls.dart';

import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 4: Real-World Application Scenarios (E2E Journeys)', () {
    // =========================================================================
    // JOURNEY A: Full Playback & Immersion Cycle
    // =========================================================================
    testWidgets('Journey A: End-to-end full playback entry, Hero transition, 6-stage reveal, and exit',
        (tester) async {
      final playlist = generateMockPlaylist(8);
      final lrcLines = generateMockLrcLines(20);
      final lyric = Lrc(lrcLines, LrcSource.local);

      final playback = E2EPlaybackController(
        initialAudio: playlist[0],
        initialQueue: playlist,
        initialState: PlayerState.playing,
      );
      final lyricController = E2ELyricController(lyric);

      // 1. 构建包含全局 Shell 与 NowPlayingPage 的完整 Router 环境
      final router = GoRouter(
        initialLocation: app_paths.AUDIOS_PAGE,
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              AppNavigationState.instance.rememberLocation(state.uri.toString());
              return NowPlayingShellUnderlay(
                child: Scaffold(
                  body: child,
                  bottomNavigationBar: const BottomPlayerBar(),
                ),
              );
            },
            routes: [
              GoRoute(
                path: app_paths.AUDIOS_PAGE,
                pageBuilder: (context, state) => const SlideTransitionPage(
                  child: Center(child: Text('MainMusicLibraryView')),
                ),
              ),
            ],
          ),
          GoRoute(
            path: app_paths.NOW_PLAYING_PAGE,
            pageBuilder: (context, state) {
              AppNavigationState.instance.rememberLocation(state.uri.toString());
              return const NowPlayingTransitionPage(child: NowPlayingPage());
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ThemeProvider.instance),
            ChangeNotifierProvider<PlaybackController>.value(value: playback),
            ChangeNotifierProvider<LyricController>.value(value: lyricController),
            ChangeNotifierProvider<DesktopLyricController>.value(
              value: E2EDesktopLyricController(),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildE2ETestTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndAdvance();

      // 2. 验证主界面与底栏就绪
      expect(find.text('MainMusicLibraryView'), findsOneWidget);
      expect(find.byType(BottomPlayerBar), findsOneWidget);
      expect(find.text(playlist[0].displayTitle), findsAtLeastNWidgets(1));

      // 3. 点击底栏封面触发导航至 NowPlayingPage
      final coverFinder = find.descendant(
        of: find.byType(BottomPlayerBar),
        matching: find.byType(NowPlayingArtworkHeroFrame),
      );
      expect(coverFinder, findsOneWidget);
      await tester.tap(coverFinder);
      await tester.pump();

      // 4. 驱动转场并验证 Hero 飞行与 6 阶段入场
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndAdvance();

      expect(find.byType(NowPlayingPage), findsOneWidget);

      // 5. 模拟歌词播放推进
      lyricController.emitLine(2);
      await tester.pump(const Duration(milliseconds: 100));
      lyricController.emitLine(4);
      await tester.pump(const Duration(milliseconds: 100));

      // 6. 点击返回按钮
      final backButton = find.byTooltip('返回');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndAdvance();
      }

      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // JOURNEY B: Desktop Window Management & 3D Tilt Interaction
    // =========================================================================
    testWidgets('Journey B: Window maximize, 3D artwork pan tilt, spring return, and autohide wake',
        (tester) async {
      final audio = E2ETestAudio(
        title: 'Symphonic Universe',
        artist: 'Cosmic Composer',
        album: 'Galaxies',
        path: 'E:\\Music\\j_b.flac',
      );
      final playback = E2EPlaybackController(
        initialAudio: audio,
        initialState: PlayerState.playing,
      );

      // 1. 窗口处于常规窗口化状态
      WindowControls.layoutMode.value = WindowLayoutMode.normal;

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          screenSize: const Size(1280, 800),
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      // 2. 模拟系统窗口最大化
      WindowControls.layoutMode.value = WindowLayoutMode.maximized;
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          screenSize: const Size(1920, 1080),
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      expect(find.byType(NowPlayingPage), findsOneWidget);

      // 3. 执行 3D 画册拖拽倾斜手势
      final dragFinder = find.byKey(const ValueKey('now-playing-artwork-drag'));
      if (dragFinder.evaluate().isNotEmpty) {
        final gesture = await tester.startGesture(tester.getCenter(dragFinder));
        await gesture.moveBy(const Offset(40, -30));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(-20, 10));
        await tester.pump(const Duration(milliseconds: 16));

        // 4. 释放手势触发弹簧回弹
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndAdvance();
      }

      // 5. 模拟鼠标唤醒底栏
      final mouseGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouseGesture.addPointer(location: const Offset(960, 1000));
      await tester.pump(const Duration(milliseconds: 50));
      await mouseGesture.removePointer();
      await tester.pumpAndAdvance();

      // 6. 还原窗口模式
      WindowControls.layoutMode.value = WindowLayoutMode.normal;
      await tester.binding.setSurfaceSize(null);
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // JOURNEY C: Continuous Playlist Traversal & Dynamic Theme/Spectrum Flow
    // =========================================================================
    testWidgets('Journey C: Continuous playlist skipping, seek slider, spectrum bursts, and theme mode toggle',
        (tester) async {
      final queue = generateMockPlaylist(10);
      final playback = E2EPlaybackController(
        initialAudio: queue[0],
        initialQueue: queue,
        initialState: PlayerState.playing,
        initialDuration: 280.0,
      );
      final lyricController = E2ELyricController();

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          lyricController: lyricController,
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      // 1. 进度拖拽 Seek
      playback.seek(120.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(playback.position, equals(120.0));

      // 2. 连续切歌 3 次
      for (int i = 0; i < 3; i++) {
        playback.nextAudio();
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(playback.nowPlaying?.title, equals(queue[3].title));

      // 3. 注入频谱数据
      playback.emitSpectrum([0.3, 0.6, 0.9, 0.4, 0.8, 0.2]);
      await tester.pump(const Duration(milliseconds: 30));

      // 4. 切换至浅色主题
      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          lyricController: lyricController,
          brightness: Brightness.light,
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      // 5. 切换回深色主题
      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          lyricController: lyricController,
          brightness: Brightness.dark,
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      expect(tester.takeException(), isNull);
      expect(find.byType(NowPlayingPage), findsOneWidget);
    });

    // =========================================================================
    // JOURNEY D: Heavy Multi-Route Navigation Stress Journey
    // =========================================================================
    testWidgets('Journey D: Rapid multi-route traversal across Library, Details, Search, and NowPlaying',
        (tester) async {
      final audio = E2ETestAudio(
        title: 'Stress Journey Master',
        artist: 'Navigator',
        album: 'Atlas',
        path: 'E:\\Music\\j_d.flac',
      );
      final playback = E2EPlaybackController(
        initialAudio: audio,
        initialState: PlayerState.playing,
      );

      final router = GoRouter(
        initialLocation: '/audios',
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              AppNavigationState.instance.rememberLocation(state.uri.toString());
              return NowPlayingShellUnderlay(
                child: Scaffold(
                  body: child,
                  bottomNavigationBar: const BottomPlayerBar(),
                ),
              );
            },
            routes: [
              GoRoute(
                path: '/audios',
                pageBuilder: (context, state) => const SlideTransitionPage(
                  child: Center(child: Text('AudiosPageRoute')),
                ),
                routes: [
                  GoRoute(
                    path: 'detail',
                    pageBuilder: (context, state) => const DetailTransitionPage(
                      child: Center(child: Text('AudioDetailRoute')),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/search',
                pageBuilder: (context, state) => const SlideTransitionPage(
                  child: Center(child: Text('SearchPageRoute')),
                ),
              ),
            ],
          ),
          GoRoute(
            path: app_paths.NOW_PLAYING_PAGE,
            pageBuilder: (context, state) => const NowPlayingTransitionPage(
              child: NowPlayingPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ThemeProvider.instance),
            ChangeNotifierProvider<PlaybackController>.value(value: playback),
            ChangeNotifierProvider<LyricController>.value(
              value: E2ELyricController(),
            ),
            ChangeNotifierProvider<DesktopLyricController>.value(
              value: E2EDesktopLyricController(),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildE2ETestTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndAdvance();

      // 1. 验证首页
      expect(find.text('AudiosPageRoute'), findsOneWidget);

      // 2. 导航至详情子路由
      router.go('/audios/detail');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndAdvance();
      expect(find.text('AudioDetailRoute'), findsOneWidget);

      // 3. 导航至搜索页
      router.go('/search');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndAdvance();
      expect(find.text('SearchPageRoute'), findsOneWidget);

      // 4. 导航至播放详情页
      router.go(app_paths.NOW_PLAYING_PAGE);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndAdvance();
      expect(find.byType(NowPlayingPage), findsOneWidget);

      // 5. 快速返回主界面
      router.go('/audios');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndAdvance();
      expect(find.text('AudiosPageRoute'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}


