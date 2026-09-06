import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/audio_lyric_preview_panel.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('Adversarial M1-M3: Lifecycle & Resource Leak Safety', () {
    testWidgets(
      'UniPage safely disposes AnimationController mid-flight during expansion without ticker leak',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Lifecycle Song',
          artist: 'Artist',
          album: 'Album',
          path: r'E:\Music\lifecycle.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        var showRightPane = false;
        var mountedInTree = true;
        late StateSetter updateTree;

        await tester.pumpWidget(
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
            child: MaterialApp(
              theme: buildTestTheme(),
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateTree = setState;
                  if (!mountedInTree) {
                    return const Scaffold(body: Text('Unmounted'));
                  }
                  return Scaffold(
                    body: UniPage<TestAudio>(
                      title: 'Lifecycle',
                      pref: PagePreference(0, SortOrder.ascending, ContentView.list),
                      enableShufflePlay: false,
                      enableSortMethod: false,
                      enableSortOrder: false,
                      enableContentViewSwitch: false,
                      contentList: [audio],
                      contentBuilder: (c, item, i, _) => AudioTile(
                        audioIndex: i,
                        playlist: [item],
                      ),
                      rightPaneBuilder: (_) => Container(color: Colors.blue),
                      showRightPane: showRightPane,
                      rightPaneWidth: 284,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 触发展开动画
        updateTree(() => showRightPane = true);
        await tester.pump();
        // 推进 50ms（处于动画中途）
        await tester.pump(const Duration(milliseconds: 50));

        // 动画未完成时直接卸载 UniPage
        updateTree(() => mountedInTree = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 断言无任何 Ticker 泄漏或生命周期异常
        expect(tester.takeException(), isNull);
        expect(find.text('Unmounted'), findsOneWidget);
      },
    );

    testWidgets(
      'UniPage safely disposes AnimationController mid-flight during reverse collapse',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Collapse Song',
          artist: 'Artist',
          album: 'Album',
          path: r'E:\Music\collapse.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        var showRightPane = true;
        var mountedInTree = true;
        late StateSetter updateTree;

        await tester.pumpWidget(
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
            child: MaterialApp(
              theme: buildTestTheme(),
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateTree = setState;
                  if (!mountedInTree) {
                    return const Scaffold(body: Text('Unmounted'));
                  }
                  return Scaffold(
                    body: UniPage<TestAudio>(
                      title: 'Collapse',
                      pref: PagePreference(0, SortOrder.ascending, ContentView.list),
                      enableShufflePlay: false,
                      enableSortMethod: false,
                      enableSortOrder: false,
                      enableContentViewSwitch: false,
                      contentList: [audio],
                      contentBuilder: (c, item, i, _) => AudioTile(
                        audioIndex: i,
                        playlist: [item],
                      ),
                      rightPaneBuilder: (_) => Container(color: Colors.red),
                      showRightPane: showRightPane,
                      rightPaneWidth: 284,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 触发收起动画
        updateTree(() => showRightPane = false);
        await tester.pump();
        // 推进 60ms（收起退场中）
        await tester.pump(const Duration(milliseconds: 60));

        // 卸载
        updateTree(() => mountedInTree = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('Unmounted'), findsOneWidget);
      },
    );

    testWidgets(
      'UniPage survives rapid successive toggles of showRightPane',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Flap Song',
          artist: 'Artist',
          album: 'Album',
          path: r'E:\Music\flap.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        var showRightPane = false;
        late StateSetter updateTree;

        await tester.pumpWidget(
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
            child: MaterialApp(
              theme: buildTestTheme(),
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateTree = setState;
                  return Scaffold(
                    body: UniPage<TestAudio>(
                      title: 'Flap',
                      pref: PagePreference(0, SortOrder.ascending, ContentView.list),
                      enableShufflePlay: false,
                      enableSortMethod: false,
                      enableSortOrder: false,
                      enableContentViewSwitch: false,
                      contentList: [audio],
                      contentBuilder: (c, item, i, _) => AudioTile(
                        audioIndex: i,
                        playlist: [item],
                      ),
                      rightPaneBuilder: (_) =>
                          const Text('RightPaneContent', key: ValueKey('rp-content')),
                      showRightPane: showRightPane,
                      rightPaneWidth: 284,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 快速交替连续切换
        for (var i = 0; i < 6; i++) {
          updateTree(() => showRightPane = !showRightPane);
          await tester.pump(const Duration(milliseconds: 30));
        }

        // 最终稳定收起
        updateTree(() => showRightPane = false);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('rp-content')), findsNothing);
      },
    );

    testWidgets(
      'Queue drawer repeatedly opens and closes without leaking dialog routes or listeners',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio1 = TestAudio(
          title: 'Queue Loop 1',
          artist: 'Artist',
          album: 'Album',
          path: r'E:\Music\q1.flac',
        );
        final audio2 = TestAudio(
          title: 'Queue Loop 2',
          artist: 'Artist',
          album: 'Album',
          path: r'E:\Music\q2.flac',
        );
        final playback = FakePlaybackController(
          audio: audio1,
          queue: [audio1, audio2],
        );

        await tester.pumpWidget(
          buildMediaHarness(
            playbackController: playback,
            lyricController: FakeLyricController(Lrc([], LrcSource.local)),
            desktopLyricController: FakeDesktopLyricController(),
            child: const Scaffold(
              bottomNavigationBar: BottomPlayerBar(),
            ),
          ),
        );
        await tester.pump();

        // 循环打开与关闭抽屉 8 次
        for (var cycle = 0; cycle < 8; cycle++) {
          final queueButton = find.byTooltip('打开播放队列');
          await tester.tap(queueButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.text('播放队列'), findsOneWidget);

          // 模拟在抽屉打开时切歌
          playback.playIndexOfPlaylist(cycle % 2);
          await tester.pump();

          // 关闭抽屉
          final closeButton = find.byTooltip('关闭');
          await tester.tap(closeButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.text('播放队列'), findsNothing);
        }

        // 验证关闭后切歌不应触发已注销的 listener 报错
        playback.playIndexOfPlaylist(0);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Queue drawer dismissed mid-transition settles cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Mid Dismiss',
          artist: 'Artist',
          album: 'Album',
          path: r'E:\Music\dismiss.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        await tester.pumpWidget(
          buildMediaHarness(
            playbackController: playback,
            lyricController: FakeLyricController(Lrc([], LrcSource.local)),
            desktopLyricController: FakeDesktopLyricController(),
            child: const Scaffold(
              bottomNavigationBar: BottomPlayerBar(),
            ),
          ),
        );
        await tester.pump();

        final queueButton = find.byTooltip('打开播放队列');
        await tester.tap(queueButton);
        await tester.pump();
        // 进场 80ms
        await tester.pump(const Duration(milliseconds: 80));

        // 点击遮罩外部区域关闭
        await tester.tapAt(const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        expect(find.text('播放队列'), findsNothing);
      },
    );
  });

  group('Adversarial M1-M3: Boundary Dimensions & Layout Robustness', () {
    testWidgets(
      'Queue drawer operates stably under extreme 400px window width',
      (tester) async {
        // 极小窗口宽度 400px
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Narrow Window Track',
          artist: 'Narrow Artist',
          album: 'Narrow Album',
          path: r'E:\Music\narrow.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        await tester.pumpWidget(
          buildMediaHarness(
            playbackController: playback,
            lyricController: FakeLyricController(Lrc([], LrcSource.local)),
            desktopLyricController: FakeDesktopLyricController(),
            child: const Scaffold(
              bottomNavigationBar: BottomPlayerBar(),
            ),
          ),
        );
        await tester.pump();

        final queueBtn = find.byTooltip('打开播放队列');
        expect(queueBtn, findsOneWidget);
        await tester.tap(queueBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // 验证 BackdropFilter 和 抽屉内容在 400px 下无异常渲染
        expect(tester.takeException(), isNull);
        expect(find.text('播放队列'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsWidgets);

        // 关闭
        final closeButton = find.byTooltip('关闭');
        await tester.tap(closeButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UniPage handles extreme 400px narrow window with active right pane and side rail gracefully',
      (tester) async {
        tester.view.physicalSize = const Size(400, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Uni Narrow Audio',
          artist: 'Narrow Artist',
          album: 'Narrow Album',
          path: r'E:\Music\uni_narrow.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        await tester.pumpWidget(
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
            child: MaterialApp(
              theme: buildTestTheme(),
              home: Scaffold(
                body: UniPage<TestAudio>(
                  title: 'Narrow Uni',
                  pref: PagePreference(0, SortOrder.ascending, ContentView.list),
                  enableShufflePlay: false,
                  enableSortMethod: false,
                  enableSortOrder: false,
                  enableContentViewSwitch: false,
                  contentList: [audio],
                  contentBuilder: (c, item, i, _) => SizedBox(
                    height: 64,
                    child: Text(item.title),
                  ),
                  sideIndexLabels: const ['A', 'B', 'C'],
                  sideIndexResolver: (list, letter) => 0,
                  rightPaneBuilder: (_) => const Text('LyricPane'),
                  showRightPane: true,
                  rightPaneWidth: 200,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('LyricPane'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioTile context menu anchors properly under extreme scrolling and window bounds',
      (tester) async {
        tester.view.physicalSize = const Size(600, 500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audios = List.generate(
          20,
          (i) => TestAudio(
            title: 'Song #$i',
            artist: 'Artist #$i',
            album: 'Album #$i',
            path: 'E:\\Music\\s_$i.flac',
          ),
        );
        final playback = FakePlaybackController(audio: audios[0], queue: audios);

        await tester.pumpWidget(
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
            child: MaterialApp(
              theme: buildTestTheme(),
              home: Scaffold(
                body: ListView.builder(
                  itemCount: audios.length,
                  itemBuilder: (context, i) => AudioTile(
                    audioIndex: i,
                    playlist: audios,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 滚动到底部
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        // 找到当前屏幕内可见的更多按钮
        final moreButtons = find.byTooltip('更多');
        expect(moreButtons, findsWidgets);

        await tester.tap(moreButtons.first);
        await tester.pumpAndSettle();

        expect(find.text('播放'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Adversarial M1-M3: Empty State & Pathological Lyric Rendering', () {
    testWidgets(
      'UniPage renders without exceptions on completely empty list with all actions enabled',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final playback = FakePlaybackController(
          audio: TestAudio(
            title: 'Empty Test',
            artist: 'A',
            album: 'B',
            path: 'E:\\none.flac',
          ),
          queue: [],
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
            child: MaterialApp(
              theme: buildTestTheme(),
              home: Scaffold(
                body: UniPage<TestAudio>(
                  title: 'Empty Uni',
                  pref: PagePreference(0, SortOrder.ascending, ContentView.list),
                  contentList: const [],
                  contentBuilder: (c, item, i, _) => const SizedBox(),
                  enableShufflePlay: true,
                  enableSortMethod: false,
                  enableSortOrder: false,
                  enableContentViewSwitch: false,
                  sideIndexLabels: const ['A', 'B'],
                  sideIndexResolver: (list, letter) => null,
                  locateIndexResolver: (list) => null,
                  rightPaneBuilder: (_) => const Text('EmptyRightPane'),
                  showRightPane: true,
                  rightPaneWidth: 284,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('EmptyRightPane'), findsOneWidget);
      },
    );

    testWidgets(
      'AudioLyricPreviewPanel handles massive 2000-line lyrics with high frequency jump updates',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final audio = TestAudio(
          title: 'Massive Lyric Song',
          artist: 'Massive Artist',
          album: 'Massive Album',
          path: r'E:\Music\massive.flac',
        );
        final playback = FakePlaybackController(audio: audio, queue: [audio]);

        final massiveLines = List.generate(
          2000,
          (i) => LrcLine(
            Duration(seconds: i * 2),
            '第 $i 行 超长歌词内容 包含很多字用于压力测试 ' * 3,
            isBlank: false,
            length: const Duration(seconds: 2),
          ),
        );
        final lyricController = FakeLyricController(
          Lrc(massiveLines, LrcSource.local),
        );

        await tester.pumpWidget(
          buildMediaHarness(
            playbackController: playback,
            lyricController: lyricController,
            desktopLyricController: FakeDesktopLyricController(),
            child: const Scaffold(
              body: SizedBox(
                width: 284,
                height: 600,
                child: AudioLyricPreviewPanel(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 高频跨越式推进歌词行号 (0 -> 500 -> 1500 -> 1999 -> 0)
        lyricController.emitLine(500);
        await tester.pump(const Duration(milliseconds: 50));
        lyricController.emitLine(1500);
        await tester.pump(const Duration(milliseconds: 50));
        lyricController.emitLine(1999);
        await tester.pump(const Duration(milliseconds: 50));
        lyricController.emitLine(0);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}


