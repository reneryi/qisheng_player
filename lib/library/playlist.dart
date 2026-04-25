// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/utils.dart';

List<Playlist> PLAYLISTS = [];
Timer? _playlistSaveDebounce;

void scheduleSavePlaylists(
    {Duration delay = const Duration(milliseconds: 200)}) {
  _playlistSaveDebounce?.cancel();
  _playlistSaveDebounce = Timer(delay, () {
    unawaited(savePlaylists());
  });
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
  try {
    final supportPath = (await getAppDataDir()).path;
    final playlistsPath = "$supportPath\\playlists.json";

    PLAYLISTS.clear();
    if (!File(playlistsPath).existsSync()) return;

    final libraryAudios = <String, Audio>{
      for (final audio in AudioLibrary.instance.audioCollection)
        audio.path: audio,
    };

    final playlistsStr = File(playlistsPath).readAsStringSync();
    if (playlistsStr.trim().isEmpty) return;
    final List playlistsJson = json.decode(playlistsStr);

    for (Map item in playlistsJson) {
      PLAYLISTS.add(Playlist.fromMap(item, libraryAudios: libraryAudios));
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }
}

Future<void> savePlaylists() async {
  try {
    final supportPath = (await getAppDataDir()).path;
    final playlistsPath = "$supportPath\\playlists.json";

    List<Map> playlistMaps = [];
    for (final item in PLAYLISTS) {
      playlistMaps.add(item.toMap());
    }

    final playlistsJson = json.encode(playlistMaps);
    final output = await File(playlistsPath).create(recursive: true);
    await output.writeAsString(playlistsJson);
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
