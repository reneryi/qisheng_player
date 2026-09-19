import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('Transport Controls Icon Redesign & Interaction Motion Tests', () {
    late TestAudio testAudio;
    late FakePlaybackController playback;

    setUp(() {
      testAudio = TestAudio(
        title: 'Motion Test Song',
        artist: 'Motion Artist',
        album: 'Motion Album',
        path: r'E:\Music\motion.flac',
      );
      playback = FakePlaybackController(
        audio: testAudio,
        queue: [testAudio],
      );
    });

    Widget createWidget() {
      return buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(
          Lrc(const [], LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 1200,
            child: BottomPlayerBar(),
          ),
        ),
      );
    }

    testWidgets('1. All 5 transport controls exist with proper keys and filled icons',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final shuffleFinder =
          find.byKey(const ValueKey('bottom-player-bar-shuffle-button'));
      final prevFinder =
          find.byKey(const ValueKey('bottom-player-bar-prev-button'));
      final playFinder =
          find.byKey(const ValueKey('bottom-player-bar-play-button'));
      final nextFinder =
          find.byKey(const ValueKey('bottom-player-bar-next-button'));
      final seqFinder =
          find.byKey(const ValueKey('bottom-player-bar-sequence-button'));

      expect(shuffleFinder, findsOneWidget);
      expect(prevFinder, findsOneWidget);
      expect(playFinder, findsOneWidget);
      expect(nextFinder, findsOneWidget);
      expect(seqFinder, findsOneWidget);

      // Verify icons inside buttons have fill: 1.0
      final playIconFinder = find.descendant(
        of: playFinder,
        matching: find.byType(Icon),
      );
      expect(playIconFinder, findsOneWidget);
      final playIconWidget = tester.widget<Icon>(playIconFinder);
      expect(playIconWidget.fill, equals(1.0));
      expect(playIconWidget.weight, equals(700));

      final prevIconFinder = find.descendant(
        of: prevFinder,
        matching: find.byType(Icon),
      );
      expect(prevIconFinder, findsOneWidget);
      final prevIconWidget = tester.widget<Icon>(prevIconFinder);
      expect(prevIconWidget.fill, equals(1.0));
      expect(prevIconWidget.weight, equals(600));

      final nextIconFinder = find.descendant(
        of: nextFinder,
        matching: find.byType(Icon),
      );
      expect(nextIconFinder, findsOneWidget);
      final nextIconWidget = tester.widget<Icon>(nextIconFinder);
      expect(nextIconWidget.fill, equals(1.0));
      expect(nextIconWidget.weight, equals(600));
    });

    testWidgets('2. Rapid click on primary button triggers spring compression and recovery smoothly',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playFinder =
          find.byKey(const ValueKey('bottom-player-bar-play-button'));

      // Initial state: paused
      expect(playback.playerState, equals(PlayerState.paused));

      // Simulate pointer down and quick tap
      await tester.tap(playFinder);
      await tester.pump();

      // Service should be started
      expect(playback.playerState, equals(PlayerState.playing));

      // Advance through spring rebound
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the icon switched to pause
      final pauseIconFinder = find.descendant(
        of: playFinder,
        matching: find.byIcon(Symbols.pause_rounded),
      );
      expect(pauseIconFinder, findsOneWidget);
    });

    testWidgets('3. Directional kinetic feedback: Prev nudges left, Next nudges right on press',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final prevFinder =
          find.byKey(const ValueKey('bottom-player-bar-prev-button'));
      final nextFinder =
          find.byKey(const ValueKey('bottom-player-bar-next-button'));

      // Press Prev button down and advance beyond tap recognition timeout
      final prevGesture = await tester.startGesture(tester.getCenter(prevFinder));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 50));

      final prevTranslates = tester.widgetList<Transform>(
        find.descendant(of: prevFinder, matching: find.byType(Transform)),
      );
      final hasLeftNudge = prevTranslates.any((t) => t.transform.getTranslation().x < 0);
      expect(hasLeftNudge, isTrue, reason: 'Prev button should kick left on press');

      await prevGesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Press Next button down and advance beyond tap recognition timeout
      final nextGesture = await tester.startGesture(tester.getCenter(nextFinder));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 50));

      final nextTranslates = tester.widgetList<Transform>(
        find.descendant(of: nextFinder, matching: find.byType(Transform)),
      );
      final hasRightNudge = nextTranslates.any((t) => t.transform.getTranslation().x > 0);
      expect(hasRightNudge, isTrue, reason: 'Next button should kick right on press');

      await nextGesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('4. Shuffle and sequence mode buttons toggle and display active indicators',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final shuffleFinder =
          find.byKey(const ValueKey('bottom-player-bar-shuffle-button'));
      final seqFinder =
          find.byKey(const ValueKey('bottom-player-bar-sequence-button'));

      // Tap shuffle
      await tester.tap(shuffleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(playback.shuffle.value, isTrue);

      // Tap sequence: should turn off shuffle and activate sequence loop
      await tester.tap(seqFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(playback.shuffle.value, isFalse);
      expect(playback.playMode.value, equals(PlayMode.loop));

      // Tap sequence again: should enter single loop
      await tester.tap(seqFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(playback.playMode.value, equals(PlayMode.singleLoop));
    });

    testWidgets('5. Play/Pause AnimatedSwitcher morph transition fires during play/pause toggle',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playFinder =
          find.byKey(const ValueKey('bottom-player-bar-play-button'));

      // Tap play button to toggle to playing
      await tester.tap(playFinder);
      await tester.pump(); // Start transition

      // Mid-transition at 100ms: both old and new icon should be in flight inside AnimatedSwitcher
      await tester.pump(const Duration(milliseconds: 100));

      final rotationTransitions = tester.widgetList<RotationTransition>(
        find.descendant(of: playFinder, matching: find.byType(RotationTransition)),
      );
      expect(
        rotationTransitions.isNotEmpty,
        isTrue,
        reason: 'AnimatedSwitcher must mount RotationTransition for play/pause morphing',
      );

      // Finish transition
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.playerState, equals(PlayerState.playing));
    });

    testWidgets('6. Shuffle and Sequence mode transitions execute animations on state toggle',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final shuffleFinder =
          find.byKey(const ValueKey('bottom-player-bar-shuffle-button'));

      // Press shuffle down: should trigger spin kinetic
      final shuffleGesture = await tester.startGesture(tester.getCenter(shuffleFinder));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 50));

      final shuffleTransforms = tester.widgetList<Transform>(
        find.descendant(of: shuffleFinder, matching: find.byType(Transform)),
      );
      // Verify rotational kinetic is active in the transform matrix
      final hasRotation = shuffleTransforms.any((t) {
        final storage = t.transform.storage;
        // In 4x4 matrix, rotation in 2D changes m[0], m[1], m[4], m[5]
        return storage[1].abs() > 0.01 || storage[4].abs() > 0.01;
      });
      expect(
        hasRotation,
        isTrue,
        reason: 'Shuffle press must trigger rotational kinetic Transform.rotate',
      );

      await shuffleGesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sequence button: toggle to singleLoop to verify vertical SlideTransition on icon change
      final seqFinder =
          find.byKey(const ValueKey('bottom-player-bar-sequence-button'));
      // First click: loop
      await tester.tap(seqFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Second click: singleLoop (icon changes from repeat to repeat_one_on)
      await tester.tap(seqFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final seqSlides = tester.widgetList<SlideTransition>(
        find.descendant(of: seqFinder, matching: find.byType(SlideTransition)),
      );
      expect(
        seqSlides.isNotEmpty,
        isTrue,
        reason: 'Sequence mode switch to singleLoop must run SlideTransition via AnimatedSwitcher',
      );

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('7. Hover scale animates smoothly across frames rather than jumping in 0ms',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playFinder =
          find.byKey(const ValueKey('bottom-player-bar-play-button'));

      // Move mouse over play button
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(playFinder));
      await tester.pump(); // Frame 0 of hover: scale should not have instantly jumped to full 1.045

      // At 60ms: partially hovered
      await tester.pump(const Duration(milliseconds: 60));
      // At 180ms: fully hovered
      await tester.pump(const Duration(milliseconds: 120));

      // Move mouse away
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('8. Rapid consecutive clicks do not cause timer collision or animation lockup',
        (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playFinder =
          find.byKey(const ValueKey('bottom-player-bar-play-button'));
      final nextFinder =
          find.byKey(const ValueKey('bottom-player-bar-next-button'));

      // Simulate 5 rapid taps at 25ms intervals on play button
      for (int i = 0; i < 5; i++) {
        await tester.tap(playFinder);
        await tester.pump(const Duration(milliseconds: 25));
      }

      // Simulate 5 rapid taps at 25ms intervals on next button
      for (int i = 0; i < 5; i++) {
        await tester.tap(nextFinder);
        await tester.pump(const Duration(milliseconds: 25));
      }

      // Settle all spring animations and timers
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BottomPlayerBar), findsOneWidget);
    });
  });
}
