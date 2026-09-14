import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/smtc_flutter.dart';

class FakeSmtcFlutter implements SmtcFlutter {
  final _controller = StreamController<SMTCControlEvent>.broadcast();
  SMTCState? lastState;
  String? lastTitle;
  int? lastProgress;
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
  }

  @override
  Future<void> updateTimeProperties({required int progress}) async {
    lastProgress = progress;
  }
}

Audio createAudio(String title, String filePath) {
  return Audio(
    title,
    'TestArtist',
    'TestAlbum',
    null,
    null,
    1,
    1,
    60,
    320,
    44100,
    null,
    null,
    null,
    null,
    filePath,
    1,
    1,
    'WAV',
  );
}

String createTempWavFile(String filename) {
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

String createCorruptedAudioFile(String filename) {
  final tempPath = path.join(Directory.current.path, filename);
  File(tempPath).writeAsStringSync('CORRUPTED_NOT_AUDIO_DATA_FOR_TESTING');
  return tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playback 2-Phase Commit & State Safety Transaction Tests (R1)', () {
    late String validWav1;
    late String validWav2;
    late String corruptWav;
    late String nonExistentPath;

    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => '.',
      );
      validWav1 = createTempWavFile('test_valid_track_1.wav');
      validWav2 = createTempWavFile('test_valid_track_2.wav');
      corruptWav = createCorruptedAudioFile('test_corrupt_track.wav');
      nonExistentPath = path.join(Directory.current.path, 'completely_missing_audio.wav');
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      for (final p in [validWav1, validWav2, corruptWav]) {
        final f = File(p);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    });

    test('1. State rollback when loading nonexistent or corrupted audio without corrupting nowPlaying', () {
      final player = BassPlayer();
      final fakeSmtc = FakeSmtcFlutter();
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

      final playback = PlaybackService(
        PlayService.instance,
        player: player,
        smtc: fakeSmtc,
        preferenceOverride: pref,
      );

      try {
        final audioValid = createAudio('Valid Track 1', validWav1);
        final audioCorrupt = createAudio('Corrupted Track', corruptWav);
        final playlist = [audioValid, audioCorrupt];

        // First play valid audio
        playback.play(0, playlist);
        expect(playback.nowPlaying, equals(audioValid));
        expect(playback.playlistIndex, equals(0));
        expect(player.hasSource, isTrue);
        expect(playback.isPlaying, isTrue);

        // Attempt manual switch to corrupted audio
        playback.playIndexOfPlaylist(1);

        // 2-Phase Commit guarantees state rollback: nowPlaying is not corrupted to corrupt audio
        expect(playback.nowPlaying, isNot(equals(audioCorrupt)));
        expect(playback.playlistIndex, isNot(equals(1)));

        // Since the previous stream was released during setSource, playback is safely stopped
        expect(player.hasSource, isFalse);
        expect(playback.isPlaying, isFalse);
        expect(fakeSmtc.lastState, equals(SMTCState.paused));
      } finally {
        playback.close();
      }
    });

    test('2. Auto-next skips broken files and successfully plays next valid track', () {
      final player = BassPlayer();
      final fakeSmtc = FakeSmtcFlutter();
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

      final playback = PlaybackService(
        PlayService.instance,
        player: player,
        smtc: fakeSmtc,
        preferenceOverride: pref,
      );

      try {
        final audioValid1 = createAudio('Valid Track 1', validWav1);
        final audioCorrupt = createAudio('Corrupted Track', corruptWav);
        final audioValid2 = createAudio('Valid Track 2', validWav2);
        final playlist = [audioValid1, audioCorrupt, audioValid2];

        playback.play(0, playlist);
        expect(playback.nowPlaying, equals(audioValid1));
        expect(playback.playlistIndex, equals(0));

        // Trigger auto-next (simulating track 1 completion)
        playback.autoNextAudio();

        // Should automatically skip corrupted track 1 and land on valid track 2
        expect(playback.nowPlaying, equals(audioValid2));
        expect(playback.playlistIndex, equals(2));
        expect(player.hasSource, isTrue);
        expect(playback.isPlaying, isTrue);
        expect(fakeSmtc.lastState, equals(SMTCState.playing));
      } finally {
        playback.close();
      }
    });

    test('3. Auto-next terminates safely without infinite loop when all remaining files are broken', () {
      final player = BassPlayer();
      final fakeSmtc = FakeSmtcFlutter();
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

      final playback = PlaybackService(
        PlayService.instance,
        player: player,
        smtc: fakeSmtc,
        preferenceOverride: pref,
      );

      try {
        final audioCorrupt1 = createAudio('Corrupted Track 1', corruptWav);
        final audioCorrupt2 = createAudio('Corrupted Track 2', nonExistentPath);
        final playlist = [audioCorrupt1, audioCorrupt2];

        playback.playlist.value = playlist;

        // Trigger auto-next when all tracks are invalid
        playback.autoNextAudio();

        // Must terminate gracefully without crashing, recursion overflow, or ghost playing
        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(fakeSmtc.lastState, isNot(equals(SMTCState.playing)));
      } finally {
        playback.close();
      }
    });

    test('4. restoreLastSession handles broken files without setting false playing or stuck state', () async {
      final player = BassPlayer();
      final fakeSmtc = FakeSmtcFlutter();
      final brokenAudio = createAudio('Broken Session Track', nonExistentPath);

      // Populate AudioLibrary collection with broken track
      AudioLibrary.instance.audioCollection = [brokenAudio];

      final pref = PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        brokenAudio.path,
        [brokenAudio.path],
        0,
        10.0,
      );

      final playback = PlaybackService(
        PlayService.instance,
        player: player,
        smtc: fakeSmtc,
        preferenceOverride: pref,
      );

      try {
        await playback.restoreLastSession();

        // Failed restore must keep nowPlaying = null to avoid stuck UI
        expect(playback.nowPlaying, isNull);
        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
        expect(fakeSmtc.lastState, isNot(equals(SMTCState.playing)));
      } finally {
        playback.close();
      }
    });

    test('5. start() prevents ghost playing when active stream is missing', () {
      final player = BassPlayer();
      final fakeSmtc = FakeSmtcFlutter();
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

      final playback = PlaybackService(
        PlayService.instance,
        player: player,
        smtc: fakeSmtc,
        preferenceOverride: pref,
      );

      try {
        // Force set a nowPlaying that references a missing file without an active stream
        playback.nowPlaying = createAudio('Ghost Audio', nonExistentPath);
        expect(player.hasSource, isFalse);

        // Call start() - reload will fail on missing file
        playback.start();

        // start() must abort and NOT send playing state to SMTC (no ghost playing)
        expect(fakeSmtc.lastState, isNot(equals(SMTCState.playing)));
        expect(playback.isPlaying, isFalse);
        expect(player.hasSource, isFalse);
      } finally {
        playback.close();
      }
    });
  });
}
