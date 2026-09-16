import 'dart:convert';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/utils.dart';

class PlaybackSessionSnapshot {
  final String? audioPath;
  final int playlistIndex;
  final double position;
  final int updatedAtMs;

  const PlaybackSessionSnapshot({
    required this.audioPath,
    required this.playlistIndex,
    required this.position,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toMap() => {
        "audioPath": audioPath,
        "playlistIndex": playlistIndex,
        "position": position,
        "updatedAtMs": updatedAtMs,
      };

  factory PlaybackSessionSnapshot.fromMap(Map map) => PlaybackSessionSnapshot(
        audioPath: map["audioPath"]?.toString(),
        playlistIndex: (map["playlistIndex"] as num?)?.toInt() ?? 0,
        position: (map["position"] as num?)?.toDouble() ?? 0.0,
        updatedAtMs: (map["updatedAtMs"] as num?)?.toInt() ?? 0,
      );
}

class PlaybackSessionStore {
  static Future<String> _getPath() async {
    final supportPath = (await getAppDataDir()).path;
    return "$supportPath\\playback_session.json";
  }

  /// 保存轻量播放进度快照 (< 100 字节)，避免频繁序列化全量偏好及庞大播放队列
  static Future<void> saveSnapshot({
    required String? audioPath,
    required int playlistIndex,
    required double position,
  }) async {
    try {
      final path = await _getPath();
      final snapshot = PlaybackSessionSnapshot(
        audioPath: audioPath,
        playlistIndex: playlistIndex,
        position: position,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final jsonStr = json.encode(snapshot.toMap());
      await atomicWriteString(path, jsonStr);
    } catch (err, trace) {
      LOGGER.w("[PlaybackSessionStore] 保存进度快照失败: $err", stackTrace: trace);
    }
  }

  /// 读取最近一次记录的播放进度快照
  static Future<PlaybackSessionSnapshot?> readSnapshot() async {
    try {
      final path = await _getPath();
      final file = File(path);
      if (!await file.exists()) return null;
      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;
      final decoded = json.decode(str);
      if (decoded is! Map) return null;
      return PlaybackSessionSnapshot.fromMap(decoded);
    } catch (err, trace) {
      LOGGER.w("[PlaybackSessionStore] 读取进度快照失败: $err", stackTrace: trace);
      return null;
    }
  }
}
