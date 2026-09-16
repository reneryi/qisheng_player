import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('Playback Mode & Shuffle Button Visual State & Interaction Tests', () {
    testWidgets(
        '1. Clicking shuffle in sequence/loop mode turns on shuffle and turns off sequence highlight',
        (tester) async {
      final audio = TestAudio(
        title: 'Mode Test Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\test.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );
      // Start in loop mode (用户常说的顺序/列表循环高亮状态)
      playback.setPlayMode(PlayMode.loop);
      playback.useShuffle(false);

      await tester.pumpWidget(
        buildMediaHarness(
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Sequence button should be selected/highlighted in loop mode
      expect(playback.playMode.value, equals(PlayMode.loop));
      expect(playback.shuffle.value, isFalse);

      final sequenceFinder = find.byTooltip('列表循环');
      expect(sequenceFinder, findsOneWidget);

      final shuffleFinder = find.byTooltip('随机播放');
      expect(shuffleFinder, findsOneWidget);

      // Click shuffle to enable random play
      await tester.tap(shuffleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Now shuffle must be active and sequence button must be turned OFF (灭掉, PlayMode.forward, selected: false)
      expect(playback.shuffle.value, isTrue);
      expect(playback.playMode.value, equals(PlayMode.forward));

      // Tooltips updated
      expect(find.byTooltip('关闭随机播放'), findsOneWidget);
      expect(find.byTooltip('顺序播放'), findsOneWidget);
    });

    testWidgets(
        '2. Two clicks from shuffle to reach singleLoop: click 1 responds to sequence/loop and turns off shuffle, click 2 enters singleLoop',
        (tester) async {
      final audio = TestAudio(
        title: 'Mode Test Song 2',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\test2.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );
      // Initially in shuffle mode
      playback.useShuffle(true);
      playback.setPlayMode(PlayMode.forward);

      await tester.pumpWidget(
        buildMediaHarness(
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(playback.shuffle.value, isTrue);
      expect(find.byTooltip('关闭随机播放'), findsOneWidget);
      expect(find.byTooltip('顺序播放'), findsOneWidget);

      // CLICK 1: 点击顺序播放按钮
      // 应该先响应顺序播放（列表循环），同时随机播放正常灭掉
      final sequenceButtonFinder = find.byTooltip('顺序播放');
      await tester.tap(sequenceButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(playback.shuffle.value, isFalse,
          reason: 'Click 1 must turn off shuffle');
      expect(playback.playMode.value, equals(PlayMode.loop),
          reason: 'Click 1 must respond to sequence mode (loop)');
      expect(find.byTooltip('列表循环'), findsOneWidget);
      expect(find.byTooltip('随机播放'), findsOneWidget);

      // CLICK 2: 再次点击顺序播放按钮
      // 应该变成单曲循环，且随机播放保持灭掉
      final loopButtonFinder = find.byTooltip('列表循环');
      await tester.tap(loopButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(playback.playMode.value, equals(PlayMode.singleLoop),
          reason: 'Click 2 must enter singleLoop');
      expect(playback.shuffle.value, isFalse,
          reason: 'Shuffle must remain off');
      expect(find.byTooltip('单曲循环'), findsOneWidget);
      expect(find.byTooltip('随机播放'), findsOneWidget);
    });

    testWidgets(
        '3. In singleLoop, clicking shuffle turns off singleLoop and activates shuffle',
        (tester) async {
      final audio = TestAudio(
        title: 'Mode Test Song 3',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\test3.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );
      playback.setPlayMode(PlayMode.singleLoop);
      playback.useShuffle(false);

      await tester.pumpWidget(
        buildMediaHarness(
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byTooltip('单曲循环'), findsOneWidget);
      final shuffleFinder = find.byTooltip('随机播放');

      await tester.tap(shuffleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(playback.shuffle.value, isTrue);
      expect(playback.playMode.value, equals(PlayMode.forward));
      expect(find.byTooltip('关闭随机播放'), findsOneWidget);
      expect(find.byTooltip('顺序播放'), findsOneWidget);
    });

    test('4. PlaybackPreference.fromMap normalizes playMode to forward when shuffle is true', () {
      final map = {
        'shuffle': true,
        'playMode': 'loop',
      };
      final pref = PlaybackPreference.fromMap(map);
      expect(pref.shuffle, isTrue);
      expect(pref.playMode, equals(PlayMode.forward));

      final mapNormal = {
        'shuffle': false,
        'playMode': 'singleLoop',
      };
      final prefNormal = PlaybackPreference.fromMap(mapNormal);
      expect(prefNormal.shuffle, isFalse);
      expect(prefNormal.playMode, equals(PlayMode.singleLoop));
    });

    testWidgets('5. Sequence button visual state in shuffle mode strictly displays sequence repeat icon and unselected state',
        (tester) async {
      final audio = TestAudio(
        title: 'Mode Test Song 5',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\test5.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );
      // Simulate underlying playMode being loop or singleLoop while shuffle is active
      playback.setPlayMode(PlayMode.singleLoop);
      playback.useShuffle(true);

      await tester.pumpWidget(
        buildMediaHarness(
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // In shuffle mode, sequence button MUST display '顺序播放' and Symbols.repeat, selected: false
      expect(playback.shuffle.value, isTrue);
      expect(find.byTooltip('顺序播放'), findsOneWidget);
      expect(find.byTooltip('关闭随机播放'), findsOneWidget);

      // Verify sequence button icon is repeat, not repeat_one_on
      expect(find.byIcon(Symbols.repeat), findsOneWidget);
      expect(find.byIcon(Symbols.repeat_one_on), findsNothing);
    });
  });
}
