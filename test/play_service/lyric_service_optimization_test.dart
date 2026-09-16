import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyricService 性能优化与三段式定位算法测试', () {
    late FakePlaybackController fakePlayback;
    late FakeDesktopLyricController fakeDesktopLyric;
    late LyricService lyricService;
    late TestAudio sampleAudio;

    final testLyric = Lrc.fromLrcText('''
[00:10.00]First line
[00:20.00]Second line
[00:30.00]Third line
[00:40.00]Fourth line
''', LrcSource.local)!;

    setUp(() {
      sampleAudio = TestAudio(
        title: "Test Title",
        artist: "Test Artist",
        album: "Test Album",
        path: "C:\\music\\test.mp3",
      );
      fakePlayback = FakePlaybackController(
        audio: sampleAudio,
        queue: [sampleAudio],
      );
      fakeDesktopLyric = FakeDesktopLyricController();
      lyricService = LyricService.forTest(
        playbackService: fakePlayback,
        desktopLyricService: fakeDesktopLyric,
        getDefaultLyric: (audio, localFirst) async => testLyric,
      );
    });

    tearDown(() async {
      await lyricService.close();
    });

    test('加载特定歌词后 _currentLyric 同步可见', () async {
      expect(lyricService.currentLyric, isNull);
      lyricService.useSpecificLyric(testLyric);
      expect(lyricService.currentLyric, isNotNull);
      expect(lyricService.currentLyric!.lines.length, equals(4));
    });

    test('三段式定位算法：前置等待、区间保持、顺序步进与二分回退', () async {
      lyricService.useSpecificLyric(testLyric);

      final lineEvents = <int>[];
      final sub = lyricService.lyricLineStream.listen(lineEvents.add);

      // 1. 播放位置在第一行之前 (t = 5s) -> 停留在第一行 (index 0)
      fakePlayback.seek(5.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(0));

      // 2. 播放到第一行 (t = 12s) -> 处于第0行区间 [10s, 20s)
      fakePlayback.seek(12.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(0));

      // 3. 区间内高频微小推进 (t = 15s) -> 保持第0行区间 O(1)
      fakePlayback.seek(15.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(0));

      // 4. 顺序推进到紧随其后的第二句 (t = 22s) -> 步进至第1行 O(1)
      fakePlayback.seek(22.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(1));

      // 5. 顺序推进到第三句 (t = 31s) -> 步进至第2行 O(1)
      fakePlayback.seek(31.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(2));

      // 6. 大幅快进跨越跳转 (t = 45s) -> 二分搜索定位至第3行 O(log N)
      fakePlayback.seek(45.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(3));

      // 7. 倒带回退拖动进度条 (t = 11s) -> 二分搜索安全回退至第0行 O(log N)
      fakePlayback.seek(11.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(0));

      // 8. 循环重播回到起点 (t = 0.5s) -> 安全回退至第0行
      fakePlayback.seek(0.5);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(0));

      // 9. 播放到最后一句之后 (t = 60s) -> 维持在最后一句 (index 3)
      fakePlayback.seek(60.0);
      await pumpEventQueue();
      expect(lyricService.currentLyricLineIndex, equals(3));

      await sub.cancel();
    });
  });
}
