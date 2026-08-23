import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const Duration onlineCoverFailureTtl = Duration(days: 7);
const Duration onlineCoverRequestTimeout = Duration(seconds: 15);
const int onlineCoverMaxBytes = 12 * 1024 * 1024;

@visibleForTesting
String onlineCoverCacheKey(String path) {
  final normalized = path.replaceAll('/', r'\').toLowerCase();
  return sha256.convert(utf8.encode(normalized)).toString();
}

@visibleForTesting
bool isSupportedOnlineCoverContentType(ContentType? contentType) =>
    contentType?.primaryType.toLowerCase() == 'image';

@visibleForTesting
Future<Uint8List> readBoundedCoverBytes(
  Stream<List<int>> response, {
  int maxBytes = onlineCoverMaxBytes,
  Duration timeout = onlineCoverRequestTimeout,
}) {
  return _collectBoundedCoverBytes(response, maxBytes: maxBytes)
      .timeout(timeout);
}

Future<Uint8List> _collectBoundedCoverBytes(
  Stream<List<int>> response, {
  required int maxBytes,
}) async {
  final builder = BytesBuilder(copy: false);
  var totalBytes = 0;
  await for (final chunk in response) {
    totalBytes += chunk.length;
    if (totalBytes > maxBytes) {
      throw const FormatException("在线封面超过大小限制");
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Map<String, int> retainRecentCoverFailures(
  Map<String, int> failures,
  int nowMilliseconds, {
  Duration ttl = onlineCoverFailureTtl,
}) {
  final ttlMilliseconds = ttl.inMilliseconds;
  return Map<String, int>.from(failures)
    ..removeWhere((_, timestamp) {
      final age = nowMilliseconds - timestamp;
      return age > ttlMilliseconds;
    });
}

class OnlineCoverStore {
  OnlineCoverStore._()
      : _search = uniSearch,
        _nowMilliseconds = (() => DateTime.now().millisecondsSinceEpoch),
        _persistFailuresForTesting = null;
  static final OnlineCoverStore instance = OnlineCoverStore._();

  @visibleForTesting
  OnlineCoverStore.forTesting({
    required Future<List<SongSearchResult>> Function(Audio) search,
    Map<String, int> failedPaths = const {},
    int Function()? nowMilliseconds,
    Future<void> Function(Map<String, int>)? persistFailures,
  })  : _search = search,
        _nowMilliseconds =
            nowMilliseconds ?? (() => DateTime.now().millisecondsSinceEpoch),
        _persistFailuresForTesting = persistFailures,
        _loaded = true {
    _failedAudioPaths.addAll(failedPaths);
  }

  final Map<String, String> _cachedPathMap = {};
  final Map<String, int> _failedAudioPaths = {};
  final Map<String, Future<ImageProvider?>> _inflightSearches = {};
  final Future<List<SongSearchResult>> Function(Audio) _search;
  final int Function() _nowMilliseconds;
  final Future<void> Function(Map<String, int>)? _persistFailuresForTesting;
  bool _loaded = false;

  Future<void> read() async {
    if (_loaded) return;
    _loaded = true;

    final supportPath = (await getAppDataDir()).path;
    try {
      final cachePath = "$supportPath\\cover_cache.json";
      final cacheFile = File(cachePath);
      if (cacheFile.existsSync()) {
        final raw = await cacheFile.readAsString();
        if (raw.trim().isNotEmpty) {
          final map = json.decode(raw) as Map<String, dynamic>;
          _cachedPathMap.clear();
          for (final entry in map.entries) {
            final value = entry.value?.toString();
            if (value == null || value.isEmpty) continue;
            _cachedPathMap[entry.key] = value;
          }
        }
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }

    try {
      final failedFile = File("$supportPath\\cover_cache_failed.json");
      if (!failedFile.existsSync()) return;
      final raw = await failedFile.readAsString();
      if (raw.trim().isEmpty) return;
      final map = json.decode(raw) as Map<String, dynamic>;
      final loaded = <String, int>{
        for (final entry in map.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
      final recent = retainRecentCoverFailures(loaded, _nowMilliseconds());
      _failedAudioPaths
        ..clear()
        ..addAll(recent);
      if (recent.length != loaded.length) await _saveFailures();
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> save() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final cachePath = "$supportPath\\cover_cache.json";
      await atomicWriteString(cachePath, json.encode(_cachedPathMap));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> _saveFailures() async {
    final snapshot = Map<String, int>.unmodifiable(_failedAudioPaths);
    final persistForTesting = _persistFailuresForTesting;
    if (persistForTesting != null) {
      await persistForTesting(snapshot);
      return;
    }
    try {
      final supportPath = (await getAppDataDir()).path;
      await atomicWriteString(
        "$supportPath\\cover_cache_failed.json",
        json.encode(snapshot),
      );
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  bool _hasRecentFailure(String path) {
    final timestamp = _failedAudioPaths[path];
    if (timestamp == null) return false;
    final age = _nowMilliseconds() - timestamp;
    if (age <= onlineCoverFailureTtl.inMilliseconds) return true;
    _failedAudioPaths.remove(path);
    return false;
  }

  Future<void> _markFailed(String path) async {
    _failedAudioPaths[path] = _nowMilliseconds();
    await _saveFailures();
  }

  Future<Directory> _coverCacheDir() async {
    final supportPath = (await getAppDataDir()).path;
    return Directory("$supportPath\\cover_cache").create(recursive: true);
  }

  String _cacheNameForPath(String path) {
    return onlineCoverCacheKey(path);
  }

  Future<ImageProvider?> getCover(Audio audio) async {
    await read();
    final cached = _cachedPathMap[audio.path];
    if (cached != null && File(cached).existsSync()) {
      return FileImage(File(cached));
    }
    if (_hasRecentFailure(audio.path)) {
      return null;
    }

    final inflight = _inflightSearches[audio.path];
    if (inflight != null) return inflight;

    final future = _searchAndCacheCover(audio);
    _inflightSearches[audio.path] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightSearches[audio.path], future)) {
        _inflightSearches.remove(audio.path);
      }
    }
  }

  Future<ImageProvider?> _searchAndCacheCover(Audio audio) async {
    final searchResults = await _search(audio);
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
      await _markFailed(audio.path);
      return null;
    }
    final cover = await setCoverFromUrl(audio: audio, url: hit.coverUrl!);
    if (cover == null) await _markFailed(audio.path);
    return cover;
  }

  Future<ImageProvider?> setCoverFromUrl({
    required Audio audio,
    required String url,
  }) async {
    HttpClient? client;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != "http" && uri.scheme != "https")) {
        return null;
      }

      client = HttpClient()
        ..connectionTimeout = onlineCoverRequestTimeout
        ..idleTimeout = onlineCoverRequestTimeout;
      final req = await client.getUrl(uri).timeout(onlineCoverRequestTimeout);
      req.headers.set(
        HttpHeaders.userAgentHeader,
        "QishengPlayer/${AppSettings.version}",
      );
      final resp = await req.close().timeout(onlineCoverRequestTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final contentType = resp.headers.contentType;
      if (!isSupportedOnlineCoverContentType(contentType)) return null;
      if (resp.contentLength > onlineCoverMaxBytes) return null;

      final bytes = await readBoundedCoverBytes(resp);
      if (bytes.isEmpty) return null;

      final dir = await _coverCacheDir();
      final cachePath = "${dir.path}\\${_cacheNameForPath(audio.path)}.jpg";
      await File(cachePath).writeAsBytes(bytes, flush: true);
      _cachedPathMap[audio.path] = cachePath;
      if (_failedAudioPaths.remove(audio.path) != null) {
        await _saveFailures();
      }
      await save();
      return FileImage(File(cachePath));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
      return null;
    } finally {
      client?.close(force: true);
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
    if (_failedAudioPaths.remove(path) != null) {
      unawaited(_saveFailures());
    }
  }
}
