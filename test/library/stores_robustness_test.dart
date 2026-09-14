import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/library/play_count_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appDataDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_stores_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    appDataDir = await getAppDataDir();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('PlayCountStore robustness tests', () {
    late String playCountPath;
    String? originalContent;

    setUp(() {
      playCountPath = "${appDataDir.path}\\play_count.json";
      final file = File(playCountPath);
      if (file.existsSync()) {
        originalContent = file.readAsStringSync();
      } else {
        originalContent = null;
      }
    });

    tearDown(() {
      final file = File(playCountPath);
      if (originalContent != null) {
        file.writeAsStringSync(originalContent!);
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('PlayCountStore load failure does not lock isLoaded and blocks empty save overwrite', () async {
      final file = File(playCountPath);
      // 写入损坏的 JSON
      file.writeAsStringSync("INVALID_JSON_CORRUPTED{{{");

      final store = PlayCountStore.instance;
      store.resetLoadedForTesting(loaded: false);

      // 读取失败，不应置位 isLoaded 为 true
      await store.read();
      expect(store.isLoaded, isFalse);

      // 当 !_loaded 时调用 save()，不应覆盖磁盘文件
      await store.save();
      expect(file.readAsStringSync(), equals("INVALID_JSON_CORRUPTED{{{"));

      // 修复磁盘数据为合法内容
      final validData = {"song_a.flac": 42, "song_b.flac": 7};
      file.writeAsStringSync(json.encode(validData));

      // 再次执行 read()，应能成功重试
      await store.read();
      expect(store.isLoaded, isTrue);
      expect(store.getByPath("song_a.flac"), equals(42));
      expect(store.getByPath("song_b.flac"), equals(7));

      // 此时已加载，修改并 save() 应当成功落盘
      await store.increaseByPath("song_a.flac");
      expect(store.getByPath("song_a.flac"), equals(43));
      await store.save();

      final saved = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(saved["song_a.flac"], equals(43));
      expect(saved["song_b.flac"], equals(7));
    });

    test('PlayCountStore.forTesting respects loaded guard when initialized with loaded: false', () async {
      final persisted = <Map<String, int>>[];
      final store = PlayCountStore.forTesting(
        persist: (counts) async => persisted.add(counts),
        loaded: false,
      );

      expect(store.isLoaded, isFalse);
      await store.save();
      expect(persisted, isEmpty);

      store.resetLoadedForTesting(loaded: true);
      await store.save();
      expect(persisted, hasLength(1));
    });
  });

  group('AudioMetadataOverrideStore robustness tests', () {
    late String overridePath;
    String? originalContent;

    setUp(() {
      overridePath = "${appDataDir.path}\\audio_override.json";
      final file = File(overridePath);
      if (file.existsSync()) {
        originalContent = file.readAsStringSync();
      } else {
        originalContent = null;
      }
    });

    tearDown(() {
      final file = File(overridePath);
      if (originalContent != null) {
        file.writeAsStringSync(originalContent!);
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('AudioMetadataOverrideStore load failure allows retry and prevents empty overwrite', () async {
      final file = File(overridePath);
      file.writeAsStringSync("BROKEN_OVERRIDE_JSON_###");

      final store = AudioMetadataOverrideStore.instance;
      store.resetLoadedForTesting(loaded: false);

      await store.read();
      expect(store.isLoaded, isFalse);

      // save 应被拦截，不覆盖损坏的原文件
      await store.save();
      expect(file.readAsStringSync(), equals("BROKEN_OVERRIDE_JSON_###"));

      // 修复为有效数据
      final validOverrides = {
        r"D:\Music\song.flac": {
          "title": "Overridden Title",
          "artist": "Overridden Artist",
          "album": "Overridden Album",
        }
      };
      file.writeAsStringSync(json.encode(validOverrides));

      // 再次 read()，能够重试并成功恢复
      await store.read();
      expect(store.isLoaded, isTrue);

      final audio = Audio(
        "Original",
        "Original",
        "Original",
        null,
        null,
        1,
        1,
        200,
        null,
        null,
        null,
        null,
        null,
        null,
        r"D:\Music\song.flac",
        1700000000,
        1700000000,
        null,
      );

      store.applyToAudio(audio);
      expect(audio.title, equals("Overridden Title"));
      expect(audio.artist, equals("Overridden Artist"));
      expect(audio.album, equals("Overridden Album"));
    });
  });

  group('OnlineCoverStore robustness tests', () {
    late String cachePath;
    String? originalContent;

    setUp(() {
      cachePath = "${appDataDir.path}\\cover_cache.json";
      final file = File(cachePath);
      if (file.existsSync()) {
        originalContent = file.readAsStringSync();
      } else {
        originalContent = null;
      }
    });

    tearDown(() {
      final file = File(cachePath);
      if (originalContent != null) {
        file.writeAsStringSync(originalContent!);
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('OnlineCoverStore load failure allows retry and protects existing disk cache', () async {
      final file = File(cachePath);
      file.writeAsStringSync("{CORRUPT_JSON_DATA}");

      final store = OnlineCoverStore.instance;
      store.resetLoadedForTesting(loaded: false);

      await store.read();
      expect(store.isLoaded, isFalse);

      await store.save();
      expect(file.readAsStringSync(), equals("{CORRUPT_JSON_DATA}"));

      final validCache = {
        r"D:\Music\track.flac": r"C:\AppData\covers\hash123.jpg",
      };
      file.writeAsStringSync(json.encode(validCache));

      await store.read();
      expect(store.isLoaded, isTrue);
    });
  });
}
