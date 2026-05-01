import 'dart:io';
import 'dart:convert';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// from index.json
class AudioLibrary {
  List<AudioFolder> folders;

  AudioLibrary._(this.folders);

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
  ///     "folders": [
  ///         {
  ///             "audios": [
  ///                 {...},
  ///                 ...
  ///             ],
  ///             ...
  ///         },
  ///         ...
  ///     ],
  ///     "version": 113
  /// }
  /// ```
  static Future<void> initFromIndex() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final indexPath = "$supportPath\\index.json";

      final indexStr = File(indexPath).readAsStringSync();
      if (indexStr.trim().isEmpty) return;
      final Map indexJson = json.decode(indexStr);
      final List foldersJson = indexJson["folders"];
      final List<AudioFolder> folders = [];

      for (Map folderMap in foldersJson) {
        final List audiosJson = folderMap["audios"];
        final List<Audio> audios = [];
        for (Map audioMap in audiosJson) {
          audios.add(Audio.fromMap(audioMap));
        }
        folders.add(AudioFolder.fromMap(folderMap, audios));
      }

      _instance = AudioLibrary._(folders);

      instance._rebuildCollections();
      await AudioMetadataOverrideStore.instance.read();
      AudioMetadataOverrideStore.instance.applyToLibrary(instance);
      instance._rebuildCollections();
      notifyChanged();
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
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

  AudioFolder(this.audios, this.path, this.modified, this.latest);

  factory AudioFolder.fromMap(Map map, List<Audio> audios) =>
      AudioFolder(audios, map["path"], map["modified"], map["latest"]);

  @override
  String toString() {
    return {
      "audios": audios.toString(),
      "path": path,
      "modified":
          DateTime.fromMillisecondsSinceEpoch(modified * 1000).toString(),
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

  Future<ImageProvider?>? _coverFuture;
  Future<ImageProvider?>? _mediumCoverFuture;
  Future<ImageProvider?>? _largeCoverFuture;
  Future<Uint8List?>? _coverBytesFuture;

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
    this.by,
  ) : splitedArtists = artist.split(
          RegExp(AppSettings.instance.artistSplitPattern),
        ) {
    _normalizeCorruptedMetadata();
  }

  factory Audio.fromMap(Map map) => Audio(
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
  Future<ImageProvider?> _getResizedPic({
    required int width,
    required int height,
  }) async {
    final ratio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    return getPictureFromPath(
      path: mediaPath,
      width: (width * ratio).round(),
      height: (height * ratio).round(),
    ).then((pic) {
      if (pic == null) {
        return OnlineCoverStore.instance.getCover(this);
      }

      return MemoryImage(pic);
    });
  }

  /// 缓存ImageProvider而不是Uint8List（bytes）
  /// 缓存bytes时，每次加载图片都要重新解码，内存占用很大。快速滚动时能到700mb
  /// 缓存ImageProvider不用重新解码。快速滚动时最多250mb
  /// 48*48
  Future<ImageProvider?> get cover {
    final existingFuture = _coverFuture;
    if (existingFuture != null) return existingFuture;

    final future = _getResizedPic(width: 48, height: 48);
    _coverFuture = future;
    return future;
  }

  /// 读取音乐文件中的原始封面字节，供调色板提取使用。
  Future<Uint8List?> get coverBytes {
    final existingFuture = _coverBytesFuture;
    if (existingFuture != null) return existingFuture;

    final future = getOriginalPictureFromPath(path: mediaPath).then((pic) {
      if (pic == null || pic.isEmpty) return null;
      return pic;
    });
    _coverBytesFuture = future;
    return future;
  }

  void clearCoverCache() {
    _coverFuture = null;
    _mediumCoverFuture = null;
    _largeCoverFuture = null;
    _coverBytesFuture = null;
  }

  /// audio detail page 不需要频繁调用，所以不缓存图片
  /// 200 * 200
  Future<ImageProvider?> get mediumCover {
    final existingFuture = _mediumCoverFuture;
    if (existingFuture != null) return existingFuture;

    final future = _getResizedPic(width: 200, height: 200);
    _mediumCoverFuture = future;
    return future;
  }

  /// now playing 不需要频繁调用，所以不缓存图片
  /// size: 400 * devicePixelRatio（屏幕缩放大小）
  Future<ImageProvider?> get largeCover {
    final existingFuture = _largeCoverFuture;
    if (existingFuture != null) return existingFuture;

    final future = _getResizedPic(width: 400, height: 400);
    _largeCoverFuture = future;
    return future;
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

  void _normalizeCorruptedMetadata() {
    title = _sanitizeMetadataText(
      title,
      fallback: _fallbackTitleFromPath(mediaPath),
    );
    artist = _sanitizeMetadataText(artist, fallback: "未知艺术家");
    album = _sanitizeMetadataText(album, fallback: "未知专辑");
    splitedArtists = _normalizeArtistNames(artist);
    if (splitedArtists.isEmpty) {
      splitedArtists = ["未知艺术家"];
    }
    artist = splitedArtists.join(" / ");
  }

  static List<String> _normalizeArtistNames(String input) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw
        in input.split(RegExp(AppSettings.instance.artistSplitPattern))) {
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
  Future<ImageProvider?> get picture =>
      works.first._getResizedPic(width: 200, height: 200);

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
  Future<ImageProvider?> get cover =>
      works.first._getResizedPic(width: 200, height: 200);

  Album({required this.name});
}
