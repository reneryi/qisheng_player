import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_file_helper.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';

class LrcLine extends UnsyncLyricLine {
  bool isBlank;
  Duration length;

  LrcLine(super.start, super.content,
      {required this.isBlank, this.length = Duration.zero});

  static LrcLine defaultLine = LrcLine(
    Duration.zero,
    "无歌词",
    isBlank: false,
    length: Duration.zero,
  );

  @override
  String toString() {
    return {"time": start.toString(), "content": content}.toString();
  }

  /// line: [mm:ss.msmsms]content
  static final _timeTagRegex = RegExp(r'\[(\d{1,2}):(\d{2}(?:\.\d+)?)\]');

  /// 解析包含单个或多个时间戳的行，展开为独立的 [LrcLine] 列表
  static List<LrcLine> parseLines(String line, [int? offset]) {
    if (line.trim().isEmpty) return const [];
    final matches = _timeTagRegex.allMatches(line).toList();
    if (matches.isEmpty) return const [];

    final content = line.replaceAll(_timeTagRegex, '').trim();
    final result = <LrcLine>[];

    for (final match in matches) {
      final minuteStr = match.group(1);
      final secondStr = match.group(2);
      if (minuteStr == null || secondStr == null) continue;
      final minute = int.tryParse(minuteStr);
      final second = double.tryParse(secondStr);
      if (minute == null || second == null) continue;

      final inMilliseconds = ((minute * 60 + second) * 1000).toInt();
      result.add(LrcLine(
        Duration(
          milliseconds: max(inMilliseconds - (offset ?? 0), 0),
        ),
        content,
        isBlank: content.isEmpty,
      ));
    }

    return result;
  }

  static LrcLine? fromLine(String line, [int? offset]) =>
      parseLines(line, offset).firstOrNull;
}

enum LrcSource {
  /// mp3: USLT frame
  /// flac: LYRICS comment
  local("本地"),
  web("网络");

  final String name;

  const LrcSource(this.name);
}

class Lrc extends Lyric {
  LrcSource source;

  Lrc(super.lines, this.source);

  @override
  String toString() {
    return {"type": source, "lyric": lines}.toString();
  }

  /// 姝岃瘝涓€鑸槸鏈夊簭鐨?
  /// 鎸夌収鏃堕棿鍗囧簭鎺掑簭锛屼繚鐣欏師鏂囧拰璇戞枃鐨勯『搴忥紝闇€瑕佷娇鐢ㄧǔ瀹氱殑鎺掑簭绠楁硶
  /// 这里使用插入排序
  void _sort() {
    for (int i = 1; i < lines.length; i++) {
      var temp = lines[i];
      int j;
      for (j = i; j > 0 && lines[j - 1].start > temp.start; j--) {
        lines[j] = lines[j - 1];
      }
      lines[j] = temp;
    }
  }

  /// line_1 and line_2时间戳相同，合并成line_1[separator]line_2
  Lrc _combineLrcLine(String separator) {
    List<LrcLine> combinedLines = [];
    var buf = StringBuffer();
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].start != lines[i - 1].start) {
        buf.write((lines[i - 1] as UnsyncLyricLine).content);
        combinedLines.add(LrcLine(
          lines[i - 1].start,
          buf.toString(),
          isBlank: (lines[i - 1] as LrcLine).isBlank,
          length: (lines[i - 1] as LrcLine).length,
        ));
        buf.clear();
      } else {
        buf.write((lines[i - 1] as UnsyncLyricLine).content);
        buf.write(separator);
      }
    }
    if (lines.isNotEmpty) {
      buf.write((lines.last as UnsyncLyricLine).content);
      combinedLines.add(LrcLine(
        lines.last.start,
        buf.toString(),
        isBlank: (lines.last as LrcLine).isBlank,
        length: (lines.last as LrcLine).length,
      ));
    }

    return Lrc(combinedLines, source);
  }

  /// 如果separator为null，不合并歌词；否则，合并相同时间戳的歌词
  static Lrc? fromLrcText(String lrc, LrcSource source, {String? separator}) {
    var lrcLines = lrc.split("\n");

    int? offsetInMilliseconds;
    final offsetPattern = RegExp(r'\[\s*offset\s*:\s*([+-]?\d+)\s*\]');
    for (var line in lrcLines) {
      final matched = offsetPattern.firstMatch(line);
      if (matched == null) continue;
      offsetInMilliseconds = int.tryParse(matched.group(1) ?? "");
      break;
    }

    var lines = <LrcLine>[];
    for (int i = 0; i < lrcLines.length; i++) {
      lines.addAll(LrcLine.parseLines(lrcLines[i], offsetInMilliseconds));
    }

    if (lines.isEmpty) {
      return null;
    }

    final result = Lrc(lines, source);
    result._sort();

    for (var i = 0; i < result.lines.length - 1; i++) {
      final current = result.lines[i] as LrcLine;
      final next = result.lines[i + 1] as LrcLine;
      final diff = next.start - current.start;
      current.length = diff.isNegative ? Duration.zero : diff;
    }
    if (result.lines.isNotEmpty) {
      (result.lines.last as LrcLine).length = Duration.zero;
    }

    if (separator == null) {
      return result;
    }

    return result._combineLrcLine(separator);
  }

  /// 鍙敮鎸佽鍙?ID3V2, VorbisComment, Mp4Ilst 瀛樺偍鐨勫唴宓屾瓕璇?
  /// 以及相同目录相同文件名的 .lrc 澶栨寕姝岃瘝锛坲tf-8 or utf-16锛?
  static Lrc _clipToCueSegment(Audio belongTo, Lrc lyric) {
    if (!belongTo.isCueTrack) return lyric;

    final cueStartMs = belongTo.cueStartMs ?? 0;
    final cueEndMs =
        belongTo.cueEndMs ?? (cueStartMs + belongTo.duration * 1000);
    if (cueEndMs <= cueStartMs) return lyric;

    final sourceLines = lyric.lines.whereType<LrcLine>().toList();
    final clippedLines = <LrcLine>[];
    for (final line in sourceLines) {
      final lineStartMs = line.start.inMilliseconds;
      if (lineStartMs < cueStartMs || lineStartMs >= cueEndMs) continue;

      clippedLines.add(LrcLine(
        Duration(milliseconds: lineStartMs - cueStartMs),
        line.content,
        isBlank: line.isBlank,
      ));
    }

    if (clippedLines.isEmpty) return lyric;

    for (var i = 0; i < clippedLines.length - 1; i++) {
      clippedLines[i].length =
          clippedLines[i + 1].start - clippedLines[i].start;
    }
    final tailMs =
        cueEndMs - cueStartMs - clippedLines.last.start.inMilliseconds;
    clippedLines.last.length = Duration(milliseconds: max(tailMs, 0));

    return Lrc(clippedLines, lyric.source);
  }

  /// 安全读取本地歌词文件，支持 UTF-8 及 UTF-16 (LE / BE) 编码格式，并支持 GBK/GB2312 编码回退
  static Future<String?> _readLrcFileSafely(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        // UTF-16 LE
        final units = <int>[];
        for (var i = 2; i < bytes.length - 1; i += 2) {
          units.add(bytes[i] | (bytes[i + 1] << 8));
        }
        return String.fromCharCodes(units);
      } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        // UTF-16 BE
        final units = <int>[];
        for (var i = 2; i < bytes.length - 1; i += 2) {
          units.add((bytes[i] << 8) | bytes[i + 1]);
        }
        return String.fromCharCodes(units);
      }
      try {
        return utf8.decode(bytes);
      } catch (_) {
        try {
          final rustLrc = await getLyricFromPath(path: file.path);
          if (rustLrc != null && rustLrc.isNotEmpty) {
            return rustLrc;
          }
        } catch (_) {}
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {
      return null;
    }
  }

  /// 只支持读取 ID3V2, VorbisComment, Mp4Ilst 存储的内嵌歌词
  /// 以及相同目录相同文件名的 .lrc 外挂歌词（utf-8 or utf-16）
  static Future<Lrc?> fromAudioPath(
    Audio belongTo, {
    String? separator = "─",
  }) async {
    // 若为 CUE 分轨，优先在母带同目录下探测分轨专属外挂 .lrc 文件
    if (belongTo.isCueTrack) {
      final motherDir = File(belongTo.mediaPath).parent.path;
      final separatorChar = Platform.pathSeparator;
      final safeTitle = LyricFileHelper.sanitizeFileName(belongTo.title);
      final primaryLrcPath = LyricFileHelper.getLrcFilePath(belongTo);

      final candidates = <String>{
        primaryLrcPath,
        '$motherDir$separatorChar$safeTitle.lrc',
      };
      if (belongTo.track > 0) {
        candidates.add('$motherDir$separatorChar${belongTo.track}. $safeTitle.lrc');
        final pad = belongTo.track.toString().padLeft(2, '0');
        candidates.add('$motherDir$separatorChar$pad - $safeTitle.lrc');
      }

      for (final candidate in candidates) {
        final file = File(candidate);
        if (file.existsSync()) {
          final content = await _readLrcFileSafely(file);
          if (content != null && content.trim().isNotEmpty) {
            final lrc = Lrc.fromLrcText(
              content,
              LrcSource.local,
              separator: separator,
            );
            if (lrc != null && lrc.lines.isNotEmpty) {
              return lrc;
            }
          }
        }
      }
    }

    Lrc? lyric = await getLyricFromPath(path: belongTo.mediaPath).then((value) {
      if (value == null) {
        return null;
      }
      return Lrc.fromLrcText(value, LrcSource.local, separator: separator);
    });

    if (lyric != null) {
      lyric = _clipToCueSegment(belongTo, lyric);
    }

    return lyric;
  }
}
