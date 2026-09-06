import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/component/ui/audio_format_badge.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';

import '../test_helpers/media_test_harness.dart';

/// 对抗性测试音频基类：支持可定制的封面 Future 与音轨元数据
class AdversarialTestAudio extends Audio {
  AdversarialTestAudio({
    required String title,
    required String artist,
    required String album,
    String? composer,
    String? arranger,
    int duration = 240,
    int bitrate = 320,
    int sampleRate = 48000,
    required String path,
    this.coverFuture,
    this.mediumCoverFuture,
    this.largeCoverFuture,
  }) : super(
          title,
          artist,
          album,
          composer,
          arranger,
          1,
          1,
          duration,
          bitrate,
          sampleRate,
          null,
          null,
          null,
          null,
          path,
          1,
          1,
          'Lofty',
        );

  final Future<ImageProvider<Object>?>? coverFuture;
  final Future<ImageProvider<Object>?>? mediumCoverFuture;
  final Future<ImageProvider<Object>?>? largeCoverFuture;

  @override
  Future<ImageProvider<Object>?> get cover =>
      coverFuture ?? super.cover;

  @override
  Future<ImageProvider<Object>?> get mediumCover =>
      mediumCoverFuture ?? coverFuture ?? super.mediumCover;

  @override
  Future<ImageProvider<Object>?> get largeCover =>
      largeCoverFuture ?? coverFuture ?? super.largeCover;
}

final Uint8List kValidTinyPngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0xC9, 0xFE, 0x92, 0xEF, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final Uint8List kCorruptImageBytes = Uint8List.fromList(const [
  0x00, 0x01, 0x02, 0x03, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Tier 5: NowPlayingArtworkRectTween Mathematical Rigor', () {
    test('verifies exact boundary values and time slice interpolation (t=0.0, 0.25, 0.5, 0.75, 1.0)', () {
      const beginRect = Rect.fromLTWH(24, 700, 56, 56);
      const endRect = Rect.fromLTWH(200, 100, 400, 400);

      final tween = NowPlayingArtworkRectTween(begin: beginRect, end: endRect);

      // t = 0.0 边界严格等同 begin
      expect(tween.lerp(0.0), equals(beginRect));

      // t = 1.0 边界严格等同 end
      expect(tween.lerp(1.0), equals(endRect));

      // 计算飞行距离与理论最大弧线拱高 (apex)
      final travelDist = (endRect.center - beginRect.center).distance;
      final expectedAmplitude = (travelDist * 0.012).clamp(0.0, 7.0);

      // t = 0.5: sin(0.5*pi) = 1.0 (最大顶点)
      final midLerp = Rect.lerp(beginRect, endRect, 0.5)!;
      final midCurved = tween.lerp(0.5)!;
      expect(midCurved.left, closeTo(midLerp.left, 1e-6));
      expect(midCurved.width, closeTo(midLerp.width, 1e-6));
      expect(midCurved.height, closeTo(midLerp.height, 1e-6));
      expect(midCurved.top, closeTo(midLerp.top - expectedAmplitude, 1e-6));

      // t = 0.25 与 t = 0.75: sin(0.25*pi) = sin(0.75*pi) = sqrt(2)/2
      final sinQuarter = math.sin(0.25 * math.pi);
      final q1Lerp = Rect.lerp(beginRect, endRect, 0.25)!;
      final q1Curved = tween.lerp(0.25)!;
      expect(q1Curved.top, closeTo(q1Lerp.top - expectedAmplitude * sinQuarter, 1e-6));

      final q3Lerp = Rect.lerp(beginRect, endRect, 0.75)!;
      final q3Curved = tween.lerp(0.75)!;
      expect(q3Curved.top, closeTo(q3Lerp.top - expectedAmplitude * sinQuarter, 1e-6));

      // 弧线对称性验证：t=0.25 与 t=0.75 处偏离线性插值的位移严格相等
      final diffQ1 = q1Lerp.top - q1Curved.top;
      final diffQ3 = q3Lerp.top - q3Curved.top;
      expect(diffQ1, closeTo(diffQ3, 1e-6));
    });

    test('stress tests extreme distances, zero-length paths, negative rects and clamping', () {
      // 1. 超长距离位移 (10000 像素)：振幅必须被严格限制在 7.0 像素以内，防止抛物线飞出屏幕
      const hugeBegin = Rect.fromLTWH(0, 0, 50, 50);
      const hugeEnd = Rect.fromLTWH(8000, 6000, 500, 500);
      final hugeTween = NowPlayingArtworkRectTween(begin: hugeBegin, end: hugeEnd);
      final hugeMidLinear = Rect.lerp(hugeBegin, hugeEnd, 0.5)!;
      final hugeMidCurved = hugeTween.lerp(0.5)!;
      expect(hugeMidLinear.top - hugeMidCurved.top, closeTo(7.0, 1e-6));

      // 2. 原地不动 (zero travel distance)：振幅为 0，无额外 NaN 或抖动
      const zeroBegin = Rect.fromLTWH(100, 100, 60, 60);
      const zeroEnd = Rect.fromLTWH(100, 100, 60, 60);
      final zeroTween = NowPlayingArtworkRectTween(begin: zeroBegin, end: zeroEnd);
      expect(zeroTween.lerp(0.0), equals(zeroBegin));
      expect(zeroTween.lerp(0.5), equals(zeroBegin));
      expect(zeroTween.lerp(1.0), equals(zeroBegin));

      // 3. 负坐标与极端缩放
      const negBegin = Rect.fromLTWH(-500, -200, 10, 10);
      const negEnd = Rect.fromLTWH(-100, -50, 2000, 2000);
      final negTween = NowPlayingArtworkRectTween(begin: negBegin, end: negEnd);
      final negLerp = negTween.lerp(0.5);
      expect(negLerp, isNotNull);
      expect(negLerp!.isFinite, isTrue);

      // 4. 外推时间点 (t < 0.0 or t > 1.0) 不发生崩溃
      final tNegative = zeroTween.lerp(-0.5);
      final tOverflow = zeroTween.lerp(1.5);
      expect(tNegative, isNotNull);
      expect(tOverflow, isNotNull);
    });
  });

  group('Adversarial Tier 5: Flight Shuttle & Hero Transition Dynamics', () {
    testWidgets('flight shuttle smoothly interpolates radius & maintains shadow across time slices', (tester) async {
      final animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 400),
      );
      addTearDown(animationController.dispose);

      final fromHeroKey = GlobalKey();
      final toHeroKey = GlobalKey();

      final audio = AdversarialTestAudio(
        title: 'Shuttle Audio',
        artist: 'Shuttle Artist',
        album: 'Shuttle Album',
        path: r'E:\Music\shuttle.flac',
        coverFuture: Future.value(MemoryImage(kValidTinyPngBytes)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Column(
              children: [
                Hero(
                  key: fromHeroKey,
                  tag: nowPlayingArtworkHeroTag,
                  child: NowPlayingArtworkCard(
                    audio: audio,
                    radius: 26.0,
                    elevation: 0.8,
                  ),
                ),
                Hero(
                  key: toHeroKey,
                  tag: 'target-hero',
                  child: RepaintBoundary(
                    child: NowPlayingArtworkCard(
                      audio: audio,
                      radius: 24.0,
                      elevation: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final fromContext = fromHeroKey.currentContext!;
      final toContext = toHeroKey.currentContext!;

      // 构造穿梭组件
      final flightWidget = nowPlayingArtworkFlightShuttleBuilder(
        fromContext,
        animationController,
        HeroFlightDirection.push,
        fromContext,
        toContext,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: flightWidget,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 验证在 t=0.0, 0.25, 0.5, 0.75, 1.0 各个关键节点下：
      final timePoints = [0.0, 0.25, 0.5, 0.75, 1.0];
      for (final t in timePoints) {
        animationController.value = t;
        await tester.pump();

        final cardFinder = find.byType(NowPlayingArtworkCard);
        expect(cardFinder, findsOneWidget);
        final card = tester.widget<NowPlayingArtworkCard>(cardFinder);

        // 验证半径严格介于 24.0 与 26.0 之间
        expect(card.radius, greaterThanOrEqualTo(23.999));
        expect(card.radius, lessThanOrEqualTo(26.001));

        // 验证具有阴影与标准海拔
        expect(card.showShadow, isTrue);
        expect(card.elevation, equals(1.0));

        // 验证外框裁切 ClipRRect 存在且圆角正确
        final clipFinder = find.byType(ClipRRect);
        expect(clipFinder, findsOneWidget);
        final clip = tester.widget<ClipRRect>(clipFinder);
        expect(clip.borderRadius, equals(BorderRadius.circular(card.radius)));
      }
    });

    testWidgets('flight shuttle gracefully falls back when hero children are non-artwork widgets', (tester) async {
      final animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
        value: 0.5,
      );
      addTearDown(animationController.dispose);

      final fromHeroKey = GlobalKey();
      final toHeroKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Column(
              children: [
                Hero(
                  key: fromHeroKey,
                  tag: 'from',
                  child: const SizedBox(width: 50, height: 50),
                ),
                Hero(
                  key: toHeroKey,
                  tag: 'to',
                  child: const Text('Unknown'),
                ),
              ],
            ),
          ),
        ),
      );

      final fromContext = fromHeroKey.currentContext!;
      final toContext = toHeroKey.currentContext!;

      // 穿梭构建器面对未知 Widget 不崩溃，优雅 fallback 默认圆角
      final shuttle = nowPlayingArtworkFlightShuttleBuilder(
        fromContext,
        animationController,
        HeroFlightDirection.push,
        fromContext,
        toContext,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(body: shuttle),
        ),
      );
      await tester.pump();

      expect(find.byType(NowPlayingArtworkCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid push and pop route transitions do not crash or leave orphan tickers', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = AdversarialTestAudio(
        title: 'Rapid Route Song',
        artist: 'Rapid Route Artist',
        album: 'Rapid Route Album',
        path: r'E:\Music\rapid_route.flac',
        coverFuture: Future.value(MemoryImage(kValidTinyPngBytes)),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: Navigator(
            key: navKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Column(
                    children: [
                      Expanded(child: Text('Home')),
                      BottomPlayerBar(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 打开播放详情页路由
      final navState = navKey.currentState!;
      navState.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return NowPlayingRouteTransitionScope(
              animation: animation,
              child: const NowPlayingPage(),
            );
          },
        ),
      );

      // 推进至飞行中途 (40ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      // 在飞行中途强行 pop
      navState.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 再次快速 push
      navState.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return NowPlayingRouteTransitionScope(
              animation: animation,
              child: const NowPlayingPage(),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(NowPlayingArtworkCard), findsWidgets);
    });
  });

  group('Adversarial Tier 5: Extreme & Malformed Input Resilience', () {
    testWidgets('handles null cover Future gracefully without breaking UI', (tester) async {
      final audio = AdversarialTestAudio(
        title: 'No Cover Song',
        artist: 'No Cover Artist',
        album: 'No Cover Album',
        path: r'E:\Music\no_cover.flac',
        coverFuture: Future.value(null),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: NowPlayingArtworkCard(audio: audio),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证优雅渲染占位音乐音符图标
      expect(find.byIcon(Symbols.music_note), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles corrupt cover image bytes via errorBuilder without unhandled exceptions', (tester) async {
      final audio = AdversarialTestAudio(
        title: 'Corrupt Cover Song',
        artist: 'Corrupt Cover Artist',
        album: 'Corrupt Cover Album',
        path: r'E:\Music\corrupt_cover.flac',
        coverFuture: Future.value(MemoryImage(kCorruptImageBytes)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: NowPlayingArtworkCard(audio: audio),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // errorBuilder 回退到占位符
      expect(find.byType(NowPlayingArtworkCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles extreme audio metadata: mono channel, 0 duration, empty strings, massive bitrate', (tester) async {
      final edgeAudio = AdversarialTestAudio(
        title: '',
        artist: '',
        album: '',
        duration: 0,
        bitrate: 192000, // 192 Mbps
        sampleRate: 768000, // 768 kHz
        path: r'E:\Music\extreme.dsf',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: AudioFormatBadge(
                audio: edgeAudio,
                compact: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AudioFormatBadge), findsOneWidget);
    });

    testWidgets('rapid song switching (50 switches) does not leak memory or throw race exceptions', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final songs = List.generate(
        50,
        (i) => AdversarialTestAudio(
          title: 'Stress Song #$i',
          artist: 'Stress Artist #$i',
          album: 'Stress Album #$i',
          path: 'E:\\Music\\stress_$i.flac',
          coverFuture: Future.value(MemoryImage(kValidTinyPngBytes)),
        ),
      );

      final playback = FakePlaybackController(
        audio: songs.first,
        queue: songs,
      );
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: const ImmersiveNowPlayingView(compact: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 连续高频切换 50 首歌曲
      for (int i = 0; i < 50; i++) {
        playback.setNowPlaying(songs[i], queue: songs);
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Stress Song #49'), findsOneWidget);
    });
  });

  group('Adversarial Tier 5: 3D Gesture Dragging, Boundary Physics & Geometry', () {
    testWidgets('3D drag clamp strictly bounds extreme offsets and maintains valid transform matrix', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = AdversarialTestAudio(
        title: '3D Drag Song',
        artist: '3D Artist',
        album: '3D Album',
        path: r'E:\Music\drag3d.flac',
        coverFuture: Future.value(MemoryImage(kValidTinyPngBytes)),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: const ImmersiveNowPlayingView(compact: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final dragTarget = find.byKey(const ValueKey('now-playing-artwork-drag'));
      expect(dragTarget, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(dragTarget));

      // 1. 超极大位移拖拽测试 (dx: 8000, dy: -6000)
      await gesture.moveBy(const Offset(8000, -6000));
      await tester.pump();

      Transform getTransformWidget() {
        return tester.widget<Transform>(
          find.descendant(of: dragTarget, matching: find.byType(Transform)).first,
        );
      }

      var transform = getTransformWidget().transform;
      // 验证变换矩阵有效且无 NaN / Infinity
      expect(transform.storage.every((v) => v.isFinite), isTrue);

      // 位移原点偏移距离必须严格被 clamp 在 10.0 像素以内
      var displacedOrigin = MatrixUtils.transformPoint(transform, Offset.zero);
      expect(displacedOrigin.distance, lessThanOrEqualTo(10.001));

      // 2. 负向极大位移拖拽测试 (dx: -9999, dy: 9999)
      await gesture.moveBy(const Offset(-18000, 16000));
      await tester.pump();

      transform = getTransformWidget().transform;
      expect(transform.storage.every((v) => v.isFinite), isTrue);
      displacedOrigin = MatrixUtils.transformPoint(transform, Offset.zero);
      expect(displacedOrigin.distance, lessThanOrEqualTo(10.001));

      // 3. 释放手势，验证阻尼弹簧平滑回弹至 (0,0)
      await gesture.up();
      await tester.pump();

      // 推进弹簧模拟过程
      for (int step = 0; step < 40; step++) {
        await tester.pump(const Duration(milliseconds: 16));
        final currentMatrix = getTransformWidget().transform;
        expect(currentMatrix.storage.every((v) => v.isFinite), isTrue);
      }
      await tester.pump(const Duration(milliseconds: 300));

      final settledMatrix = getTransformWidget().transform;
      final finalOrigin = MatrixUtils.transformPoint(settledMatrix, Offset.zero);
      expect(finalOrigin.distance, lessThan(0.01));
    });

    testWidgets('unmounting widget mid-drag does not cause setState after dispose or ticker leaks', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = AdversarialTestAudio(
        title: 'Unmount Drag Song',
        artist: 'Unmount Artist',
        album: 'Unmount Album',
        path: r'E:\Music\unmount_drag.flac',
        coverFuture: Future.value(MemoryImage(kValidTinyPngBytes)),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));

      var mountedState = true;
      late StateSetter updateTree;

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              if (!mountedState) {
                return const Scaffold(body: Text('Unmounted'));
              }
              return const ImmersiveNowPlayingView(compact: false);
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final dragTarget = find.byKey(const ValueKey('now-playing-artwork-drag'));
      final gesture = await tester.startGesture(tester.getCenter(dragTarget));
      await gesture.moveBy(const Offset(300, 200));
      await tester.pump();

      // 拖拽进行中强行卸载组件树
      updateTree(() => mountedState = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Unmounted'), findsOneWidget);

      await gesture.up();
    });

    testWidgets('route status reverse animation automatically resets drag state and halts spring', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = AdversarialTestAudio(
        title: 'Route Status Drag Song',
        artist: 'Route Status Artist',
        album: 'Route Status Album',
        path: r'E:\Music\route_status.flac',
        coverFuture: Future.value(MemoryImage(kValidTinyPngBytes)),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));

      final routeController = AnimationController(
        vsync: const TestVSync(),
        value: 1.0,
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(routeController.dispose);

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: NowPlayingRouteTransitionScope(
            animation: routeController,
            child: const ImmersiveNowPlayingView(compact: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final dragTarget = find.byKey(const ValueKey('now-playing-artwork-drag'));
      final gesture = await tester.startGesture(tester.getCenter(dragTarget));
      await gesture.moveBy(const Offset(80, 50));
      await tester.pump();

      // 模拟路由退出反向动画启动
      routeController.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('Adversarial Tier 5: Dead Code Elimination Static Verification', () {
    test('verifies turntable / vinyl dead code is 100% eliminated from the codebase', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final forbiddenKeywords = [
        'turntable',
        'vinyl',
        'stylus',
        'tonearm',
        '唱机',
        '黑胶',
        '唱针',
      ];

      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync().toLowerCase();
          for (final keyword in forbiddenKeywords) {
            if (content.contains(keyword.toLowerCase())) {
              violations.add('${entity.path} contains forbidden keyword "$keyword"');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Found remnants of turntable/vinyl dead code:\n${violations.join('\n')}',
      );
    });

    test('verifies NowPlayingPage only instantiates pure album artwork stage', () {
      final pageFile = File('lib/page/now_playing_page/component_views.dart');
      expect(pageFile.existsSync(), isTrue);
      final content = pageFile.readAsStringSync();

      // 验证包含现代纯画册组件 _ArtworkStageView / NowPlayingArtworkCard
      expect(content.contains('_NowPlayingArtwork'), isTrue);
      expect(content.contains('NowPlayingArtworkCard'), isTrue);
      expect(content.contains('nowPlayingArtworkHeroTag'), isTrue);
    });
  });
}


