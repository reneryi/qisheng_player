// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/utils.dart';

List<Playlist> PLAYLISTS = [];
Timer? _playlistSaveDebounce;
bool _playlistsLoaded = false;

bool get isPlaylistsLoaded => _playlistsLoaded;

@visibleForTesting
void resetPlaylistsLoadedForTesting({bool loaded = false}) {
  _playlistsLoaded = loaded;
  _playlistSaveDebounce?.cancel();
  _playlistSaveDebounce = null;
}

void scheduleSavePlaylists(
    {Duration delay = const Duration(milliseconds: 200)}) {
  _playlistSaveDebounce?.cancel();
  _playlistSaveDebounce = Timer(delay, () {
    unawaited(savePlaylists());
  });
}

Future<void> flushPlaylistsSave() async {
  if (_playlistSaveDebounce != null) {
    _playlistSaveDebounce?.cancel();
    _playlistSaveDebounce = null;
    await savePlaylists();
  }
}

void removeAudioFromAllPlaylistsByPath(String path) {
  bool changed = false;
  for (final playlist in PLAYLISTS) {
    changed = playlist.audios.remove(path) != null || changed;
  }
  if (changed) {
    scheduleSavePlaylists();
  }
}

Future<void> readPlaylists() async {
  await flushPlaylistsSave();
  try {
    final supportPath = (await getAppDataDir()).path;
    final playlistsPath = "$supportPath\\playlists.json";

    if (!File(playlistsPath).existsSync()) {
      PLAYLISTS.clear();
      _playlistsLoaded = true;
      return;
    }

    final libraryAudios = <String, Audio>{
      for (final audio in AudioLibrary.instance.audioCollection)
        audio.path: audio,
    };

    final playlistsStr = File(playlistsPath).readAsStringSync();
    if (playlistsStr.trim().isEmpty) {
      PLAYLISTS.clear();
      _playlistsLoaded = true;
      return;
    }
    final List playlistsJson = json.decode(playlistsStr);

    final newPlaylists = <Playlist>[];
    for (Map item in playlistsJson) {
      newPlaylists.add(Playlist.fromMap(item, libraryAudios: libraryAudios));
    }
    PLAYLISTS.clear();
    PLAYLISTS.addAll(newPlaylists);
    _playlistsLoaded = true;
  } catch (err, trace) {
    _playlistsLoaded = false;
    LOGGER.e(err, stackTrace: trace);
  }
}

void reconcilePlaylistsWithLibrary([Iterable<Audio>? libraryAudios]) {
  final audios = libraryAudios ?? AudioLibrary.instance.audioCollection;
  final canonicalByPath = <String, Audio>{
    for (final audio in audios) audio.path: audio,
  };

  for (final playlist in PLAYLISTS) {
    playlist.reconcileAudios(canonicalByPath);
  }
}

Future<void> syncPlaylistsWithLibrary() async {
  await flushPlaylistsSave();
  if (!_playlistsLoaded) {
    await readPlaylists();
  } else {
    reconcilePlaylistsWithLibrary();
  }
}

Future<void> savePlaylists() async {
  _playlistSaveDebounce?.cancel();
  _playlistSaveDebounce = null;
  if (!_playlistsLoaded) {
    if (PLAYLISTS.isEmpty) {
      LOGGER.w("savePlaylists: 歌单尚未就绪或加载异常，跳过空数据落盘以防覆写磁盘文件");
      return;
    }
    _playlistsLoaded = true;
  }
  try {
    final supportPath = (await getAppDataDir()).path;
    final playlistsPath = "$supportPath\\playlists.json";

    List<Map> playlistMaps = [];
    for (final item in PLAYLISTS) {
      playlistMaps.add(item.toMap());
    }

    final playlistsJson = json.encode(playlistMaps);
    await atomicWriteString(playlistsPath, playlistsJson);
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }
}

class Playlist {
  String name;

  /// path, audio
  Map<String, Audio> audios;

  Playlist(this.name, this.audios);

  bool containsAudio(Audio audio) => audios.containsKey(audio.path);

  void reconcileAudios(Map<String, Audio> canonicalByPath) {
    for (final entry in audios.entries.toList()) {
      final canonical = canonicalByPath[entry.key];
      if (canonical != null) {
        audios[entry.key] = canonical;
      }
    }
  }

  bool addAudio(Audio audio) {
    if (audios.containsKey(audio.path)) return false;
    audios[audio.path] = audio;
    scheduleSavePlaylists();
    return true;
  }

  bool removeAudioByPath(String path) {
    final removed = audios.remove(path) != null;
    if (removed) {
      scheduleSavePlaylists();
    }
    return removed;
  }

  void applyCustomOrder(List<Audio> orderedAudios) {
    final rebuilt = <String, Audio>{};
    for (final item in orderedAudios) {
      rebuilt[item.path] = item;
    }
    for (final entry in audios.entries) {
      if (!rebuilt.containsKey(entry.key)) {
        rebuilt[entry.key] = entry.value;
      }
    }
    audios = rebuilt;
    scheduleSavePlaylists();
  }

  Map toMap() {
    final List<Map> audioMaps = [];
    for (var item in audios.values) {
      audioMaps.add(item.toMap());
    }
    return {"name": name, "audios": audioMaps};
  }

  factory Playlist.fromMap(
    Map map, {
    Map<String, Audio>? libraryAudios,
  }) {
    final Map<String, Audio> audios = {};
    final List audioMaps = map["audios"] ?? [];
    for (var item in audioMaps) {
      final path = item["path"]?.toString();
      if (path == null || path.isEmpty) continue;
      final audio = libraryAudios?[path] ?? Audio.fromMap(item);
      audios[audio.path] = audio;
    }
    return Playlist(map["name"], audios);
  }
}
