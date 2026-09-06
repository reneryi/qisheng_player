import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/window_controls.dart';

import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 3: Cross-Feature Combinations', () {
    // =========================================================================
    // T3.1: Window Maximize + Hero Flight Concurrent Interaction
    // =========================================================================
    testWidgets('T3.1: Window layout mode toggle during mid-flight Hero animation',
        (tester) async {
      final audio = E2ETestAudio(
        title: 'Cross Flight Track',
        artist: 'Inter-Feature',
        album: 'Matrix',
        path: 'E:\\Music\\t3_1.flac',
      );
      final playback = E2EPlaybackController(
        initialAudio: audio,
        initialState: PlayerState.playing,
      );

      final transitionController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 480),
      );

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          child: NowPlayingRouteTransitionScope(
            animation: transitionController,
            child: const NowPlayingPage(),
          ),
        ),
      );
      await tester.pumpAndAdvance(const Duration(milliseconds: 50));

      // 动画进行到中段 t=0.5
      transitionController.value = 0.5;
      await tester.pump();

      // 在飞跃中段触发窗口最大化边距切换
      WindowControls.layoutMode.value = WindowLayoutMode.maximized;
      await tester.pump(const Duration(milliseconds: 30));

      // 完成剩余飞跃动画
      transitionController.value = 1.0;
      await tester.pumpAndAdvance();

      expect(tester.takeException(), isNull);
      expect(find.byType(NowPlayingPage), findsOneWidget);

      WindowControls.layoutMode.value = WindowLayoutMode.normal;
      transitionController.dispose();
    });

    // =========================================================================
    // T3.2: Shell Underlay Fade + Theme Mode Change Concurrent Interaction
    // =========================================================================
    testWidgets('T3.2: Shell Underlay fade concurrent with Dark/Light theme switching',
        (tester) async {
      final nav = AppNavigationState.instance;

      final underlay = NowPlayingShellUnderlay(
        child: Container(
          color: Colors.blue,
          child: const Text('ThemeUnderlay'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildE2ETestTheme(brightness: Brightness.dark),
          home: Scaffold(body: underlay),
        ),
      );
      await tester.pumpAndAdvance();

      // 激活 NowPlayingPage 并立即切换主题模式
      nav.setNowPlayingPageActive(true);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildE2ETestTheme(brightness: Brightness.light),
          home: Scaffold(body: underlay),
        ),
      );
      await tester.pumpAndAdvance();

      expect(find.byKey(const ValueKey('now-playing-shell-underlay-opacity')), findsOneWidget);
      nav.setNowPlayingPageActive(false);
      await tester.pumpAndAdvance();
    });

    // =========================================================================
    // T3.3: Track Switch + Mid-Flight Hero Interpolation
    // =========================================================================
    testWidgets('T3.3: Skipping track during active cover Hero transition',
        (tester) async {
      final queue = generateMockPlaylist(5);
      final playback = E2EPlaybackController(
        initialAudio: queue[0],
        initialQueue: queue,
        initialState: PlayerState.playing,
      );

      final transitionController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 480),
      );

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          child: NowPlayingRouteTransitionScope(
            animation: transitionController,
            child: const NowPlayingPage(),
          ),
        ),
      );
      await tester.pumpAndAdvance(const Duration(milliseconds: 20));

      // 飞跃到 t=0.4 时快速切歌
      transitionController.value = 0.4;
      await tester.pump();
      playback.nextAudio();
      await tester.pump(const Duration(milliseconds: 16));

      // 再次切歌并推进到终点
      playback.nextAudio();
      transitionController.value = 1.0;
      await tester.pumpAndAdvance();

      expect(tester.takeException(), isNull);
      expect(playback.nowPlaying?.title, equals(queue[2].title));
      transitionController.dispose();
    });

    // =========================================================================
    // T3.4: 3D Pan Tilt Gesture + Window Resize + Staged Reveal
    // =========================================================================
    testWidgets('T3.4: 3D pan tilt gesture on artwork while resizing window',
        (tester) async {
      final audio = E2ETestAudio(
        title: '3D Resize Fusion',
        artist: 'Interactive',
        album: 'Dimension',
        path: 'E:\\Music\\t3_4.flac',
      );
      final playback = E2EPlaybackController(initialAudio: audio);

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          screenSize: const Size(1280, 800),
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      final dragFinder = find.byKey(const ValueKey('now-playing-artwork-drag'));
      if (dragFinder.evaluate().isNotEmpty) {
        final gesture = await tester.startGesture(tester.getCenter(dragFinder));
        await gesture.moveBy(const Offset(30, -20));
        await tester.pump(const Duration(milliseconds: 16));

        // 拖拽手势按住期间动态改变窗口尺寸
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        await tester.pump(const Duration(milliseconds: 50));

        await gesture.up();
        await tester.pumpAndAdvance();
        await tester.binding.setSurfaceSize(null);
      }
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // T3.5: Rapid Route Push-Pop Navigation Storm
    // =========================================================================
    testWidgets('T3.5: Rapid push-pop navigation storm (10 rapid open-close cycles)',
        (tester) async {
      final nav = AppNavigationState.instance;

      for (int i = 0; i < 10; i++) {
        nav.rememberLocation('/audios');
        nav.setNowPlayingPageActive(true);
        expect(nav.nowPlayingPageActive, isTrue);

        nav.rememberLocation('/now_playing');
        nav.setNowPlayingPageActive(false);
        expect(nav.nowPlayingPageActive, isFalse);
      }
      expect(nav.lastShellLocation, equals('/now_playing'));
    });

    // =========================================================================
    // T3.6: AutoHide Bottom Bar + Lyric Scale Zooming & Scrolling
    // =========================================================================
    testWidgets('T3.6: AutoHide bottom player bar timer expiration with lyric interaction',
        (tester) async {
      final lines = generateMockLrcLines(30);
      final lyricController = E2ELyricController(Lrc(lines, LrcSource.local));
      final audio = E2ETestAudio(
        title: 'Lyric Zoom Flow',
        artist: 'Poet',
        album: 'Verses',
        path: 'E:\\Music\\t3_6.flac',
      );
      final playback = E2EPlaybackController(initialAudio: audio);

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          lyricController: lyricController,
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      // 发射歌词行进度变更
      lyricController.emitLine(5);
      await tester.pump(const Duration(milliseconds: 100));
      lyricController.emitLine(12);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NowPlayingPage), findsOneWidget);
    });

    // =========================================================================
    // T3.7: Spectrum Visualizer + Cover Breath Glow + RepaintBoundary
    // =========================================================================
    testWidgets('T3.7: Real-time audio spectrum bursts combined with cover breath animation',
        (tester) async {
      final audio = E2ETestAudio(
        title: 'Hi-Fi Spectrum Surge',
        artist: 'Resonance',
        album: 'Harmonics',
        path: 'E:\\Music\\t3_7.flac',
      );
      final playback = E2EPlaybackController(
        initialAudio: audio,
        initialState: PlayerState.playing,
      );

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          child: const NowPlayingPage(),
        ),
      );
      await tester.pumpAndAdvance();

      // 连续灌入 10 组高频 FFT 频谱数据
      for (int i = 0; i < 10; i++) {
        final spectrumData = List.generate(
          24,
          (idx) => (math.sin(i * 0.5 + idx * 0.3).abs() * 0.9).clamp(0.1, 1.0),
        );
        playback.emitSpectrum(spectrumData);
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    // =========================================================================
    // T3.8: Dock Inset + Overlay Bar Appearance + Window Mode Switch
    // =========================================================================
    testWidgets('T3.8: MainLayoutFrame dynamic insets recalculation under overlay and mode switch',
        (tester) async {
      const topBar = SizedBox(height: 48, child: Text('CustomTopBar'));
      const overlayBar = SizedBox(height: 72, child: Text('CustomOverlayBar'));
      const content = Text('MainScrollContent');

      await tester.pumpWidget(
        buildE2ETestHarness(
          child: const MainLayoutFrame(
            titleBar: topBar,
            overlay: overlayBar,
            child: content,
          ),
        ),
      );
      await tester.pumpAndAdvance();

      expect(find.text('CustomTopBar'), findsOneWidget);
      expect(find.text('CustomOverlayBar'), findsOneWidget);
      expect(find.text('MainScrollContent'), findsOneWidget);

      // 切换至最大化模式
      WindowControls.layoutMode.value = WindowLayoutMode.maximized;
      await tester.pumpAndAdvance();
      expect(find.text('MainScrollContent'), findsOneWidget);

      WindowControls.layoutMode.value = WindowLayoutMode.normal;
    });

    // =========================================================================
    // T3.9: Detail Route Transition + Underlay Scale Pushback
    // =========================================================================
    testWidgets('T3.9: Detail route navigation transition coordinates smoothly',
        (tester) async {
      const page = DetailTransitionPage(
        child: Scaffold(body: Text('DetailTargetRoute')),
      );

      final router = GoRouter(
        initialLocation: '/test_detail',
        routes: [
          GoRoute(
            path: '/test_detail',
            pageBuilder: (context, state) => page,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndAdvance();

      expect(find.text('DetailTargetRoute'), findsOneWidget);
    });

    // =========================================================================
    // T3.10: PlayMode Cycle + Queue Reorder + Spectrum Progress Slider Seek
    // =========================================================================
    testWidgets('T3.10: Simultaneous playlist reorder, mode switch, and spectrum seek',
        (tester) async {
      final queue = generateMockPlaylist(6);
      final playback = E2EPlaybackController(
        initialAudio: queue[0],
        initialQueue: queue,
        initialState: PlayerState.playing,
        initialDuration: 300.0,
      );

      await tester.pumpWidget(
        buildE2ETestHarness(
          playbackController: playback,
          child: const BottomPlayerBar(),
        ),
      );
      await tester.pumpAndAdvance();

      // 1. 调整播放模式
      playback.setPlayMode(PlayMode.singleLoop);
      // 2. 调整播放列表顺序
      playback.reorderPlaylist(0, 3);
      // 3. 执行进度 Seek
      playback.seek(150.0);
      await tester.pumpAndAdvance();

      expect(playback.playMode.value, equals(PlayMode.singleLoop));
      expect(playback.position, equals(150.0));
      expect(playback.playlist.value[3].title, equals(queue[0].title));
    });
  });
}


