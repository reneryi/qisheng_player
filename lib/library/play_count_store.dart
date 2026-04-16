import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/utils.dart';

class PlayCountStore {
  PlayCountStore._();
  static final PlayCountStore instance = PlayCountStore._();

  final Map<String, int> _counts = {};
  bool _loaded = false;

  Future<void> read() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final supportPath = (await getAppDataDir()).path;
      final playCountPath = "$supportPath\\play_count.json";
      final file = File(playCountPath);
      if (!file.existsSync()) return;

      final jsonStr = await file.readAsString();
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      _counts.clear();
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is num) {
          _counts[entry.key] = value.toInt().clamp(0, 1 << 30);
        }
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> save() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final playCountPath = "$supportPath\\play_count.json";
      final output = await File(playCountPath).create(recursive: true);
      await output.writeAsString(json.encode(_counts));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  int getByPath(String path) => _counts[path] ?? 0;

  int get(Audio audio) => getByPath(audio.path);

  Future<void> increaseByPath(String path) async {
    _counts[path] = (_counts[path] ?? 0) + 1;
    await save();
  }

  Future<void> increase(Audio audio) => increaseByPath(audio.path);
}
