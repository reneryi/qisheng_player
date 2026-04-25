import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/music_matcher.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class OnlineCoverStore {
  OnlineCoverStore._();
  static final OnlineCoverStore instance = OnlineCoverStore._();

  final Map<String, String> _cachedPathMap = {};
  final Set<String> _failedAudioPaths = {};
  bool _loaded = false;

  Future<void> read() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final supportPath = (await getAppDataDir()).path;
      final cachePath = "$supportPath\\cover_cache.json";
      final cacheFile = File(cachePath);
      if (!cacheFile.existsSync()) return;

      final raw = await cacheFile.readAsString();
      if (raw.trim().isEmpty) return;
      final map = json.decode(raw) as Map<String, dynamic>;
      _cachedPathMap.clear();
      for (final entry in map.entries) {
        final value = entry.value?.toString();
        if (value == null || value.isEmpty) continue;
        _cachedPathMap[entry.key] = value;
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> save() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final cachePath = "$supportPath\\cover_cache.json";
      final output = await File(cachePath).create(recursive: true);
      await output.writeAsString(json.encode(_cachedPathMap));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<Directory> _coverCacheDir() async {
    final supportPath = (await getAppDataDir()).path;
    return Directory("$supportPath\\cover_cache").create(recursive: true);
  }

  String _cacheNameForPath(String path) {
    final bytes = utf8.encode(path);
    final builder = StringBuffer();
    for (final item in bytes) {
      builder.write(item.toRadixString(16).padLeft(2, '0'));
    }
    return builder.toString();
  }

  Future<ImageProvider?> getCover(Audio audio) async {
    await read();
    final cached = _cachedPathMap[audio.path];
    if (cached != null && File(cached).existsSync()) {
      return FileImage(File(cached));
    }
    if (_failedAudioPaths.contains(audio.path)) {
      return null;
    }

    final searchResults = await uniSearch(audio);
    final hit = searchResults.firstWhere(
      (item) => item.coverUrl != null && item.coverUrl!.isNotEmpty,
      orElse: () => SongSearchResult(
        ResultSource.qq,
        "",
        "",
        "",
        0,
      ),
    );
    if (hit.coverUrl == null || hit.coverUrl!.isEmpty) {
      _failedAudioPaths.add(audio.path);
      return null;
    }
    return setCoverFromUrl(audio: audio, url: hit.coverUrl!);
  }

  Future<ImageProvider?> setCoverFromUrl({
    required Audio audio,
    required String url,
  }) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final client = HttpClient();
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, "CorianderPlayer/1.5");
      final resp = await req.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;

      final bytes = await consolidateHttpClientResponseBytes(resp);
      if (bytes.isEmpty) return null;

      final dir = await _coverCacheDir();
      final cachePath = "${dir.path}\\${_cacheNameForPath(audio.path)}.jpg";
      await File(cachePath).writeAsBytes(bytes, flush: true);
      _cachedPathMap[audio.path] = cachePath;
      _failedAudioPaths.remove(audio.path);
      await save();
      return FileImage(File(cachePath));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
      return null;
    }
  }

  void removeByPath(String path) {
    final removed = _cachedPathMap.remove(path);
    if (removed != null) {
      final file = File(removed);
      if (file.existsSync()) {
        file.deleteSync();
      }
      save();
    }
    _failedAudioPaths.remove(path);
  }
}
