import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_shutdown.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_cue_lyric_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    LYRIC_SOURCES.clear();
    resetLyricSourcesLoadedForTesting(loaded: false);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    LYRIC_SOURCES.clear();
    resetLyricSourcesLoadedForTesting(loaded: false);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('R2.1: 为包含 #CUE: 的虚拟分轨曲目绑定歌词来源后落盘并重启，映射完整保留不被过滤', () async {
    final cueTrack1 = p.join(tempDir.path, 'album.cue#CUE:01');
    final cueTrack2 = p.join(tempDir.path, 'album.cue#CUE:02');

    // 确保物理文件并不存在，验证完全不依赖物理文件
    expect(File(cueTrack1).existsSync(), isFalse);
    expect(File(cueTrack2).existsSync(), isFalse);

    LYRIC_SOURCES[cueTrack1] =
        LyricSource(LyricSourceType.qq, qqSongId: 998877);
    LYRIC_SOURCES[cueTrack2] =
        LyricSource(LyricSourceType.kugou, kugouSongHash: 'CUE_TRACK_HASH');

    await saveLyricSources();

    // 模拟应用重启：清空内存状态，重新读取配置
    LYRIC_SOURCES.clear();
    resetLyricSourcesLoadedForTesting(loaded: false);

    await readLyricSources();

    expect(isLyricSourcesLoaded, isTrue);
    expect(LYRIC_SOURCES.length, 2);
    expect(LYRIC_SOURCES[cueTrack1]?.source, LyricSourceType.qq);
    expect(LYRIC_SOURCES[cueTrack1]?.qqSongId, 998877);
    expect(LYRIC_SOURCES[cueTrack2]?.source, LyricSourceType.kugou);
    expect(LYRIC_SOURCES[cueTrack2]?.kugouSongHash, 'CUE_TRACK_HASH');
  });

  test('R2.2: 离线移动硬盘/网络盘曲目在重启时歌词来源不被抹除', () async {
    const offlinePath = r'Z:\NetworkDrive\Music\offline_song.flac';
    expect(File(offlinePath).existsSync(), isFalse);

    LYRIC_SOURCES[offlinePath] =
        LyricSource(LyricSourceType.netease, neteaseSongId: '12345678');
    await saveLyricSources();

    LYRIC_SOURCES.clear();
    resetLyricSourcesLoadedForTesting(loaded: false);

    await readLyricSources();

    expect(LYRIC_SOURCES.containsKey(offlinePath), isTrue);
    expect(LYRIC_SOURCES[offlinePath]?.neteaseSongId, '12345678');
  });

  test('R2.3: 读取或反序列化发生异常时，禁止退出 (app_shutdown) 以空数据覆写磁盘配置', () async {
    final appDir = await getAppDataDir();
    final jsonFile = File(p.join(appDir.path, 'lyric_source.json'));
    await jsonFile.parent.create(recursive: true);

    // 写入已有的有效数据
    final originalContent = json.encode({
      r'E:\Music\precious_song.flac': {'source': 'qq', 'id': 556677},
    });
    await jsonFile.writeAsString(originalContent);

    // 写入损坏内容，模拟反序列化/I/O 异常
    await jsonFile.writeAsString('{"damaged_json": {invalid...');

    // 执行读取
    LYRIC_SOURCES.clear();
    resetLyricSourcesLoadedForTesting(loaded: false);
    await readLyricSources();

    // 验证状态守卫保持为未加载
    expect(isLyricSourcesLoaded, isFalse);
    expect(LYRIC_SOURCES.isEmpty, isTrue);

    // 恢复磁盘原本内容（模拟用户磁盘上原本有重要数据，但启动时读取发生锁竞争或部分损坏）
    await jsonFile.writeAsString(originalContent);

    // 触发退出流程
    final coordinator = AppShutdownCoordinator.production();
    await coordinator.shutdown();

    // 验证磁盘内容没有被以空数据覆盖！原本的数据完好无损！
    final diskContent = jsonFile.readAsStringSync();
    expect(diskContent, originalContent);
    final diskMap = json.decode(diskContent) as Map;
    expect(diskMap.containsKey(r'E:\Music\precious_song.flac'), isTrue);
  });

  test('R2.4: 主动维护清理只会清除不存在物理文件的普通曲目，不会误删 #CUE: 虚拟分轨', () async {
    final realFile = File(p.join(tempDir.path, 'real.flac'))..createSync();
    final deletedFile = p.join(tempDir.path, 'deleted.flac');
    final cueTrack = p.join(tempDir.path, 'disc.cue#CUE:03');

    LYRIC_SOURCES[realFile.path] = LyricSource(LyricSourceType.local);
    LYRIC_SOURCES[deletedFile] = LyricSource(LyricSourceType.qq, qqSongId: 1);
    LYRIC_SOURCES[cueTrack] =
        LyricSource(LyricSourceType.netease, neteaseSongId: '2');
    await saveLyricSources();

    final removedCount = await pruneMissingLyricSources();

    expect(removedCount, 1);
    expect(LYRIC_SOURCES.containsKey(realFile.path), isTrue);
    expect(LYRIC_SOURCES.containsKey(cueTrack), isTrue);
    expect(LYRIC_SOURCES.containsKey(deletedFile), isFalse);
  });
}
