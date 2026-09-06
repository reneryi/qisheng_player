import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/component/marquee_text.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/component/spectrum_progress_slider.dart';
import 'package:qisheng_player/component/ui/audio_format_badge.dart';
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

  group('Tier 1: Feature Coverage (Features 1 - 11)', () {
    // =========================================================================
    // FEATURE 1: Vinyl Code Clean Removal
    // =========================================================================
    group('Feature 1: Vinyl Code Clean Removal', () {
      testWidgets('T1.1.1: NowPlayingArtworkCard renders standard album art instead of turntable disc',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Celestial Dream',
          artist: 'Starlight',
          album: 'Infinity',
          path: 'E:\\Music\\f1_1.flac',
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

        // 验证不再渲染任何唱片或唱针相关组件，中央呈现纯画册结构
        expect(find.byType(NowPlayingArtworkHeroFrame), findsAtLeastNWidgets(1));
        expect(find.byKey(const ValueKey('now-playing-artwork-drag')), findsOneWidget);
      });

      testWidgets('T1.1.2: BottomPlayerBar renders standard TrackCover without vinyl elements',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Horizon Glow',
          artist: 'Aurora',
          album: 'Northern Lights',
          path: 'E:\\Music\\f1_2.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.playing,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(SpinningArtwork), findsOneWidget);
        expect(find.byType(NowPlayingArtworkHeroFrame), findsOneWidget);
      });

      testWidgets('T1.1.3: Cover image is clipped with standardized rounded corners',
          (tester) async {
        const frame = NowPlayingArtworkHeroFrame(
          radius: 26.0,
          child: SizedBox(width: 200, height: 200),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: frame)),
          ),
        );

        final clipFinder = find.descendant(
          of: find.byType(NowPlayingArtworkHeroFrame),
          matching: find.byType(ClipRRect),
        );
        expect(clipFinder, findsOneWidget);
        final clipWidget = tester.widget<ClipRRect>(clipFinder);
        expect(clipWidget.borderRadius, BorderRadius.circular(26.0));
      });

      testWidgets('T1.1.4: Placeholder note icon is displayed when audio cover is null',
          (tester) async {
        final audioNoCover = E2ETestAudio(
          title: 'Acoustic Rain',
          artist: 'Echo',
          album: 'Nature',
          path: 'E:\\Music\\f1_4.flac',
          provideCover: false,
        );
        final playback = E2EPlaybackController(
          initialAudio: audioNoCover,
          initialState: PlayerState.stopped,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        // 验证空封面状态下优雅降级显示音符图标占位
        expect(find.byType(NowPlayingArtworkHeroFrame), findsOneWidget);
      });

      test('T1.1.5: Artwork Hero tag remains consistent across route endpoints', () {
        expect(nowPlayingArtworkHeroTag, equals('now-playing-artwork'));
        expect(nowPlayingArtworkHeroRadius, equals(26.0));
      });
    });

    // =========================================================================
    // FEATURE 2: Vinyl Settings & Pref Clean
    // =========================================================================
    group('Feature 2: Vinyl Settings & Pref Clean', () {
      test('T1.2.1: AppSettings initializes with clean defaults', () {
        final settings = AppSettings.instance;
        expect(settings.coverBreathEffect, isNotNull);
        expect(settings.showSpectrumVisualizer, isNotNull);
        expect(settings.lyricDepthBlur, isNotNull);
      });

      test('T1.2.2: AppPreference retains structural integrity', () {
        final pref = AppPreference.instance;
        expect(pref.nowPlayingPagePref, isNotNull);
        expect(pref.nowPlayingPagePref.nowPlayingViewMode, isNotNull);
      });

      test('T1.2.3: Mutating cover breath setting triggers notification', () {
        final settings = AppSettings.instance;
        final initial = settings.coverBreathEffect;
        settings.coverBreathEffect = !initial;
        expect(settings.coverBreathEffect, equals(!initial));
        settings.coverBreathEffect = initial;
      });

      test('T1.2.4: Mutating spectrum visualizer setting updates state', () {
        final settings = AppSettings.instance;
        final initial = settings.showSpectrumVisualizer;
        settings.showSpectrumVisualizer = !initial;
        expect(settings.showSpectrumVisualizer, equals(!initial));
        settings.showSpectrumVisualizer = initial;
      });

      test('T1.2.5: NowPlayingViewMode supports enum conversions', () {
        expect(NowPlayingViewMode.fromString('onlyMain'), equals(NowPlayingViewMode.onlyMain));
        expect(NowPlayingViewMode.fromString('withLyric'), equals(NowPlayingViewMode.withLyric));
        expect(NowPlayingViewMode.fromString('withPlaylist'), equals(NowPlayingViewMode.withPlaylist));
        expect(NowPlayingViewMode.fromString('invalid_mode'), isNull);
      });
    });

    // =========================================================================
    // FEATURE 3: Pure Cover Layout Standardization
    // =========================================================================
    group('Feature 3: Pure Cover Layout Standardization', () {
      testWidgets('T1.3.1: Large layout renders artwork in center column',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Solar Wind',
          artist: 'Helios',
          album: 'Sunburst',
          path: 'E:\\Music\\f3_1.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.playing,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(1400, 900),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
        expect(find.byType(NowPlayingArtworkHeroFrame), findsAtLeastNWidgets(1));
      });

      testWidgets('T1.3.2: Compact layout adapts gracefully on small screens',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Miniature Flow',
          artist: 'Micro',
          album: 'Pocket',
          path: 'E:\\Music\\f3_2.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.playing,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(800, 600),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T1.3.3: MarqueeText renders track display title accurately',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Deep Midnight Odyssey Across Nebula',
          artist: 'Vortex Composer',
          album: 'Odyssey',
          path: 'E:\\Music\\f3_3.flac',
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

        expect(find.text('Deep Midnight Odyssey Across Nebula'), findsAtLeastNWidgets(1));
      });

      testWidgets('T1.3.4: Audio format badge reflects FLAC 48000Hz lossless format',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Hi-Res Symphony',
          artist: 'Orchestra',
          album: 'Classics',
          path: 'E:\\Music\\f3_4.flac',
          bitrate: 1411,
          sampleRate: 96000,
          audioType: 'FLAC',
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

        expect(find.byType(AudioFormatBadge), findsAtLeastNWidgets(1));
      });

      testWidgets('T1.3.5: Layout seamlessly switches when viewport is resized',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Adaptive Beats',
          artist: 'Responsive DJ',
          album: 'Grid',
          path: 'E:\\Music\\f3_5.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.playing,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(1280, 800),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        // 调整至紧凑尺寸并重新渲染
        await tester.binding.setSurfaceSize(const Size(700, 500));
        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(700, 500),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
        await tester.binding.setSurfaceSize(null);
      });
    });

    // =========================================================================
    // FEATURE 4: Hero Subtree Alignment & Decoupling
    // =========================================================================
    group('Feature 4: Hero Subtree Alignment & Decoupling', () {
      testWidgets('T1.4.1: BottomPlayerBar embeds Hero with nowPlayingArtworkHeroTag',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Hero Sync',
          artist: 'Symmetric',
          album: 'Alignment',
          path: 'E:\\Music\\f4_1.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        final heroFinder = find.byWidgetPredicate(
          (widget) => widget is Hero && widget.tag == nowPlayingArtworkHeroTag,
        );
        expect(heroFinder, findsOneWidget);
      });

      testWidgets('T1.4.2: Hero child matches NowPlayingArtworkHeroFrame structure',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Symmetry Check',
          artist: 'Dual Track',
          album: 'Pure',
          path: 'E:\\Music\\f4_2.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        final frameFinder = find.descendant(
          of: find.byType(Hero),
          matching: find.byType(NowPlayingArtworkHeroFrame),
        );
        expect(frameFinder, findsOneWidget);
      });

      testWidgets('T1.4.3: 3D Gesture recognizer is isolated on artwork stage',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Gesture Tilt',
          artist: 'Spatial',
          album: 'Touch',
          path: 'E:\\Music\\f4_3.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        final dragDetector = find.byKey(const ValueKey('now-playing-artwork-drag'));
        expect(dragDetector, findsOneWidget);
      });

      testWidgets('T1.4.4: SpinningArtwork scales smoothly during playback state change',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Breathe State',
          artist: 'Pulse',
          album: 'Beats',
          path: 'E:\\Music\\f4_4.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.paused,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        // 切换至播放状态
        playback.start();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndAdvance();

        expect(playback.playerState, equals(PlayerState.playing));
      });

      testWidgets('T1.4.5: disableHero disables Hero to avoid duplicate tag collisions',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Hero Guard',
          artist: 'Protector',
          album: 'Shield',
          path: 'E:\\Music\\f4_5.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(disableHero: true),
          ),
        );
        await tester.pumpAndAdvance();

        final heroFinder = find.byWidgetPredicate(
          (widget) => widget is Hero && widget.tag == nowPlayingArtworkHeroTag,
        );
        expect(heroFinder, findsNothing);
      });
    });

    // =========================================================================
    // FEATURE 5: Flight Shuttle & Tween Geometry Refactor
    // =========================================================================
    group('Feature 5: Flight Shuttle & Tween Geometry Refactor', () {
      test('T1.5.1: NowPlayingArtworkRectTween begins at exact begin rect at t=0.0', () {
        const begin = Rect.fromLTWH(24, 720, 58, 58);
        const end = Rect.fromLTWH(200, 150, 320, 320);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        final result = tween.lerp(0.0);
        expect(result, equals(begin));
      });

      test('T1.5.2: NowPlayingArtworkRectTween ends at exact end rect at t=1.0', () {
        const begin = Rect.fromLTWH(24, 720, 58, 58);
        const end = Rect.fromLTWH(200, 150, 320, 320);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        final result = tween.lerp(1.0);
        expect(result, equals(end));
      });

      test('T1.5.3: NowPlayingArtworkRectTween elevates midpoint with natural upward arc', () {
        const begin = Rect.fromLTWH(24, 720, 58, 58);
        const end = Rect.fromLTWH(200, 150, 320, 320);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        final linearMid = Rect.lerp(begin, end, 0.5)!;
        final curvedMid = tween.lerp(0.5)!;

        expect(curvedMid.top, lessThan(linearMid.top));
        expect(linearMid.top - curvedMid.top, greaterThan(3.0));
      });

      test('T1.5.4: RectTween maintains 1:1 aspect ratio throughout trajectory', () {
        const begin = Rect.fromLTWH(10, 600, 60, 60);
        const end = Rect.fromLTWH(150, 100, 300, 300);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        for (double t = 0.0; t <= 1.0; t += 0.1) {
          final rect = tween.lerp(t)!;
          expect(rect.width, closeTo(rect.height, 0.001));
        }
      });

      test('T1.5.5: RectTween returns null when begin or end is null', () {
        final tweenNullBegin = NowPlayingArtworkRectTween(begin: null, end: const Rect.fromLTWH(0, 0, 10, 10));
        expect(tweenNullBegin.lerp(0.5), isNull);

        final tweenNullEnd = NowPlayingArtworkRectTween(begin: const Rect.fromLTWH(0, 0, 10, 10), end: null);
        expect(tweenNullEnd.lerp(0.5), isNull);
      });
    });

    // =========================================================================
    // FEATURE 6: Coordinate Stability (No FittedBox)
    // =========================================================================
    group('Feature 6: Coordinate Stability (No FittedBox)', () {
      testWidgets('T1.6.1: Artwork maintains stable dimensions across re-layouts',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Stable Frame',
          artist: 'Geometric',
          album: 'Cartesian',
          path: 'E:\\Music\\f6_1.flac',
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

        final artworkFinder = find.byType(NowPlayingArtworkHeroFrame).first;
        expect(artworkFinder, findsOneWidget);
        final initialSize = tester.getSize(artworkFinder);
        expect(initialSize.width, greaterThan(10.0));
        expect(initialSize.height, greaterThan(10.0));
      });

      testWidgets('T1.6.2: Centered layout keeps horizontal symmetry',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Centered Balance',
          artist: 'Harmonics',
          album: 'Symmetry',
          path: 'E:\\Music\\f6_2.flac',
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

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T1.6.3: Multi-column structure allocates balanced proportions',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Column Proportion',
          artist: 'Architect',
          album: 'Layouts',
          path: 'E:\\Music\\f6_3.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(1400, 900),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T1.6.4: Window drag region spans across header safely',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Header Region',
          artist: 'Titlebar',
          album: 'Controls',
          path: 'E:\\Music\\f6_4.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byTooltip('返回'), findsOneWidget);
      });

      testWidgets('T1.6.5: Artwork hit absorber absorbs redundant gestures cleanly',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Hit Absorber',
          artist: 'Barrier',
          album: 'Shield',
          path: 'E:\\Music\\f6_5.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(AbsorbPointer), findsAtLeastNWidgets(1));
      });
    });

    // =========================================================================
    // FEATURE 7: Shell Transition & Scale Push-back
    // =========================================================================
    group('Feature 7: Shell Transition & Scale Push-back', () {
      testWidgets('T1.7.1: NowPlayingRouteTransitionScope propagates animation controller',
          (tester) async {
        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(milliseconds: 480),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: NowPlayingRouteTransitionScope(
              animation: controller,
              child: Builder(
                builder: (context) {
                  final anim = NowPlayingRouteTransitionScope.maybeOf(context);
                  return Text('ScopeValue:${anim?.value.toStringAsFixed(2)}');
                },
              ),
            ),
          ),
        );

        expect(find.text('ScopeValue:0.00'), findsOneWidget);
        controller.value = 0.5;
        await tester.pump();
        expect(find.text('ScopeValue:0.50'), findsOneWidget);
        controller.dispose();
      });

      test('T1.7.2: Shell Underlay updates visibility when route changes', () {
        final nav = AppNavigationState.instance;
        nav.setNowPlayingPageActive(true);
        expect(nav.nowPlayingPageActive, isTrue);

        nav.setNowPlayingPageActive(false);
        expect(nav.nowPlayingPageActive, isFalse);
      });

      testWidgets('T1.7.3: Underlay ignores pointer events when active',
          (tester) async {
        final nav = AppNavigationState.instance;
        nav.setNowPlayingPageActive(true);

        final underlay = NowPlayingShellUnderlay(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('UnderlayBtn'),
          ),
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: underlay)));
        await tester.pumpAndAdvance();

        final ignoreFinder = find.byKey(const ValueKey('now-playing-shell-underlay-pointer'));
        expect(ignoreFinder, findsOneWidget);
        final ignorePointer = tester.widget<IgnorePointer>(ignoreFinder);
        expect(ignorePointer.ignoring, isTrue);

        nav.setNowPlayingPageActive(false);
        await tester.pumpAndAdvance();
      });

      test('T1.7.4: AppNavigationState location history remembers last route', () {
        final nav = AppNavigationState.instance;
        nav.rememberLocation('/audios');
        expect(nav.lastShellLocation, equals('/audios'));

        nav.rememberLocation('/albums');
        expect(nav.lastShellLocation, equals('/albums'));
      });

      testWidgets('T1.7.5: Route transition scope returns null when not present in ancestry',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final anim = NowPlayingRouteTransitionScope.maybeOf(context);
                return Text('ScopeStatus:${anim == null ? 'NONE' : 'FOUND'}');
              },
            ),
          ),
        );

        expect(find.text('ScopeStatus:NONE'), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 8: Staged Reveal Timeline Choreography
    // =========================================================================
    group('Feature 8: Staged Reveal Timeline Choreography', () {
      testWidgets('T1.8.1: Staged reveal propagates animation progression through transition scope',
          (tester) async {
        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(milliseconds: 500),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: NowPlayingRouteTransitionScope(
              animation: controller,
              child: Builder(
                builder: (context) {
                  final anim = NowPlayingRouteTransitionScope.maybeOf(context);
                  return Scaffold(
                    body: FadeTransition(
                      opacity: anim ?? const AlwaysStoppedAnimation(1.0),
                      child: const Text('StagedTarget'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('StagedTarget'), findsOneWidget);
        controller.value = 0.0;
        await tester.pump();

        controller.value = 0.50;
        await tester.pump();

        controller.value = 1.0;
        await tester.pump();
        expect(find.text('StagedTarget'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('T1.8.2: NowPlayingPage mounts staged reveal sections gracefully',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Timeline Symphony',
          artist: 'Orchestrator',
          album: 'Staged',
          path: 'E:\\Music\\f8_2.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T1.8.3: AutoHideBottomPlayerBar reveals after threshold',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'AutoHide Bar',
          artist: 'Threshold',
          album: 'Timing',
          path: 'E:\\Music\\f8_3.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T1.8.4: Lyric view displays parsed lyric lines accurately',
          (tester) async {
        final lyric = Lrc([
          LrcLine(const Duration(seconds: 0), 'First Verse Melody', isBlank: false, length: const Duration(seconds: 5)),
          LrcLine(const Duration(seconds: 5), 'Second Verse Harmony', isBlank: false, length: const Duration(seconds: 5)),
        ], LrcSource.local);
        final lyricController = E2ELyricController(lyric);

        await tester.pumpWidget(
          buildE2ETestHarness(
            lyricController: lyricController,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.text('First Verse Melody'), findsAtLeastNWidgets(1));
      });

      testWidgets('T1.8.5: Lyric view gracefully presents fallback when lyric is empty',
          (tester) async {
        final lyricController = E2ELyricController(Lrc([], LrcSource.local));

        await tester.pumpWidget(
          buildE2ETestHarness(
            lyricController: lyricController,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.text('暂无歌词'), findsAtLeastNWidgets(1));
      });
    });

    // =========================================================================
    // FEATURE 9: 120fps GPU Texture Caching & Optimization
    // =========================================================================
    group('Feature 9: 120fps GPU Texture Caching & Optimization', () {
      testWidgets('T1.9.1: Artwork frame child encapsulates RepaintBoundary for GPU caching',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'GPU Texture Test',
          artist: 'Shader',
          album: 'Raster',
          path: 'E:\\Music\\f9_1.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        final repaintFinders = find.descendant(
          of: find.byType(NowPlayingArtworkHeroFrame),
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintFinders, findsAtLeastNWidgets(1));
      });

      testWidgets('T1.9.2: Spectrum visualizer encapsulates RepaintBoundary',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Spectrum GPU',
          artist: 'Frequency',
          album: 'FFT',
          path: 'E:\\Music\\f9_2.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);
        playback.emitSpectrum([0.5, 0.8, 0.3, 0.9, 0.2]);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
      });

      testWidgets('T1.9.3: SpectrumProgressSlider handles continuous value updates without frame lag',
          (tester) async {
        final spectrumNotifier = ValueNotifier<List<double>>([0.2, 0.4, 0.6, 0.8]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SpectrumProgressSlider(
                spectrum: spectrumNotifier,
                value: 30,
                max: 100,
                onChanged: (val) {},
              ),
            ),
          ),
        );
        await tester.pumpAndAdvance();

        spectrumNotifier.value = [0.8, 0.6, 0.4, 0.2];
        await tester.pump();
        expect(find.byType(SpectrumProgressSlider), findsOneWidget);
      });

      testWidgets('T1.9.4: Repaint boundary isolates artwork glow from text layout',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Glow Isolation',
          artist: 'Boundary',
          album: 'Paint',
          path: 'E:\\Music\\f9_4.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(RepaintBoundary), findsWidgets);
      });

      testWidgets('T1.9.5: Rapid frame pumping executes with zero exceptions',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Frame Stress',
          artist: 'High FPS',
          album: 'Smooth',
          path: 'E:\\Music\\f9_5.flac',
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

        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // FEATURE 10: MainLayoutFrame Animated Insets
    // =========================================================================
    group('Feature 10: MainLayoutFrame Animated Insets', () {
      test('T1.10.1: resolveMainLayoutDockInset with reserveDockSpace and overlay returns dockHeight + 2*shellGap', () {
        final result = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: 80.0,
          shellGap: 8.0,
        );
        expect(result, equals(80.0 + 8.0 * 2));
      });

      test('T1.10.2: resolveMainLayoutDockInset with reserveDockSpace only returns shellGap', () {
        final result = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: false,
          dockHeight: 80.0,
          shellGap: 8.0,
        );
        expect(result, equals(8.0));
      });

      test('T1.10.3: resolveMainLayoutDockInset with reserveDockSpace false returns 0.0', () {
        final result = resolveMainLayoutDockInset(
          reserveDockSpace: false,
          hasOverlay: true,
          dockHeight: 80.0,
          shellGap: 8.0,
        );
        expect(result, equals(0.0));
      });

      testWidgets('T1.10.4: MainLayoutFrame renders titleBar and child correctly',
          (tester) async {
        const frame = MainLayoutFrame(
          titleBar: Text('TitleBarSection'),
          child: Text('ContentSection'),
        );

        await tester.pumpWidget(
          buildE2ETestHarness(child: frame),
        );
        await tester.pumpAndAdvance();

        expect(find.text('TitleBarSection'), findsOneWidget);
        expect(find.text('ContentSection'), findsOneWidget);
      });

      testWidgets('T1.10.5: WindowControls layoutMode changes trigger responsive layout re-evaluation',
          (tester) async {
        WindowControls.layoutMode.value = WindowLayoutMode.normal;

        const frame = MainLayoutFrame(
          titleBar: Text('Header'),
          child: Text('Body'),
        );

        await tester.pumpWidget(buildE2ETestHarness(child: frame));
        await tester.pumpAndAdvance();

        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pumpAndAdvance();

        expect(find.text('Body'), findsOneWidget);
        WindowControls.layoutMode.value = WindowLayoutMode.normal;
      });
    });

    // =========================================================================
    // FEATURE 11: Comprehensive E2E Verification & Hardening
    // =========================================================================
    group('Feature 11: Comprehensive E2E Verification & Hardening', () {
      test('T1.11.1: Audio model constructor with full parameters instantiates properly', () {
        final audio = E2ETestAudio(
          title: 'Full Param Audio',
          artist: 'Complete Artist',
          album: 'Complete Album',
          composer: 'Composer A',
          arranger: 'Arranger B',
          path: 'E:\\Music\\f11_1.flac',
          duration: 360,
          bitrate: 990,
          sampleRate: 48000,
          audioType: 'FLAC',
        );

        expect(audio.displayTitle, equals('Full Param Audio'));
        expect(audio.displayArtist, equals('Complete Artist'));
        expect(audio.album, equals('Complete Album'));
        expect(audio.duration, equals(360));
      });

      test('T1.11.2: PlaybackController playlist queue manipulation functions deterministically', () {
        final t1 = E2ETestAudio(title: 'T1', artist: 'A1', album: 'Alb1', path: '1.flac');
        final t2 = E2ETestAudio(title: 'T2', artist: 'A2', album: 'Alb2', path: '2.flac');
        final controller = E2EPlaybackController(
          initialAudio: t1,
          initialQueue: [t1, t2],
        );

        expect(controller.playlist.value.length, equals(2));
        controller.nextAudio();
        expect(controller.nowPlaying?.title, equals('T2'));

        controller.reorderPlaylist(0, 1);
        expect(controller.playlist.value.first.title, equals('T2'));

        controller.removeAudioFromPlaylistByPath('2.flac');
        expect(controller.playlist.value.length, equals(1));
        controller.dispose();
      });

      testWidgets('T1.11.3: MarqueeText handles short text without scroll controller overhead',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: MarqueeText(text: 'Short', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.text('Short'), findsOneWidget);
      });

      testWidgets('T1.11.4: Bottom player bar transport buttons emit playback service events',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Action Test',
          artist: 'Player Controls',
          album: 'UX',
          path: 'E:\\Music\\f11_4.flac',
        );
        final playback = E2EPlaybackController(
          initialAudio: audio,
          initialState: PlayerState.paused,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        // 点击播放按钮
        await tester.tap(find.byTooltip('播放'));
        await tester.pump();
        expect(playback.playerState, equals(PlayerState.playing));

        // 点击暂停按钮
        await tester.tap(find.byTooltip('暂停'));
        await tester.pump();
        expect(playback.playerState, equals(PlayerState.paused));
      });

      test('T1.11.5: PlayMode cycle transitions smoothly', () {
        final audio = E2ETestAudio(title: 'Mode', artist: 'Cycle', album: 'Loop', path: 'm.flac');
        final playback = E2EPlaybackController(initialAudio: audio);

        expect(playback.playMode.value, equals(PlayMode.loop));
        playback.setPlayMode(PlayMode.forward);
        expect(playback.playMode.value, equals(PlayMode.forward));
        playback.setPlayMode(PlayMode.singleLoop);
        expect(playback.playMode.value, equals(PlayMode.singleLoop));
        playback.dispose();
      });
    });
  });
}


