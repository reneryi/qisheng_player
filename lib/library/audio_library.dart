import 'dart:io';
import 'dart:convert';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

typedef CoverSizesLoader = Future<PictureSizes?> Function({
  required String path,
  required int smallWidth,
  required int smallHeight,
  required int mediumWidth,
  required int mediumHeight,
  required int largeWidth,
  required int largeHeight,
});

enum AudioLibraryLoadStatus { loaded, missing, empty, invalid }

class AudioCoverProviders {
  const AudioCoverProviders(this.small, this.medium, this.large);

  final ImageProvider? small;
  final ImageProvider? medium;
  final ImageProvider? large;
}

class AudioCoverCache {
  static const int maxProvidersEntries = 300;
  static const int maxBytesEntries = 20;

  static final Map<String, Future<AudioCoverProviders>> _providersCache = {};
  static final Map<String, Future<Uint8List?>> _bytesCache = {};

  static double _lastDpiRatio = 1.0;

  @visibleForTesting
  static int get providersCacheCount => _providersCache.length;

  @visibleForTesting
  static double get lastDpiRatio => _lastDpiRatio;

  static void checkDpiAdaptation(double currentRatio) {
    if ((_lastDpiRatio - currentRatio).abs() > 0.05) {
      _providersCache.clear();
      _lastDpiRatio = currentRatio;
    }
  }

  static Future<AudioCoverProviders> getProviders(
    String key,
    Future<AudioCoverProviders> Function() loader,
  ) {
    final view = PlatformDispatcher.instance.views.firstOrNull;
    if (view != null) {
      checkDpiAdaptation(view.devicePixelRatio);
    }
    final existing = _providersCache.remove(key);
    if (existing != null) {
      _providersCache[key] = existing;
      return existing;
    }
    if (_providersCache.length >= maxProvidersEntries) {
      final oldestKey = _providersCache.keys.first;
      _providersCache.remove(oldestKey);
    }
    final future = loader();
    _providersCache[key] = future;
    future.catchError((_) {
      _providersCache.remove(key);
      return const AudioCoverProviders(null, null, null);
    });
    return future;
  }

  static Future<Uint8List?> getBytes(
    String key,
    Future<Uint8List?> Function() loader,
  ) {
    final existing = _bytesCache.remove(key);
    if (existing != null) {
      _bytesCache[key] = existing;
      return existing;
    }
    if (_bytesCache.length >= maxBytesEntries) {
      final oldestKey = _bytesCache.keys.first;
      _bytesCache.remove(oldestKey);
    }
    final future = loader();
    _bytesCache[key] = future;
    future.catchError((_) {
      _bytesCache.remove(key);
      return null;
    });
    return future;
  }

  static void invalidate(String key) {
    _providersCache.remove(key);
    _bytesCache.remove(key);
  }

  @visibleForTesting
  static void clearAll() {
    _providersCache.clear();
    _bytesCache.clear();
  }
}

class IndexParsePayload {
  final String indexPath;
  final String artistSplitPattern;
  const IndexParsePayload(this.indexPath, this.artistSplitPattern);
}

class IndexParseResult {
  final List<AudioFolder> folders;
  final List<String> roots;
  final int version;
  final bool isEmpty;
  const IndexParseResult({
    required this.folders,
    required this.roots,
    this.version = 114,
    this.isEmpty = false,
  });
}

IndexParseResult _parseIndexInIsolate(IndexParsePayload payload) {
  final file = File(payload.indexPath);
  if (!file.existsSync()) {
    return const IndexParseResult(folders: [], roots: [], isEmpty: true);
  }
  final indexStr = file.readAsStringSync();
  if (indexStr.trim().isEmpty) {
    return const IndexParseResult(folders: [], roots: [], isEmpty: true);
  }
  final decoded = json.decode(indexStr);
  if (decoded is! Map || decoded["folders"] is! List) {
    throw const FormatException("index.json 缺少有效的 folders 数组");
  }
  final List foldersJson = decoded["folders"] as List;
  final List rootsJson = (decoded["roots"] as List?) ?? [];
  final List<String> roots = rootsJson.map((e) => e.toString()).toList();
  final int version = (decoded["version"] as num?)?.toInt() ?? 114;

  final List<AudioFolder> folders = [];
  for (final folderValue in foldersJson) {
    if (folderValue is! Map || folderValue["audios"] is! List) {
      throw const FormatException("index.json 包含无效的文件夹条目");
    }
    final folderMap = folderValue;
    final List audiosJson = folderMap["audios"] as List;
    final List<Audio> audios = [];
    for (final audioValue in audiosJson) {
      if (audioValue is! Map) {
        throw const FormatException("index.json 包含无效的音频条目");
      }
      audios.add(
        Audio.fromMap(
          audioValue,
          artistSplitPattern: payload.artistSplitPattern,
        ),
      );
    }
    folders.add(AudioFolder.fromMap(folderMap, audios));
  }

  return IndexParseResult(
    folders: folders,
    roots: roots,
    version: version,
  );
}

@visibleForTesting
IndexParseResult parseIndexInIsolate(IndexParsePayload payload) =>
    _parseIndexInIsolate(payload);

/// from index.json
class AudioLibrary {
  List<AudioFolder> folders;
  List<String> roots = [];

  AudioLibrary._(this.folders, {List<String>? roots}) : roots = roots ?? [];

  /// 所有音乐
  List<Audio> audioCollection = [];

  Map<String, Artist> artistCollection = {};

  Map<String, Album> albumCollection = {};

  /// must call [initFromIndex]
  static AudioLibrary get instance {
    _instance ??= AudioLibrary._([]);
    return _instance!;
  }

  static AudioLibrary? _instance;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifyChanged() {
    revision.value++;
  }

  /// 目前 index 结构：
  /// ```json
  /// {
  ///     "version": 114,
  ///     "roots": [...],
  ///     "folders": [
  ///         {
  ///             "audios": [
  ///                 {...},
  ///                 ...
  ///             ],
  ///             ...
  ///         },
  ///         ...
  ///     ]
  /// }
  /// ```
  static Future<AudioLibraryLoadStatus> initFromIndex() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final indexPath = "$supportPath\\index.json";
      final indexFile = File(indexPath);
      if (!indexFile.existsSync()) {
        return AudioLibraryLoadStatus.missing;
      }

      final splitPattern = AppSettings.instance.artistSplitPattern;
      final result = await compute(
        _parseIndexInIsolate,
        IndexParsePayload(indexPath, splitPattern),
      );

      if (result.isEmpty) {
        return AudioLibraryLoadStatus.empty;
      }

      _instance = AudioLibrary._(result.folders, roots: result.roots);

      await AudioMetadataOverrideStore.instance.read();
      AudioMetadataOverrideStore.instance.applyToLibrary(instance);
      instance._rebuildCollections();
      notifyChanged();
      return AudioLibraryLoadStatus.loaded;
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
      return AudioLibraryLoadStatus.invalid;
    }
  }

  void _rebuildCollections() {
    audioCollection.clear();
    artistCollection.clear();
    albumCollection.clear();
    _buildCollections();
  }

  void removeAudioByPath(String path) {
    removeAudiosByPaths({path});
  }

  void removeAudiosByPaths(Set<String> paths) {
    if (paths.isEmpty) return;
    for (final folder in folders) {
      folder.audios.removeWhere((audio) => paths.contains(audio.path));
    }
    _rebuildCollections();
    notifyChanged();
  }

  void rebuildCollectionsFromCurrentFolders() {
    _rebuildCollections();
    notifyChanged();
  }

  void _buildCollections() {
    for (var f in folders) {
      audioCollection.addAll(f.audios);
    }

    for (Audio audio in audioCollection) {
      for (String artistName in audio.splitedArtists) {
        /// 如果artistCollection中有artistName指向的artist，putIfAbsent会返回该artist。
        /// 随后往这个artist里添加该audio。
        ///
        /// 如果没有，创建一个名字为artistName的空艺术家，并将artistName与之相连。
        /// 随后往这个artist里添加该audio。
        artistCollection
            .putIfAbsent(artistName, () => Artist(name: artistName))
            .works
            .add(audio);
      }

      /// 如果albumCollection中有audio.album指向的album，putIfAbsent会返回该album。
      /// 随后往这个album里添加该audio。
      ///
      /// 如果没有，创建一个名字为audio.album的空艺术家，并将audio.album与之相连。
      /// 随后往这个album里添加该audio。
      albumCollection
          .putIfAbsent(audio.album, () => Album(name: audio.album))
          .works
          .add(audio);
    }

    /// 将艺术家和专辑链接起来
    for (Artist artist in artistCollection.values) {
      for (Audio audio in artist.works) {
        artist.albumsMap.putIfAbsent(
          audio.album,
          () => albumCollection[audio.album]!,
        );
      }
    }

    /// 将专辑和艺术家链接起来
    for (Album album in albumCollection.values) {
      for (Audio audio in album.works) {
        for (String artistName in audio.splitedArtists) {
          album.artistsMap.putIfAbsent(
            artistName,
            () => artistCollection[artistName]!,
          );
        }
      }
    }
  }

  @override
  String toString() {
    return folders.toString();
  }
}

class AudioFolder {
  List<Audio> audios;

  /// absolute path
  String path;

  /// secs since UNIX EPOCH
  int modified;

  /// secs since UNIX EPOCH
  int latest;

  final bool pendingRetry;

  AudioFolder(
    this.audios,
    this.path,
    this.modified,
    this.latest, {
    this.pendingRetry = false,
  });

  factory AudioFolder.fromMap(Map map, List<Audio> audios) => AudioFolder(
        audios,
        map["path"],
        map["modified"],
        map["latest"],
        pendingRetry: map["pending_retry"] == true,
      );

  @override
  String toString() {
    return {
      "audios": audios.toString(),
      "path": path,
      "modified":
          DateTime.fromMillisecondsSinceEpoch(modified * 1000).toString(),
      "pending_retry": pendingRetry,
    }.toString();
  }
}

class Audio {
  String title;

  /// 从音乐标签中读取的艺术家字符串，可能包含多个艺术家，以“、”，“/”等分隔。
  String artist;

  /// 分割[artist]得到的结果
  List<String> splitedArtists;

  String album;

  String? composer;

  String? arranger;

  /// 0: 没有碟号
  int disc;

  /// 0: 没有track
  int track;

  /// audio's duration in secs
  int duration;

  /// kbps
  int? bitrate;

  int? sampleRate;

  /// ReplayGain track gain (dB)
  double? replayGainDb;

  /// 原始音频路径（CUE 轨道使用）
  String? sourcePath;

  /// CUE 轨道起始时间（毫秒）
  int? cueStartMs;

  /// CUE 轨道结束时间（毫秒）
  int? cueEndMs;

  /// absolute path
  String path;

  /// secs since UNIX EPOCH
  int modified;

  /// secs since UNIX EPOCH
  int created;

  /// 标签来源（Lofty、Windows、null）
  String? by;

  final CoverSizesLoader _coverSizesLoader;

  /// 以“、”和“/”分割艺术家，会把名称中带有这些符号的艺术家分割。
  /// 暂时想不到别的方法。
  Audio(
    this.title,
    this.artist,
    this.album,
    this.composer,
    this.arranger,
    this.disc,
    this.track,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.replayGainDb,
    this.sourcePath,
    this.cueStartMs,
    this.cueEndMs,
    this.path,
    this.modified,
    this.created,
    this.by, {
    CoverSizesLoader? coverSizesLoaderForTesting,
    String? artistSplitPattern,
  })  : _coverSizesLoader =
            coverSizesLoaderForTesting ?? getPictureSizesFromPath,
        splitedArtists = artist.split(
          RegExp(artistSplitPattern ?? _resolveSplitPattern()),
        ) {
    _normalizeCorruptedMetadata(artistSplitPattern: artistSplitPattern);
  }

  static String _resolveSplitPattern() {
    try {
      return AppSettings.instance.artistSplitPattern;
    } catch (_) {
      return r'[、/]';
    }
  }

  factory Audio.fromMap(Map map, {String? artistSplitPattern}) => Audio(
        map["title"],
        map["artist"],
        map["album"],
        map["composer"]?.toString(),
        map["arranger"]?.toString(),
        map["disc"] ?? _inferDiscFromPath(map["path"]),
        map["track"] ?? 0,
        map["duration"] ?? 0,
        map["bitrate"],
        map["sample_rate"],
        (map["replay_gain_db"] as num?)?.toDouble(),
        map["source_path"],
        (map["cue_start_ms"] as num?)?.toInt(),
        (map["cue_end_ms"] as num?)?.toInt(),
        map["path"],
        map["modified"],
        map["created"],
        map["by"],
        artistSplitPattern: artistSplitPattern,
      );

  Map toMap() => {
        "title": title,
        "artist": artist,
        "album": album,
        "composer": composer,
        "arranger": arranger,
        "disc": disc,
        "track": track,
        "duration": duration,
        "bitrate": bitrate,
        "sample_rate": sampleRate,
        "replay_gain_db": replayGainDb,
        "source_path": sourcePath,
        "cue_start_ms": cueStartMs,
        "cue_end_ms": cueEndMs,
        "path": path,
        "modified": modified,
        "created": created,
        "by": by
      };

  bool get isCueTrack =>
      sourcePath != null && cueStartMs != null && cueEndMs != null;

  /// CUE 轨道的真实媒体文件路径；普通音频等同于 [path]
  String get mediaPath => sourcePath ?? path;

  String get fileExtension {
    final resolved = mediaPath;
    final extIndex = resolved.lastIndexOf('.');
    if (extIndex < 0 || extIndex >= resolved.length - 1) {
      return "UNKNOWN";
    }
    return resolved.substring(extIndex + 1).toUpperCase();
  }

  String get qualitySummary {
    final parts = <String>[fileExtension];
    if (sampleRate != null && sampleRate! > 0) {
      final khz = sampleRate! / 1000.0;
      final text = (sampleRate! % 1000 == 0)
          ? "${khz.toStringAsFixed(0)}kHz"
          : "${khz.toStringAsFixed(1)}kHz";
      parts.add(text);
    }
    if (bitrate != null && bitrate! > 0) {
      parts.add("${bitrate}kbps");
    }
    return parts.join(" · ");
  }

  bool get hasCredits =>
      (composer?.trim().isNotEmpty ?? false) ||
      (arranger?.trim().isNotEmpty ?? false);

  bool get hasKnownArtist =>
      artist.trim().isNotEmpty && artist != "UNKNOWN" && artist != "未知艺术家";

  bool get hasKnownAlbum =>
      album.trim().isNotEmpty && album != "UNKNOWN" && album != "未知专辑";

  String get displayTitle =>
      title.trim().isNotEmpty ? title : _fallbackTitleFromPath(mediaPath);

  String get displayArtist =>
      hasKnownArtist ? splitedArtists.join(" / ") : "未知艺术家";

  String get displayAlbum => hasKnownAlbum ? album : "未知专辑";

  String get displayArtistAlbumLine {
    final parts = <String>[];
    if (hasKnownArtist) parts.add(displayArtist);
    if (hasKnownAlbum) parts.add(displayAlbum);
    return parts.isEmpty ? "未知艺术家" : parts.join(" · ");
  }

  void updateMetadata({
    String? title,
    String? artist,
    String? album,
  }) {
    if (title != null) this.title = title;
    if (artist != null) this.artist = artist;
    if (album != null) this.album = album;
    _normalizeCorruptedMetadata();
  }

  /// 读取音乐文件的图片，自动适应缩放
  Future<AudioCoverProviders> _loadCoverProviders() async {
    final view = PlatformDispatcher.instance.views.firstOrNull;
    final ratio = view?.devicePixelRatio ?? 1.0;
    AudioCoverCache.checkDpiAdaptation(ratio);
    final smallW = (48 * ratio).round();
    final mediumW = (200 * ratio).round();
    final largeW = (400 * ratio).round();
    final sizes = await _coverSizesLoader(
      path: mediaPath,
      smallWidth: smallW,
      smallHeight: smallW,
      mediumWidth: mediumW,
      mediumHeight: mediumW,
      largeWidth: largeW,
      largeHeight: largeW,
    );
    if (sizes == null) {
      final file = await OnlineCoverStore.instance.getCoverFile(this);
      if (file == null) {
        return const AudioCoverProviders(null, null, null);
      }
      final fileImage = FileImage(file);
      return AudioCoverProviders(
        ResizeImage.resizeIfNeeded(smallW, smallW, fileImage),
        ResizeImage.resizeIfNeeded(mediumW, mediumW, fileImage),
        ResizeImage.resizeIfNeeded(largeW, largeW, fileImage),
      );
    }
    return AudioCoverProviders(
      sizes.small == null ? null : MemoryImage(sizes.small!),
      sizes.medium == null ? null : MemoryImage(sizes.medium!),
      sizes.large == null ? null : MemoryImage(sizes.large!),
    );
  }

  Future<AudioCoverProviders> get _coverProviders {
    return AudioCoverCache.getProviders(mediaPath, _loadCoverProviders);
  }

  /// 缓存ImageProvider而不是Uint8List（bytes）
  /// 缓存bytes时，每次加载图片都要重新解码，内存占用很大。快速滚动时能到700mb
  /// 缓存ImageProvider不用重新解码。快速滚动时最多250mb
  /// 48*48
  Future<ImageProvider?> get cover {
    return _coverProviders.then((covers) => covers.small);
  }

  /// 读取音乐文件中的原始封面字节，供调色板提取使用。
  Future<Uint8List?> get coverBytes {
    return AudioCoverCache.getBytes(mediaPath, () {
      return getOriginalPictureFromPath(path: mediaPath).then((pic) {
        if (pic == null || pic.isEmpty) return null;
        return pic;
      });
    });
  }

  void clearCoverCache() {
    AudioCoverCache.invalidate(mediaPath);
  }

  @visibleForTesting
  static void clearCoverCacheForTesting() {
    AudioCoverCache.clearAll();
  }

  /// audio detail page 不需要频繁调用，所以不缓存图片
  /// 200 * 200
  Future<ImageProvider?> get mediumCover {
    return _coverProviders.then((covers) => covers.medium);
  }

  /// now playing 不需要频繁调用，所以不缓存图片
  /// size: 400 * devicePixelRatio（屏幕缩放大小）
  Future<ImageProvider?> get largeCover {
    return _coverProviders.then((covers) => covers.large);
  }

  @override
  String toString() {
    return {
      "title": title,
      "artist": artist,
      "album": album,
      "disc": disc,
      "path": path,
      "sourcePath": sourcePath,
      "cueStartMs": cueStartMs,
      "cueEndMs": cueEndMs,
      "modified":
          DateTime.fromMillisecondsSinceEpoch(modified * 1000).toString(),
      "created": DateTime.fromMillisecondsSinceEpoch(created * 1000).toString(),
    }.toString();
  }

  static int _inferDiscFromPath(String? path) {
    if (path == null || path.isEmpty) return 0;
    final discMatch = RegExp(r'(?:^|[\\/\s_-])(disc|cd|disk)\s*0*([1-9]\d*)',
            caseSensitive: false)
        .firstMatch(path);
    if (discMatch != null) {
      return int.tryParse(discMatch.group(2) ?? "") ?? 0;
    }
    return 0;
  }

  void _normalizeCorruptedMetadata({String? artistSplitPattern}) {
    title = _sanitizeMetadataText(
      title,
      fallback: _fallbackTitleFromPath(mediaPath),
    );
    artist = _sanitizeMetadataText(artist, fallback: "未知艺术家");
    album = _sanitizeMetadataText(album, fallback: "未知专辑");
    splitedArtists = _normalizeArtistNames(
      artist,
      artistSplitPattern: artistSplitPattern,
    );
    if (splitedArtists.isEmpty) {
      splitedArtists = ["未知艺术家"];
    }
    artist = splitedArtists.join(" / ");
  }

  static List<String> _normalizeArtistNames(
    String input, {
    String? artistSplitPattern,
  }) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in input.split(
      RegExp(artistSplitPattern ?? _resolveSplitPattern()),
    )) {
      final name = _sanitizeMetadataText(raw, fallback: "").trim();
      if (name.isEmpty || name == "UNKNOWN" || name == "未知艺术家") continue;
      if (seen.add(name.toLowerCase())) result.add(name);
    }
    return result;
  }

  static String _sanitizeMetadataText(
    String input, {
    required String fallback,
  }) {
    if (input.trim().isEmpty) return fallback;
    final repaired = _repairUtf8Mojibake(input).trim();
    if (repaired == "UNKNOWN") return fallback;

    // 常见损坏字符：replacement char / BOM / 控制字符 / 常见乱码占位。
    final hasCorruptedToken = RegExp(
      r'[\uFFFD\uFEFF\u0000-\u001F]|锟斤拷|�',
    ).hasMatch(repaired);

    if (!hasCorruptedToken) return repaired;
    final cleaned = repaired
        .replaceAll(RegExp(r'[\uFFFD\uFEFF\u0000-\u001F]'), '')
        .replaceAll('锟斤拷', '')
        .replaceAll('�', '')
        .trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned;
  }

  static String _repairUtf8Mojibake(String input) {
    final bytes = <int>[];
    for (final rune in input.runes) {
      final byte = _windows1252ReverseMap[rune] ?? (rune <= 0xFF ? rune : null);
      if (byte == null) return input;
      bytes.add(byte);
    }

    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);
      return decoded == input ? input : decoded;
    } on FormatException {
      return input;
    }
  }

  static const Map<int, int> _windows1252ReverseMap = {
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  static String _fallbackTitleFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }
}

class Artist {
  String name;

  /// 所有专辑
  Map<String, Album> albumsMap = {};

  /// 作品
  List<Audio> works = [];

  /// 只能用在artist detail page
  /// 200*200
  Future<ImageProvider?> get picture => works.first.mediumCover;

  Artist({required this.name});
}

class Album {
  String name;

  /// 参与的艺术家
  Map<String, Artist> artistsMap = {};

  /// 作品
  List<Audio> works = [];

  /// 只能用在album detail page
  /// 200*200
  Future<ImageProvider?> get cover => works.first.mediumCover;

  Album({required this.name});
}
