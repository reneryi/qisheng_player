import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/utils.dart';

enum LyricSourceType {
  qq("qq"),
  kugou("kugou"),
  netease("netease"),
  local("local");

  final String name;
  const LyricSourceType(this.name);
}

/// 默认歌词来源
class LyricSource {
  LyricSourceType source;
  int? qqSongId;
  String? kugouSongHash;
  String? neteaseSongId;

  LyricSource(this.source,
      {this.qqSongId, this.kugouSongHash, this.neteaseSongId});

  static LyricSource fromMap(Map map) {
    if (map["source"] == "qq") {
      return LyricSource(LyricSourceType.qq, qqSongId: map["id"]);
    } else if (map["source"] == "kugou") {
      return LyricSource(LyricSourceType.kugou, kugouSongHash: map["id"]);
    } else if (map["source"] == "netease") {
      return LyricSource(LyricSourceType.netease, neteaseSongId: map["id"]);
    } else {
      return LyricSource(LyricSourceType.local);
    }
  }

  Map toMap() {
    switch (source) {
      case LyricSourceType.qq:
        return {"source": source.name, "id": qqSongId};
      case LyricSourceType.kugou:
        return {"source": source.name, "id": kugouSongHash};
      case LyricSourceType.netease:
        return {"source": source.name, "id": neteaseSongId};
      case LyricSourceType.local:
        return {"source": source.name, "id": null};
    }
  }
}

Map<String, LyricSource> LYRIC_SOURCES = {};

/// 串行写入任务队列，确保并发调用 saveLyricSources() 时严格按序落盘，杜绝 Windows 文件占用冲突 (errno 32)
Future<void> _saveQueue = Future.value();

Future<void> readLyricSources() async {
  try {
    final supportPath = (await getAppDataDir()).path;
    final lyricSourcePath = "$supportPath\\lyric_source.json";
    final file = File(lyricSourcePath);
    if (!file.existsSync()) {
      LYRIC_SOURCES.clear();
      return;
    }

    // 在 Windows 平台上，若遇并发原子替换可能发生微秒级共享冲突 (errno 32)，进行微退避重试
    String? lyricSourceStr;
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        lyricSourceStr = file.readAsStringSync();
        break;
      } on FileSystemException {
        if (attempt == 4) rethrow;
        await Future.delayed(Duration(milliseconds: 10 * (attempt + 1)));
      }
    }

    if (lyricSourceStr == null || lyricSourceStr.trim().isEmpty) {
      LYRIC_SOURCES.clear();
      return;
    }
    final dynamic decoded = json.decode(lyricSourceStr);
    if (decoded is! Map) {
      LYRIC_SOURCES.clear();
      return;
    }

    final Map<String, LyricSource> newSources = {};
    for (final item in decoded.entries) {
      if (item.value is! Map) continue;
      if (File(item.key.toString()).existsSync() == false) continue;
      try {
        newSources[item.key.toString()] =
            LyricSource.fromMap(item.value as Map);
      } catch (_) {
        // Skip malformed individual entries
      }
    }
    LYRIC_SOURCES.clear();
    LYRIC_SOURCES.addAll(newSources);
  } catch (err, trace) {
    LYRIC_SOURCES.clear();
    LOGGER.e(err, stackTrace: trace);
  }
}

Future<void> saveLyricSources() {
  // 同步抓取当前时刻的内存快照，杜绝在排队或并发读取交织时数据被磁盘旧值覆盖
  final Map<String, Map> lyricSourceMaps = {};
  for (final item in LYRIC_SOURCES.entries) {
    lyricSourceMaps[item.key] = item.value.toMap();
  }
  final lyricSourceJson = json.encode(lyricSourceMaps);

  // 链式顺序排队执行，确保即使外部并发保存，也严格按序单线程串行落盘，并在发生异常时保持队列畅通
  _saveQueue = _saveQueue
      .then((_) => _executeSaveLyricSourcesWithRetry(lyricSourceJson))
      .catchError((err, trace) {
    LOGGER.e(err, stackTrace: trace);
  });
  return _saveQueue;
}

Future<void> _executeSaveLyricSourcesWithRetry(String lyricSourceJson) async {
  final supportPath = (await getAppDataDir()).path;
  final lyricSourcePath = "$supportPath\\lyric_source.json";

  // 在 Windows 平台上，若遇并发读取或外部杀毒/同步程序锁死文件，触发 errno 32 时进行重试退避
  const maxAttempts = 5;
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      await atomicWriteString(lyricSourcePath, lyricSourceJson);
      return;
    } on FileSystemException catch (e) {
      if (attempt == maxAttempts - 1) {
        LOGGER.e("saveLyricSources 重试 $maxAttempts 次后仍然失败: $e");
        rethrow;
      }
      final delayMs = 15 * (1 << attempt); // 15ms, 30ms, 60ms, 120ms
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}
