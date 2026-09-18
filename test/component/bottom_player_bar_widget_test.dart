import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/audio_visualizer/liquid_audio_visualizer.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/adaptive_waveform_slider.dart';
import 'package:qisheng_player/component/dual_layer_rhythm_slider.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';
import 'package:qisheng_player/component/marquee_text.dart';
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
    expect(find.byType(FluidGlowProgressSlider), findsOneWidget);
    expect(find.byType(LiquidAudioVisualizer), findsNothing);

    expect(tester.takeException(), isNull);
    expect(find.byType(FluidGlowProgressSlider), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-player-bar-queue-button')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('bottom-player-bar-queue-button')),
      findsOneWidget,
    );
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
    expect(find.byType(FluidGlowProgressSlider), findsOneWidget);

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

    final volumeButton =
        find.byKey(const ValueKey('bottom-player-bar-volume-button'));
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
    final queueButton =
        find.byKey(const ValueKey('bottom-player-bar-queue-button'));
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

  testWidgets(
      'BottomPlayerBar dynamically switches progress bar component when AppSettings changes',
      (tester) async {
    addTearDown(() {
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.fluidGlow;
    });

    final audio = TestAudio(
      title: 'Switch Song',
      artist: 'Switch Artist',
      album: 'Switch Album',
      path: r'E:\Music\switch.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(Lrc([], LrcSource.local)),
        desktopLyricController: FakeDesktopLyricController(),
        child: const Center(
          child: SizedBox(
            width: 1000,
            child: BottomPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Default is fluidGlow
    expect(find.byType(FluidGlowProgressSlider), findsOneWidget);
    expect(find.byType(AdaptiveWaveformSlider), findsNothing);
    expect(find.byType(DualLayerRhythmSlider), findsNothing);

    // Switch to adaptiveWaveform
    AppSettings.instance.progressBarType = ProgressBarType.adaptiveWaveform;
    await tester.pump();
    expect(find.byType(FluidGlowProgressSlider), findsNothing);
    expect(find.byType(AdaptiveWaveformSlider), findsOneWidget);
    expect(find.byType(DualLayerRhythmSlider), findsNothing);

    // Switch to dualLayerRhythm
    AppSettings.instance.progressBarType = ProgressBarType.dualLayerRhythm;
    await tester.pump();
    expect(find.byType(FluidGlowProgressSlider), findsNothing);
    expect(find.byType(AdaptiveWaveformSlider), findsNothing);
    expect(find.byType(DualLayerRhythmSlider), findsOneWidget);

    // 推进防抖计时器
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
      'BottomPlayerBar renders at dockHeight 116.0px and time text uses 14px w500 font with 62px width',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final audio = TestAudio(
      title: 'Long Audio Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\long.flac',
    );
    final playback = _LongFakePlaybackController(
      audio: audio,
      queue: [audio],
      customLength: 3723.0,
      customPosition: 125.0,
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(Lrc([], LrcSource.local)),
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

    // Verify BottomPlayerBar Container height is 116.0px
    final barFinder = find.byType(BottomPlayerBar);
    expect(barFinder, findsOneWidget);
    final box = tester.renderObject<RenderBox>(barFinder);
    expect(box.size.height, equals(116.0));

    // Verify time text containers are 62.0px wide and text style is 14px w500
    final timeTexts = tester.widgetList<Text>(find.byWidgetPredicate((w) =>
        w is Text && (w.data == '0:02:05' || w.data == '1:02:03')));
    expect(timeTexts.length, equals(2));
    for (final text in timeTexts) {
      expect(text.style?.fontSize, equals(14.0));
      expect(text.style?.fontWeight, equals(FontWeight.w500));
    }

    final sizedBoxes = tester.widgetList<SizedBox>(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 62.0));
    expect(sizedBoxes.length, greaterThanOrEqualTo(2));
  });

  testWidgets(
      'BottomPlayerBar injects audioSpectrum and spectrumActive into AdaptiveWaveformSlider',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    addTearDown(() {
      AppSettings.instance.progressBarTypeNotifier.value =
          ProgressBarType.fluidGlow;
    });
    AppSettings.instance.progressBarTypeNotifier.value =
        ProgressBarType.adaptiveWaveform;

    final audio = TestAudio(
      title: 'Spectrum Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\spectrum.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: FakeLyricController(Lrc([], LrcSource.local)),
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

    final sliderFinder = find.byType(AdaptiveWaveformSlider);
    expect(sliderFinder, findsOneWidget);
    final slider = tester.widget<AdaptiveWaveformSlider>(sliderFinder);
    expect(slider.spectrum, equals(playback.audioSpectrum));
    expect(slider.height, equals(36.0));

    await tester.pump(const Duration(milliseconds: 600));
  });
}

class _LongFakePlaybackController extends FakePlaybackController {
  _LongFakePlaybackController({
    required super.audio,
    required super.queue,
    this.customLength = 3723.0,
    this.customPosition = 125.0,
  });

  final double customLength;
  final double customPosition;

  @override
  double get length => customLength;

  @override
  double get position => customPosition;
}
