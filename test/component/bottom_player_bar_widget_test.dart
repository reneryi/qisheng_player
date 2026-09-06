import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/audio_visualizer/liquid_audio_visualizer.dart';
import 'package:qisheng_player/component/marquee_text.dart';
import 'package:qisheng_player/component/spectrum_progress_slider.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('BottomPlayerBar stays stable on wide layout', (tester) async {
    final audio = TestAudio(
      title: 'Wide Song',
      artist: 'Wide Artist',
      album: 'Wide Album',
      path: r'E:\Music\wide.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(
          Lrc(buildLongLrcLines(), LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 1360,
            child: BottomPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MarqueeText && widget.text == 'Wide Song',
      ),
      findsOneWidget,
    );
    expect(find.byType(SpectrumProgressSlider), findsOneWidget);
    expect(find.byType(LiquidAudioVisualizer), findsNothing);

    expect(tester.takeException(), isNull);
    expect(find.byType(SpectrumProgressSlider), findsOneWidget);
    expect(find.byTooltip('打开播放队列'), findsOneWidget);
  });

  testWidgets('BottomPlayerBar stays stable on dense layout', (tester) async {
    final audio = TestAudio(
      title: 'Dense Song',
      artist: 'Dense Artist',
      album: 'Dense Album',
      path: r'E:\Music\dense.flac',
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: audio,
          queue: [audio, ...buildLongQueue()],
        ),
        lyricController: FakeLyricController(
          Lrc(buildLongLrcLines(), LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 920,
            child: BottomPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('打开播放队列'), findsOneWidget);
  });

  testWidgets('BottomPlayerBar survives volume slider width collapse',
      (tester) async {
    final audio = TestAudio(
      title: 'Resize Song',
      artist: 'Resize Artist',
      album: 'Resize Album',
      path: r'E:\Music\resize.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );
    final desktopLyric = FakeDesktopLyricController();

    Widget buildFrame(double width) {
      return buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: desktopLyric,
        child: Center(
          child: SizedBox(
            width: width,
            child: const BottomPlayerBar(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildFrame(1360));
    await tester.pump();
    expect(find.byType(SpectrumProgressSlider), findsOneWidget);

    await tester.pumpWidget(buildFrame(920));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 260));

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(buildFrame(507));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 260));

    expect(tester.takeException(), isNull);
  });

  testWidgets('BottomPlayerBar restores the volume that was muted',
      (tester) async {
    final audio = TestAudio(
      title: 'Volume Song',
      artist: 'Volume Artist',
      album: 'Volume Album',
      path: r'E:\Music\volume.flac',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(Lrc(const [], LrcSource.local)),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(width: 1360, child: BottomPlayerBar()),
        ),
      ),
    );
    await tester.pump();

    final volumeButton = find.byWidgetPredicate(
      (widget) =>
          widget is Tooltip &&
          widget.message?.startsWith('音量（支持鼠标滚轮无级调节）') == true,
    );
    expect(volumeButton, findsOneWidget);

    await tester.tap(volumeButton);
    await tester.pump();
    expect(playback.volumeDsp, 0.0);

    await tester.tap(volumeButton);
    await tester.pump();
    expect(playback.volumeDsp, 0.5);
  });

  testWidgets('BottomPlayerBar stops and restarts the artwork ticker',
      (tester) async {
    var spinning = false;
    late StateSetter updateState;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            updateState = setState;
            return Center(
              child: SpinningArtwork(
                spinning: spinning,
                child: const SizedBox.square(dimension: 80),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);

    updateState(() => spinning = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    updateState(() => spinning = false);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('BottomPlayerBar stays stable without Scaffold ancestor',
      (tester) async {
    final audio = TestAudio(
      title: 'Overlay Song',
      artist: 'Overlay Artist',
      album: 'Overlay Album',
      path: r'E:\Music\overlay.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio, ...buildLongQueue()],
    );
    final lyric = FakeLyricController(
      Lrc(buildLongLrcLines(), LrcSource.local),
    );
    final desktopLyric = FakeDesktopLyricController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaybackController>.value(value: playback),
          ChangeNotifierProvider<LyricController>.value(value: lyric),
          ChangeNotifierProvider<DesktopLyricController>.value(
            value: desktopLyric,
          ),
        ],
        child: MaterialApp(
          theme: buildTestTheme(),
          home: const Center(
            child: SizedBox(
              width: 1280,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MarqueeText && widget.text == 'Overlay Song',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'BottomPlayerBar opens queue drawer with BackdropFilter glassmorphism and closes smoothly',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Drawer Song',
      artist: 'Drawer Artist',
      album: 'Drawer Album',
      path: r'E:\Music\drawer.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(
          Lrc([], LrcSource.local),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 1280,
            child: BottomPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    // 点击打开播放队列按钮
    final queueButton = find.byTooltip('打开播放队列');
    expect(queueButton, findsOneWidget);
    await tester.tap(queueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 验证播放队列抽屉及 BackdropFilter 毛玻璃存在
    expect(find.text('播放队列'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);

    // 点击关闭按钮
    final closeButton = find.byTooltip('关闭');
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pump();

    // 推进部分时间，抽屉处于退场动画中
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('播放队列'), findsOneWidget);

    // 推进至动画完全结束 (320ms 动画，再推进 350ms)
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('播放队列'), findsNothing);
  });
}
