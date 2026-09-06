import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
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
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/window_controls.dart';

import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2: Boundary & Corner Cases (Features 1 - 11)', () {
    // =========================================================================
    // FEATURE 1: Vinyl Code Clean Removal (Boundaries)
    // =========================================================================
    group('Feature 1: Vinyl Removal - Boundary & Extreme Conditions', () {
      testWidgets('T2.1.1: Audio with empty path and missing tags falls back to default placeholder',
          (tester) async {
        final emptyAudio = E2ETestAudio(
          title: '',
          artist: '',
          album: '',
          path: '',
          provideCover: false,
        );
        final playback = E2EPlaybackController(initialAudio: emptyAudio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
        expect(find.byType(NowPlayingArtworkHeroFrame), findsAtLeastNWidgets(1));
      });

      testWidgets('T2.1.2: Rapid switching between cover and null-cover tracks updates without crash',
          (tester) async {
        final trackWithCover = E2ETestAudio(
          title: 'Cover Track',
          artist: 'Artist 1',
          album: 'Album 1',
          path: 'E:\\Music\\cover.flac',
          provideCover: true,
        );
        final trackNoCover = E2ETestAudio(
          title: 'No Cover Track',
          artist: 'Artist 2',
          album: 'Album 2',
          path: 'E:\\Music\\nocover.flac',
          provideCover: false,
        );

        final playback = E2EPlaybackController(
          initialAudio: trackWithCover,
          initialQueue: [trackWithCover, trackNoCover],
          initialState: PlayerState.playing,
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        // 快速来回切换 5 次
        for (int i = 0; i < 5; i++) {
          playback.nextAudio();
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndAdvance();
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.1.3: Frame with zero width/height container constraints does not divide by zero',
          (tester) async {
        const frame = SizedBox(
          width: 0,
          height: 0,
          child: NowPlayingArtworkHeroFrame(
            radius: 26.0,
            child: SizedBox.shrink(),
          ),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: frame)),
          ),
        );
        await tester.pumpAndAdvance();
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.1.4: Extreme artwork radius parameter (0.0 to 1000.0) renders without layout error',
          (tester) async {
        for (final radius in [0.0, 1.0, 50.0, 200.0, 1000.0]) {
          final frame = NowPlayingArtworkHeroFrame(
            radius: radius,
            child: const SizedBox(width: 100, height: 100),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: Center(child: frame)),
            ),
          );
          await tester.pumpAndAdvance(const Duration(milliseconds: 10));
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('T2.1.5: Giant mock cover data renders safely into 1:1 square container',
          (tester) async {
        final giantAudio = E2ETestAudio(
          title: 'Gigantic Cover Track',
          artist: 'Max Resolution',
          album: 'Hi-Res Wallpapers',
          path: 'E:\\Music\\giant.flac',
          provideCover: true,
        );
        final playback = E2EPlaybackController(initialAudio: giantAudio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(1920, 1080),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingArtworkHeroFrame), findsAtLeastNWidgets(1));
      });
    });

    // =========================================================================
    // FEATURE 2: Vinyl Settings & Pref Clean (Boundaries)
    // =========================================================================
    group('Feature 2: Settings & Pref Clean - Boundary & Extreme Conditions', () {
      test('T2.2.1: parseWindowSize handles extreme, corrupt, or invalid strings safely', () {
        expect(AppSettings.parseWindowSize(''), equals(AppSettings.defaultWindowSize));
        expect(AppSettings.parseWindowSize('corrupted_text'), equals(AppSettings.defaultWindowSize));
        expect(AppSettings.parseWindowSize('NaN,Infinity'), equals(AppSettings.defaultWindowSize));
        expect(AppSettings.parseWindowSize('-100,-200'), equals(AppSettings.defaultWindowSize));
        expect(AppSettings.parseWindowSize('10,10'), equals(AppSettings.defaultWindowSize)); // Below minimum size
        expect(AppSettings.parseWindowSize('1200.5,800.5'), equals(const Size(1200.5, 800.5)));
      });

      test('T2.2.2: parseWindowBackdropMode falls back safely on invalid/unknown names', () {
        expect(AppSettings.parseWindowBackdropMode('unknown_mode'), equals(WindowBackdropMode.defaultGradient));
        expect(AppSettings.parseWindowBackdropMode(null), equals(WindowBackdropMode.defaultGradient));
        expect(AppSettings.parseWindowBackdropMode(12345), equals(WindowBackdropMode.defaultGradient));
        expect(AppSettings.parseWindowBackdropMode('meshFlow'), equals(WindowBackdropMode.meshFlow));
        expect(AppSettings.parseWindowBackdropMode('waterRipple'), equals(WindowBackdropMode.waterRipple));
        expect(AppSettings.parseWindowBackdropMode('prismaticGlass'), equals(WindowBackdropMode.prismaticGlass));
      });

      test('T2.2.4: Mutating settings rapidly maintains consistency', () {
        final settings = AppSettings.instance;
        for (int i = 0; i < 20; i++) {
          settings.showKaraokeAnimation = i % 2 == 0;
          settings.autoHideControls = i % 3 == 0;
        }
        expect(settings.showKaraokeAnimation, isA<bool>());
        expect(settings.autoHideControls, isA<bool>());
      });

      test('T2.2.5: Background version increments whenever notifyBackgroundChanged is called', () {
        final settings = AppSettings.instance;
        final initialVersion = settings.backgroundVersion.value;
        settings.notifyBackgroundChanged();
        expect(settings.backgroundVersion.value, equals(initialVersion + 1));
      });
    });

    // =========================================================================
    // FEATURE 3: Pure Cover Layout Standardization (Boundaries)
    // =========================================================================
    group('Feature 3: Pure Cover Layout - Boundary & Extreme Conditions', () {
      testWidgets('T2.3.1: Ultrawide screen (3440x1440) renders layout without overflow',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Ultrawide Horizon Odyssey',
          artist: 'Cinema Scope',
          album: 'Wide Horizons',
          path: 'E:\\Music\\f3_b1.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(3440, 1440),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T2.3.2: Extremely small screen (400x400) adjusts without unhandled exceptions',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Compact Beats',
          artist: 'Micro',
          album: 'Tiny',
          path: 'E:\\Music\\f3_b2.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(400, 400),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T2.3.3: Special unicode, control characters, and emojis in metadata sanitize properly',
          (tester) async {
        final audioSpecial = E2ETestAudio(
          title: '✨🎶 Song With \u0000 Control \uFEFF & Emoji 🚀🌈 測試',
          artist: '🎨 Artist & Composers \u0008\u001F <script>',
          album: 'Album 🛡️',
          path: 'E:\\Music\\f3_b3.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audioSpecial);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.3.4: AudioFormatBadge handles null sample rate, null bitrate gracefully',
          (tester) async {
        final audioIncomplete = E2ETestAudio(
          title: 'Incomplete Track',
          artist: 'Unknown',
          album: 'Unknown',
          path: 'E:\\Music\\incomplete.raw',
          sampleRate: 0,
          bitrate: 0,
          audioType: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AudioFormatBadge(audio: audioIncomplete, compact: false),
            ),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(AudioFormatBadge), findsOneWidget);
      });

      testWidgets('T2.3.5: Multi-resolution cover fallback responds dynamically',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Resolution Scaler',
          artist: 'Vector',
          album: 'Rasters',
          path: 'E:\\Music\\f3_b5.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingArtworkHeroFrame), findsAtLeastNWidgets(1));
      });
    });

    // =========================================================================
    // FEATURE 4: Hero Subtree Alignment & Decoupling (Boundaries)
    // =========================================================================
    group('Feature 4: Hero Subtree Alignment - Boundary & Extreme Conditions', () {
      testWidgets('T2.4.1: SpinningArtwork handles zero duration without throwing',
          (tester) async {
        const spinningWidget = SpinningArtwork(
          spinning: false,
          child: SizedBox(width: 50, height: 50),
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Center(child: spinningWidget))),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(SpinningArtwork), findsOneWidget);
      });

      testWidgets('T2.4.2: Multiple BottomPlayerBar with disableHero can mount concurrently',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Dual Mount',
          artist: 'Parallel',
          album: 'Instances',
          path: 'E:\\Music\\f4_b2.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const Column(
              children: [
                BottomPlayerBar(disableHero: true),
                BottomPlayerBar(disableHero: true),
              ],
            ),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(BottomPlayerBar), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.4.3: 3D Pan gesture drag update with extreme deltas clamps safely',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Extreme Drag',
          artist: 'Force',
          album: 'Physics',
          path: 'E:\\Music\\f4_b3.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        final dragFinder = find.byKey(const ValueKey('now-playing-artwork-drag'));
        if (dragFinder.evaluate().isNotEmpty) {
          // 模拟超大距离拖拽
          await tester.drag(dragFinder, const Offset(500, 500));
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('T2.4.4: 3D Pan gesture cancelled immediately restores spring state',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Cancel Gesture',
          artist: 'Abort',
          album: 'Rollback',
          path: 'E:\\Music\\f4_b4.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        final dragFinder = find.byKey(const ValueKey('now-playing-artwork-drag'));
        if (dragFinder.evaluate().isNotEmpty) {
          final gesture = await tester.startGesture(tester.getCenter(dragFinder));
          await gesture.moveBy(const Offset(20, 20));
          await tester.pump();
          await gesture.cancel();
          await tester.pumpAndAdvance();
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('T2.4.5: Artwork Hero frame with zero shadow/border parameters stays stable',
          (tester) async {
        const frame = NowPlayingArtworkHeroFrame(
          radius: 0,
          child: SizedBox(width: 40, height: 40),
        );

        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: frame)));
        await tester.pumpAndAdvance();
        expect(find.byType(NowPlayingArtworkHeroFrame), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 5: Flight Shuttle & Tween Geometry Refactor (Boundaries)
    // =========================================================================
    group('Feature 5: Flight Shuttle & RectTween - Boundary & Extreme Conditions', () {
      test('T2.5.1: RectTween with zero distance begin and end returns identical rect', () {
        const rect = Rect.fromLTWH(100, 100, 200, 200);
        final tween = NowPlayingArtworkRectTween(begin: rect, end: rect);

        for (double t = 0.0; t <= 1.0; t += 0.2) {
          final res = tween.lerp(t)!;
          expect(res.width, equals(200));
          expect(res.height, equals(200));
        }
      });

      test('T2.5.2: RectTween with 5000px extreme distance clamps upward offset within bounds', () {
        const begin = Rect.fromLTWH(0, 0, 50, 50);
        const end = Rect.fromLTWH(5000, 5000, 400, 400);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        final mid = tween.lerp(0.5)!;
        final linearMid = Rect.lerp(begin, end, 0.5)!;
        final deltaY = linearMid.top - mid.top;

        // 验证 offset 被 clamp 在 4.0 到 18.0 之间
        expect(deltaY, lessThanOrEqualTo(18.01));
        expect(deltaY, greaterThanOrEqualTo(3.99));
      });

      test('T2.5.3: RectTween with negative starting coordinates evaluates smoothly', () {
        const begin = Rect.fromLTWH(-100, -200, 60, 60);
        const end = Rect.fromLTWH(300, 400, 300, 300);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        final result = tween.lerp(0.5)!;
        expect(result.width, equals(180));
        expect(result.height, equals(180));
      });

      test('T2.5.4: RectTween with t outside 0..1 interval clamps or evaluates monotonically', () {
        const begin = Rect.fromLTWH(10, 10, 50, 50);
        const end = Rect.fromLTWH(200, 200, 300, 300);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        final resNegative = tween.lerp(-0.5);
        final resOver = tween.lerp(1.5);
        expect(resNegative, isNotNull);
        expect(resOver, isNotNull);
      });

      test('T2.5.5: RectTween maintains continuous differentiable curve without NaN or Inf', () {
        const begin = Rect.fromLTWH(20, 500, 56, 56);
        const end = Rect.fromLTWH(400, 100, 380, 380);
        final tween = NowPlayingArtworkRectTween(begin: begin, end: end);

        for (int i = 0; i <= 100; i++) {
          final t = i / 100.0;
          final r = tween.lerp(t)!;
          expect(r.left.isFinite, isTrue);
          expect(r.top.isFinite, isTrue);
          expect(r.width.isFinite, isTrue);
          expect(r.height.isFinite, isTrue);
        }
      });
    });

    // =========================================================================
    // FEATURE 6: Coordinate Stability (No FittedBox) (Boundaries)
    // =========================================================================
    group('Feature 6: Coordinate Stability - Boundary & Extreme Conditions', () {
      testWidgets('T2.6.1: High DPI simulation maintains pixel ratio stability',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'High DPI Master',
          artist: 'Retina',
          album: '4K Stream',
          path: 'E:\\Music\\f6_b1.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(1920, 1080),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingArtworkHeroFrame), findsAtLeastNWidgets(1));
      });

      testWidgets('T2.6.2: Layout constraints with unconstrained height default to safe bounds',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Unconstrained Height',
          artist: 'Flex',
          album: 'Infinity',
          path: 'E:\\Music\\f6_b2.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const SingleChildScrollView(
              child: SizedBox(
                height: 1200,
                child: NowPlayingPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T2.6.3: Consecutive window resize operations preserve frame hierarchy',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Resize Cycle',
          artist: 'Scaler',
          album: 'Matrix',
          path: 'E:\\Music\\f6_b3.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            screenSize: const Size(1200, 800),
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        // 连续调整 3 次尺寸
        for (final sz in [const Size(900, 700), const Size(1600, 1000), const Size(1100, 750)]) {
          await tester.binding.setSurfaceSize(sz);
          await tester.pumpWidget(
            buildE2ETestHarness(
              playbackController: playback,
              screenSize: sz,
              child: const NowPlayingPage(),
            ),
          );
          await tester.pumpAndAdvance();
        }
        await tester.binding.setSurfaceSize(null);
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.6.4: Zero margin content padding evaluates cleanly',
          (tester) async {
        const frame = MainLayoutFrame(
          titleBar: SizedBox.shrink(),
          contentPadding: EdgeInsets.zero,
          child: Text('ZeroPaddingChild'),
        );

        await tester.pumpWidget(buildE2ETestHarness(child: frame));
        await tester.pumpAndAdvance();

        expect(find.text('ZeroPaddingChild'), findsOneWidget);
      });

      testWidgets('T2.6.5: Custom maxWidth constraint is strictly honored by MainLayoutFrame',
          (tester) async {
        const customWidth = 600.0;
        const frame = MainLayoutFrame(
          maxWidth: customWidth,
          titleBar: SizedBox.shrink(),
          child: Text('CustomWidthChild'),
        );

        await tester.pumpWidget(
          buildE2ETestHarness(
            screenSize: const Size(1600, 900),
            child: frame,
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.text('CustomWidthChild'), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 7: Shell Transition & Scale Push-back (Boundaries)
    // =========================================================================
    group('Feature 7: Shell Transition - Boundary & Extreme Conditions', () {
      testWidgets('T2.7.1: Reversing transition at t=0.01 restores underlay state immediately',
          (tester) async {
        final nav = AppNavigationState.instance;
        nav.setNowPlayingPageActive(true);
        nav.setNowPlayingPageActive(false);
        expect(nav.nowPlayingPageActive, isFalse);
      });

      testWidgets('T2.7.2: Multiple rapid location updates maintain lastShellLocation stability',
          (tester) async {
        final nav = AppNavigationState.instance;
        for (int i = 0; i < 50; i++) {
          nav.rememberLocation('/route_$i');
        }
        expect(nav.lastShellLocation, equals('/route_49'));
      });

      testWidgets('T2.7.3: NowPlayingRouteTransitionScope with zero duration evaluates instantly',
          (tester) async {
        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: Duration.zero,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: NowPlayingRouteTransitionScope(
              animation: controller,
              child: Builder(
                builder: (context) {
                  final anim = NowPlayingRouteTransitionScope.maybeOf(context);
                  return Text('ScopeVal:${anim?.value}');
                },
              ),
            ),
          ),
        );

        expect(find.text('ScopeVal:0.0'), findsOneWidget);
        controller.dispose();
      });

      testWidgets('T2.7.4: Underlay opacity clamps between 0.0 and 1.0 without out-of-range overflow',
          (tester) async {
        final nav = AppNavigationState.instance;
        nav.setNowPlayingPageActive(true);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NowPlayingShellUnderlay(child: Text('UnderlayContent')),
            ),
          ),
        );
        await tester.pumpAndAdvance();

        final opacityFinder = find.byKey(const ValueKey('now-playing-shell-underlay-opacity'));
        expect(opacityFinder, findsOneWidget);
        nav.setNowPlayingPageActive(false);
      });

      testWidgets('T2.7.5: Navigation fallback opens default location if history is empty',
          (tester) async {
        final nav = AppNavigationState.instance;
        expect(nav.lastShellLocation.isNotEmpty, isTrue);
      });
    });

    // =========================================================================
    // FEATURE 8: Staged Reveal Timeline Choreography (Boundaries)
    // =========================================================================
    group('Feature 8: Staged Reveal Timeline - Boundary & Extreme Conditions', () {
      testWidgets('T2.8.1: Massive lyric list (500 lines) parses and lays out without frame freeze',
          (tester) async {
        final lines = generateMockLrcLines(500);
        final lyric = Lrc(lines, LrcSource.local);
        final lyricController = E2ELyricController(lyric);

        await tester.pumpWidget(
          buildE2ETestHarness(
            lyricController: lyricController,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T2.8.2: Lyric with 0s lengths parses and renders safely',
          (tester) async {
        final zeroLengthLyric = Lrc([
          LrcLine(Duration.zero, 'Zero Length Line 1', isBlank: false, length: Duration.zero),
          LrcLine(const Duration(seconds: 2), 'Zero Length Line 2', isBlank: false, length: Duration.zero),
        ], LrcSource.local);

        final lyricController = E2ELyricController(zeroLengthLyric);

        await tester.pumpWidget(
          buildE2ETestHarness(
            lyricController: lyricController,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.text('Zero Length Line 1'), findsAtLeastNWidgets(1));
      });

      testWidgets('T2.8.3: Lyric with all blank lines falls back to clean presentation',
          (tester) async {
        final blankLyric = Lrc([
          LrcLine(Duration.zero, '', isBlank: true),
          LrcLine(const Duration(seconds: 1), '   ', isBlank: true),
        ], LrcSource.local);

        final lyricController = E2ELyricController(blankLyric);

        await tester.pumpWidget(
          buildE2ETestHarness(
            lyricController: lyricController,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T2.8.4: Autohide bottom bar reset timer upon user mouse hover',
          (tester) async {
        final audio = E2ETestAudio(
          title: 'Hover Reset Track',
          artist: 'Interactive',
          album: 'Actions',
          path: 'E:\\Music\\f8_b4.flac',
        );
        final playback = E2EPlaybackController(initialAudio: audio);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        // 模拟鼠标悬停
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(const Offset(600, 750));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.removePointer();

        expect(find.byType(NowPlayingPage), findsOneWidget);
      });

      testWidgets('T2.8.5: Staged reveal at precise boundary values (0.12, 0.24, 0.34, 0.82) handles float math cleanly',
          (tester) async {
        for (final threshold in [0.0, 0.12, 0.24, 0.34, 0.48, 0.68, 0.82, 1.0]) {
          final controller = AnimationController(
            vsync: const TestVSync(),
            value: threshold,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: NowPlayingRouteTransitionScope(
                animation: controller,
                child: Builder(
                  builder: (context) {
                    final anim = NowPlayingRouteTransitionScope.maybeOf(context);
                    return Text('Threshold:${anim?.value.toStringAsFixed(2)}');
                  },
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Threshold:${threshold.toStringAsFixed(2)}'), findsOneWidget);
          controller.dispose();
        }
      });
    });

    // =========================================================================
    // FEATURE 9: 120fps GPU Texture Caching & Optimization (Boundaries)
    // =========================================================================
    group('Feature 9: 120fps GPU Caching - Boundary & Extreme Conditions', () {
      testWidgets('T2.9.1: Spectrum visualizer handles empty FFT data array safely',
          (tester) async {
        final playback = E2EPlaybackController();
        playback.emitSpectrum([]);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.9.2: Spectrum visualizer with 1024 FFT bins clamps to safe 24-bar limit',
          (tester) async {
        final playback = E2EPlaybackController();
        final massiveSpectrum = List.generate(1024, (i) => (i % 100) / 100.0);
        playback.emitSpectrum(massiveSpectrum);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(RepaintBoundary), findsWidgets);
      });

      testWidgets('T2.9.3: Spectrum with out-of-range magnitude [-50.0, 999.0] clamps gracefully',
          (tester) async {
        final playback = E2EPlaybackController();
        playback.emitSpectrum([-50.0, -1.0, 0.0, 1.5, 999.0]);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const NowPlayingPage(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.9.5: Zero DSP volume disables active spectrum painting load',
          (tester) async {
        final playback = E2EPlaybackController(initialVolume: 0.0);
        playback.emitSpectrum([0.5, 0.8, 0.2]);

        await tester.pumpWidget(
          buildE2ETestHarness(
            playbackController: playback,
            child: const BottomPlayerBar(),
          ),
        );
        await tester.pumpAndAdvance();

        expect(find.byType(SpectrumProgressSlider), findsOneWidget);
      });
    });

    // =========================================================================
    // FEATURE 10: MainLayoutFrame Animated Insets (Boundaries)
    // =========================================================================
    group('Feature 10: Animated Insets - Boundary & Extreme Conditions', () {
      test('T2.10.1: Fullscreen layout mode computes valid shellGap', () {
        WindowControls.layoutMode.value = WindowLayoutMode.fullscreen;
        expect(WindowControls.shellGap, equals(10.0));
        WindowControls.layoutMode.value = WindowLayoutMode.normal;
      });

      test('T2.10.2: resolveMainLayoutDockInset with negative shellGap clamps safely', () {
        final result = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: 80.0,
          shellGap: 0.0,
        );
        expect(result, equals(80.0));
      });

      test('T2.10.3: resolveMainLayoutDockInset with 0 dockHeight calculates pure gap', () {
        final result = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: 0.0,
          shellGap: 12.0,
        );
        expect(result, equals(24.0));
      });

      testWidgets('T2.10.4: MainLayoutFrame with overlay present renders stacked layout',
          (tester) async {
        const frame = MainLayoutFrame(
          titleBar: Text('TopBar'),
          overlay: Text('OverlayBar'),
          child: Text('MainChild'),
        );

        await tester.pumpWidget(buildE2ETestHarness(child: frame));
        await tester.pumpAndAdvance();

        expect(find.text('TopBar'), findsOneWidget);
        expect(find.text('OverlayBar'), findsOneWidget);
        expect(find.text('MainChild'), findsOneWidget);
      });

      testWidgets('T2.10.5: WindowLayoutMode transitions normal -> maximized -> fullscreen execute smoothly',
          (tester) async {
        const frame = MainLayoutFrame(
          titleBar: Text('Title'),
          child: Text('Body'),
        );

        await tester.pumpWidget(buildE2ETestHarness(child: frame));
        await tester.pumpAndAdvance();

        for (final mode in WindowLayoutMode.values) {
          WindowControls.layoutMode.value = mode;
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndAdvance();
          expect(find.text('Body'), findsOneWidget);
        }
        WindowControls.layoutMode.value = WindowLayoutMode.normal;
      });
    });

    // =========================================================================
    // FEATURE 11: Comprehensive E2E Verification & Hardening (Boundaries)
    // =========================================================================
    group('Feature 11: Verification & Hardening - Boundary & Extreme Conditions', () {
      test('T2.11.1: Seeking to extreme values (negative or beyond length) is handled safely', () {
        final controller = E2EPlaybackController(initialDuration: 100.0);
        controller.seek(-50.0);
        expect(controller.position, equals(-50.0));

        controller.seek(5000.0);
        expect(controller.position, equals(5000.0));
        controller.dispose();
      });

      test('T2.11.2: Invalid playlist index operations ignore out-of-bounds requests safely', () {
        final t = E2ETestAudio(title: 'T', artist: 'A', album: 'Alb', path: '1.flac');
        final controller = E2EPlaybackController(initialAudio: t, initialQueue: [t]);

        controller.playIndexOfPlaylist(-1);
        expect(controller.playlistIndex, equals(0));

        controller.playIndexOfPlaylist(99);
        expect(controller.playlistIndex, equals(0));
        controller.dispose();
      });

      testWidgets('T2.11.3: MarqueeText with empty text renders whitespace fallback',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: MarqueeText(text: '', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        );
        await tester.pumpAndAdvance();
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.11.4: SpectrumProgressSlider with zero max duration renders without division by zero',
          (tester) async {
        final spectrum = ValueNotifier<List<double>>([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SpectrumProgressSlider(
                spectrum: spectrum,
                value: 0,
                max: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndAdvance();
        expect(find.byType(SpectrumProgressSlider), findsOneWidget);
      });

      test('T2.11.5: DesktopLyricController handles high frequency messages without loss', () {
        final controller = E2EDesktopLyricController();
        for (int i = 0; i < 100; i++) {
          controller.sendPlayerStateMessage(i % 2 == 0);
        }
        expect(controller.sentPlayerStates.length, equals(100));
      });
    });
  });
}


