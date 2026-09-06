import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/window_drag_region.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets(
      'ImmersiveNowPlayingView immersive mode handles long lyrics without overflow',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Immersive Song',
      artist: ' Immersive Artist / Immersive Artist / UNKNOWN / Guest Artist ',
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
        child: const ImmersiveNowPlayingView(
          compact: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
    expect(find.text('Immersive Song'), findsOneWidget);
    expect(find.text('Immersive Artist / Guest Artist'), findsOneWidget);
    final titleText = tester.widget<Text>(find.text('Immersive Song'));
    final artistText =
        tester.widget<Text>(find.text('Immersive Artist / Guest Artist'));
    expect(titleText.textAlign,
        TextAlign.center); // 閲嶆瀯锛氶潪 compact 妯″紡涓嬫瓕鏇叉爣棰樺凡璁句负灞呬腑瀵归綈
    expect(titleText.style?.fontWeight, FontWeight.w800);
    expect(titleText.style?.decoration, TextDecoration.none);
    expect(artistText.textAlign,
        TextAlign.center); // 閲嶆瀯锛氶潪 compact 妯″紡涓嬫瓕鎵嬫枃瀛楀凡璁句负灞呬腑瀵归綈
    expect(artistText.style?.fontWeight, FontWeight.w400);
    expect(artistText.style?.decoration, TextDecoration.none);
    expect(
      find.text('Immersive Artist / Guest Artist 璺?Immersive Album'),
      findsNothing,
    );
    expect(find.text('flac'), findsNothing);
  });

  testWidgets(
      'ImmersiveNowPlayingView immersive compact mode handles long lyrics without overflow',
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
        child: const ImmersiveNowPlayingView(
          compact: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
  });

  testWidgets('ImmersiveNowPlayingView handles rapid lyric line changes', (
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
        child: const ImmersiveNowPlayingView(
          compact: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    lyric
      ..emitLine(3)
      ..emitLine(12)
      ..emitLine(8)
      ..emitLine(200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ImmersiveNowPlayingView artwork stage empty area avoids action hits',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Artwork Song',
      artist: 'Artwork Artist',
      album: 'Artwork Album',
      path: r'E:\Music\artwork-hit.flac',
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
        child: const ImmersiveNowPlayingView(
          compact: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WindowDragRegion), findsNothing);

    final heroRect = tester.getRect(find.byType(Hero).first);
    final hitPoint = Offset(heroRect.center.dx, heroRect.top - 24);
    final hitWidgets = _hitWidgetTypes(tester.hitTestOnBinding(hitPoint));

    expect(hitWidgets, isNot(contains('IconButton')));
    expect(hitWidgets, isNot(contains('FilledButton')));
    expect(hitWidgets, isNot(contains('InkWell')));
    expect(hitWidgets, isNot(contains('DragToMoveArea')));
  });

  testWidgets('ImmersiveNowPlayingView empty area absorbs clicks silently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Drag Song',
      artist: 'Drag Artist',
      album: 'Drag Album',
      path: r'E:\Music\drag-hit.flac',
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
        child: const ImmersiveNowPlayingView(
          compact: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final heroRect = tester.getRect(find.byType(Hero).first);
    final hitPoint = Offset(heroRect.center.dx, heroRect.top - 24);
    final hitWidgets = _hitWidgetTypes(tester.hitTestOnBinding(hitPoint));

    expect(find.byType(WindowDragRegion), findsNothing);
    expect(hitWidgets, isNot(contains('DragToMoveArea')));
    expect(hitWidgets, contains('AbsorbPointer'));
  });

  testWidgets('artwork drag stays bounded and preserves the Hero rectangle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = TestAudio(
      title: 'Spring Song',
      artist: 'Spring Artist',
      album: 'Spring Album',
      path: r'E:\Music\spring-a.flac',
    );
    final second = TestAudio(
      title: 'Next Song',
      artist: 'Next Artist',
      album: 'Next Album',
      path: r'E:\Music\spring-b.flac',
    );
    final playback = FakePlaybackController(
      audio: first,
      queue: [first, second],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const ImmersiveNowPlayingView(compact: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final dragTarget = find.byKey(
      const ValueKey('now-playing-artwork-drag'),
    );
    final hero = find.byType(Hero).first;
    final initialHeroRect = tester.getRect(hero);
    final gesture = await tester.startGesture(tester.getCenter(dragTarget));
    await gesture.moveBy(const Offset(120, 90));
    await tester.pump();

    Transform artworkTransform() {
      return tester.widget<Transform>(
        find.descendant(of: dragTarget, matching: find.byType(Transform)).first,
      );
    }

    final transformedOrigin = MatrixUtils.transformPoint(
      artworkTransform().transform,
      Offset.zero,
    );
    expect(transformedOrigin.distance, lessThanOrEqualTo(10.01));
    expect(tester.getRect(hero), initialHeroRect);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      MatrixUtils.transformPoint(artworkTransform().transform, Offset.zero)
          .distance,
      lessThan(0.01),
    );

    final secondGesture =
        await tester.startGesture(tester.getCenter(dragTarget));
    await secondGesture.moveBy(const Offset(-80, 40));
    await tester.pump();
    playback.setNowPlaying(second, queue: [first, second]);
    await tester.pump();
    expect(
      MatrixUtils.transformPoint(artworkTransform().transform, Offset.zero)
          .distance,
      lessThan(0.01),
    );
    await secondGesture.up();
  });

  testWidgets('ImmersiveNowPlayingView renders synced lyric words', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Synced Song',
      artist: 'Synced Artist',
      album: 'Synced Album',
      path: r'E:\Music\synced-now-playing.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final lyric = FakeLyricController(
      TestSyncLyric([
        TestSyncLine(
          Duration.zero,
          const Duration(seconds: 3),
          [
            TestSyncWord(Duration.zero, const Duration(seconds: 1), 'Hel'),
            TestSyncWord(
              const Duration(seconds: 1),
              const Duration(seconds: 1),
              'lo',
            ),
          ],
        ),
      ]),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const ImmersiveNowPlayingView(
          compact: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Hel'), findsOneWidget);
    expect(find.text('lo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NowPlayingPage delays bottom bar until route entrance is ready',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Route Song',
      artist: 'Route Artist',
      album: 'Route Album',
      path: r'E:\Music\route-now-playing.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );
    final routeAnimation = AnimationController(
      vsync: tester,
      value: 0.2,
      duration: const Duration(milliseconds: 430),
    );
    addTearDown(routeAnimation.dispose);

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: NowPlayingRouteTransitionScope(
          animation: routeAnimation,
          child: const NowPlayingPage(),
        ),
      ),
    );
    await tester.pump();

    final overlayOpacityFinder = find.byWidgetPredicate(
      (widget) => widget is AnimatedOpacity && widget.child is BottomPlayerBar,
    );
    expect(overlayOpacityFinder, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(overlayOpacityFinder).opacity, 0);

    routeAnimation.value = 1.0;
    await tester.pump();

    expect(tester.widget<AnimatedOpacity>(overlayOpacityFinder).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ImmersiveNowPlayingView cover glow uses RepaintBoundary for GPU texture caching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Glow Cover Song',
      artist: 'Glow Artist',
      album: 'Glow Album',
      path: r'E:\Music\glow.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ThemeProvider.instance),
          ChangeNotifierProvider<PlaybackController>.value(
            value: playback,
          ),
          ChangeNotifierProvider<LyricController>.value(
            value: lyric,
          ),
          ChangeNotifierProvider<DesktopLyricController>.value(
            value: FakeDesktopLyricController(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: AppTheme.applyChromeSurfaces(
              ColorScheme.fromSeed(
                seedColor: const Color(0xFF53A4FF),
                brightness: Brightness.dark,
              ),
            ),
            effectsLevel: UiEffectsLevel.visual,
          ),
          home: const Scaffold(
            body: ImmersiveNowPlayingView(compact: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证呼吸发光层中的 ImageFiltered 被 RepaintBoundary 包裹，以启用 GPU 纹理缓存
    final imageFilteredFinder = find.byType(ImageFiltered);
    expect(imageFilteredFinder, findsOneWidget);

    final repaintBoundaryFinder = find.ancestor(
      of: imageFilteredFinder,
      matching: find.byType(RepaintBoundary),
    );
    expect(repaintBoundaryFinder, findsWidgets);
  });

  testWidgets('_CenteredLyricView lazily mounts BackdropFilter only when scale indicator is shown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Scale Lyric Song',
      artist: 'Scale Artist',
      album: 'Scale Album',
      path: r'E:\Music\scale-lyric.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const ImmersiveNowPlayingView(compact: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 闲置状态下：BackdropFilter 必须完全卸载以释放 GPU 采样通道
    expect(find.byType(BackdropFilter), findsNothing);

    // 触发双指缩放手势唤醒缩放指示器
    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(find.byType(Scrollbar)));
    final scaleFinder = find.byType(GestureDetector);
    final scaleDetector = tester.widgetList<GestureDetector>(scaleFinder).firstWhere(
      (gd) => gd.onScaleUpdate != null,
    );
    scaleDetector.onScaleUpdate!(
      ScaleUpdateDetails(
        scale: 1.25,
        focalPoint: Offset.zero,
        localFocalPoint: Offset.zero,
      ),
    );
    await tester.pump();

    // 缩放激活时：BackdropFilter 惰性挂载于绘制树
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('歌词大小: 125%'), findsOneWidget);

    // 1400ms 定时器触发后：BackdropFilter 自动从绘制树彻底卸载
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('NowPlayingRouteTransitionScope locks lyric scroll during entrance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Entrance Song',
      artist: 'Entrance Artist',
      album: 'Entrance Album',
      path: r'E:\Music\entrance-scroll.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );
    final routeAnimation = AnimationController(
      vsync: tester,
      value: 0.45, // 入场进行中 (< 0.95)
      duration: const Duration(milliseconds: 480),
    );
    addTearDown(routeAnimation.dispose);

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: NowPlayingRouteTransitionScope(
          animation: routeAnimation,
          child: const NowPlayingPage(),
        ),
      ),
    );
    await tester.pump();

    // 在转场入场期间切换歌词行，验证不会抛出异常并完成定位
    lyric.emitLine(5);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 转场彻底完成 (>= 0.95)
    routeAnimation.value = 1.0;
    await tester.pump();
    lyric.emitLine(8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}

class TestSyncLyric extends Lyric {
  TestSyncLyric(super.lines);
}

class TestSyncLine extends SyncLyricLine {
  TestSyncLine(super.start, super.length, super.words, [super.translation]);
}

class TestSyncWord extends SyncLyricWord {
  TestSyncWord(super.start, super.length, super.content);
}

List<String> _hitWidgetTypes(HitTestResult result) {
  return result.path.map((entry) {
    final target = entry.target;
    if (target is RenderObject) {
      final creator = target.debugCreator;
      final widget =
          creator == null ? null : (creator as dynamic).element.widget;
      if (widget != null) {
        return widget.runtimeType.toString();
      }
    }
    return target.runtimeType.toString();
  }).toList(growable: false);
}
