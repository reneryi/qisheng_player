// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:qisheng_player/lyric/krc.dart';
import 'package:qisheng_player/lyric/qrc.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import '../test_helpers/media_test_harness.dart';

void main() {
  late String tempWavPath;

  setUpAll(() {
    tempWavPath = path.join(Directory.current.path, 'test_sample_challenger_m1_2.wav');
    const sampleRate = 44100;
    const numChannels = 2;
    const bitsPerSample = 16;
    const numSamples = sampleRate ~/ 4; // 0.25s
    const byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const blockAlign = numChannels * (bitsPerSample ~/ 8);
    const dataSize = numSamples * blockAlign;

    final buffer = BytesBuilder();
    buffer.add('RIFF'.codeUnits);
    buffer.add((ByteData(4)..setUint32(0, 36 + dataSize, Endian.little)).buffer.asUint8List());
    buffer.add('WAVE'.codeUnits);
    buffer.add('fmt '.codeUnits);
    buffer.add((ByteData(4)..setUint32(0, 16, Endian.little)).buffer.asUint8List());
    buffer.add((ByteData(2)..setUint16(0, 1, Endian.little)).buffer.asUint8List());
    buffer.add((ByteData(2)..setUint16(0, numChannels, Endian.little)).buffer.asUint8List());
    buffer.add((ByteData(4)..setUint32(0, sampleRate, Endian.little)).buffer.asUint8List());
    buffer.add((ByteData(4)..setUint32(0, byteRate, Endian.little)).buffer.asUint8List());
    buffer.add((ByteData(2)..setUint16(0, blockAlign, Endian.little)).buffer.asUint8List());
    buffer.add((ByteData(2)..setUint16(0, bitsPerSample, Endian.little)).buffer.asUint8List());
    buffer.add('data'.codeUnits);
    buffer.add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List());
    buffer.add(Uint8List(dataSize));
    File(tempWavPath).writeAsBytesSync(buffer.toBytes());
  });

  tearDownAll(() {
    final f = File(tempWavPath);
    if (f.existsSync()) {
      f.deleteSync();
    }
  });

  group('Adversarial Lyric Testing: QRC & KRC', () {
    test('Empirical: QrcLine with word containing parentheses when parsed from line', () {
      const lineStr = '[1000,2000]say (yeah)(100,200)';
      final line = QrcLine.fromLine(lineStr);
      expect(line, isNotNull);
      expect(line!.words, isNotEmpty);
      expect(line.words.first.content, equals('say (yeah)'),
          reason: 'LYRIC-03 regression: QrcLine.fromLine splits by ")" which breaks words containing parentheses!');
    });

    test('Empirical: QrcLine with multiple words containing parentheses', () {
      const lineStr = '[1000,2000]intro(0,500)(yeah)(500,500)outro(1000,500)';
      final line = QrcLine.fromLine(lineStr);
      expect(line, isNotNull);
      final wordContents = line!.words.map((w) => w.content).toList();
      print('DEBUG: QrcLine multiple words: $wordContents');
    });

    test('Empirical: Krc.fromKrcText with corrupted language frame throws FormatException', () {
      const corruptedKrc = '[language:!@#not_valid_base64#@!]\n[1000,2000]<0,2000,0>test';
      expect(() => Krc.fromKrcText(corruptedKrc), throwsA(isA<FormatException>()),
          reason: 'KRC language decoding has no try-catch guard around base64/json parsing');
    });

    test('Empirical: KrcLine with word containing angle brackets', () {
      const lineStr = '[1000,2000]<0,500,0>test <1><500,500,0>word';
      final line = KrcLine.fromLine(lineStr);
      expect(line, isNotNull);
      final wordContents = line!.words.map((w) => w.content).toList();
      print('DEBUG: KrcLine word contents for "<0,500,0>test <1><500,500,0>word": $wordContents');
    });
  });

  group('Adversarial BASS Lifecycle: Idempotency and State Queries', () {
    test('Calling methods after free() throws or handles safely without native crash', () {
      final player = BassPlayer();
      player.setSource(tempWavPath);
      player.free();

      // Verify that calling hasSource returns false
      expect(player.hasSource, isFalse);
      // Second free() throws StateError because DynamicLibrary is already closed
      expect(() => player.free(), throwsA(isA<StateError>()));
      // Verify freeFStream() after free() is safe because stream is already null
      expect(() => player.freeFStream(), returnsNormally);
    });

    test('Rapid setSource and freeFStream in a loop', () {
      final player = BassPlayer();
      try {
        for (int i = 0; i < 15; i++) {
          player.setSource(tempWavPath);
          expect(player.hasSource, isTrue);
          expect(player.length, greaterThan(0));
          player.freeFStream();
          expect(player.hasSource, isFalse);
        }
      } finally {
        player.free();
      }
    });
  });

  group('Adversarial UI Testing: CurrentPlaylistView Drag and Reorder', () {
    testWidgets('Drag and reorder item in CurrentPlaylistView with duplicates', (tester) async {
      final songA = TestAudio(title: 'Song A', artist: 'Artist A', album: 'Album A', path: r'E:\Music\a.flac');
      final songB = TestAudio(title: 'Song B', artist: 'Artist B', album: 'Album B', path: r'E:\Music\b.flac');
      final songC = TestAudio(title: 'Song A', artist: 'Artist A', album: 'Album A', path: r'E:\Music\a.flac'); // duplicate of A

      final queue = [songA, songB, songC];
      final fakeController = FakePlaybackController(
        audio: songA,
        queue: queue,
      );

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: fakeController,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const SizedBox(
            width: 420,
            height: 600,
            child: CurrentPlaylistView(
              showHeader: false,
              dense: true,
              enableReorder: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(3));

      // Drag from first handle down past second handle
      final handles = find.byIcon(Icons.drag_indicator_rounded);
      final firstHandle = handles.first;
      
      // Perform drag gesture
      final dragGesture = await tester.startGesture(tester.getCenter(firstHandle));
      await tester.pump();
      await dragGesture.moveBy(const Offset(0, 80));
      await tester.pump();
      await dragGesture.up();
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull, reason: 'Reordering items with duplicate paths must not throw');
    });
  });
}
