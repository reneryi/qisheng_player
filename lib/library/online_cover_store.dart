import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/metadata_provider.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const Duration onlineCoverFailureTtl = Duration(days: 7);
const Duration onlineCoverRequestTimeout = Duration(seconds: 15);
const int onlineCoverMaxBytes = 32 * 1024 * 1024;

@visibleForTesting
String onlineCoverCacheKey(String path) {
  final normalized = path.replaceAll('/', r'\').toLowerCase();
  return sha256.convert(utf8.encode(normalized)).toString();
}

@visibleForTesting
bool isSupportedOnlineCoverContentType(ContentType? contentType) {
  if (contentType == null) return false;
  final mime = contentType.mimeType.toLowerCase();
  return mime == 'image/jpeg' || mime == 'image/jpg' || mime == 'image/png';
}

@visibleForTesting
bool isJpegBytes(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

@visibleForTesting
bool isPngBytes(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

String? detectCoverExtension(Uint8List bytes) {
  if (isJpegBytes(bytes)) return '.jpg';
  if (isPngBytes(bytes)) return '.png';
  return null;
}

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
  final Map<String, Future<File?>> _inflightFileSearches = {};
  final Future<List<SongSearchResult>> Function(Audio) _search;
  final int Function() _nowMilliseconds;
  final Future<void> Function(Map<String, int>)? _persistFailuresForTesting;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  @visibleForTesting
  void resetLoadedForTesting({bool loaded = false}) {
    _loaded = loaded;
  }

  Future<void> read() async {
    if (_loaded) return;

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

      final failedFile = File("$supportPath\\cover_cache_failed.json");
      if (failedFile.existsSync()) {
        final raw = await failedFile.readAsString();
        if (raw.trim().isNotEmpty) {
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
        }
      }
      _loaded = true;
    } catch (err, trace) {
      _loaded = false;
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> save() async {
    if (!_loaded) {
      LOGGER.w("OnlineCoverStore.save: blocked save because store is not loaded yet");
      return;
    }
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

  @visibleForTesting
  bool hasRecentFailureForTesting(String path) => _hasRecentFailure(path);

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

  Future<File?> getCoverFile(Audio audio) async {
    await read();
    final lookupPath = audio.mediaPath;
    final cached = _cachedPathMap[lookupPath] ?? _cachedPathMap[audio.path];
    if (cached != null) {
      final file = File(cached);
      if (file.existsSync()) {
        return file;
      }
    }
    if (_hasRecentFailure(audio.path)) {
      return null;
    }

    final inflight = _inflightFileSearches[lookupPath];
    if (inflight != null) return inflight;

    final future = _searchAndCacheCoverFile(audio, lookupPath);
    _inflightFileSearches[lookupPath] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightFileSearches[lookupPath], future)) {
        _inflightFileSearches.remove(lookupPath);
      }
    }
  }

  Future<ImageProvider?> getCover(Audio audio) async {
    final file = await getCoverFile(audio);
    return file != null ? FileImage(file) : null;
  }

  Future<File?> _searchAndCacheCoverFile(
    Audio audio,
    String lookupPath,
  ) async {
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
    final file = await setCoverFileFromUrl(
      audio: audio,
      url: hit.coverUrl!,
      targetPath: lookupPath,
    );
    if (file == null) await _markFailed(audio.path);
    return file;
  }

  Future<File?> setCoverFileFromUrl({
    required Audio audio,
    required String url,
    String? targetPath,
  }) async {
    final lookupPath = targetPath ?? audio.mediaPath;
    HttpClient? client;
    try {
      var targetUrl = url.trim();
      if (targetUrl.contains('126.net')) {
        targetUrl = formatNeteaseImageUrl(targetUrl, size: 1024);
      }
      if (targetUrl.startsWith('http://') &&
          (targetUrl.contains('126.net') ||
              targetUrl.contains('gtimg.cn') ||
              targetUrl.contains('qq.com'))) {
        targetUrl = 'https://${targetUrl.substring(7)}';
      }
      final uri = Uri.tryParse(targetUrl);
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

      req.followRedirects = true;
      req.maxRedirects = 5;
      final resp = await req.close().timeout(onlineCoverRequestTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final contentType = resp.headers.contentType;
      if (!isSupportedOnlineCoverContentType(contentType)) return null;
      if (resp.contentLength > 0 && resp.contentLength > onlineCoverMaxBytes) return null;

      final bytes = await readBoundedCoverBytes(resp,
          maxBytes: onlineCoverMaxBytes, timeout: onlineCoverRequestTimeout);
      if (bytes.isEmpty) return null;


      final extension = detectCoverExtension(bytes);
      if (extension == null) {
        LOGGER.w("OnlineCoverStore: downloaded image is neither JPEG nor PNG magic bytes, rejected");
        return null;
      }

      final dir = await _coverCacheDir();
      final cachePath = "${dir.path}\\${_cacheNameForPath(lookupPath)}$extension";
      final file = File(cachePath);
      await file.writeAsBytes(bytes, flush: true);
      _cachedPathMap[lookupPath] = cachePath;
      final removedLookup = _failedAudioPaths.remove(lookupPath) != null;
      final removedAudio = _failedAudioPaths.remove(audio.path) != null;
      if (removedLookup || removedAudio) {
        await _saveFailures();
      }
      await save();
      return file;
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<ImageProvider?> setCoverFromUrl({
    required Audio audio,
    required String url,
    String? targetPath,
  }) async {
    final file = await setCoverFileFromUrl(
      audio: audio,
      url: url,
      targetPath: targetPath,
    );
    return file != null ? FileImage(file) : null;
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
