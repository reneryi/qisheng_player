import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/audios_page.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  setUp(() {
    AudioLibrary.instance.audioCollection.clear();
    AppPreference.instance.audiosPagePref = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.list,
      showLyricPreview: false,
    );
  });

  testWidgets(
      'AudiosPage keeps side index and locate button when preview is closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = TestAudio(
      title: 'Alpha Song',
      artist: 'Artist One',
      album: 'Album One',
      path: r'E:\Music\alpha.flac',
    );
    final second = TestAudio(
      title: 'Beta Song',
      artist: 'Artist Two',
      album: 'Album Two',
      path: r'E:\Music\beta.flac',
    );
    AudioLibrary.instance.audioCollection.addAll([first, second]);

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: first,
          queue: [first, second],
        ),
        lyricController: FakeLyricController(
          Lrc(
            [
              LrcLine(
                Duration.zero,
                '第一行歌词',
                isBlank: false,
                length: const Duration(seconds: 3),
              ),
            ],
            LrcSource.local,
          ),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const AudiosPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('uni-page-side-index')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('uni-page-locate-button')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('audio-lyric-preview-panel')), findsNothing);
  });

  testWidgets(
      'AudiosPage shows lyric preview and shifts side index after toggling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = TestAudio(
      title: 'Alpha Song',
      artist: 'Artist One',
      album: 'Album One',
      path: r'E:\Music\alpha-open.flac',
    );
    final second = TestAudio(
      title: 'Beta Song',
      artist: 'Artist Two',
      album: 'Album Two',
      path: r'E:\Music\beta-open.flac',
    );
    AudioLibrary.instance.audioCollection.addAll([first, second]);

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: FakePlaybackController(
          audio: first,
          queue: [first, second],
        ),
        lyricController: FakeLyricController(
          Lrc(
            [
              LrcLine(
                Duration.zero,
                '展开前歌词',
                isBlank: false,
                length: const Duration(seconds: 3),
              ),
            ],
            LrcSource.local,
          ),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: const AudiosPage(),
      ),
    );
    await tester.pumpAndSettle();

    final beforeRight = tester
        .getTopRight(find.byKey(const ValueKey('uni-page-side-index')))
        .dx;

    await tester.tap(find.byKey(const ValueKey('toggle-lyric-preview')));
    await tester.pumpAndSettle();

    final afterRight = tester
        .getTopRight(find.byKey(const ValueKey('uni-page-side-index')))
        .dx;

    expect(find.byKey(const ValueKey('audio-lyric-preview-panel')),
        findsOneWidget);
    expect(afterRight, greaterThan(beforeRight));
  });

  testWidgets('AudiosPage lyric preview follows current playback changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = TestAudio(
      title: 'First Song',
      artist: 'Artist One',
      album: 'Album One',
      path: r'E:\Music\first-preview.flac',
    );
    final second = TestAudio(
      title: 'Second Song',
      artist: 'Artist Two',
      album: 'Album Two',
      path: r'E:\Music\second-preview.flac',
    );
    AudioLibrary.instance.audioCollection.addAll([first, second]);
    AppPreference.instance.audiosPagePref.showLyricPreview = true;

    final playback = FakePlaybackController(
      audio: first,
      queue: [first, second],
    );
    final lyric = FakeLyricController(
      Lrc(
        [
          LrcLine(
            Duration.zero,
            '第一首歌词',
            isBlank: false,
            length: const Duration(seconds: 3),
          ),
        ],
        LrcSource.local,
      ),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const AudiosPage(),
      ),
    );
    await tester.pumpAndSettle();

    final previewPanel =
        find.byKey(const ValueKey('audio-lyric-preview-panel'));
    expect(
      find.descendant(of: previewPanel, matching: find.text('First Song')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: previewPanel, matching: find.text('第一首歌词')),
      findsOneWidget,
    );

    playback.playIndexOfPlaylist(1);
    lyric.setLyric(
      Lrc(
        [
          LrcLine(
            Duration.zero,
            '第二首歌词',
            isBlank: false,
            length: const Duration(seconds: 3),
          ),
        ],
        LrcSource.local,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: previewPanel, matching: find.text('Second Song')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: previewPanel, matching: find.text('第二首歌词')),
      findsOneWidget,
    );
  });

  testWidgets('AudiosPage lyric preview centers active lyric line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Center Song',
      artist: 'Artist Center',
      album: 'Album Center',
      path: r'E:\Music\center-preview.flac',
    );
    AudioLibrary.instance.audioCollection.add(audio);
    AppPreference.instance.audiosPagePref.showLyricPreview = true;

    final lines = List.generate(
      32,
      (index) => LrcLine(
        Duration(seconds: index * 3),
        index == 18 ? '当前中心歌词' : '歌词第$index行',
        isBlank: false,
        length: const Duration(seconds: 3),
      ),
    );
    final lyric = FakeLyricController(Lrc(lines, LrcSource.local));

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController:
            FakePlaybackController(audio: audio, queue: [audio]),
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const AudiosPage(),
      ),
    );
    await tester.pumpAndSettle();

    lyric.emitLine(18);
    await tester.pumpAndSettle();

    final activeLine = find.text('当前中心歌词');
    final activeCenter = tester.getCenter(activeLine);
    final previewPanel = tester.getRect(
      find.byKey(const ValueKey('audio-lyric-preview-panel')),
    );

    expect(activeCenter.dy, greaterThan(previewPanel.top));
    expect(activeCenter.dy, lessThan(previewPanel.bottom));
    expect(
      (activeCenter.dy - previewPanel.center.dy).abs(),
      lessThan(previewPanel.height * 0.22),
    );
  });

  testWidgets('AudiosPage lyric preview shows playback and lyric empty states',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = TestAudio(
      title: 'State Song',
      artist: 'Artist State',
      album: 'Album State',
      path: r'E:\Music\state-preview.flac',
    );
    AudioLibrary.instance.audioCollection.add(first);
    AppPreference.instance.audiosPagePref.showLyricPreview = true;

    final playback = FakePlaybackController(audio: first, queue: [first]);
    final lyric = FakeLyricController(
      Lrc(
        [
          LrcLine(
            Duration.zero,
            '初始歌词',
            isBlank: false,
            length: const Duration(seconds: 3),
          ),
        ],
        LrcSource.local,
      ),
    );

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController: playback,
        lyricController: lyric,
        desktopLyricController: FakeDesktopLyricController(),
        child: const AudiosPage(),
      ),
    );
    await tester.pumpAndSettle();

    playback.setNowPlaying(null, queue: const []);
    await tester.pumpAndSettle();

    final previewPanel =
        find.byKey(const ValueKey('audio-lyric-preview-panel'));
    expect(
      find.descendant(of: previewPanel, matching: find.text('暂无正在播放的歌曲')),
      findsOneWidget,
    );

    playback.setNowPlaying(first, queue: [first]);
    lyric.setLyric(Lrc([], LrcSource.local));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: previewPanel, matching: find.text('暂无歌词')),
      findsOneWidget,
    );
  });

  testWidgets(
      'AudiosPage lyric preview executes smooth exit animation when toggled off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Exit Test Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\exit.flac',
    );
    AudioLibrary.instance.audioCollection.add(audio);
    AppPreference.instance.audiosPagePref.showLyricPreview = true;

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController:
            FakePlaybackController(audio: audio, queue: [audio]),
        lyricController: FakeLyricController(Lrc([], LrcSource.local)),
        desktopLyricController: FakeDesktopLyricController(),
        child: const AudiosPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 初始处于打开状态
    expect(find.byKey(const ValueKey('audio-lyric-preview-panel')),
        findsOneWidget);

    // 点击关闭按钮
    await tester.tap(find.byKey(const ValueKey('toggle-lyric-preview')));

    // 推进 100ms（动画执行中）：面板仍然保活在 Widget 树中执行淡出与收缩动画
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('audio-lyric-preview-panel')),
        findsOneWidget);

    // 推进至动画完全结束
    await tester.pumpAndSettle();
    // 面板完全卸载
    expect(find.byKey(const ValueKey('audio-lyric-preview-panel')),
        findsNothing);
  });
}
