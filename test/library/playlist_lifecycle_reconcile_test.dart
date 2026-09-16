import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/playlist.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_playlist_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    PLAYLISTS.clear();
    resetPlaylistsLoadedForTesting(loaded: false);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    PLAYLISTS.clear();
    resetPlaylistsLoadedForTesting(loaded: false);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('R1.1: 首次同步加载磁盘配置并置位 _playlistsLoaded 守卫', () async {
    final appDir = await getAppDataDir();
    final playlistsFile = File(p.join(appDir.path, 'playlists.json'));
    await playlistsFile.parent.create(recursive: true);

    final initialJson = json.encode([
      {
        'name': 'My Favorite',
        'audios': [
          {
            'path': r'E:\Music\song1.flac',
            'title': 'Disk Song 1',
            'artist': 'Artist 1',
            'album': 'Album 1',
            'duration': 180,
            'modified': 1000,
            'created': 1000,
          }
        ]
      }
    ]);
    await playlistsFile.writeAsString(initialJson);

    expect(isPlaylistsLoaded, isFalse);

    await syncPlaylistsWithLibrary();

    expect(isPlaylistsLoaded, isTrue);
    expect(PLAYLISTS.length, 1);
    expect(PLAYLISTS.first.name, 'My Favorite');
    expect(PLAYLISTS.first.audios.length, 1);
  });

  test('R1.2: 内存引用重绑定保持 Playlist 对象实例不变并原地更新音频引用', () async {
    final staleAudio = TestAudio(
      path: r'E:\Music\song1.flac',
      title: 'Stale Title',
      artist: 'Stale Artist',
      album: 'Stale Album',
    );
    final playlist = Playlist('Rock Classics', {staleAudio.path: staleAudio});
    PLAYLISTS.add(playlist);
    resetPlaylistsLoadedForTesting(loaded: true);

    // 记录原始 Playlist 引用
    final originalPlaylistInstance = PLAYLISTS.first;

    final canonicalAudio = TestAudio(
      path: r'E:\Music\song1.flac',
      title: 'Updated Canonical Title',
      artist: 'Canonical Artist',
      album: 'Canonical Album',
    );

    // 触发重绑定
    reconcilePlaylistsWithLibrary([canonicalAudio]);

    // 验证 Playlist 实例对象严格保持同一内存指针，没有被清空替换
    expect(identical(PLAYLISTS.first, originalPlaylistInstance), isTrue);
    expect(PLAYLISTS.first.audios[staleAudio.path], same(canonicalAudio));
    expect(PLAYLISTS.first.audios[staleAudio.path]?.title, 'Updated Canonical Title');
  });

  test('R1.3: 防抖保存周期内触发重读或同步，强制 flush 挂起任务确保数据无丢失', () async {
    final appDir = await getAppDataDir();
    final playlistsFile = File(p.join(appDir.path, 'playlists.json'));
    await playlistsFile.parent.create(recursive: true);

    final playlist = Playlist('User Created', {});
    PLAYLISTS.add(playlist);
    resetPlaylistsLoadedForTesting(loaded: true);

    final newSong = TestAudio(
      path: r'E:\Music\new_added.mp3',
      title: 'New Track',
      artist: 'Artist',
      album: 'Album',
    );

    // 用户在 UI 中添加歌曲，触发防抖保存（200ms）
    playlist.addAudio(newSong);

    // 验证此时磁盘尚未写入（仍在防抖窗口中）
    expect(playlistsFile.existsSync(), isFalse);

    // 模拟音乐库扫描完成或外部触发 syncPlaylistsWithLibrary
    await syncPlaylistsWithLibrary();

    // 验证此时防抖写盘已被强制 flush 到磁盘，数据完整存在
    expect(playlistsFile.existsSync(), isTrue);
    final diskContent = json.decode(playlistsFile.readAsStringSync()) as List;
    expect(diskContent.length, 1);
    expect(diskContent.first['name'], 'User Created');
    final audios = diskContent.first['audios'] as List;
    expect(audios.length, 1);
    expect(audios.first['path'], newSong.path);
  });

  test('R1.4: 显式调用 readPlaylists 前也会自动 flush 现存防抖写盘任务', () async {
    final appDir = await getAppDataDir();
    final playlistsFile = File(p.join(appDir.path, 'playlists.json'));
    await playlistsFile.parent.create(recursive: true);

    final playlist = Playlist('Manual Read Flush', {});
    PLAYLISTS.add(playlist);
    resetPlaylistsLoadedForTesting(loaded: true);

    final song = TestAudio(
      path: r'E:\Music\flush_before_read.flac',
      title: 'Flushed Track',
      artist: 'Flushed Artist',
      album: 'Flushed Album',
    );

    playlist.addAudio(song);
    expect(playlistsFile.existsSync(), isFalse);

    // 显式调用 readPlaylists()，必须先 flush 现存挂起任务再重读
    await readPlaylists();

    expect(playlistsFile.existsSync(), isTrue);
    expect(PLAYLISTS.first.audios.containsKey(song.path), isTrue);
  });
}
