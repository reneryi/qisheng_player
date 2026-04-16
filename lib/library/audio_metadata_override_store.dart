import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/utils.dart';

class AudioMetadataOverrideStore {
  AudioMetadataOverrideStore._();
  static final AudioMetadataOverrideStore instance = AudioMetadataOverrideStore._();

  final Map<String, Map<String, String>> _overrides = {};
  bool _loaded = false;

  Future<void> read() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final supportPath = (await getAppDataDir()).path;
      final file = File("$supportPath\\audio_override.json");
      if (!file.existsSync()) return;

      final map = json.decode(await file.readAsString()) as Map<String, dynamic>;
      _overrides.clear();
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final title = value["title"]?.toString();
        final artist = value["artist"]?.toString();
        final album = value["album"]?.toString();
        _overrides[entry.key] = {
          if (title != null) "title": title,
          if (artist != null) "artist": artist,
          if (album != null) "album": album,
        };
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> save() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final file = await File("$supportPath\\audio_override.json")
          .create(recursive: true);
      await file.writeAsString(json.encode(_overrides));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  void applyToAudio(Audio audio) {
    final override = _overrides[audio.path];
    if (override == null) return;
    if (override["title"] != null && override["title"]!.trim().isNotEmpty) {
      audio.title = override["title"]!.trim();
    }
    if (override["artist"] != null && override["artist"]!.trim().isNotEmpty) {
      audio.artist = override["artist"]!.trim();
    }
    if (override["album"] != null && override["album"]!.trim().isNotEmpty) {
      audio.album = override["album"]!.trim();
    }
    audio.splitedArtists =
        audio.artist.split(RegExp(AppSettings.instance.artistSplitPattern));
  }

  void applyToLibrary(AudioLibrary library) {
    for (final audio in library.audioCollection) {
      applyToAudio(audio);
    }
  }

  Future<void> setOverride({
    required Audio audio,
    required String title,
    required String artist,
    required String album,
  }) async {
    _overrides[audio.path] = {
      "title": title.trim(),
      "artist": artist.trim(),
      "album": album.trim(),
    };
    applyToAudio(audio);
    await save();
  }
}
