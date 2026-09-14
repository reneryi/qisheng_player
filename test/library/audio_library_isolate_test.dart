import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String indexPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('audio_lib_isolate_test');
    indexPath = '${tempDir.path}\\index.json';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('parseIndexInIsolate parses version 114 index with roots and pendingRetry', () async {
    final indexJson = {
      "version": 114,
      "roots": [
        r"D:\Music\Lossless",
        r"E:\HiRes",
      ],
      "folders": [
        {
          "path": r"D:\Music\Lossless\AlbumA",
          "modified": 1726000000,
          "latest": 1726001000,
          "pending_retry": false,
          "audios": [
            {
              "title": "Track One",
              "artist": "Artist A、Artist B",
              "album": "Album A",
              "composer": "Composer 1",
              "arranger": "Arranger 1",
              "disc": 1,
              "track": 1,
              "duration": 240,
              "bitrate": 960,
              "sample_rate": 44100,
              "replay_gain_db": -2.5,
              "path": r"D:\Music\Lossless\AlbumA\01.flac",
              "modified": 1726000500,
              "created": 1726000000,
              "by": "Lofty",
            },
          ],
        },
        {
          "path": r"Z:\NAS\OfflineAlbum",
          "modified": 1725000000,
          "latest": 1725000000,
          "pending_retry": true,
          "audios": [
            {
              "title": "Offline Song",
              "artist": "NAS Artist / Guest",
              "album": "NAS Album",
              "disc": 1,
              "track": 1,
              "duration": 180,
              "path": r"Z:\NAS\OfflineAlbum\song.flac",
              "modified": 1725000000,
              "created": 1725000000,
              "by": "Lofty",
            }
          ],
        },
      ],
    };

    File(indexPath).writeAsStringSync(json.encode(indexJson));

    final payload = IndexParsePayload(indexPath, r'[、/]');
    final result = await compute(parseIndexInIsolate, payload);

    expect(result.isEmpty, isFalse);
    expect(result.version, equals(114));
    expect(result.roots, equals([r"D:\Music\Lossless", r"E:\HiRes"]));
    expect(result.folders, hasLength(2));

    final normalFolder = result.folders[0];
    expect(normalFolder.path, equals(r"D:\Music\Lossless\AlbumA"));
    expect(normalFolder.pendingRetry, isFalse);
    expect(normalFolder.audios, hasLength(1));
    expect(normalFolder.audios[0].title, equals("Track One"));
    expect(normalFolder.audios[0].splitedArtists, equals(["Artist A", "Artist B"]));

    final offlineFolder = result.folders[1];
    expect(offlineFolder.path, equals(r"Z:\NAS\OfflineAlbum"));
    expect(offlineFolder.pendingRetry, isTrue);
    expect(offlineFolder.audios, hasLength(1));
    expect(offlineFolder.audios[0].title, equals("Offline Song"));
    expect(offlineFolder.audios[0].splitedArtists, equals(["NAS Artist", "Guest"]));
  });

  test('parseIndexInIsolate custom artistSplitPattern works across isolates', () async {
    final indexJson = {
      "version": 114,
      "roots": [r"C:\Music"],
      "folders": [
        {
          "path": r"C:\Music\Album",
          "modified": 1726000000,
          "latest": 1726000000,
          "audios": [
            {
              "title": "Collab Track",
              "artist": "Alice feat. Bob & Charlie",
              "album": "Album",
              "path": r"C:\Music\Album\01.flac",
              "modified": 1726000000,
              "created": 1726000000,
            },
          ],
        },
      ],
    };

    File(indexPath).writeAsStringSync(json.encode(indexJson));

    // 使用自定义分隔符正则匹配 " feat. " 与 " & "
    const customPattern = r'(?:\s+feat\.\s+|\s+&\s+)';
    final payload = IndexParsePayload(indexPath, customPattern);
    final result = await compute(parseIndexInIsolate, payload);

    expect(result.folders[0].audios[0].splitedArtists, equals(["Alice", "Bob", "Charlie"]));
  });

  test('parseIndexInIsolate returns isEmpty on non-existent or empty file', () async {
    final nonExistent = IndexParsePayload('${tempDir.path}\\non_existent.json', r'[、/]');
    final missingResult = await compute(parseIndexInIsolate, nonExistent);
    expect(missingResult.isEmpty, isTrue);
    expect(missingResult.folders, isEmpty);

    final emptyFile = File('${tempDir.path}\\empty.json')..writeAsStringSync("   ");
    final emptyPayload = IndexParsePayload(emptyFile.path, r'[、/]');
    final emptyResult = await compute(parseIndexInIsolate, emptyPayload);
    expect(emptyResult.isEmpty, isTrue);
  });

  test('AudioLibrary.initFromIndex populates roots and folders via isolate compute', () async {
    final supportDir = await getAppDataDir();
    final realIndexPath = "${supportDir.path}\\index.json";
    final realIndexFile = File(realIndexPath);
    final previousContent = realIndexFile.existsSync() ? realIndexFile.readAsStringSync() : null;

    addTearDown(() {
      if (previousContent != null) {
        realIndexFile.writeAsStringSync(previousContent);
      } else if (realIndexFile.existsSync()) {
        realIndexFile.deleteSync();
      }
    });

    final testIndex = {
      "version": 114,
      "roots": [r"D:\MyAudioRoot"],
      "folders": [
        {
          "path": r"D:\MyAudioRoot\SubFolder",
          "modified": 1726100000,
          "latest": 1726100000,
          "pending_retry": true,
          "audios": [
            {
              "title": "Isolate Track",
              "artist": "Singer",
              "album": "Record",
              "path": r"D:\MyAudioRoot\SubFolder\track.mp3",
              "modified": 1726100000,
              "created": 1726100000,
            }
          ],
        }
      ],
    };

    realIndexFile.writeAsStringSync(json.encode(testIndex));

    final status = await AudioLibrary.initFromIndex();
    expect(status, equals(AudioLibraryLoadStatus.loaded));
    expect(AudioLibrary.instance.roots, equals([r"D:\MyAudioRoot"]));
    expect(AudioLibrary.instance.folders, hasLength(1));
    expect(AudioLibrary.instance.folders.first.pendingRetry, isTrue);
    expect(AudioLibrary.instance.audioCollection, hasLength(1));
    expect(AudioLibrary.instance.audioCollection.first.title, equals("Isolate Track"));
  });
}
