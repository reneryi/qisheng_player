import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:qisheng_player/app_settings.dart';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/metadata_provider.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/utils.dart';

String entityId(String kind, String key) =>
    '$kind:${sha256.convert(utf8.encode(key))}';

class ArtistProfile {
  const ArtistProfile(this.id, this.name);
  final String id, name;
}

class AlbumProfile {
  const AlbumProfile(this.id, this.name, this.artist);
  final String id, name, artist;
}

enum AutoMatchStatus {
  success,
  noCandidate,
  lowConfidence,
  failed,
}

class AutoMatchResult {
  const AutoMatchResult({
    required this.status,
    required this.message,
    this.candidate,
  });

  final AutoMatchStatus status;
  final String message;
  final MetadataCandidate? candidate;
}

/// Separate entity artwork, never an alias for a track's embedded picture.
class ArtworkStore extends ChangeNotifier {
  ArtworkStore._()
      : providers = const [
          PlatformMetadataProvider(ResultSource.netease),
          PlatformMetadataProvider(ResultSource.qq),
        ],
        _downloader = download;
  static final instance = ArtworkStore._();
  @visibleForTesting
  ArtworkStore.testing({
    required Directory directory,
    required this.providers,
    required Future<Uint8List> Function(String url) downloader,
  })  : _directory = directory,
        _loaded = true,
        _downloader = downloader;
  final Map<String, Map<String, dynamic>> _records = {};
  final Map<String, Map<String, dynamic>> _bindings = {};
  final Map<String, Future<ImageProvider?>> _inflight = {};
  final Map<String, int> _versions = {};
  final List<Completer<void>> _waiters = [];
  int _running = 0;
  bool _loaded = false;
  Future<void>? _loading;
  Future<void> _saving = Future.value();
  Directory? _directory;
  final List<MetadataProvider> providers;
  final Future<Uint8List> Function(String url) _downloader;

  Future<void> read() =>
      _loading ??= _read().whenComplete(() => _loading = null);
  Future<void> _read() async {
    if (_loaded) return;
    _directory = Directory('${(await getAppDataDir()).path}/entity_artwork');
    await _directory!.create(recursive: true);
    final file = File('${_directory!.path}/profiles.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString()) as Map;
      if (data['version'] != 1) throw const FormatException('不支持的图片资料版本');
      for (final e in (data['records'] as Map).entries) {
        _records[e.key] = Map<String, dynamic>.from(e.value);
      }
      for (final e in (data['bindings'] as Map).entries) {
        _bindings[e.key] = Map<String, dynamic>.from(e.value);
      }
    }
    _loaded = true;
  }

  Future<void> _save() {
    if (!_loaded) throw StateError('图片资料尚未载入');
    final content =
        jsonEncode({'version': 1, 'records': _records, 'bindings': _bindings});
    final next = _saving.then((_) async {
      if (_directory == null || !await _directory!.exists()) return;
      await atomicWriteString('${_directory!.path}/profiles.json', content);
    });
    _saving = next.catchError((Object e) {
      LOGGER.e('图片资料保存失败: $e');
    });
    return next;
  }

  String? boundAlbum(Audio audio) {
    final binding = _bindings[audio.path];
    if (binding == null ||
        binding['album'] != audio.album ||
        binding['artist'] != audio.artist ||
        binding['albumArtist'] != audio.albumArtist) {
      return null;
    }
    return binding['id'] as String?;
  }

  Future<void> associate(Audio audio, SongSearchResult result,
      {bool prefetch = true}) async {
    await read();
    final previousRecords = _copyMap(_records);
    final previousBindings = _copyMap(_bindings);
    String? linkedAlbumId;

    if (audio.album.trim().isNotEmpty &&
        normalizeEntityName(audio.album) == normalizeEntityName(result.album) &&
        result.albumId != null) {
      final id = entityId('album', '${result.source.name}:${result.albumId}');
      linkedAlbumId = id;
      _bindings[audio.path] = {
        'id': id,
        'album': audio.album,
        'artist': audio.artist,
        'albumArtist': audio.albumArtist
      };
      _records[id]?.remove('failedAt');
      _link(
          id,
          MetadataCandidate(
              source: result.source,
              id: result.albumId!,
              name: result.album,
              kind: 'album',
              artist: result.albumArtist ?? result.artists,
              imageUrl: null,
              evidence: true));
    }
    for (final artist in result.artistRefs) {
      if (artist.id.trim().isNotEmpty &&
          audio.splitedArtists.any(
              (a) => normalizeEntityName(a) == normalizeEntityName(artist.name))) {
        final id = entityId('artist', normalizeEntityName(artist.name));
        _records[id]?.remove('failedAt');
        _link(
            id,
            MetadataCandidate(
                source: result.source,
                id: artist.id,
                name: artist.name,
                kind: 'artist',
                evidence: true));
      }
    }
    try {
      await _save();
    } catch (_) {
      _restoreMap(_records, previousRecords);
      _restoreMap(_bindings, previousBindings);
      rethrow;
    }
    notifyListeners();

    // 智能多级联动：在后台异步预拉取专辑专属封面与歌手官方头像（若本地尚无缓存）
    if (prefetch && _directory != null && await _directory!.exists()) {
      if (linkedAlbumId != null && cached(linkedAlbumId) == null) {
        unawaited(imageFor(
            linkedAlbumId, audio.album, 'album', [audio], audio.albumArtist)
            .catchError((_) => null));
      }
      for (final a in result.artistRefs) {
        final artistId = entityId('artist', normalizeEntityName(a.name));
        if (cached(artistId) == null) {
          unawaited(imageFor(artistId, a.name, 'artist', [audio], '')
              .catchError((_) => null));
        }
      }
    }
  }

  void _link(String key, MetadataCandidate candidate) {
    final old = _records[key];
    if (old?['manual'] == true) return;
    _versions[key] = (_versions[key] ?? 0) + 1;
    _records[key] = {
      if (old?['file'] != null) 'file': old!['file'],
      'candidate': candidate.toJson(),
    };
  }

  Future<void> mergeAlbum(Album from, Album into) async {
    await read();
    final previousBindings = _copyMap(_bindings);
    for (final audio in from.works) {
      _bindings[audio.path] = {
        'id': into.id,
        'album': audio.album,
        'artist': audio.artist,
        'albumArtist': audio.albumArtist
      };
    }
    try {
      await _save();
    } catch (_) {
      _restoreMap(_bindings, previousBindings);
      rethrow;
    }
    AudioLibrary.instance.rebuildCollectionsFromCurrentFolders();
    notifyListeners();
  }

  ImageProvider? cached(String id) {
    final name = _records[id]?['file'];
    if (name is! String ||
        _directory == null ||
        name.contains('/') ||
        name.contains('\\')) {
      return null;
    }
    final file = File('${_directory!.path}/$name');
    return file.existsSync() ? FileImage(file) : null;
  }

  bool hasArtwork(String id) => cached(id) != null;

  Future<ImageProvider?> artistImage(Artist artist) =>
      imageFor(artist.id, artist.name, 'artist', artist.works, '');
  Future<ImageProvider?> albumImage(Album album) async {
    final image = await imageFor(
        album.id, album.name, 'album', album.works, album.effectiveArtist);
    if (image != null) return image;
    for (final audio in album.works) {
      final cover = await audio.embeddedCover;
      if (cover != null) return cover;
    }
    return null;
  }

  Future<ImageProvider?> imageFor(String id, String name, String kind,
      List<Audio> works, String albumArtist, {bool force = false}) {
    final image = cached(id);
    if (image != null && !force) return Future.value(image);
    // Initialization is explicit; widget tests and unloaded libraries never start networking.
    if (!_loaded || (works.isEmpty && name.isEmpty)) return Future.value(null);
    if (force) {
      _records[id]?.remove('failedAt');
    } else {
      final failed = _records[id]?['failedAt'] as int?;
      if (failed != null &&
          DateTime.now().millisecondsSinceEpoch - failed < 86400000) {
        return Future.value(null);
      }
    }
    final requestKey = "$id:${_versions[id] ?? 0}";
    return _inflight.putIfAbsent(
        requestKey,
        () => _automatic(id, name, kind, works, albumArtist).whenComplete(() {
              _inflight.remove(requestKey);
            }));
  }

  Future<void> _acquire() async {
    if (_running >= 3) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    } else {
      _running++;
    }
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  Future<ImageProvider?> _automatic(String id, String name, String kind,
      List<Audio> works, String albumArtist) async {
    final version = _versions[id] ?? 0;
    await _acquire();
    try {
      MetadataCandidate? candidate;
      final stored = _records[id]?['candidate'];
      if (stored is Map) candidate = MetadataCandidate.fromJson(stored);
      candidate ??= selectAutomaticEntity(
          await candidates(name, kind, works, albumArtist),
          name,
          kind,
          albumArtist);
      if (candidate == null) {
        throw const FormatException('没有唯一且身份明确的候选，请手动查找图片');
      }
      final detailed = await providers
          .firstWhere((p) => p.source == candidate!.source)
          .detail(candidate);
      final bytes = await _downloader(detailed.imageUrl!);
      if ((_versions[id] ?? 0) != version) return cached(id);
      await _persistImage(id, bytes,
          manual: false, candidate: detailed, expectedVersion: version);
      return cached(id);
    } catch (e) {
      if ((_versions[id] ?? 0) == version) {
        final previous = _records[id] == null
            ? null
            : Map<String, dynamic>.from(_records[id]!);
        _records[id] = {
          ...?_records[id],
          'failedAt': DateTime.now().millisecondsSinceEpoch,
          'error': e.toString()
        };
        try {
          await _save();
        } catch (error) {
          if (previous == null) {
            _records.remove(id);
          } else {
            _records[id] = previous;
          }
          LOGGER.e("图片失败记录保存失败: $error");
        }
      }
      return cached(id);
    } finally {
      _release();
    }
  }

  Future<List<MetadataCandidate>> candidates(
      String name, String kind, List<Audio> works, String albumArtist) async {
    if (name.trim().isEmpty && works.isEmpty) return [];
    final unique = <String, MetadataCandidate>{};
    final searchName =
        name.trim().isNotEmpty ? name.trim() : (works.firstOrNull?.artist ?? '');

    // 1. 原生实体检索（直取歌手官方头像或专辑封面，高精度且快速）
    if (searchName.isNotEmpty) {
      final entityGroups = await Future.wait(providers.map((p) async {
        try {
          return await p.searchEntities(searchName, kind,
              albumArtist: albumArtist);
        } catch (_) {
          return <MetadataCandidate>[];
        }
      }));
      for (final c in entityGroups.expand((g) => g)) {
        unique[c.identity] = c;
      }
    }

    // 2. 歌曲反查检索（补充候选或单测桩兜底）
    if (unique.isEmpty && works.isNotEmpty) {
      final witness = works.first;
      final query = kind == 'artist'
          ? '$name ${witness.title}'
          : '$name ${albumArtist.isEmpty ? witness.artist : albumArtist}';
      final groups = await Future.wait(providers.map((provider) async {
        try {
          return await provider.searchSongs(query, witness);
        } catch (_) {
          return <SongSearchResult>[];
        }
      }));
      for (final song in groups.expand((g) => g)) {
        final evidence = works.any((w) =>
            normalizeEntityName(w.title) == normalizeEntityName(song.title) &&
            (song.durationMs == null ||
                (w.duration * 1000 - song.durationMs!).abs() <= 3000));
        final entries = kind == 'artist'
            ? [
                for (final a in song.artistRefs)
                  MetadataCandidate(
                      source: song.source,
                      id: a.id,
                      name: a.name,
                      kind: kind,
                      evidence: evidence)
              ]
            : [
                if (song.albumId != null)
                  MetadataCandidate(
                      source: song.source,
                      id: song.albumId!,
                      name: song.album,
                      kind: kind,
                      artist: song.albumArtist ?? song.artists,
                      imageUrl: song.coverUrl,
                      evidence: evidence)
              ];
        for (final c in entries) {
          if (unique[c.identity]?.evidence != true) unique[c.identity] = c;
        }
      }
    }
    return unique.values.toList();
  }

  Future<void> select(String id, MetadataCandidate candidate) async {
    await read();
    final version = (_versions[id] ?? 0) + 1;
    _versions[id] = version;
    final detailed = await providers
        .firstWhere((p) => p.source == candidate.source)
        .detail(candidate);
    await _persistImage(id, await _downloader(detailed.imageUrl!),
        manual: true, candidate: detailed, expectedVersion: version);
  }

  Future<void> local(String id, Uint8List bytes) async {
    await read();
    final version = (_versions[id] ?? 0) + 1;
    _versions[id] = version;
    await _persistImage(id, bytes, manual: true, expectedVersion: version);
  }

  Future<void> reset(String id) async {
    await read();
    _versions[id] = (_versions[id] ?? 0) + 1;
    final previous =
        _records[id] == null ? null : Map<String, dynamic>.from(_records[id]!);
    final candidate = _records[id]?['candidate'];
    _records[id] = {if (candidate != null) 'candidate': candidate};
    try {
      await _save();
    } catch (_) {
      if (previous == null) {
        _records.remove(id);
      } else {
        _records[id] = previous;
      }
      rethrow;
    }
    notifyListeners();
  }

  Future<AutoMatchResult> autoMatchEntity({
    required String id,
    required String name,
    required String kind,
    required List<Audio> works,
    String albumArtist = '',
  }) async {
    await read();
    try {
      final list = await candidates(name, kind, works, albumArtist);
      if (list.isEmpty) {
        return const AutoMatchResult(
          status: AutoMatchStatus.noCandidate,
          message: '未检索到在线候选结果',
        );
      }

      final targetNormName = normalizeEntityName(name);
      final targetArtistNorm = normalizeEntityName(albumArtist);
      final scored = <({MetadataCandidate candidate, double score})>[];

      for (final c in list) {
        double score = 0.0;
        final cNameNorm = normalizeEntityName(c.name);
        final cArtistNorm = normalizeEntityName(c.artist);

        if (kind == 'artist') {
          if (cNameNorm == targetNormName) {
            score += 60.0;
          } else if (cNameNorm.contains(targetNormName) ||
              targetNormName.contains(cNameNorm)) {
            score += 30.0;
          } else {
            continue;
          }
          if (c.evidence == true) score += 30.0;
          if (c.imageUrl != null && c.imageUrl!.trim().isNotEmpty) {
            score += 10.0;
          }
        } else {
          // album
          if (cNameNorm == targetNormName) {
            score += 50.0;
          } else {
            continue;
          }

          if (targetArtistNorm.isNotEmpty && cArtistNorm.isNotEmpty) {
            if (cArtistNorm == targetArtistNorm) {
              score += 35.0;
            } else if (cArtistNorm.contains(targetArtistNorm) ||
                targetArtistNorm.contains(cArtistNorm)) {
              score += 20.0;
            } else {
              if (c.evidence != true) continue;
            }
          } else if (works.isNotEmpty) {
            final workArtists = works
                .expand((w) => w.splitedArtists)
                .map((a) => normalizeEntityName(a))
                .toSet();
            if (workArtists.contains(cArtistNorm)) {
              score += 30.0;
            } else if (c.evidence == true) {
              score += 20.0;
            }
          }

          if (c.evidence == true) score += 20.0;
          if (c.imageUrl != null && c.imageUrl!.trim().isNotEmpty) {
            score += 10.0;
          }
        }

        scored.add((candidate: c, score: score));
      }

      if (scored.isEmpty) {
        return const AutoMatchResult(
          status: AutoMatchStatus.lowConfidence,
          message: '未检索到高置信度匹配项，请通过「查找图片」手动确认',
        );
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      final best = scored.first;

      // 严格判定阈值：80分及以上才自动采纳，防止误判
      if (best.score < 80.0) {
        return AutoMatchResult(
          status: AutoMatchStatus.lowConfidence,
          message:
              '候选置信度不足（评分 ${best.score.toInt()}），为防止误判未自动采纳，请在「查找图片」中手动核对',
          candidate: best.candidate,
        );
      }

      await select(id, best.candidate);
      return AutoMatchResult(
        status: AutoMatchStatus.success,
        message:
            '已成功智能匹配并更新${kind == "artist" ? "歌手头像" : "专辑封面"}（${best.candidate.source.name} · ${best.candidate.name}）',
        candidate: best.candidate,
      );
    } catch (e) {
      LOGGER.e('智能匹配执行异常: $e');
      return AutoMatchResult(
        status: AutoMatchStatus.failed,
        message: '智能匹配失败: $e',
      );
    }
  }

  static const int maxArtworkBytes = 32 * 1024 * 1024;
  static const int maxDisplayDimension = 2048;

  Future<void> _persistImage(String id, Uint8List rawBytes,
      {required bool manual,
      MetadataCandidate? candidate,
      required int expectedVersion}) async {
    final bytes = await optimizeImageBytes(rawBytes);
    final name = '${sha256.convert(bytes)}${detectCoverExtension(bytes) ?? ".png"}';
    final file = File('${_directory!.path}/$name');
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    if ((_versions[id] ?? 0) != expectedVersion) return;
    final previous =
        _records[id] == null ? null : Map<String, dynamic>.from(_records[id]!);
    _records[id] = {
      'file': name,
      'manual': manual,
      if (candidate != null) 'candidate': candidate.toJson()
    };
    try {
      await _save();
    } catch (_) {
      if (previous == null) {
        _records.remove(id);
      } else {
        _records[id] = previous;
      }
      rethrow;
    }
    // Defers UI notifications out of FutureBuilder's build stack.
    notifyListeners();
  }

  static Future<Uint8List> optimizeImageBytes(Uint8List bytes,
      {int maxDimension = maxDisplayDimension}) async {
    await validateImage(bytes);
    final descriptor = await ui.ImmutableBuffer.fromUint8List(bytes);
    int width = 0;
    int height = 0;
    try {
      final image = await ui.ImageDescriptor.encoded(descriptor);
      width = image.width;
      height = image.height;
      image.dispose();
    } finally {
      descriptor.dispose();
    }

    if (width <= maxDimension && height <= maxDimension) {
      return bytes;
    }

    int targetW = width;
    int targetH = height;
    if (width >= height) {
      targetH = (height * maxDimension / width).round();
      targetW = maxDimension;
    } else {
      targetW = (width * maxDimension / height).round();
      targetH = maxDimension;
    }

    if (targetW <= 0) targetW = 1;
    if (targetH <= 0) targetH = 1;

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final byteData =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      } finally {
        frame.image.dispose();
      }
    } catch (e) {
      LOGGER.w('图片下采样优化失败，保留原图: $e');
    } finally {
      codec.dispose();
    }
    return bytes;
  }

  static Future<void> validateImage(Uint8List bytes) async {
    if (bytes.isEmpty ||
        bytes.length > maxArtworkBytes ||
        detectCoverExtension(bytes) == null) {
      throw const FormatException('请选择有效且不超过 32 MB 的 JPEG／PNG 图片');
    }
    final descriptor = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final image = await ui.ImageDescriptor.encoded(descriptor);
      try {
        if (image.width > 16384 ||
            image.height > 16384 ||
            image.width * image.height > 64000000) {
          throw const FormatException('图片像素尺寸过大，超过 6400 万像素限制');
        }
      } finally {
        image.dispose();
      }
    } finally {
      descriptor.dispose();
    }
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
    try {
      (await codec.getNextFrame()).image.dispose();
    } finally {
      codec.dispose();
    }
  }

  static Future<Uint8List> download(String url) async {
    final uri = Uri.parse(url);
    if (!['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('无效的图片地址');
    }
    final client = HttpClient()..connectionTimeout = onlineCoverRequestTimeout;
    try {
      final request =
          await client.getUrl(uri).timeout(onlineCoverRequestTimeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'QishengPlayer/${AppSettings.version}',
      );
      final response = await request.close().timeout(onlineCoverRequestTimeout);
      if (response.statusCode != 200 ||
          response.contentLength > onlineCoverMaxBytes) {
        throw const HttpException('图片下载失败');
      }
      final bytes = await readBoundedCoverBytes(response);
      await validateImage(bytes);
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, Map<String, dynamic>> _copyMap(
          Map<String, Map<String, dynamic>> source) =>
      source
          .map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));

  static void _restoreMap(Map<String, Map<String, dynamic>> target,
      Map<String, Map<String, dynamic>> snapshot) {
    target
      ..clear()
      ..addAll(snapshot);
  }

  @visibleForTesting
  bool isManual(String id) => _records[id]?['manual'] == true;

  @visibleForTesting
  String? storedFileName(String id) => _records[id]?['file'] as String?;
}
