import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_shutdown.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_lyric_source_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    LYRIC_SOURCES.clear();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    LYRIC_SOURCES.clear();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('LyricSource 序列化与反序列化测试', () {
    test('LyricSource 各平台数据模型与 Map 相互转换正确', () {
      final qqSource = LyricSource(LyricSourceType.qq, qqSongId: 1001);
      final kugouSource =
          LyricSource(LyricSourceType.kugou, kugouSongHash: 'ABCDEF123456');
      final neteaseSource =
          LyricSource(LyricSourceType.netease, neteaseSongId: '2002');
      final localSource = LyricSource(LyricSourceType.local);

      expect(qqSource.toMap(), {'source': 'qq', 'id': 1001});
      expect(kugouSource.toMap(), {'source': 'kugou', 'id': 'ABCDEF123456'});
      expect(neteaseSource.toMap(), {'source': 'netease', 'id': '2002'});
      expect(localSource.toMap(), {'source': 'local', 'id': null});

      final parsedQq = LyricSource.fromMap({'source': 'qq', 'id': 1001});
      expect(parsedQq.source, LyricSourceType.qq);
      expect(parsedQq.qqSongId, 1001);

      final parsedKugou =
          LyricSource.fromMap({'source': 'kugou', 'id': 'ABCDEF123456'});
      expect(parsedKugou.source, LyricSourceType.kugou);
      expect(parsedKugou.kugouSongHash, 'ABCDEF123456');

      final parsedNetease =
          LyricSource.fromMap({'source': 'netease', 'id': '2002'});
      expect(parsedNetease.source, LyricSourceType.netease);
      expect(parsedNetease.neteaseSongId, '2002');

      final parsedLocal = LyricSource.fromMap({'source': 'local', 'id': null});
      expect(parsedLocal.source, LyricSourceType.local);
    });
  });

  group('歌词源原子持久化 readLyricSources / saveLyricSources 测试', () {
    test('saveLyricSources 将内存中歌词源配置完整、原子性地写入磁盘，readLyricSources 可完整还原',
        () async {
      // 创建模拟存在的真实音频文件
      final audioFile1 = File(p.join(tempDir.path, 'song1.flac'))..createSync();
      final audioFile2 = File(p.join(tempDir.path, 'song2.mp3'))..createSync();
      final audioFile3 = File(p.join(tempDir.path, 'song3.m4a'))..createSync();

      LYRIC_SOURCES[audioFile1.path] =
          LyricSource(LyricSourceType.qq, qqSongId: 8888);
      LYRIC_SOURCES[audioFile2.path] =
          LyricSource(LyricSourceType.kugou, kugouSongHash: 'KUGOU_HASH_999');
      LYRIC_SOURCES[audioFile3.path] =
          LyricSource(LyricSourceType.netease, neteaseSongId: 'NETEASE_666');

      // 执行持久化保存
      await saveLyricSources();

      // 验证生成的 JSON 文件存在并有效
      final appDir = await getAppDataDir();
      final jsonFile = File(p.join(appDir.path, 'lyric_source.json'));
      expect(jsonFile.existsSync(), isTrue);

      final content = json.decode(jsonFile.readAsStringSync()) as Map;
      expect(content[audioFile1.path]['source'], 'qq');
      expect(content[audioFile1.path]['id'], 8888);
      expect(content[audioFile2.path]['source'], 'kugou');
      expect(content[audioFile2.path]['id'], 'KUGOU_HASH_999');
      expect(content[audioFile3.path]['source'], 'netease');
      expect(content[audioFile3.path]['id'], 'NETEASE_666');

      // 清空内存状态
      LYRIC_SOURCES.clear();
      expect(LYRIC_SOURCES.isEmpty, isTrue);

      // 读取磁盘配置还原
      await readLyricSources();

      expect(LYRIC_SOURCES.length, 3);
      expect(LYRIC_SOURCES[audioFile1.path]?.source, LyricSourceType.qq);
      expect(LYRIC_SOURCES[audioFile1.path]?.qqSongId, 8888);
      expect(LYRIC_SOURCES[audioFile2.path]?.source, LyricSourceType.kugou);
      expect(LYRIC_SOURCES[audioFile2.path]?.kugouSongHash, 'KUGOU_HASH_999');
      expect(LYRIC_SOURCES[audioFile3.path]?.source, LyricSourceType.netease);
      expect(LYRIC_SOURCES[audioFile3.path]?.neteaseSongId, 'NETEASE_666');
    });

    test('CUE分轨与离线音频在 readLyricSources 时被完整保护，脏配置清理移交主动维护', () async {
      final existingFile = File(p.join(tempDir.path, 'valid.flac'))..createSync();
      final cueTrackPath = p.join(tempDir.path, 'album.cue#CUE:01');
      final deletedPath = p.join(tempDir.path, 'removed.flac');

      LYRIC_SOURCES[existingFile.path] =
          LyricSource(LyricSourceType.qq, qqSongId: 123);
      LYRIC_SOURCES[cueTrackPath] =
          LyricSource(LyricSourceType.kugou, kugouSongHash: 'CUE_HASH');
      LYRIC_SOURCES[deletedPath] =
          LyricSource(LyricSourceType.netease, neteaseSongId: '456');

      await saveLyricSources();
      LYRIC_SOURCES.clear();

      await readLyricSources();

      // 验证 readLyricSources 不会抹除离线文件和 CUE 虚拟分轨
      expect(LYRIC_SOURCES.containsKey(existingFile.path), isTrue);
      expect(LYRIC_SOURCES.containsKey(cueTrackPath), isTrue);
      expect(LYRIC_SOURCES.containsKey(deletedPath), isTrue);
      expect(LYRIC_SOURCES.length, 3);

      // 执行主动维护清理：清理不存在的物理文件，但保护 CUE 虚拟分轨
      final cleanedCount = await pruneMissingLyricSources();
      expect(cleanedCount, 1);
      expect(LYRIC_SOURCES.containsKey(existingFile.path), isTrue);
      expect(LYRIC_SOURCES.containsKey(cueTrackPath), isTrue, reason: 'CUE 分轨必须受到保护');
      expect(LYRIC_SOURCES.containsKey(deletedPath), isFalse);
      expect(LYRIC_SOURCES.length, 2);
    });
  });

  group('AppShutdownCoordinator 退出拦截与状态持久化集成测试', () {
    test('AppShutdownCoordinator.production() 包含 saveLyricSources 且关闭时完整执行持久化',
        () async {
      final audioFile = File(p.join(tempDir.path, 'shutdown_test.flac'))
        ..createSync();
      LYRIC_SOURCES[audioFile.path] =
          LyricSource(LyricSourceType.qq, qqSongId: 77777);

      final coordinator = AppShutdownCoordinator.production();

      // 执行优雅关机流程
      await coordinator.shutdown();

      // 验证 lyric_source.json 是否被保存成功
      final appDir = await getAppDataDir();
      final jsonFile = File(p.join(appDir.path, 'lyric_source.json'));
      expect(jsonFile.existsSync(), isTrue);

      final content = json.decode(jsonFile.readAsStringSync()) as Map;
      expect(content[audioFile.path]['source'], 'qq');
      expect(content[audioFile.path]['id'], 77777);
    });
  });

  group('SetLyricSourceDialog 与 AudioEditDialog 无冲突写入协作测试', () {
    test('两处设置对话框对不同音频并发写入 LYRIC_SOURCES 不会冲突或产生脏数据', () async {
      final audioA = File(p.join(tempDir.path, 'track_a.flac'))..createSync();
      final audioB = File(p.join(tempDir.path, 'track_b.flac'))..createSync();

      // 模拟 SetLyricSourceDialog 写入 Track A
      final futureA = () async {
        LYRIC_SOURCES[audioA.path] =
            LyricSource(LyricSourceType.qq, qqSongId: 101);
        await saveLyricSources();
      }();

      // 模拟 AudioEditDialog 写入 Track B
      final futureB = () async {
        LYRIC_SOURCES[audioB.path] =
            LyricSource(LyricSourceType.kugou, kugouSongHash: 'HASH_202');
        await saveLyricSources();
      }();

      await Future.wait([futureA, futureB]);

      // 验证内存状态
      expect(LYRIC_SOURCES[audioA.path]?.qqSongId, 101);
      expect(LYRIC_SOURCES[audioB.path]?.kugouSongHash, 'HASH_202');

      // 清空并重新从磁盘读取，验证持久化一致性
      LYRIC_SOURCES.clear();
      await readLyricSources();

      expect(LYRIC_SOURCES[audioA.path]?.source, LyricSourceType.qq);
      expect(LYRIC_SOURCES[audioA.path]?.qqSongId, 101);
      expect(LYRIC_SOURCES[audioB.path]?.source, LyricSourceType.kugou);
      expect(LYRIC_SOURCES[audioB.path]?.kugouSongHash, 'HASH_202');
    });

    test('对同一音频先后通过不同对话框修改歌词源，后发生的操作能够干净覆盖先发生的操作并持久化', () async {
      final audio = File(p.join(tempDir.path, 'same_track.flac'))..createSync();

      // 1. 首先在 SetLyricSourceDialog 设为 QQ 音乐
      LYRIC_SOURCES[audio.path] =
          LyricSource(LyricSourceType.qq, qqSongId: 111);
      await saveLyricSources();
      expect(LYRIC_SOURCES[audio.path]?.source, LyricSourceType.qq);

      // 2. 随后在 AudioEditDialog 切换为网易云音乐
      LYRIC_SOURCES[audio.path] =
          LyricSource(LyricSourceType.netease, neteaseSongId: '222');
      await saveLyricSources();
      expect(LYRIC_SOURCES[audio.path]?.source, LyricSourceType.netease);
      expect(LYRIC_SOURCES[audio.path]?.neteaseSongId, '222');

      // 3. 验证磁盘读出一致
      LYRIC_SOURCES.clear();
      await readLyricSources();
      expect(LYRIC_SOURCES[audio.path]?.source, LyricSourceType.netease);
      expect(LYRIC_SOURCES[audio.path]?.neteaseSongId, '222');

      // 4. 用户点击“恢复自动匹配”解除绑定
      LYRIC_SOURCES.remove(audio.path);
      await saveLyricSources();

      LYRIC_SOURCES.clear();
      await readLyricSources();
      expect(LYRIC_SOURCES.containsKey(audio.path), isFalse);
    });
  });

  group('LyricService.useOnlineLyric() 歌词源选择偏好保持测试', () {
    test('当未指定歌词源时，useOnlineLyric 会调用默认在线匹配', () async {
      var defaultOnlineCalled = false;
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: p.join(tempDir.path, 'song_default.flac'),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final desktopLyric = FakeDesktopLyricController();

      final service = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => Future.value(null),
        getOnlineDefaultLyric: (a) async {
          defaultOnlineCalled = true;
          return null;
        },
      );
      addTearDown(service.dispose);
      addTearDown(playback.dispose);

      // LYRIC_SOURCES 为空，调用 useOnlineLyric 应触发 getOnlineDefaultLyric
      service.useOnlineLyric();
      await Future<void>.delayed(Duration.zero);

      expect(defaultOnlineCalled, isTrue);
    });

    test('当 LYRIC_SOURCES 设置为 local 时，useOnlineLyric 不会调用第三方 ID 而是调用默认在线匹配',
        () async {
      var defaultOnlineCalled = false;
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: p.join(tempDir.path, 'song_local.flac'),
      );
      LYRIC_SOURCES[audio.path] = LyricSource(LyricSourceType.local);

      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final desktopLyric = FakeDesktopLyricController();

      final service = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => Future.value(null),
        getOnlineDefaultLyric: (a) async {
          defaultOnlineCalled = true;
          return null;
        },
      );
      addTearDown(service.dispose);
      addTearDown(playback.dispose);

      service.useOnlineLyric();
      await Future<void>.delayed(Duration.zero);

      expect(defaultOnlineCalled, isTrue);
    });
  });
}

