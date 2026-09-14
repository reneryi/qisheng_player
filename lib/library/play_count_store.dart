import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/foundation.dart';

class PlayCountStore {
  PlayCountStore._()
      : saveDebounceDuration = const Duration(milliseconds: 500),
        _persistForTesting = null;

  static final PlayCountStore instance = PlayCountStore._();

  @visibleForTesting
  PlayCountStore.forTesting({
    required Future<void> Function(Map<String, int>) persist,
    this.saveDebounceDuration = const Duration(milliseconds: 500),
    bool loaded = true,
  })  : _persistForTesting = persist,
        _loaded = loaded;

  final Map<String, int> _counts = {};
  final Duration saveDebounceDuration;
  final Future<void> Function(Map<String, int>)? _persistForTesting;
  Timer? _saveDebounce;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  @visibleForTesting
  void resetLoadedForTesting({bool loaded = false}) {
    _loaded = loaded;
  }

  Future<void> read() async {
    if (_loaded) return;

    try {
      final supportPath = (await getAppDataDir()).path;
      final playCountPath = "$supportPath\\play_count.json";
      final file = File(playCountPath);
      if (!file.existsSync()) {
        _loaded = true;
        return;
      }

      final jsonStr = await file.readAsString();
      if (jsonStr.trim().isEmpty) {
        _loaded = true;
        return;
      }
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      _counts.clear();
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is num) {
          _counts[entry.key] = value.toInt().clamp(0, 1 << 30);
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
      LOGGER.w("PlayCountStore.save: blocked save because store is not loaded yet");
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = null;
    try {
      final persistForTesting = _persistForTesting;
      if (persistForTesting != null) {
        await persistForTesting(Map.unmodifiable(_counts));
        return;
      }
      final supportPath = (await getAppDataDir()).path;
      final playCountPath = "$supportPath\\play_count.json";
      await atomicWriteString(playCountPath, json.encode(_counts));
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  int getByPath(String path) => _counts[path] ?? 0;

  int get(Audio audio) => getByPath(audio.path);

  Future<void> increaseByPath(String path) async {
    _counts[path] = (_counts[path] ?? 0).clamp(0, 1 << 30) + 1;
    _scheduleSave();
  }

  Future<void> increase(Audio audio) => increaseByPath(audio.path);

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(saveDebounceDuration, () => unawaited(save()));
  }
}
