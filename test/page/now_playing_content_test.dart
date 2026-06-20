import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/window_drag_region.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets(
      'NowPlayingContentView immersive mode handles long lyrics without overflow',
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
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
    expect(find.text('Immersive Song'), findsOneWidget);
    expect(find.text('Immersive Artist / Guest Artist'), findsOneWidget);
    final titleText = tester.widget<Text>(find.text('Immersive Song'));
    final artistText =
        tester.widget<Text>(find.text('Immersive Artist / Guest Artist'));
    expect(titleText.textAlign, TextAlign.center); // 重构：非 compact 模式下歌曲标题已设为居中对齐
    expect(titleText.style?.fontWeight, FontWeight.w800);
    expect(titleText.style?.decoration, TextDecoration.none);
    expect(artistText.textAlign, TextAlign.center); // 重构：非 compact 模式下歌手文字已设为居中对齐
    expect(artistText.style?.fontWeight, FontWeight.w400);
    expect(artistText.style?.decoration, TextDecoration.none);
    expect(
      find.text('Immersive Artist / Guest Artist 路 Immersive Album'),
      findsNothing,
    );
    expect(find.text('flac'), findsNothing);
  });

  testWidgets(
      'NowPlayingContentView immersive compact mode handles long lyrics without overflow',
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
        child: const NowPlayingContentView(
          compact: true,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsWidgets);
  });

  testWidgets('NowPlayingContentView handles rapid lyric line changes', (
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
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

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
      'NowPlayingContentView artwork stage empty area avoids action hits',
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
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WindowDragRegion), findsNothing);

    final heroRect = tester.getRect(find.byType(Hero).first);
    final hitPoint = Offset(heroRect.center.dx, heroRect.top - 24);
    final hitWidgets = _hitWidgetTypes(tester.hitTestOnBinding(hitPoint));

    expect(hitWidgets, isNot(contains('IconButton')));
    expect(hitWidgets, isNot(contains('FilledButton')));
    expect(hitWidgets, isNot(contains('InkWell')));
    expect(hitWidgets, isNot(contains('DragToMoveArea')));
  });

  testWidgets('NowPlayingContentView empty area absorbs clicks silently', (
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
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroRect = tester.getRect(find.byType(Hero).first);
    final hitPoint = Offset(heroRect.center.dx, heroRect.top - 24);
    final hitWidgets = _hitWidgetTypes(tester.hitTestOnBinding(hitPoint));

    expect(find.byType(WindowDragRegion), findsNothing);
    expect(hitWidgets, isNot(contains('DragToMoveArea')));
    expect(hitWidgets, contains('AbsorbPointer'));
  });

  testWidgets('NowPlayingContentView renders synced lyric words', (
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
        child: const NowPlayingContentView(
          compact: false,
          styleMode: NowPlayingStyleMode.immersive,
        ),
      ),
    );
    await tester.pumpAndSettle();

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
