import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/src/bass/bass_wasapi.dart';

import '../test_helpers/media_test_harness.dart';


void main() {
  group('Exclusive Mode Constants & Interface', () {
    test('BASS_WASAPI constants include AUTOFORMAT', () {
      expect(BASS_WASAPI_EXCLUSIVE, 1);
      expect(BASS_WASAPI_EVENT, 16);
      expect(BASS_WASAPI_AUTOFORMAT, 256);
    });

    test('PlaybackController defaults wasapiExclusive to false', () {
      final controller = FakePlaybackController(
        audio: TestAudio(
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          path: r'C:\music\test.flac',
        ),
        queue: const [],
      );
      expect(controller.wasapiExclusive.value, isFalse);
      controller.useExclusiveMode(true);
      expect(controller.wasapiExclusive.value, isTrue);
      controller.useExclusiveMode(false);
      expect(controller.wasapiExclusive.value, isFalse);
    });
  });

  group('Exclusive Mode Button Widget & Sizing', () {
    testWidgets('renders larger exclusive mode control and toggles mode on tap',
        (tester) async {
      final audio = TestAudio(
        title: 'Hi-Res Song',
        artist: 'Audiophile Artist',
        album: 'Master Edition',
        path: r'C:\music\hires.flac',
      );
      final playback = FakePlaybackController(
        audio: audio,
        queue: [audio],
      );

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

      // Find the '共享' button
      final sharedTextFinder = find.text('共享');
      expect(sharedTextFinder, findsOneWidget);

      // Verify enlarged typography
      final Text sharedTextWidget = tester.widget(sharedTextFinder);
      expect(sharedTextWidget.style?.fontSize, 12.0);
      expect(sharedTextWidget.style?.fontWeight, FontWeight.w600);

      // Verify enlarged icon
      final iconFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Symbols.graphic_eq,
      );
      expect(iconFinder, findsOneWidget);
      final Icon iconWidget = tester.widget(iconFinder);
      expect(iconWidget.size, 15.0);

      // Verify initial tooltip
      final tooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message != null &&
            widget.message!.contains('系统共享（常规音频混合）'),
      );
      expect(tooltipFinder, findsOneWidget);

      // Tap to toggle to exclusive mode
      await tester.tap(sharedTextFinder);
      await tester.pump(const Duration(milliseconds: 250));

      // Verify playback received toggle
      expect(playback.wasapiExclusive.value, isTrue);

      // Verify UI updated to '独占'
      final exclusiveTextFinder = find.text('独占');
      expect(exclusiveTextFinder, findsOneWidget);

      final Text exclusiveTextWidget = tester.widget(exclusiveTextFinder);
      expect(exclusiveTextWidget.style?.fontSize, 12.0);
      expect(exclusiveTextWidget.style?.fontWeight, FontWeight.w700);

      // Verify lock icon is rendered
      final lockIconFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Symbols.lock_outline,
      );
      expect(lockIconFinder, findsOneWidget);
      final Icon lockIconWidget = tester.widget(lockIconFinder);
      expect(lockIconWidget.size, 15.0);

      // Verify updated tooltip
      final exclusiveTooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message != null &&
            widget.message!.contains('WASAPI 独占（高保真源码输出）'),
      );
      expect(exclusiveTooltipFinder, findsOneWidget);

      // Tap again to toggle back to shared
      await tester.tap(exclusiveTextFinder);
      await tester.pump(const Duration(milliseconds: 250));

      expect(playback.wasapiExclusive.value, isFalse);
      expect(find.text('共享'), findsOneWidget);
    });
  });
}
