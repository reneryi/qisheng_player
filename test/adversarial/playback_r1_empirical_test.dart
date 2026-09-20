import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/smtc_flutter.dart';

class MockSmtcFlutter implements SmtcFlutter {
  final _controller = StreamController<SMTCControlEvent>.broadcast();
  SMTCState? lastState;
  String? lastTitle;
  int? lastProgress;
  int stateUpdateCount = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> close() async {
    await _controller.close();
  }

  @override
  Stream<SMTCControlEvent> subscribeToControlEvents() => _controller.stream;

  @override
  Future<void> updateDisplay({
    required String title,
    required String artist,
    required String album,
    required int duration,
    required String path,
  }) async {
    lastTitle = title;
  }

  @override
  Future<void> updateState({required SMTCState state}) async {
    lastState = state;
    stateUpdateCount++;
  }

  @override
  Future<void> updateTimeProperties({required int progress}) async {
    lastProgress = progress;
  }
}

class FakeLyricService implements LyricService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeDesktopLyricService implements DesktopLyricService {
  @override
  Future<bool> get canSendMessage => Future.value(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakePlayService implements PlayService {
  PlaybackService? _playbackService;
  final FakeLyricService _lyricService = FakeLyricService();
  final FakeDesktopLyricService _desktopLyricService = FakeDesktopLyricService();

  void attachPlaybackService(PlaybackService ps) {
    _playbackService = ps;
  }

  @override
  PlaybackService get playbackService => _playbackService!;

  @override
  PlaybackService? get existingPlaybackService => _playbackService;

  @override
  LyricService get lyricService => _lyricService;

  @override
  DesktopLyricService get desktopLyricService => _desktopLyricService;

  @override
  DesktopLyricService? get existingDesktopLyricService => _desktopLyricService;

  @override
  Future<void> close() async {}
}

PlaybackService createIsolatedPlaybackService({
  required BassPlayer player,
  required MockSmtcFlutter smtc,
  required PlaybackPreference preference,
}) {
  final fakePlayService = FakePlayService();
  final playback = PlaybackService(
    fakePlayService,
    player: player,
    smtc: smtc,
    preferenceOverride: preference,
  );
  fakePlayService.attachPlaybackService(playback);
  return playback;
}


Audio createTestAudio(
  String title,
  String filePath, {
  bool isCue = false,
  int? cueStartMs,
  int? cueEndMs,
}) {
  return Audio(
    title,
    'AdversarialArtist',
    'AdversarialAlbum',
    null,
    null,
    1,
    1,
    60,
    320,
    44100,
    null, // replayGainDb (double?)
    isCue ? filePath : null, // sourcePath (String?)
    cueStartMs, // cueStartMs (int?)
    cueEndMs, // cueEndMs (int?)
    isCue ? '$filePath#cue1' : filePath, // path (String)
    1, // modified (int)
    1, // created (int)
    'WAV', // by (String?)
  );
}


String createTestWavFile(String filename) {
  final tempWavPath = path.join(Directory.current.path, filename);
  const sampleRate = 44100;
  const numChannels = 2;
  const bitsPerSample = 16;
  const numSamples = sampleRate ~/ 2; // 0.5s
  const byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  const blockAlign = numChannels * (bitsPerSample ~/ 8);
  const dataSize = numSamples * blockAlign;

  final buffer = BytesBuilder();
  buffer.add('RIFF'.codeUnits);
  buffer.add((ByteData(4)..setUint32(0, 36 + dataSize, Endian.little))
      .buffer
      .asUint8List());
  buffer.add('WAVE'.codeUnits);
  buffer.add('fmt '.codeUnits);
  buffer.add((ByteData(4)..setUint32(0, 16, Endian.little))
      .buffer
      .asUint8List());
  buffer.add((ByteData(2)..setUint16(0, 1, Endian.little))
      .buffer
      .asUint8List());
  buffer.add((ByteData(2)..setUint16(0, numChannels, Endian.little))
      .buffer
      .asUint8List());
  buffer.add((ByteData(4)..setUint32(0, sampleRate, Endian.little))
      .buffer
      .asUint8List());
  buffer.add((ByteData(4)..setUint32(0, byteRate, Endian.little))
      .buffer
      .asUint8List());
  buffer.add((ByteData(2)..setUint16(0, blockAlign, Endian.little))
      .buffer
      .asUint8List());
  buffer.add((ByteData(2)..setUint16(0, bitsPerSample, Endian.little))
      .buffer
      .asUint8List());
  buffer.add('data'.codeUnits);
  buffer.add((ByteData(4)..setUint32(0, dataSize, Endian.little))
      .buffer
      .asUint8List());
  buffer.add(Uint8List(dataSize));
  File(tempWavPath).writeAsBytesSync(buffer.toBytes());
  return tempWavPath;
}

String createCorruptedFile(String filename) {
  final tempPath = path.join(Directory.current.path, filename);
  File(tempPath).writeAsStringSync('NOT_A_VALID_AUDIO_FILE_DATA_STRESS_TEST');
  return tempPath;
}

String createZeroByteFile(String filename) {
  final tempPath = path.join(Directory.current.path, filename);
  File(tempPath).writeAsBytesSync(Uint8List(0));
  return tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R1 Playback Empirical Stress & Adversarial Challenge Suite', () {
    late String validWav1;
    late String validWav2;
    late String validWav3;
    late String corruptWav1;
    late String zeroByteWav;
    late String nonExistentPath;

    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => '.',
      );
      validWav1 = createTestWavFile('adv_valid_1.wav');
      validWav2 = createTestWavFile('adv_valid_2.wav');
      validWav3 = createTestWavFile('adv_valid_3.wav');
      corruptWav1 = createCorruptedFile('adv_corrupt_1.wav');
      zeroByteWav = createZeroByteFile('adv_zero_byte.wav');
      nonExistentPath = path.join(Directory.current.path, 'adv_ghost_track_404.wav');
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      for (final p in [validWav1, validWav2, validWav3, corruptWav1, zeroByteWav]) {
        final f = File(p);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    });

    test('Stress 1: Rapid interleaving play commands on alternating good and bad files', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final good0 = createTestAudio('Good Track 0', validWav1);
        final bad1 = createTestAudio('Bad Corrupt 1', corruptWav1);
        final good2 = createTestAudio('Good Track 2', validWav2);
        final bad3 = createTestAudio('Bad Missing 3', nonExistentPath);
        final good4 = createTestAudio('Good Track 4', validWav3);
        final bad5 = createTestAudio('Bad ZeroByte 5', zeroByteWav);

        final alternatingPlaylist = [good0, bad1, good2, bad3, good4, bad5];
        final validAudios = {good0, good2, good4};
        final badAudios = {bad1, bad3, bad5};

        // Initialize with first good track
        playback.play(0, alternatingPlaylist);
        expect(playback.nowPlaying, equals(good0));
        expect(playback.isPlaying, isTrue);
        expect(player.hasSource, isTrue);

        // Rapidly issue alternating playback commands 60 times
        final commandSequence = [1, 0, 3, 2, 5, 4, 3, 0, 1, 4, 5, 2];
        for (int i = 0; i < 5; i++) {
          for (final targetIndex in commandSequence) {
            final targetAudio = alternatingPlaylist[targetIndex];
            final isTargetBad = badAudios.contains(targetAudio);

            playback.playIndexOfPlaylist(targetIndex);

            // Invariant Check 1: nowPlaying must NEVER be set to a corrupted track
            expect(badAudios.contains(playback.nowPlaying), isFalse,
                reason: 'Iteration $i, index $targetIndex: nowPlaying was corrupted to a bad track!');

            // Invariant Check 2: If isPlaying is true, player MUST have an active source
            if (playback.isPlaying) {
              expect(player.hasSource, isTrue,
                  reason: 'Ghost playing state detected! isPlaying=true but player.hasSource=false');
              expect(validAudios.contains(playback.nowPlaying), isTrue);
            }

            // Invariant Check 3: If target was bad and failed, player state must be paused/stopped
            if (isTargetBad) {
              expect(player.hasSource, isFalse);
              expect(playback.isPlaying, isFalse);
              expect(mockSmtc.lastState, equals(SMTCState.paused));
            }
          }
        }
      } finally {
        playback.close();
      }
    });

    test('Stress 2.1: All-bad playlist safe termination in PlayMode.forward', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final allBadPlaylist = [
          createTestAudio('Corrupt 1', corruptWav1),
          createTestAudio('Missing 2', nonExistentPath),
          createTestAudio('ZeroByte 3', zeroByteWav),
          createTestAudio('Missing 4', '$nonExistentPath.missing'),
        ];

        playback.playlist.value = allBadPlaylist;

        // Auto-next should traverse and terminate without hanging or recursion
        playback.autoNextAudio();

        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(mockSmtc.lastState, isNot(equals(SMTCState.playing)));
      } finally {
        playback.close();
      }
    });

    test('Stress 2.2: All-bad playlist safe termination in PlayMode.loop', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.loop,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final allBadPlaylist = [
          createTestAudio('Corrupt 1', corruptWav1),
          createTestAudio('Missing 2', nonExistentPath),
          createTestAudio('ZeroByte 3', zeroByteWav),
        ];

        playback.playlist.value = allBadPlaylist;

        // PlayMode.loop must NOT loop infinitely when all tracks are bad
        playback.autoNextAudio();

        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(mockSmtc.lastState, isNot(equals(SMTCState.playing)));
      } finally {
        playback.close();
      }
    });

    test('Stress 2.3: All-bad playlist safe termination in PlayMode.singleLoop', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.singleLoop,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final allBadPlaylist = [
          createTestAudio('Corrupt Single', corruptWav1),
          createTestAudio('Missing Single', nonExistentPath),
        ];

        playback.playlist.value = allBadPlaylist;

        // Single loop must not loop endlessly on current failed track
        playback.autoNextAudio();

        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(mockSmtc.lastState, isNot(equals(SMTCState.playing)));
      } finally {
        playback.close();
      }
    });

    test('Stress 2.4: All-bad playlist safe termination in Shuffle mode', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.loop,
        1.0,
        true, // shuffle = true
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final allBadPlaylist = [
          createTestAudio('Shuffle Bad 1', corruptWav1),
          createTestAudio('Shuffle Bad 2', nonExistentPath),
          createTestAudio('Shuffle Bad 3', zeroByteWav),
          createTestAudio('Shuffle Bad 4', '$nonExistentPath.bad'),
        ];

        playback.playlist.value = allBadPlaylist;
        playback.shuffle.value = true;

        // Shuffle auto next must terminate cleanly when all tracks fail
        playback.autoNextAudio();

        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(mockSmtc.lastState, isNot(equals(SMTCState.playing)));
      } finally {
        playback.close();
      }
    });

    test('Stress 2.5: High cardinality all-bad playlist (100 tracks) does not stack overflow', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final hundredBad = List.generate(
          100,
          (i) => createTestAudio('Missing $i', '${nonExistentPath}_$i.wav'),
        );

        playback.playlist.value = hundredBad;

        // Must process without StackOverflowError
        playback.autoNextAudio();

        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
      } finally {
        playback.close();
      }
    });

    test('Stress 3: Interleaved seek, pause, start on failed and corrupted tracks', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final badTrack = createTestAudio('Corrupt Track', corruptWav1);
        playback.playlist.value = [badTrack];

        // 1. Attempt play on bad track (fails)
        playback.playIndexOfPlaylist(0);
        expect(player.hasSource, isFalse);
        expect(playback.isPlaying, isFalse);

        // 2. Interleaved seek, pause, start
        playback.seek(42.0);
        playback.pause();
        playback.start(); // start() should abort without active stream
        playback.seek(-10.0);
        playback.start();
        playback.pause();

        // Invariant: Ghost playing must be prevented
        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(mockSmtc.lastState, isNot(equals(SMTCState.playing)));

        // 3. Rapid toggling 30 times
        for (int i = 0; i < 30; i++) {
          playback.seek(i.toDouble());
          playback.start();
          playback.pause();
          expect(playback.isPlaying, isFalse);
          expect(player.hasSource, isFalse);
        }
      } finally {
        playback.close();
      }
    });

    test('Stress 4: Corrupted CUE track handling with invalid mediaPath', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        final corruptCue = createTestAudio(
          'Corrupted CUE Track',
          corruptWav1,
          isCue: true,
          cueStartMs: 25000,
          cueEndMs: 50000,
        );

        final goodTrack = createTestAudio('Valid Track', validWav1);

        playback.play(0, [goodTrack, corruptCue]);
        expect(playback.nowPlaying, equals(goodTrack));
        expect(player.hasSource, isTrue);

        // Attempt switch to corrupt CUE track
        playback.playIndexOfPlaylist(1);

        // Should safely rollback, no ghost playing
        expect(playback.nowPlaying, isNot(equals(corruptCue)));
        expect(player.hasSource, isFalse);
        expect(playback.isPlaying, isFalse);
        expect(mockSmtc.lastState, equals(SMTCState.paused));
      } finally {
        playback.close();
      }
    });

    test('Stress 5: Empty playlist boundary defense', () {
      final player = BassPlayer();
      final mockSmtc = MockSmtcFlutter();
      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      );

      final playback = createIsolatedPlaybackService(
        player: player,
        smtc: mockSmtc,
        preference: pref,
      );

      try {
        playback.playlist.value = [];

        // All operations must gracefully complete without throwing RangeError / NoSuchMethodError
        playback.autoNextAudio();
        playback.nextAudio();
        playback.lastAudio();
        playback.play(0, []);
        playback.playIndexOfPlaylist(-1);
        playback.playIndexOfPlaylist(100);

        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
      } finally {
        playback.close();
      }
    });
  });
}
