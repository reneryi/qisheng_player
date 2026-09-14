import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File realIndexFile;
  String? previousContent;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => '.',
    );
    final supportDir = await getAppDataDir();
    final realIndexPath = "${supportDir.path}\\index.json";
    realIndexFile = File(realIndexPath);
    previousContent = realIndexFile.existsSync() ? realIndexFile.readAsStringSync() : null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (previousContent != null) {
      realIndexFile.writeAsStringSync(previousContent!);
    } else if (realIndexFile.existsSync()) {
      realIndexFile.deleteSync();
    }
  });



  group('R2 Indexing Fault Tolerance & Incremental Updates Empirical Suite', () {
    test('1. Simulated offline directory retains cached audios with pending_retry: true', () async {
      // Create simulated index with an inaccessible offline directory (e.g. detached NAS)
      const offlinePath = r'Z:\DetachedNAS\Music\LosslessAlbum';
      final indexData = {
        "version": 114,
        "roots": [r"Z:\DetachedNAS\Music", r"D:\LocalMusic"],
        "folders": [
          {
            "path": offlinePath,
            "modified": 1726000000,
            "latest": 1726000000,
            "pending_retry": true,
            "audios": [
              {
                "title": "Cached NAS Track 1",
                "artist": "NAS Artist",
                "album": "NAS Album",
                "disc": 1,
                "track": 1,
                "duration": 210,
                "path": r"Z:\DetachedNAS\Music\LosslessAlbum\01.flac",
                "modified": 1726000000,
                "created": 1726000000,
                "size": 15000000,
              },
              {
                "title": "Cached NAS Track 2",
                "artist": "NAS Artist",
                "album": "NAS Album",
                "disc": 1,
                "track": 2,
                "duration": 195,
                "path": r"Z:\DetachedNAS\Music\LosslessAlbum\02.flac",
                "modified": 1726000000,
                "created": 1726000000,
                "size": 14000000,
              }
            ]
          }
        ]
      };

      realIndexFile.writeAsStringSync(json.encode(indexData));

      final loadStatus = await AudioLibrary.initFromIndex();
      expect(loadStatus, equals(AudioLibraryLoadStatus.loaded));

      final lib = AudioLibrary.instance;
      expect(lib.roots, contains(r"Z:\DetachedNAS\Music"));
      expect(lib.folders, hasLength(1));

      final folder = lib.folders.first;
      expect(folder.path, equals(offlinePath));
      // Must retain pending_retry flag
      expect(folder.pendingRetry, isTrue,
          reason: 'Offline folder must be flagged with pendingRetry: true');

      // Crucial: audios MUST NOT be cleared or wiped to []
      expect(folder.audios, hasLength(2),
          reason: 'Offline folder must retain cached audio tracks');
      expect(folder.audios.map((a) => a.title),
          containsAll(['Cached NAS Track 1', 'Cached NAS Track 2']));
      expect(lib.audioCollection, hasLength(2));
    });

    test('2. Truly empty directory has audios cleared while pending_retry is false', () async {
      const realEmptyPath = r'D:\LocalMusic\EmptiedFolder';
      final indexData = {
        "version": 114,
        "roots": [r"D:\LocalMusic"],
        "folders": [
          {
            "path": realEmptyPath,
            "modified": 1726001000,
            "latest": 1726001000,
            "pending_retry": false,
            "audios": [] // Successfully scanned and empty
          }
        ]
      };

      realIndexFile.writeAsStringSync(json.encode(indexData));

      final loadStatus = await AudioLibrary.initFromIndex();
      expect(loadStatus, equals(AudioLibraryLoadStatus.loaded));

      final folder = AudioLibrary.instance.folders.first;
      expect(folder.path, equals(realEmptyPath));
      expect(folder.pendingRetry, isFalse);
      expect(folder.audios, isEmpty);
    });

    test('3. External file mtime update propagates through index version 114 schema', () async {
      const initialMtime = 1726000000;
      const updatedMtime = 1726005000; // 5000 seconds later (e.g. tag edited in Mp3tag)
      const newFileSize = 25123456;

      final indexData = {
        "version": 114,
        "roots": [r"D:\MusicLibrary"],
        "folders": [
          {
            "path": r"D:\MusicLibrary\Artist\Album",
            "modified": 1726000000, // Parent folder timestamp untouched
            "latest": updatedMtime,
            "pending_retry": false,
            "audios": [
              {
                "title": "Edited Title by Mp3tag",
                "artist": "Updated Artist",
                "album": "Updated Album",
                "disc": 1,
                "track": 3,
                "duration": 240,
                "path": r"D:\MusicLibrary\Artist\Album\03.flac",
                "modified": updatedMtime,
                "created": initialMtime,
                "size": newFileSize,
                "by": "Lofty",
              }
            ]
          }
        ]
      };

      realIndexFile.writeAsStringSync(json.encode(indexData));

      final loadStatus = await AudioLibrary.initFromIndex();
      expect(loadStatus, equals(AudioLibraryLoadStatus.loaded));

      final audio = AudioLibrary.instance.audioCollection.first;
      expect(audio.title, equals("Edited Title by Mp3tag"));
      expect(audio.artist, equals("Updated Artist"));
      expect(audio.modified, equals(updatedMtime));
      expect(audio.by, equals("Lofty"));
    });

    test('4. Discovery of new subfolder under configured root is reflected in library model', () async {
      final indexData = {
        "version": 114,
        "roots": [r"E:\LosslessAudio"],
        "folders": [
          {
            "path": r"E:\LosslessAudio\ExistingAlbum",
            "modified": 1726000000,
            "latest": 1726000000,
            "pending_retry": false,
            "audios": [
              {
                "title": "Existing Track",
                "artist": "Artist 1",
                "album": "Existing Album",
                "path": r"E:\LosslessAudio\ExistingAlbum\01.flac",
                "modified": 1726000000,
                "created": 1726000000,
              }
            ]
          },
          // Newly discovered subfolder under E:\LosslessAudio
          {
            "path": r"E:\LosslessAudio\DiscoveredSubdir\NewAlbum",
            "modified": 1726009000,
            "latest": 1726009000,
            "pending_retry": false,
            "audios": [
              {
                "title": "New Track in Subfolder",
                "artist": "New Artist",
                "album": "New Album",
                "path": r"E:\LosslessAudio\DiscoveredSubdir\NewAlbum\01.flac",
                "modified": 1726009000,
                "created": 1726009000,
              }
            ]
          }
        ]
      };

      realIndexFile.writeAsStringSync(json.encode(indexData));

      final loadStatus = await AudioLibrary.initFromIndex();
      expect(loadStatus, equals(AudioLibraryLoadStatus.loaded));

      expect(AudioLibrary.instance.folders, hasLength(2));
      final discoveredFolder = AudioLibrary.instance.folders.firstWhere(
        (f) => f.path == r"E:\LosslessAudio\DiscoveredSubdir\NewAlbum",
      );
      expect(discoveredFolder.pendingRetry, isFalse);
      expect(discoveredFolder.audios.first.title, equals("New Track in Subfolder"));
      expect(AudioLibrary.instance.audioCollection, hasLength(2));
    });
  });
}
