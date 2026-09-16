import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/play_service/playback_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playback_session_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
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

  group('PlaybackSessionStore 轻量进度快照存储测试', () {
    test('初始无文件时 readSnapshot 返回 null', () async {
      final snapshot = await PlaybackSessionStore.readSnapshot();
      expect(snapshot, isNull);
    });

    test('saveSnapshot 正确原子落盘且 readSnapshot 完整恢复', () async {
      await PlaybackSessionStore.saveSnapshot(
        audioPath: 'C:\\music\\great_song.flac',
        playlistIndex: 5,
        position: 128.5,
      );

      final snapshot = await PlaybackSessionStore.readSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.audioPath, equals('C:\\music\\great_song.flac'));
      expect(snapshot.playlistIndex, equals(5));
      expect(snapshot.position, equals(128.5));
      expect(snapshot.updatedAtMs, greaterThan(0));
    });

    test('损坏或空文件安全返回 null，不抛出未捕获异常', () async {
      final file = File('${tempDir.path}\\playback_session.json');
      await file.writeAsString('{corrupted_json_content');

      final snapshot = await PlaybackSessionStore.readSnapshot();
      expect(snapshot, isNull);
    });
  });
}
