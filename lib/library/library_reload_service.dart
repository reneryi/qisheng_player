import 'dart:async';

import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';

typedef LibraryLoadOperation = Future<AudioLibraryLoadStatus> Function();
typedef LibraryDependentLoadOperation = Future<void> Function();

class LibraryReloadCoordinator {
  LibraryReloadCoordinator({
    required LibraryLoadOperation loadLibrary,
    required LibraryDependentLoadOperation loadPlaylists,
    required List<LibraryDependentLoadOperation> loadIndependentStores,
  })  : _loadLibrary = loadLibrary,
        _loadPlaylists = loadPlaylists,
        _loadIndependentStores = loadIndependentStores;

  factory LibraryReloadCoordinator.production() {
    return LibraryReloadCoordinator(
      loadLibrary: AudioLibrary.initFromIndex,
      loadPlaylists: readPlaylists,
      loadIndependentStores: [
        readLyricSources,
        PlayCountStore.instance.read,
        OnlineCoverStore.instance.read,
      ],
    );
  }

  final LibraryLoadOperation _loadLibrary;
  final LibraryDependentLoadOperation _loadPlaylists;
  final List<LibraryDependentLoadOperation> _loadIndependentStores;
  Future<AudioLibraryLoadStatus>? _activeReload;

  Future<AudioLibraryLoadStatus> reload({
    FutureOr<void> Function()? afterReload,
  }) async {
    final operation = _activeReload ?? _beginReload();
    final status = await operation;
    if (status == AudioLibraryLoadStatus.loaded && afterReload != null) {
      await afterReload();
    }
    return status;
  }

  Future<AudioLibraryLoadStatus> _beginReload() {
    final operation = _reloadCore();
    _activeReload = operation;
    operation.then<void>(
      (_) => _clearActiveReload(operation),
      onError: (_, __) => _clearActiveReload(operation),
    );
    return operation;
  }

  void _clearActiveReload(Future<AudioLibraryLoadStatus> operation) {
    if (identical(_activeReload, operation)) _activeReload = null;
  }

  Future<AudioLibraryLoadStatus> _reloadCore() async {
    final status = await _loadLibrary();
    if (status != AudioLibraryLoadStatus.loaded) return status;

    await Future.wait([
      _loadPlaylists(),
      for (final loadStore in _loadIndependentStores) loadStore(),
    ]);
    return status;
  }
}

final libraryReloadCoordinator = LibraryReloadCoordinator.production();
