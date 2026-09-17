import 'dart:io';
import 'dart:math' as math;

import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/audio_edit_service.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/utils.dart';

/// 歌词文件与内嵌标签存储管理辅助类。
/// 统一管理歌词序列化为标准 LRC 格式、同级外挂 .lrc 写入、音频内嵌元数据标签写入及 CUE 分轨防护。
class LyricFileHelper {
  LyricFileHelper._();

  static final _windowsReservedRegex = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
    caseSensitive: false,
  );

  /// 过滤文件名中的非法字符（Windows 及通用系统禁止字符：< > : " / \ | ? * 以及控制字符）
  /// 同时规避 Windows 保留设备名称（CON, PRN, AUX, NUL, COM1-9, LPT1-9）与过长路径截断。
  static String sanitizeFileName(String name) {
    var sanitized = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // 移除 Windows 文件名首尾不允许的点、空格或下划线
    sanitized = sanitized.replaceAll(RegExp(r'^[.\s_]+|[.\s_]+$'), '');
    if (sanitized.isEmpty) return 'unnamed';

    // 规避 Windows 保留设备名（如 CON, AUX, NUL 等）
    if (_windowsReservedRegex.hasMatch(sanitized)) {
      sanitized = '_$sanitized';
    }

    // 限制单文件名最大长度（120 字符），规避 Windows 260 字符 MAX_PATH 溢出
    if (sanitized.length > 120) {
      sanitized = sanitized.substring(0, 120).trimRight();
    }
    return sanitized.isEmpty ? 'unnamed' : sanitized;
  }

  /// 获取音频对应的外挂 .lrc 文件保存完整路径。
  /// - 普通单曲：同名同目录的 `xxx.lrc`
  /// - CUE 分轨：位于母带所在同级目录，文件名为分轨对应名称，如 `01. 歌名.lrc`
  static String getLrcFilePath(Audio audio) {
    if (!audio.isCueTrack) {
      final mediaPath = audio.mediaPath;
      final lastDot = mediaPath.lastIndexOf('.');
      final lastSlash = math.max(
        mediaPath.lastIndexOf('/'),
        mediaPath.lastIndexOf('\\'),
      );
      if (lastDot > lastSlash && lastDot > 0) {
        return '${mediaPath.substring(0, lastDot)}.lrc';
      }
      return '$mediaPath.lrc';
    }

    // CUE 分轨：保存至母带所在同级目录
    final motherFile = File(audio.mediaPath);
    final dir = motherFile.parent.path;
    final safeTitle = sanitizeFileName(audio.title);
    String fileName;
    if (audio.track > 0) {
      final trackPrefix = RegExp(r'^\d+\s*[\.\-_]');
      if (trackPrefix.hasMatch(safeTitle)) {
        fileName = '$safeTitle.lrc';
      } else {
        final trackStr = audio.track.toString().padLeft(2, '0');
        fileName = '$trackStr. $safeTitle.lrc';
      }
    } else {
      fileName = '$safeTitle.lrc';
    }

    final separator = Platform.pathSeparator;
    return dir.endsWith(separator)
        ? '$dir$fileName'
        : '$dir$separator$fileName';
  }

  /// 将标准 LRC 歌词文本安全写入同级外挂 .lrc 文件。
  /// 具备自动创建目录、Windows 锁文件微退避重试与原子写入。
  static Future<bool> saveLrcToFile(Audio audio, String lrcText) async {
    try {
      final lrcPath = getLrcFilePath(audio);
      await atomicWriteString(lrcPath, lrcText);
      LOGGER.i('[LyricFileHelper] 成功保存外挂歌词: $lrcPath');
      return true;
    } catch (err, trace) {
      LOGGER.e(
        '[LyricFileHelper] 保存外挂歌词文件失败: ${audio.path}',
        error: err,
        stackTrace: trace,
      );
      return false;
    }
  }

  /// 将歌词安全写回音频文件内嵌元数据标签（ID3v2 USLT / FLAC LYRICS / MP4 等）。
  /// 深度保护 CUE 轨道：CUE 分轨不写入母带物理音频文件，直接返回 false。
  static Future<bool> writeEmbeddedLyric(Audio audio, String lrcText) async {
    if (audio.isCueTrack) {
      LOGGER.w('[LyricFileHelper] CUE 分轨保护：禁止写入母带文件标签: ${audio.path}');
      return false;
    }

    try {
      final ok =
          await const AudioEditService().writeEmbeddedLyrics(audio, lrcText);
      if (!ok) {
        LOGGER.e('[LyricFileHelper] 歌词写入内嵌标签失败: ${audio.mediaPath}');
      }
      return ok;
    } catch (err, trace) {
      LOGGER.e(
        '[LyricFileHelper] 歌词写入内嵌标签异常: ${audio.mediaPath}',
        error: err,
        stackTrace: trace,
      );
      return false;
    }
  }

  /// 将抽象 `Lyric` 对象序列化为标准 LRC 格式文本。
  static String lyricToLrcString(
    Lyric lyric, {
    bool includeTranslation = true,
  }) {
    final buffer = StringBuffer();
    for (final line in lyric.lines) {
      if (line is LrcLine && line.isBlank && line.content.isEmpty) {
        continue;
      }
      final startMs = math.max(0, line.start.inMilliseconds);
      final minutes = (startMs ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((startMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final hundredths = ((startMs % 1000) ~/ 10).toString().padLeft(2, '0');
      final timeTag = '[$minutes:$seconds.$hundredths]';

      String content = '';
      String? translation;
      if (line is UnsyncLyricLine) {
        content = line.content;
      } else if (line is SyncLyricLine) {
        content = line.content;
        translation = line.translation;
      }

      if (content.trim().isEmpty &&
          (translation == null || translation.trim().isEmpty)) {
        continue;
      }

      if (includeTranslation &&
          translation != null &&
          translation.trim().isNotEmpty) {
        buffer.writeln('$timeTag$content ─ $translation');
      } else {
        buffer.writeln('$timeTag$content');
      }
    }
    return buffer.toString().trim();
  }

  /// 根据在线检索结果拉取真实 LRC 文本（适配 QQ/酷狗/网易云），统一转换为标准 LRC 字符串。
  static Future<String?> fetchOnlineLrcText(SongSearchResult result) async {
    try {
      final lyric = await switch (result.source) {
        ResultSource.qq => getOnlineLyric(qqSongId: result.qqSongId),
        ResultSource.kugou =>
          getOnlineLyric(kugouSongHash: result.kugouSongHash),
        ResultSource.netease =>
          getOnlineLyric(neteaseSongId: result.neteaseSongId),
      };
      if (lyric == null) return null;
      final text = lyricToLrcString(lyric);
      return text.isNotEmpty ? text : null;
    } catch (err, trace) {
      LOGGER.e('[LyricFileHelper] 获取在线歌词文本失败', error: err, stackTrace: trace);
      return null;
    }
  }
}

extension LyricToLrcExtension on Lyric {
  String toLrcString({bool includeTranslation = true}) =>
      LyricFileHelper.lyricToLrcString(this,
          includeTranslation: includeTranslation);
}
