import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/window_controls.dart';

import '../e2e/e2e_test_helpers.dart';

void main() {
  setUp(() {
    WindowControls.layoutMode.value = WindowLayoutMode.normal;
    AppNavigationState.instance.setNowPlayingPageActive(false);
    AppSettings.instance.coverBreathEffect = true;
    AppSettings.instance.showSpectrumVisualizer = true;
  });

  tearDown(() {
    WindowControls.layoutMode.value = WindowLayoutMode.normal;
    AppNavigationState.instance.setNowPlayingPageActive(false);
  });

  // =========================================================================
  // GROUP 1: MainLayoutFrame Rapid Toggling & Mathematical Inset Continuity
  // =========================================================================
  group('MainLayoutFrame Adversarial: Inset & Rapid Toggling', () {
    testWidgets(
      'T1.1: Rapid layout mode toggling at chaotic millisecond intervals maintains stability without throwing',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MainLayoutFrame(
              titleBar: SizedBox(height: 40, key: ValueKey('title_bar')),
              overlay: SizedBox(height: 60, key: ValueKey('overlay_bar')),
              child: SizedBox.expand(child: Text('Main Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 混沌时间间隔高频连续触发模式切换
        final toggles = [
          WindowLayoutMode.maximized,
          WindowLayoutMode.normal,
          WindowLayoutMode.fullscreen,
          WindowLayoutMode.maximized,
          WindowLayoutMode.fullscreen,
          WindowLayoutMode.normal,
          WindowLayoutMode.maximized,
        ];
        final intervals = [10, 27, 45, 15, 83, 30, 55];

        for (int i = 0; i < toggles.length; i++) {
          WindowControls.layoutMode.value = toggles[i];
          await tester.pump(Duration(milliseconds: intervals[i]));

          // 验证每一帧的渲染树完整且无异常
          expect(tester.takeException(), isNull);
          final paddingFinder = find.byType(Padding).first;
          final currentPadding =
              tester.widget<Padding>(paddingFinder).padding as EdgeInsets;

          // 严格数学边界断言：边距必须在合法区间内
          expect(currentPadding.left, greaterThanOrEqualTo(4.0 - 1e-4));
          expect(currentPadding.top, greaterThanOrEqualTo(12.0 - 1e-4));
        }

        // 最终稳定收敛
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final finalPadding =
            tester.widget<Padding>(find.byType(Padding).first).padding as EdgeInsets;
        expect(finalPadding, const EdgeInsets.fromLTRB(4.0, 20.0, 4.0, 0.0));
      },
    );

    testWidgets(
      'T1.2: Intermediate inset bounds check during layout mode changes',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MainLayoutFrame(
              titleBar: SizedBox(height: 40),
              overlay: SizedBox(height: 60),
              child: SizedBox.expand(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 触发从 normal 到 maximized
        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pump();

        final outerPadding =
            tester.widget<Padding>(find.byType(Padding).first).padding as EdgeInsets;
        expect(outerPadding.top, 20.0);
        expect(outerPadding.left, 4.0);

        WindowControls.layoutMode.value = WindowLayoutMode.normal;
        await tester.pump();

        final restoredPadding =
            tester.widget<Padding>(find.byType(Padding).first).padding as EdgeInsets;
        expect(restoredPadding.top, 12.0);
        expect(restoredPadding.left, 4.0);
      },
    );

    testWidgets(
      'T1.3: Dynamic mutation of overlay presence does not cause tree crash or positioning leak',
      (tester) async {
        var showOverlay = true;
        late StateSetter updateState;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateState = setState;
                return MainLayoutFrame(
                  titleBar: const SizedBox(height: 40),
                  overlay: showOverlay
                      ? const SizedBox(height: 60, key: ValueKey('ov'))
                      : null,
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pump();

        // 动态卸载 overlay
        updateState(() => showOverlay = false);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('ov')), findsNothing);

        // 再次挂载 overlay
        updateState(() => showOverlay = true);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('ov')), findsOneWidget);
        final overlayPos =
            tester.widget<Positioned>(find.byType(Positioned).first);
        expect(overlayPos.bottom, 0.0);
      },
    );

    testWidgets(
      'T1.4: Extreme viewport dimensions (100x100 and 5120x2880) with rapid toggles maintain stability',
      (tester) async {
        // 极小视口 100x100
        tester.view.physicalSize = const Size(100, 100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(
            home: MainLayoutFrame(
              titleBar: SizedBox(height: 20),
              overlay: SizedBox(height: 20),
              child: Text('Tiny'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pump(const Duration(milliseconds: 110));
        WindowControls.layoutMode.value = WindowLayoutMode.normal;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 超大 4K 视口 5120x2880
        tester.view.physicalSize = const Size(5120, 2880);
        await tester.pump();
        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // =========================================================================
  // GROUP 2: Shell Transition, Scale 0.96 Spatial Settlement & Push/Pop
  // =========================================================================
  group('Shell & Underlay Adversarial: Scale 0.96 Push-Back & Interrupted Route Transitions', () {
    testWidgets(
      'T2.1: Interrupted route transitions (Push -> Pop mid-flight -> Push again) maintain scale & opacity continuity',
      (tester) async {
        final primaryAnim = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 480),
          value: 1.0,
        );
        final secondaryAnim = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 480),
          value: 0.0,
        );
        addTearDown(primaryAnim.dispose);
        addTearDown(secondaryAnim.dispose);

        AppNavigationState.instance.setNowPlayingPageActive(true);
        addTearDown(() => AppNavigationState.instance.setNowPlayingPageActive(false));

        const underlayPage = SlideTransitionPage<void>(
          child: ColoredBox(
            key: ValueKey('underlay_target'),
            color: Colors.indigo,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildE2ETestTheme(),
            home: Builder(
              builder: (context) => underlayPage.transitionsBuilder(
                context,
                primaryAnim,
                secondaryAnim,
                underlayPage.child,
              ),
            ),
          ),
        );
        await tester.pump();

        Transform getTransform() => tester.widget<Transform>(
              find.byKey(const ValueKey('now-playing-underlay-scale')),
            );
        Opacity getOpacity() => tester.widget<Opacity>(
              find.byKey(const ValueKey('now-playing-underlay-opacity')),
            );

        // 1. 模拟进入详情页 30% (secondaryAnim 从 0.0 前进到 0.30)
        secondaryAnim.value = 0.30;
        await tester.pump();
        final scaleAt30 = getTransform().transform.storage[0];
        final opacityAt30 = getOpacity().opacity;

        expect(scaleAt30, inExclusiveRange(0.96, 1.0));
        expect(opacityAt30, inExclusiveRange(0.0, 1.0));

        // 2. 中途打断并反向退场 (secondaryAnim 反向回到 0.10)
        secondaryAnim.value = 0.10;
        await tester.pump();
        final scaleAt10 = getTransform().transform.storage[0];
        final opacityAt10 = getOpacity().opacity;

        // 验证反向打断时的连续性：scale 和 opacity 应回到更接近 1.0
        expect(scaleAt10, greaterThan(scaleAt30));
        expect(opacityAt10, greaterThan(opacityAt30));

        // 3. 再次打断并全力进入到 1.0
        secondaryAnim.value = 1.0;
        await tester.pump();
        expect(getTransform().transform.storage[0], closeTo(0.96, 1e-4));
        expect(getOpacity().opacity, closeTo(0.0, 1e-4));
      },
    );

    testWidgets(
      'T2.2: Scale 0.96 spatial push-back curve is strictly bounded and settles at exactly 0.48 interval',
      (tester) async {
        final primaryAnim = AnimationController(vsync: tester, value: 1.0);
        final secondaryAnim = AnimationController(vsync: tester, value: 0.0);
        addTearDown(primaryAnim.dispose);
        addTearDown(secondaryAnim.dispose);

        AppNavigationState.instance.setNowPlayingPageActive(true);
        addTearDown(() => AppNavigationState.instance.setNowPlayingPageActive(false));

        const page = SlideTransitionPage<void>(
          child: SizedBox.expand(key: ValueKey('page_box')),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildE2ETestTheme(),
            home: Builder(
              builder: (context) => page.transitionsBuilder(
                context,
                primaryAnim,
                secondaryAnim,
                page.child,
              ),
            ),
          ),
        );

        Transform getTransform() => tester.widget<Transform>(
              find.byKey(const ValueKey('now-playing-underlay-scale')),
            );

        // 密集采样 secondaryAnimation 从 0.0 到 1.0 过程
        for (double t = 0.0; t <= 1.0; t += 0.04) {
          secondaryAnim.value = t;
          await tester.pump();

          final scale = getTransform().transform.storage[0];

          // 核心断言：在任何时刻，缩放绝不允许低于 0.96 或高于 1.0
          expect(scale, inInclusiveRange(0.96 - 1e-5, 1.0 + 1e-5));

          if (t >= 0.48) {
            // 在 0.48 之后，空间沉降已完全就绪，尺度恒为 0.96
            expect(scale, closeTo(0.96, 1e-4));
          }
        }
      },
    );

    testWidgets(
      'T2.3: Fast repetitive route push/pop (12 cycles) does not leak listeners, tickers or corrupt underlay state',
      (tester) async {
        final nav = AppNavigationState.instance;

        await tester.pumpWidget(
          const MaterialApp(
            home: NowPlayingShellUnderlay(
              child: Text('Shell Underlay Body', key: ValueKey('body_text')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        AnimatedOpacity getOpacity() => tester.widget<AnimatedOpacity>(
              find.byKey(const ValueKey('now-playing-shell-underlay-opacity')),
            );
        IgnorePointer getPointer() => tester.widget<IgnorePointer>(
              find.byKey(const ValueKey('now-playing-shell-underlay-pointer')),
            );

        expect(getOpacity().opacity, 1.0);
        expect(getPointer().ignoring, isFalse);

        // 快速连续 12 次进出
        for (int cycle = 0; cycle < 12; cycle++) {
          nav.setNowPlayingPageActive(true);
          await tester.pump();
          expect(getOpacity().opacity, 0.0);
          expect(getPointer().ignoring, isTrue);

          nav.setNowPlayingPageActive(false);
          await tester.pump();
          expect(getOpacity().opacity, 1.0);
          expect(getPointer().ignoring, isFalse);
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T2.4: TickerMode is disabled when underlay opacity drops to 0 to prevent background render overhead',
      (tester) async {
        final primaryAnim = AnimationController(vsync: tester, value: 1.0);
        final secondaryAnim = AnimationController(vsync: tester, value: 0.0);
        addTearDown(primaryAnim.dispose);
        addTearDown(secondaryAnim.dispose);

        AppNavigationState.instance.setNowPlayingPageActive(true);
        addTearDown(() => AppNavigationState.instance.setNowPlayingPageActive(false));

        const page = SlideTransitionPage<void>(
          child: SizedBox.expand(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildE2ETestTheme(),
            home: Builder(
              builder: (context) => page.transitionsBuilder(
                context,
                primaryAnim,
                secondaryAnim,
                page.child,
              ),
            ),
          ),
        );

        TickerMode getTickerMode() => tester.widget<TickerMode>(
              find.descendant(
                of: find.byKey(const ValueKey('now-playing-underlay-pointer')),
                matching: find.byType(TickerMode),
              ),
            );

        // 未进场前，Ticker 保持 enabled
        expect(getTickerMode().enabled, isTrue);

        // 进场完成 (secondaryAnim = 1.0)，underlayOpacity = 0.0 -> Ticker 必须被停用
        secondaryAnim.value = 1.0;
        await tester.pump();
        expect(getTickerMode().enabled, isFalse);

        // 退场还原 (secondaryAnim = 0.0) -> Ticker 恢复启用
        secondaryAnim.value = 0.0;
        await tester.pump();
        expect(getTickerMode().enabled, isTrue);
      },
    );
  });

  // =========================================================================
  // GROUP 3: 6-Stage Staged Reveal & Entrance Debounce / Track Switching
  // =========================================================================
  group('Staged Reveal Adversarial: Timeline Choreography, Reverse Exit & Entrance Debounce', () {
    testWidgets(
      'T3.1: 6-Stage Staged Reveal timing checkpoints verify precise entrance sequence',
      (tester) async {
        final routeController = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 480),
        );
        addTearDown(routeController.dispose);

        final audio = E2ETestAudio(
          title: 'Chronos Symphony',
          artist: 'Maestro Stellar',
          album: 'Time Canvas',
          path: 'E:\\Music\\chronos.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.playing,
        );
        final lyric = E2ELyricController(
          Lrc([
            LrcLine(const Duration(seconds: 0), 'Stage Verse 1',
                isBlank: false, length: const Duration(seconds: 5)),
            LrcLine(const Duration(seconds: 5), 'Stage Verse 2',
                isBlank: false, length: const Duration(seconds: 5)),
          ], LrcSource.local),
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: lyric,
            child: NowPlayingRouteTransitionScope(
              animation: routeController,
              child: const NowPlayingPage(),
            ),
          ),
        );
        await tester.pump();

        // 1. Stage 1: t = 0.05 (Hero Cover active, AppBar invisible, Identity invisible, Lyric invisible)
        routeController.value = 0.05;
        await tester.pump();

        // 2. Stage 2: t = 0.20 (AppBar in [0.12, 0.48] is animating in; Identity in [0.24, 0.68] still 0)
        routeController.value = 0.20;
        await tester.pump();

        // 3. Stage 3 & 4: t = 0.32 (Identity in [0.24, 0.68] animating; Metadata/Spectrum in [0.30, 0.80] starting)
        routeController.value = 0.32;
        await tester.pump();

        // 4. Stage 5: t = 0.50 (AppBar settled; Identity settled; Lyric in [0.34, 0.90] mid-flight)
        routeController.value = 0.50;
        await tester.pump();

        // 5. Stage 6: t = 0.81 (Lyrics almost settled, BottomBar still hidden before 0.82 threshold)
        routeController.value = 0.81;
        await tester.pump();

        // 6. Stage 6: t = 0.86 (BottomBar threshold >= 0.82 passed, revealed)
        routeController.value = 0.86;
        await tester.pump();

        // 7. Full settlement at 1.0
        routeController.value = 1.0;
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T3.2: Reverse exit choreography smoothly collapses stages in reverse order without crashing',
      (tester) async {
        final routeController = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 400),
          value: 1.0,
        );
        addTearDown(routeController.dispose);

        final audio = E2ETestAudio(
          title: 'Exit Track',
          artist: 'Exit Artist',
          album: 'Exit Album',
          path: 'E:\\Music\\exit.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);
        final lyric = E2ELyricController();

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: lyric,
            child: NowPlayingRouteTransitionScope(
              animation: routeController,
              child: const NowPlayingPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 反向退出倒放 (1.0 -> 0.70 -> 0.40 -> 0.10 -> 0.0)
        final exitSteps = [0.70, 0.40, 0.10, 0.0];
        for (final step in exitSteps) {
          routeController.value = step;
          await tester.pump(const Duration(milliseconds: 30));
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'T3.3: Rapid track switching & lyric emissions during entrance (<0.95) execute without scroll jumps or crashes',
      (tester) async {
        final routeController = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 480),
        );
        addTearDown(routeController.dispose);

        final audios = generateMockPlaylist(5);
        final playback = E2EPlaybackController(
          initialAudio: audios[0],
          initialQueue: audios,
          initialState: PlayerState.playing,
        );
        final lyric = E2ELyricController(
          Lrc(generateMockLrcLines(50), LrcSource.local),
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: lyric,
            child: NowPlayingRouteTransitionScope(
              animation: routeController,
              child: const NowPlayingPage(),
            ),
          ),
        );
        await tester.pump();

        // 在入场进行到 t = 0.20, 0.40, 0.60 时高频切歌与发送歌词行
        for (int i = 1; i <= 3; i++) {
          routeController.value = i * 0.20;
          playback.playIndexOfPlaylist(i);
          lyric.emitLine(i * 10);
          await tester.pump(const Duration(milliseconds: 30));
          expect(tester.takeException(), isNull);
        }

        // 完成入场并等待所有延迟滚动定时器全部触发清空
        routeController.value = 1.0;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T3.4: AutoHide Bottom Bar pointer hover and tap interactions maintain 5-second lifecycle stably',
      (tester) async {
        final routeController = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 480),
          value: 1.0, // 入场已完成
        );
        addTearDown(routeController.dispose);

        final audio = E2ETestAudio(
          title: 'Hover Song',
          artist: 'Hover Artist',
          album: 'Hover Album',
          path: 'E:\\Music\\hover.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: E2ELyricController(),
            child: NowPlayingRouteTransitionScope(
              animation: routeController,
              child: const NowPlayingPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 初始状态底栏可见
        expect(find.byType(BottomPlayerBar), findsOneWidget);

        // 推进 6 秒（超过 5 秒未交互自动隐藏）
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(milliseconds: 300));

        // 模拟鼠标在底部区域移动唤醒底栏
        final bottomGesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await bottomGesture.addPointer(location: const Offset(400, 750));
        await tester.pump();
        await bottomGesture.moveTo(const Offset(400, 760));
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        await bottomGesture.removePointer();
      },
    );
  });

  // =========================================================================
  // GROUP 4: 120fps GPU Texture Caching & Tree Structure Integrity
  // =========================================================================
  group('120fps GPU Optimization Adversarial: RepaintBoundary & Lazy BackdropFilter', () {
    testWidgets(
      'T4.1: RepaintBoundary isolation exists around Artwork Hero, Spectrum, Lyrics and Liquid Background',
      (tester) async {
        final audio = E2ETestAudio(
          title: 'GPU Test Track',
          artist: 'Opt Artist',
          album: 'Opt Album',
          path: 'E:\\Music\\opt.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.playing,
        );
        playback.emitSpectrum([0.5, 0.8, 0.3, 0.9, 0.4]);

        final lyric = E2ELyricController(
          Lrc(generateMockLrcLines(20), LrcSource.local),
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: lyric,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 验证渲染树中 RepaintBoundary 节点的存在
        final repaintBoundaries =
            tester.widgetList<RepaintBoundary>(find.byType(RepaintBoundary));
        expect(repaintBoundaries.length, greaterThanOrEqualTo(4));

        // 验证 Hero Frame 包含 RepaintBoundary
        final heroFrameRepaint = find.descendant(
          of: find.byType(NowPlayingArtworkHeroFrame),
          matching: find.byType(RepaintBoundary),
        );
        expect(heroFrameRepaint, findsWidgets);

        // 验证歌词视图包含 RepaintBoundary 隔离
        final lyricRepaint = find.descendant(
          of: find.byType(ImmersiveNowPlayingView),
          matching: find.byType(RepaintBoundary),
        );
        expect(lyricRepaint, findsWidgets);
      },
    );

    testWidgets(
      'T4.2: BackdropFilter is lazily mounted only during active scale indicator and unmounted when idle',
      (tester) async {
        final audio = E2ETestAudio(
          title: 'Backdrop Test',
          artist: 'Backdrop Artist',
          album: 'Backdrop Album',
          path: 'E:\\Music\\bd.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);
        final lyric = E2ELyricController(
          Lrc(generateMockLrcLines(20), LrcSource.local),
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: lyric,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 1. 闲置状态下：缩放指示胶囊未被触发，树中绝无闲置 BackdropFilter
        final idleBackdropFilters = find.descendant(
          of: find.byType(ImmersiveNowPlayingView),
          matching: find.byType(BackdropFilter),
        );
        expect(idleBackdropFilters, findsNothing);

        // 2. 触发双指手势 / onScaleUpdate 进行歌词缩放
        final scaleDetector = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .firstWhere((gd) => gd.onScaleUpdate != null);
        scaleDetector.onScaleUpdate!(
          ScaleUpdateDetails(
            scale: 1.35,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
          ),
        );
        await tester.pump();

        // 此时 _showScaleIndicator 为 true，BackdropFilter 必须被惰性挂载！
        final activeBackdropFilters = find.descendant(
          of: find.byType(ImmersiveNowPlayingView),
          matching: find.byType(BackdropFilter),
        );
        expect(activeBackdropFilters, findsOneWidget);
        expect(find.text('歌词大小: 135%'), findsOneWidget);

        // 3. 等待 1200ms 定时器触发指示器隐藏并彻底卸载 BackdropFilter
        await tester.pump(const Duration(milliseconds: 1400));

        final unmountedBackdropFilters = find.descendant(
          of: find.byType(ImmersiveNowPlayingView),
          matching: find.byType(BackdropFilter),
        );
        expect(unmountedBackdropFilters, findsNothing);
      },
    );

    testWidgets(
      'T4.3: 3D Cover drag gestures and breathing glow are structurally decoupled outside Hero',
      (tester) async {
        final audio = E2ETestAudio(
          title: 'Decoupled Song',
          artist: 'Decoupled Artist',
          album: 'Decoupled Album',
          path: 'E:\\Music\\decoupled.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            lyricController: E2ELyricController(),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 验证 GestureDetector 位于 Hero 的父级（Hero 在 GestureDetector 内部）
        final dragGestureFinder =
            find.byKey(const ValueKey('now-playing-artwork-drag'));
        expect(dragGestureFinder, findsOneWidget);

        final heroInsideGesture = find.descendant(
          of: dragGestureFinder,
          matching: find.byType(Hero),
        );
        expect(heroInsideGesture, findsOneWidget);

        // 验证 Hero 子树下仅包含纯净的 NowPlayingArtworkCard
        final heroWidget = tester.widget<Hero>(heroInsideGesture);
        expect(heroWidget.tag, nowPlayingArtworkHeroTag);
        expect(heroWidget.child, isA<NowPlayingArtworkCard>());
      },
    );
  });
}


