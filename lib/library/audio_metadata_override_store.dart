import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/utils.dart';

class AudioMetadataOverrideStore {
  AudioMetadataOverrideStore._();
  static final AudioMetadataOverrideStore instance =
      AudioMetadataOverrideStore._();

  final Map<String, Map<String, String>> _overrides = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  bool hasOverride(String path) => _overrides.containsKey(path);

  /// Rust already removed the durable override after committing the file.
  void forgetCommitted(String path) => _overrides.remove(path);

  @visibleForTesting
  void resetLoadedForTesting({bool loaded = false}) {
    _loaded = loaded;
  }

  Future<void> read() async {
    if (_loaded) return;

    try {
      final supportPath = (await getAppDataDir()).path;
      final file = File("$supportPath\\audio_override.json");
      if (!file.existsSync()) {
        _loaded = true;
        return;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _loaded = true;
        return;
      }
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
          for (final key in ['album_artist', 'track', 'disc'])
            if (value[key] != null) key: value[key].toString(),
        };
      }
      _loaded = true;
    } catch (err, trace) {
      _loaded = false;
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> save() async {
    if (!_loaded) {
      LOGGER.w(
          "AudioMetadataOverrideStore.save: blocked save because store is not loaded yet");
      return;
    }
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
    if (override.containsKey('album_artist')) {
      audio.albumArtist = override['album_artist']!;
    }
    audio.track = int.tryParse(override['track'] ?? '') ?? audio.track;
    audio.disc = int.tryParse(override['disc'] ?? '') ?? audio.disc;
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
    String? albumArtist,
    int? track,
    int? disc,
  }) async {
    await read();
    if (!_loaded) throw StateError('无法读取已有覆盖信息');
    final previous = _overrides[audio.path];
    _overrides[audio.path] = {
      "title": title.trim(),
      "artist": artist.trim(),
      "album": album.trim(),
      if (albumArtist != null) 'album_artist': albumArtist,
      if (track != null) 'track': track.toString(),
      if (disc != null) 'disc': disc.toString(),
    };
    try {
      final supportPath = (await getAppDataDir()).path;
      await atomicWriteString(
          '$supportPath\\audio_override.json', jsonEncode(_overrides));
      applyToAudio(audio);
    } catch (_) {
      if (previous == null) {
        _overrides.remove(audio.path);
      } else {
        _overrides[audio.path] = previous;
      }
      rethrow;
    }
  }
}
