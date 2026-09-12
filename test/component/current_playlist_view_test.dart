import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('CurrentPlaylistView keeps reorder enabled for long queues',
      (tester) async {
    final head = TestAudio(
      title: 'Head Song',
      artist: 'Head Artist',
      album: 'Head Album',
      path: r'E:\Music\head.flac',
    );
    final longQueue = <TestAudio>[
      head,
      for (var index = 0; index < 140; index++)
        TestAudio(
          title: 'Queue Song ${index + 1}',
          artist: 'Queue Artist ${index + 1}',
          album: 'Queue Album ${index + 1}',
          path: 'E:\\Music\\long_queue_$index.flac',
        ),
    ];

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: head,
          queue: longQueue,
        ),
        lyricController: FakeLyricController(
          Lrc(buildLongLrcLines(), LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const SizedBox(
          width: 420,
          height: 560,
          child: CurrentPlaylistView(
            showHeader: false,
            dense: true,
            enableReorder: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isNot(true));

    final reorderableList =
        tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    final padding = reorderableList.padding;
    expect(padding, isNotNull);
    expect(padding!.right, greaterThanOrEqualTo(12.0));
  });

  testWidgets('CurrentPlaylistView non-reorder mode provides gutter padding',
      (tester) async {
    final audio = TestAudio(
      title: 'Solo Song',
      artist: 'Solo Artist',
      album: 'Solo Album',
      path: r'E:\Music\solo.flac',
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: audio,
          queue: [audio],
        ),
        lyricController: FakeLyricController(
          Lrc(buildLongLrcLines(), LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const SizedBox(
          width: 420,
          height: 560,
          child: CurrentPlaylistView(
            showHeader: false,
            dense: true,
            enableReorder: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    final padding = list.padding as EdgeInsets?;
    expect(padding, isNotNull);
    expect(padding!.right, greaterThanOrEqualTo(12.0));
  });
}
