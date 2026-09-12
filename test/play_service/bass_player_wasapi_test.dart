import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:qisheng_player/src/bass/bass_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BassPlayer WASAPI Exclusive & Lifecycle', () {
    late String tempWavPath;

    setUpAll(() {
      // Create a small 44.1kHz 16-bit stereo wav file for real BASS stream tests
      tempWavPath = path.join(Directory.current.path, 'test_sample_bass.wav');
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
    });

    tearDownAll(() {
      final f = File(tempWavPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    });

    test('BassPlayer initializes successfully and switches exclusive mode without track', () {
      final player = BassPlayer();
      try {
        expect(player.wasapiExclusive, isFalse);
        final switched = player.useExclusiveMode(true);
        expect(switched, isTrue);
        expect(player.wasapiExclusive, isTrue);

        final switchedBack = player.useExclusiveMode(false);
        expect(switchedBack, isTrue);
        expect(player.wasapiExclusive, isFalse);
      } finally {
        player.free();
      }
    });

    test('BassPlayer switches exclusive mode while paused and playing with loaded track', () {
      final player = BassPlayer();
      try {
        player.setSource(tempWavPath);
        expect(player.length, greaterThan(0.4));

        // Switch to exclusive while paused/stopped: should validate WASAPI initialization cleanly
        final switchedToExclusive = player.useExclusiveMode(true);
        expect(switchedToExclusive, isTrue);
        expect(player.wasapiExclusive, isTrue);

        // Start playing in exclusive mode
        player.start();
        expect(player.playerState, PlayerState.playing);

        // Pause in exclusive mode
        player.pause();
        expect(player.playerState, PlayerState.paused);

        // Resume in exclusive mode: BASS_ERROR_ALREADY should be handled cleanly without reinit loop
        player.start();
        expect(player.playerState, PlayerState.playing);

        // Switch back to shared mode while playing
        final switchedToShared = player.useExclusiveMode(false);
        expect(switchedToShared, isTrue);
        expect(player.wasapiExclusive, isFalse);

        player.pause();
      } finally {
        player.free();
      }
    });
  });
}
