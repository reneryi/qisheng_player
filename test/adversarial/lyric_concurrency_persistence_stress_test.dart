import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_shutdown.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('qisheng_adv_lyric_stress_');
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

  Future<File> getLyricSourceJsonFile() async {
    final appDir = await getAppDataDir();
    return File(p.join(appDir.path, 'lyric_source.json'));
  }

  // ===========================================================================
  // GROUP 1: 并发读写冲突、原子落盘与状态互斥极限实证
  // ===========================================================================
  group('Adversarial Group 1: 并发读写冲突与原子落盘互斥极限挑战', () {
    test('1.1 大规模高并发（30个任务）争抢写入不同歌曲，验证原子落盘、零异常与无数据丢失', () async {
      const taskCount = 30;
      final audioFiles = <File>[];
      for (int i = 0; i < taskCount; i++) {
        final f = File(p.join(tempDir.path, 'concurrent_song_$i.flac'))
          ..createSync();
        audioFiles.add(f);
      }

      // 模拟 30 个异步写任务并发执行
      final futures = <Future<void>>[];
      for (int i = 0; i < taskCount; i++) {
        final path = audioFiles[i].path;
        final index = i;
        futures.add(() async {
          // 微量异步间隙扰动，模拟真实的 UI 触发与网络返回交错
          await Future.delayed(Duration(milliseconds: (index % 5) * 2));
          final type = switch (index % 3) {
            0 => LyricSourceType.qq,
            1 => LyricSourceType.kugou,
            _ => LyricSourceType.netease,
          };
          LYRIC_SOURCES[path] = LyricSource(
            type,
            qqSongId: type == LyricSourceType.qq ? 10000 + index : null,
            kugouSongHash:
                type == LyricSourceType.kugou ? 'HASH_${10000 + index}' : null,
            neteaseSongId:
                type == LyricSourceType.netease ? '${10000 + index}' : null,
          );
          await saveLyricSources();
        }());
      }

      // 等待所有并发写入完成
      await Future.wait(futures);

      // 验证落盘文件存在且是合法 JSON
      final jsonFile = await getLyricSourceJsonFile();
      expect(jsonFile.existsSync(), isTrue, reason: 'lyric_source.json 必须存在');

      final rawContent = jsonFile.readAsStringSync();
      expect(rawContent.isNotEmpty, isTrue);
      final Map decoded = json.decode(rawContent);

      // 验证所有 30 个条目均被正确写入，无任何丢失
      expect(decoded.length, taskCount,
          reason: '高并发写入后磁盘 JSON 中的条目数量必须完整无损');

      // 清空内存后 readLyricSources 验证读入状态完全一致
      LYRIC_SOURCES.clear();
      await readLyricSources();
      expect(LYRIC_SOURCES.length, taskCount);
      for (int i = 0; i < taskCount; i++) {
        final path = audioFiles[i].path;
        expect(LYRIC_SOURCES.containsKey(path), isTrue);
        final source = LYRIC_SOURCES[path]!;
        final expectedType = switch (i % 3) {
          0 => LyricSourceType.qq,
          1 => LyricSourceType.kugou,
          _ => LyricSourceType.netease,
        };
        expect(source.source, expectedType);
      }
    });

    test('1.2 对同一音频进行 50 次交替并发覆写竞态，验证落盘数据无结构撕裂且与最终内存一致', () async {
      final sharedAudio = File(p.join(tempDir.path, 'shared_track.flac'))
        ..createSync();

      const iterations = 50;
      final futures = <Future<void>>[];

      // 模拟 SetLyricSourceDialog (QQ音乐) 与 AudioEditDialog (网易云音乐) 对同一歌曲进行激烈覆写
      for (int i = 0; i < iterations; i++) {
        final iter = i;
        futures.add(() async {
          await Future.delayed(Duration(microseconds: (iter % 7) * 50));
          if (iter.isEven) {
            // 来自 SetLyricSourceDialog 的修改
            LYRIC_SOURCES[sharedAudio.path] =
                LyricSource(LyricSourceType.qq, qqSongId: 1000 + iter);
          } else {
            // 来自 AudioEditDialog 的修改
            LYRIC_SOURCES[sharedAudio.path] = LyricSource(
                LyricSourceType.netease,
                neteaseSongId: 'NETEASE_$iter');
          }
          await saveLyricSources();
        }());
      }

      await Future.wait(futures);

      // 检验最终磁盘状态
      final jsonFile = await getLyricSourceJsonFile();
      final decoded = json.decode(jsonFile.readAsStringSync()) as Map;
      expect(decoded.containsKey(sharedAudio.path), isTrue);

      final diskEntry = decoded[sharedAudio.path];
      final diskSource = diskEntry['source'] as String;
      if (diskSource == 'qq') {
        expect(diskEntry['id'], isA<int>());
      } else if (diskSource == 'netease') {
        expect(diskEntry['id'], isA<String>());
      }

      // 磁盘与内存数据应完全对齐
      final memorySource = LYRIC_SOURCES[sharedAudio.path]!;
      expect(diskSource, memorySource.source.name);
      if (memorySource.source == LyricSourceType.qq) {
        expect(diskEntry['id'], memorySource.qqSongId);
      } else {
        expect(diskEntry['id'], memorySource.neteaseSongId);
      }
    });

    test('1.3 读写并发极端交织测试：高频同时 readLyricSources 与 saveLyricSources 零死锁零崩溃',
        () async {
      final audioA = File(p.join(tempDir.path, 'interleave_a.flac'))
        ..createSync();
      final audioB = File(p.join(tempDir.path, 'interleave_b.flac'))
        ..createSync();

      // 先初始化一个基础文件
      LYRIC_SOURCES[audioA.path] = LyricSource(LyricSourceType.local);
      await saveLyricSources();

      bool keepRunning = true;
      var readSuccessCount = 0;
      var writeSuccessCount = 0;

      // 协程 A：持续高频读取磁盘
      final reader = () async {
        while (keepRunning) {
          await readLyricSources();
          readSuccessCount++;
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }();

      // 协程 B：持续高频写入不同数据
      final writer = () async {
        for (int i = 0; i < 25; i++) {
          LYRIC_SOURCES[audioB.path] =
              LyricSource(LyricSourceType.qq, qqSongId: 5000 + i);
          await saveLyricSources();
          writeSuccessCount++;
          await Future.delayed(const Duration(milliseconds: 3));
        }
        keepRunning = false;
      }();

      await Future.wait([reader, writer]);

      expect(readSuccessCount, greaterThan(5),
          reason: '读取协程应在写入进行期间成功多次读取无异常');
      expect(writeSuccessCount, 25, reason: '所有25次写入必须顺利通过');

      // 终态校验
      await readLyricSources();
      expect(LYRIC_SOURCES.containsKey(audioB.path), isTrue);
      expect(LYRIC_SOURCES[audioB.path]?.qqSongId, 5024);
    });

    test('1.4 并发删除 (remove) 与并发插入 (insert) 竞态测试，验证数据一致性与无破损', () async {
      final targetAudio = File(p.join(tempDir.path, 'race_target.flac'))
        ..createSync();

      // 初始设置
      LYRIC_SOURCES[targetAudio.path] =
          LyricSource(LyricSourceType.kugou, kugouSongHash: 'INITIAL_HASH');
      await saveLyricSources();

      // 并发执行：一边尝试清除，一边尝试覆写
      final f1 = () async {
        await Future.delayed(const Duration(milliseconds: 1));
        LYRIC_SOURCES.remove(targetAudio.path);
        await saveLyricSources();
      }();

      final f2 = () async {
        await Future.delayed(const Duration(milliseconds: 2));
        LYRIC_SOURCES[targetAudio.path] =
            LyricSource(LyricSourceType.qq, qqSongId: 9999);
        await saveLyricSources();
      }();

      await Future.wait([f1, f2]);

      final jsonFile = await getLyricSourceJsonFile();
      expect(jsonFile.existsSync(), isTrue);
      final decoded = json.decode(jsonFile.readAsStringSync()) as Map;

      // 验证无论哪个操作最终获胜，磁盘 JSON 格式必须合法，且与内存最终状态完全一致
      final memoryHasKey = LYRIC_SOURCES.containsKey(targetAudio.path);
      final diskHasKey = decoded.containsKey(targetAudio.path);
      expect(diskHasKey, memoryHasKey, reason: '磁盘中是否存在条目必须与内存终态完全一致');
    });

    test('1.5 模拟 SetLyricSourceDialog 与 AudioEditDialog 完整业务流程并发执行落盘与 LyricService 即时更新',
        () async {
      final dialogAudio =
          File(p.join(tempDir.path, 'dialog_song.flac'))..createSync();
      final editAudio =
          File(p.join(tempDir.path, 'edit_song.flac'))..createSync();

      final testAudio = TestAudio(
        title: '弹窗测试曲目',
        artist: '测试歌手',
        album: '测试专辑',
        path: dialogAudio.path,
      );

      final playback = FakePlaybackController(audio: testAudio, queue: [testAudio]);
      final desktopLyric = FakeDesktopLyricController();

      final mockLrc = Lrc.fromLrcText(
        '[00:01.00]歌词行1\n[00:05.00]歌词行2',
        LrcSource.local,
      )!;

      final lyricService = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => Future.value(null),
      );
      addTearDown(lyricService.dispose);
      addTearDown(playback.dispose);

      // 模拟 SetLyricSourceDialog 业务逻辑（设置当前播放歌曲为 QQ 音乐并即时注入）
      final dialogFuture = () async {
        LYRIC_SOURCES[dialogAudio.path] = LyricSource(
          LyricSourceType.qq,
          qqSongId: 777888,
        );
        await saveLyricSources();
        lyricService.useSpecificLyric(mockLrc);
      }();

      // 模拟 AudioEditDialog 业务逻辑（并发保存另一首歌曲的酷狗歌词源）
      final editFuture = () async {
        await Future.delayed(const Duration(milliseconds: 1));
        LYRIC_SOURCES[editAudio.path] = LyricSource(
          LyricSourceType.kugou,
          kugouSongHash: 'BG_HASH_999',
        );
        await saveLyricSources();
      }();

      await Future.wait([dialogFuture, editFuture]);

      // 验证 LyricService 即时更新无闪烁
      final activeLyric = await lyricService.currLyricFuture;
      expect(activeLyric, isNotNull);
      expect((activeLyric!.lines.first as UnsyncLyricLine).content, '歌词行1');

      // 验证内存状态：两处设置均完整保留
      expect(LYRIC_SOURCES[dialogAudio.path]?.qqSongId, 777888);
      expect(LYRIC_SOURCES[editAudio.path]?.kugouSongHash, 'BG_HASH_999');

      // 清空并从磁盘重新载入
      LYRIC_SOURCES.clear();
      await readLyricSources();

      expect(LYRIC_SOURCES.length, 2);
      expect(LYRIC_SOURCES[dialogAudio.path]?.source, LyricSourceType.qq);
      expect(LYRIC_SOURCES[dialogAudio.path]?.qqSongId, 777888);
      expect(LYRIC_SOURCES[editAudio.path]?.source, LyricSourceType.kugou);
      expect(LYRIC_SOURCES[editAudio.path]?.kugouSongHash, 'BG_HASH_999');
    });
  });

  // ===========================================================================
  // GROUP 2: 关机崩溃模拟与持久化协调器安全挑战
  // ===========================================================================
  group('Adversarial Group 2: 关机崩溃模拟与 AppShutdownCoordinator 退出拦截实证', () {
    test('2.1 高频写入风暴中直接触发 shutdown()，验证落盘完整性与无 .tmp 孤儿文件残留', () async {
      final files = <File>[];
      for (int i = 0; i < 15; i++) {
        final f = File(p.join(tempDir.path, 'shutdown_storm_$i.flac'))
          ..createSync();
        files.add(f);
      }

      // 启动一阵密集写入风暴，收集所有并发保存任务
      final inFlightFutures = <Future<void>>[];
      for (int i = 0; i < 15; i++) {
        final path = files[i].path;
        final idx = i;
        LYRIC_SOURCES[path] =
            LyricSource(LyricSourceType.qq, qqSongId: 20000 + idx);
        inFlightFutures.add(saveLyricSources());
      }

      // 在高频修改后直接触发生产环境关机流程
      final coordinator = AppShutdownCoordinator.production();
      await coordinator.shutdown();

      // 等待并发保存完全收敛
      await Future.wait(inFlightFutures);

      // 验证磁盘 JSON 存在且为有效 JSON
      final jsonFile = await getLyricSourceJsonFile();
      expect(jsonFile.existsSync(), isTrue);

      final content = jsonFile.readAsStringSync();
      expect(content.trim().isNotEmpty, isTrue);
      final Map decoded = json.decode(content);
      expect(decoded, isA<Map>());

      // 验证临时文件 .tmp 已全部被安全清理，没有任何孤儿残留
      final appDir = await getAppDataDir();
      final tmpFiles = appDir
          .listSync()
          .where((entity) => entity.path.endsWith('.tmp'))
          .toList();
      expect(tmpFiles, isEmpty, reason: '关机后不得残留任何 .tmp 临时写入文件');
    });

    test('2.2 多事件源并发同时调用 shutdown()，验证幂等性只执行一次且状态落盘完整', () async {
      final audio = File(p.join(tempDir.path, 'multi_shutdown.flac'))
        ..createSync();
      LYRIC_SOURCES[audio.path] =
          LyricSource(LyricSourceType.netease, neteaseSongId: '888777');

      final coordinator = AppShutdownCoordinator.production();

      // 5 个并发调用同时请求关机
      final shutdownFutures = List.generate(5, (_) => coordinator.shutdown());
      await Future.wait(shutdownFutures);

      final jsonFile = await getLyricSourceJsonFile();
      expect(jsonFile.existsSync(), isTrue);
      final decoded = json.decode(jsonFile.readAsStringSync()) as Map;
      expect(decoded[audio.path]['source'], 'netease');
      expect(decoded[audio.path]['id'], '888777');
    });

    test('2.3 极端故障隔离：其他持久化任务抛出异常或超时不影响 saveLyricSources 落盘', () async {
      final audio = File(p.join(tempDir.path, 'fault_isolation.flac'))
        ..createSync();
      LYRIC_SOURCES[audio.path] =
          LyricSource(LyricSourceType.kugou, kugouSongHash: 'SAFE_HASH');

      // 构造包含恶意故障操作的 AppShutdownCoordinator
      final coordinator = AppShutdownCoordinator(
        closePlayer: () async {},
        persistState: [
          // 故障任务 1：直接抛出严重异常
          () async => throw StateError('Simulated catastrophic database crash'),
          // 正常任务：保存歌词源
          saveLyricSources,
          // 故障任务 2：返回正常但抛出 FileSystemException
          () async => throw const FileSystemException('Disk write blocked'),
        ],
      );

      // 执行关机
      await coordinator.shutdown();

      // 即使同组其他任务发生异常，saveLyricSources 依然顺利完成落盘
      final jsonFile = await getLyricSourceJsonFile();
      expect(jsonFile.existsSync(), isTrue);
      final decoded = json.decode(jsonFile.readAsStringSync()) as Map;
      expect(decoded[audio.path]['source'], 'kugou');
      expect(decoded[audio.path]['id'], 'SAFE_HASH');
    });
  });

  // ===========================================================================
  // GROUP 3: 脏数据清理与破损/畸形 JSON 容灾降级
  // ===========================================================================
  group('Adversarial Group 3: 脏数据清理与破损/畸形 JSON 容灾降级实证', () {
    test('3.1 物理音频删除实证：物理文件删除后自动剪除幽灵记录，重新保存后磁盘彻底净化', () async {
      final validAudio1 = File(p.join(tempDir.path, 'valid_audio_1.flac'))
        ..createSync();
      final validAudio2 = File(p.join(tempDir.path, 'valid_audio_2.mp3'))
        ..createSync();
      final deletedAudio1 = File(p.join(tempDir.path, 'deleted_audio_1.flac'))
        ..createSync();
      final deletedAudio2 = File(p.join(tempDir.path, 'deleted_audio_2.wav'))
        ..createSync();

      // 初始写入4个文件
      LYRIC_SOURCES[validAudio1.path] =
          LyricSource(LyricSourceType.qq, qqSongId: 1111);
      LYRIC_SOURCES[validAudio2.path] =
          LyricSource(LyricSourceType.kugou, kugouSongHash: 'VALID2');
      LYRIC_SOURCES[deletedAudio1.path] =
          LyricSource(LyricSourceType.netease, neteaseSongId: 'DEL1');
      LYRIC_SOURCES[deletedAudio2.path] = LyricSource(LyricSourceType.local);
      await saveLyricSources();

      // 物理删除其中两个文件
      deletedAudio1.deleteSync();
      deletedAudio2.deleteSync();
      expect(deletedAudio1.existsSync(), isFalse);
      expect(deletedAudio2.existsSync(), isFalse);

      // 清空内存并执行读取
      LYRIC_SOURCES.clear();
      await readLyricSources();

      // 验证内存中幽灵记录被自动剪除
      expect(LYRIC_SOURCES.containsKey(deletedAudio1.path), isFalse);
      expect(LYRIC_SOURCES.containsKey(deletedAudio2.path), isFalse);
      expect(LYRIC_SOURCES.length, 2);
      expect(LYRIC_SOURCES.containsKey(validAudio1.path), isTrue);
      expect(LYRIC_SOURCES.containsKey(validAudio2.path), isTrue);

      // 重新执行持久化落盘
      await saveLyricSources();

      // 直接解析磁盘文件，验证磁盘中已彻底清除被删除的文件
      final jsonFile = await getLyricSourceJsonFile();
      final diskMap = json.decode(jsonFile.readAsStringSync()) as Map;
      expect(diskMap.length, 2);
      expect(diskMap.containsKey(deletedAudio1.path), isFalse);
      expect(diskMap.containsKey(deletedAudio2.path), isFalse);
    });

    test('3.2 损坏/截断/非合法 JSON 容灾降级矩阵：平滑降级为空 Map 且不抛出未捕获异常', () async {
      final jsonFile = await getLyricSourceJsonFile();
      await jsonFile.parent.create(recursive: true);

      final corruptedPayloads = <String, String>{
        '截断的半截 JSON': '{"C:\\music\\song.flac": {"source": "qq",',
        '0 字节完全空文件': '',
        '纯空白换行符': '   \n\r\t   \n',
        '顶层为 List 非 Map': '[{"path": "foo"}, 123]',
        '顶层为字符串': '"this is a plain string"',
        '顶层为数字': '987654',
        '顶层为布尔值': 'true',
        '顶层为 null 字面量': 'null',
      };

      for (final entry in corruptedPayloads.entries) {
        final label = entry.key;
        final payload = entry.value;

        // 写入测试坏损内容
        jsonFile.writeAsStringSync(payload);

        // 设置内存默认脏值，验证 readLyricSources 是否安全清空
        LYRIC_SOURCES['dummy_path'] = LyricSource(LyricSourceType.local);

        // 执行读取，必须平滑降级，绝不允许向外抛出未捕获异常
        await expectLater(readLyricSources(), completes,
            reason: '场景 [$label] 不得抛出任何未捕获异常');

        // 校验平滑降级后 LYRIC_SOURCES 保持为空 Map
        expect(LYRIC_SOURCES.isEmpty, isTrue,
            reason: '场景 [$label] 应平滑降级为空 Map');
      }
    });

    test('3.3 二进制乱码与非法 UTF-8 字节容灾降级测试', () async {
      final jsonFile = await getLyricSourceJsonFile();
      await jsonFile.parent.create(recursive: true);

      // 写入非 UTF-8 随机二进制乱码
      jsonFile.writeAsBytesSync([0xFF, 0xFE, 0x00, 0x12, 0x88, 0x99, 0xAA]);

      LYRIC_SOURCES['dummy_path'] = LyricSource(LyricSourceType.local);

      // 必须安全吸收异常，平滑降级
      await readLyricSources();
      expect(LYRIC_SOURCES.isEmpty, isTrue);
    });

    test('3.4 畸形条目与类型破损防御：未知 source 优雅降级为 local，非 Map 条目安全捕获', () async {
      final validSong = File(p.join(tempDir.path, 'valid_malformed_test.flac'))
        ..createSync();
      final jsonFile = await getLyricSourceJsonFile();
      await jsonFile.parent.create(recursive: true);

      // 场景 1：source 为未知枚举名称 -> 应优雅降级为 local
      final unknownSourcePayload = json.encode({
        validSong.path: {'source': 'bilibili_music', 'id': '9999'},
      });
      jsonFile.writeAsStringSync(unknownSourcePayload);
      await readLyricSources();
      expect(LYRIC_SOURCES.containsKey(validSong.path), isTrue);
      expect(LYRIC_SOURCES[validSong.path]?.source, LyricSourceType.local,
          reason: '未知来源类型必须安全降级为 local');

      // 场景 2：条目值不是 Map 而是非法字符串
      final invalidValuePayload = json.encode({
        validSong.path: 'invalid_string_instead_of_map',
      });
      jsonFile.writeAsStringSync(invalidValuePayload);
      await readLyricSources();
      expect(LYRIC_SOURCES.isEmpty, isTrue, reason: '非法条目结构安全降级不崩溃');

      // 场景 3：qq 的 id 类型破损（传入 String 而非 int）
      final typeMismatchPayload = json.encode({
        validSong.path: {'source': 'qq', 'id': 'not_an_int'},
      });
      jsonFile.writeAsStringSync(typeMismatchPayload);
      await readLyricSources();
      expect(LYRIC_SOURCES.isEmpty, isTrue, reason: '类型错误条目安全被捕获不崩溃');
    });
  });

  // ===========================================================================
  // GROUP 4: 歌词平滑切换与竞态/空指针防御
  // ===========================================================================
  group('Adversarial Group 4: 歌词平滑切换、竞态拦截与空指针防御实证', () {
    test('4.1 乱序异步响应防覆盖实证：慢速在线响应决不能覆盖先完成的快速本地响应', () async {
      final audio = TestAudio(
        title: 'Racing Track',
        artist: 'Speedy Artist',
        album: 'Fast Album',
        path: p.join(tempDir.path, 'racing.flac'),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final desktopLyric = FakeDesktopLyricController();

      // 构造两个可控延迟的歌词提供者
      final localLyric = Lrc.fromLrcText(
        '[00:01.00]这是本地歌词行 1\n[00:05.00]这是本地歌词行 2',
        LrcSource.local,
      )!;
      final onlineLyric = Lrc.fromLrcText(
        '[00:01.00]这是慢速在线歌词行 1\n[00:05.00]这是慢速在线歌词行 2',
        LrcSource.web,
      )!;

      final slowOnlineCompleter = Completer<Lyric?>();
      final fastLocalCompleter = Completer<Lyric?>();

      final service = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => Future.value(null),
        getLocalLyric: (a) => fastLocalCompleter.future,
        getOnlineDefaultLyric: (a) => slowOnlineCompleter.future,
      );
      addTearDown(service.dispose);
      addTearDown(playback.dispose);

      // 1. 用户先点击“在线歌词”（慢速网络请求发出）
      service.useOnlineLyric();

      // 2. 紧接着用户立刻点击“本地歌词”（快速本地解析发出）
      service.useLocalLyric();

      // 3. 本地歌词先返回（完成快）
      fastLocalCompleter.complete(localLyric);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final midLyric = await service.currLyricFuture;
      expect(midLyric, isNotNull);
      expect((midLyric!.lines.first as UnsyncLyricLine).content, '这是本地歌词行 1');

      // 4. 经过较长网络延迟后，慢速在线歌词才终于到达
      slowOnlineCompleter.complete(onlineLyric);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 5. 核心验证：慢速在线歌词必须被 _lyricLoadVersion 拦截丢弃，当前歌词坚决保持为本地歌词！
      final finalLyric = await service.currLyricFuture;
      expect(finalLyric, isNotNull);
      expect((finalLyric!.lines.first as UnsyncLyricLine).content, '这是本地歌词行 1',
          reason: '过时的慢速网络响应绝不能覆盖用户随后选择的本地歌词');
    });

    test('4.2 极速多源连击切换压力测试：20次连续高频切换无 null 穿透，行索引安全稳定', () async {
      final audio = TestAudio(
        title: 'Switching Track',
        artist: 'Rapid Artist',
        album: 'Rapid Album',
        path: p.join(tempDir.path, 'rapid_switch.flac'),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final desktopLyric = FakeDesktopLyricController();

      final dummyLyric = Lrc.fromLrcText(
        '[00:00.00]第一行\n[00:03.00]第二行\n[00:08.00]第三行',
        LrcSource.local,
      )!;

      final service = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => Future.value(dummyLyric),
        getLocalLyric: (_) => Future.value(dummyLyric),
        getOnlineDefaultLyric: (_) => Future.value(dummyLyric),
      );
      addTearDown(service.dispose);
      addTearDown(playback.dispose);

      // 高频连续 20 次随机切换
      for (int i = 0; i < 20; i++) {
        switch (i % 4) {
          case 0:
            service.useLocalLyric();
            break;
          case 1:
            service.useOnlineLyric();
            break;
          case 2:
            service.useSpecificLyric(dummyLyric);
            break;
          case 3:
            service.updateLyric();
            break;
        }
        playback.seek((i * 1.5) % 10.0);
      }

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // 验证没有崩溃，行索引安全合规
      expect(service.currentLyricLineIndex, inInclusiveRange(0, 2));
      final resolved = await service.currLyricFuture;
      expect(resolved, isNotNull);
    });

    test('4.3 空歌词与单行歌词在极端播放位置推进下的边界防护', () async {
      final audio = TestAudio(
        title: 'Empty Lyric Track',
        artist: 'Edge Artist',
        album: 'Edge Album',
        path: p.join(tempDir.path, 'edge.flac'),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final desktopLyric = FakeDesktopLyricController();

      final emptyLyric = Lrc([], LrcSource.local);
      final singleLineLyric = Lrc.fromLrcText(
        '[00:00.00]唯一的一行歌词',
        LrcSource.local,
      )!;

      final service = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => Future.value(emptyLyric),
      );
      addTearDown(service.dispose);
      addTearDown(playback.dispose);

      // 场景 A: 载入空歌词，推送超大位置
      service.useSpecificLyric(emptyLyric);
      await Future<void>.delayed(Duration.zero);

      playback.seek(100.0);
      playback.seek(9999.0);
      playback.seek(-10.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.currentLyricLineIndex, 0, reason: '空歌词下行索引必须安全守卫为 0');

      // 场景 B: 载入单行歌词，推送超大越界位置
      service.useSpecificLyric(singleLineLyric);
      await Future<void>.delayed(Duration.zero);

      playback.seek(999999.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.currentLyricLineIndex, 0,
          reason: '单行歌词下超大时间戳必须 clamp 在 0');
    });

    test('4.4 异步加载中途被 dispose() 时的生命周期安全性', () async {
      final audio = TestAudio(
        title: 'Disposed Track',
        artist: 'Disposed Artist',
        album: 'Disposed Album',
        path: p.join(tempDir.path, 'disposed.flac'),
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final desktopLyric = FakeDesktopLyricController();

      final pendingCompleter = Completer<Lyric?>();

      final service = LyricService.forTest(
        playbackService: playback,
        desktopLyricService: desktopLyric,
        getDefaultLyric: (_, __) => pendingCompleter.future,
        getOnlineDefaultLyric: (_) => pendingCompleter.future,
      );

      // 发起异步在线加载
      service.useOnlineLyric();

      // 在异步请求未完成时，直接销毁 service
      service.dispose();

      // 随后异步请求完成并返回歌词
      final delayedLyric = Lrc.fromLrcText(
        '[00:01.00]延迟返回的歌词',
        LrcSource.web,
      );
      pendingCompleter.complete(delayedLyric);

      // 等待微任务完成，验证绝不向已关闭的 stream 抛出 StateError 崩溃
      await Future<void>.delayed(const Duration(milliseconds: 20));
      playback.dispose();
    });
  });
}
