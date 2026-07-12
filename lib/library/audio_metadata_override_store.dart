import 'dart:convert';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/utils.dart';

class AudioMetadataOverrideStore {
  AudioMetadataOverrideStore._();
  static final AudioMetadataOverrideStore instance =
      AudioMetadataOverrideStore._();

  final Map<String, Map<String, String>> _overrides = {};
  bool _loaded = false;

  Future<void> read() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final supportPath = (await getAppDataDir()).path;
      final file = File("$supportPath\\audio_override.json");
      if (!file.existsSync()) return;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;
      final map = json.decode(raw) as Map<String, dynamic>;
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
      await atomicWriteString(
        "$supportPath\\audio_override.json",
        json.encode(_overrides),
      );
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  void applyToAudio(Audio audio) {
    final override = _overrides[audio.path];
    if (override == null) return;
    audio.updateMetadata(
      title: override["title"]?.trim().isNotEmpty == true
          ? override["title"]!.trim()
          : null,
      artist: override["artist"]?.trim().isNotEmpty == true
          ? override["artist"]!.trim()
          : null,
      album: override["album"]?.trim().isNotEmpty == true
          ? override["album"]!.trim()
          : null,
    );
  }

  void applyToLibrary(AudioLibrary library) {
    for (final folder in library.folders) {
      for (final audio in folder.audios) {
        applyToAudio(audio);
      }
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
