import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/library_reload_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  test('dependent stores load only after the audio library is ready', () async {
    final events = <String>[];
    var libraryReady = false;
    final coordinator = LibraryReloadCoordinator(
      loadLibrary: () async {
        events.add('library:start');
        await Future<void>.delayed(Duration.zero);
        libraryReady = true;
        events.add('library:end');
        return AudioLibraryLoadStatus.loaded;
      },
      loadPlaylists: () async {
        expect(libraryReady, isTrue);
        events.add('playlists');
      },
      loadIndependentStores: [
        () async {
          expect(libraryReady, isTrue);
          events.add('lyrics');
        },
      ],
    );

    final status = await coordinator.reload(
      afterReload: () => events.add('reconcile'),
    );

    expect(status, AudioLibraryLoadStatus.loaded);
    expect(events, [
      'library:start',
      'library:end',
      'playlists',
      'lyrics',
      'reconcile',
    ]);
  });

  test('invalid library skips dependent state and reconciliation', () async {
    var dependentLoads = 0;
    var reconciled = false;
    final coordinator = LibraryReloadCoordinator(
      loadLibrary: () async => AudioLibraryLoadStatus.invalid,
      loadPlaylists: () async {
        dependentLoads++;
      },
      loadIndependentStores: [
        () async {
          dependentLoads++;
        },
      ],
    );

    final status = await coordinator.reload(
      afterReload: () => reconciled = true,
    );

    expect(status, AudioLibraryLoadStatus.invalid);
    expect(dependentLoads, 0);
    expect(reconciled, isFalse);
  });

  test('concurrent reloads share one active library load', () async {
    final libraryLoad = Completer<AudioLibraryLoadStatus>();
    var libraryLoadCalls = 0;
    var afterReloadCalls = 0;
    final coordinator = LibraryReloadCoordinator(
      loadLibrary: () {
        libraryLoadCalls++;
        return libraryLoad.future;
      },
      loadPlaylists: () async {},
      loadIndependentStores: const [],
    );

    final first = coordinator.reload(
      afterReload: () => afterReloadCalls++,
    );
    final second = coordinator.reload(
      afterReload: () => afterReloadCalls++,
    );
    await Future<void>.delayed(Duration.zero);

    expect(libraryLoadCalls, 1);
    libraryLoad.complete(AudioLibraryLoadStatus.loaded);
    expect(await Future.wait([first, second]), [
      AudioLibraryLoadStatus.loaded,
      AudioLibraryLoadStatus.loaded,
    ]);
    expect(afterReloadCalls, 2);
  });

  test('a completed core reload is not retained by a slow callback', () async {
    final callbackStarted = Completer<void>();
    final releaseCallback = Completer<void>();
    var libraryLoadCalls = 0;
    final coordinator = LibraryReloadCoordinator(
      loadLibrary: () async {
        libraryLoadCalls++;
        return AudioLibraryLoadStatus.loaded;
      },
      loadPlaylists: () async {},
      loadIndependentStores: const [],
    );

    final first = coordinator.reload(
      afterReload: () async {
        callbackStarted.complete();
        await releaseCallback.future;
      },
    );
    await callbackStarted.future;

    expect(await coordinator.reload(), AudioLibraryLoadStatus.loaded);
    expect(libraryLoadCalls, 2);

    releaseCallback.complete();
    await first;
  });

  test('rebindAudiosToLibrary preserves order and canonicalizes by path', () {
    final stale = TestAudio(
      title: 'Old title',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.flac',
    );
    final canonical = TestAudio(
      title: 'New title',
      artist: 'Artist',
      album: 'Album',
      path: stale.path,
    );
    final outsideLibrary = TestAudio(
      title: 'External',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\External\song.flac',
    );

    final rebound = rebindAudiosToLibrary(
      [stale, outsideLibrary],
      [canonical],
    );

    expect(rebound, hasLength(2));
    expect(rebound.first, same(canonical));
    expect(rebound.last, same(outsideLibrary));
  });
}
