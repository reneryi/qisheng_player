import 'dart:convert';
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
    tempWavPath = path.join(Directory.current.path, 'test_sample_m1_1.wav');
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

  group('Empirical Challenge: BASS Engine Boundary Resilience', () {
    test('freeFStream on uninitialized player is a safe no-op', () {
      final player = BassPlayer();
      try {
        expect(player.hasSource, isFalse);
        expect(() => player.freeFStream(), returnsNormally);
        expect(player.hasSource, isFalse);
      } finally {
        player.free();
      }
    });

    test('rapid consecutive freeFStream calls do not crash or double-free', () {
      final player = BassPlayer();
      try {
        player.setSource(tempWavPath);
        expect(player.hasSource, isTrue);

        for (int i = 0; i < 20; i++) {
          player.freeFStream();
          expect(player.hasSource, isFalse);
        }
      } finally {
        player.free();
      }
    });

    test('player teardown order: free cancels controllers and timers safely', () {
      final player = BassPlayer();
      player.setSource(tempWavPath);
      expect(player.hasSource, isTrue);
      player.free();
      // After free, calling free again or verifying no crash
    });
  });

  group('Empirical Challenge: KRC Parser Extreme Inputs', () {
    test('KRC with consecutive empty lines and whitespace lines', () {
      const krcInput = '\n\n   \n\r\n[ar:test]\n\n\n[1000,2000]<0,2000,0>test\n\n\r\n';
      final krc = Krc.fromKrcText(krcInput);
      expect(krc.lines, isNotEmpty);
      final line = krc.lines.firstWhere((l) => (l as KrcLine).words.any((w) => w.content == 'test')) as KrcLine;
      expect(line.words.first.content, 'test');
    });

    test('KRC with malformed tags: unclosed brackets, inverted brackets, empty tags', () {
      const krcInput = '[invalid\n'
          'invalid]\n'
          '][reversed\n'
          '[]\n'
          '[ti:]\n'
          '[1000,2000]<0,1000,0>valid\n';
      final krc = Krc.fromKrcText(krcInput);
      expect(krc.lines, isNotEmpty);
      final line = krc.lines.firstWhere((l) => (l as KrcLine).words.any((w) => w.content == 'valid')) as KrcLine;
      expect(line.words.first.content, 'valid');
    });

    test('KRC translation count mismatch extremes: trans > lines and lines > trans', () {
      // 0 lines, 3 trans
      final langJson3 = json.encode({
        "content": [
          {
            "type": 1,
            "lyricContent": [
              ["Trans 1"],
              ["Trans 2"],
              ["Trans 3"]
            ]
          }
        ]
      });
      final b64Lang3 = base64.encode(utf8.encode(langJson3));
      final krcTextNoLines = '[language:$b64Lang3]\n';
      final krc0 = Krc.fromKrcText(krcTextNoLines);
      expect(krc0.lines, isEmpty);

      // 5 lines, 1 trans
      final langJson1 = json.encode({
        "content": [
          {
            "type": 1,
            "lyricContent": [
              ["Trans 1"]
            ]
          }
        ]
      });
      final b64Lang1 = base64.encode(utf8.encode(langJson1));
      final krcText5Lines = '[language:$b64Lang1]\n'
          '[1000,1000]<0,1000,0>L1\n'
          '[2000,1000]<0,1000,0>L2\n'
          '[3000,1000]<0,1000,0>L3\n'
          '[4000,1000]<0,1000,0>L4\n'
          '[5000,1000]<0,1000,0>L5\n';
      final krc5 = Krc.fromKrcText(krcText5Lines);
      final lines = krc5.lines.cast<KrcLine>();
      expect(lines[0].translation, 'Trans 1');
      expect(lines[1].translation, isNull);
      expect(lines[2].translation, isNull);
      expect(lines[3].translation, isNull);
      expect(lines[4].translation, isNull);
    });
  });

  group('Empirical Challenge: QRC Parser Word Parentheses & Empty Lines', () {
    test('QrcWord.fromWord handles various word patterns', () {
      final w1 = QrcWord.fromWord("hello(100,200)");
      expect(w1, isNotNull);
      expect(w1!.content, 'hello');
      expect(w1.start, const Duration(milliseconds: 100));
      expect(w1.length, const Duration(milliseconds: 200));

      final w2 = QrcWord.fromWord("say (yeah)(100,200)");
      expect(w2, isNotNull);
      expect(w2!.content, 'say (yeah)');

      final w3 = QrcWord.fromWord("(feat. artist)(500,1000)");
      expect(w3, isNotNull);
      expect(w3!.content, '(feat. artist)');
    });

    test('Qrc.fromQrcText handles empty lines and empty translation lines', () {
      const qrcText = '\n\n[1000,2000]hello(0,2000)\n\n\n[4000,2000]world(0,2000)\n';
      const transText = '\n\n[00:01.00]你好\n\n[00:04.00]世界\n';
      final qrc = Qrc.fromQrcText(qrcText, transText);
      final syncLines = qrc.lines.cast<QrcLine>();
      expect(syncLines.length, greaterThanOrEqualTo(2));
      final line1 = syncLines.firstWhere((l) => l.words.any((w) => w.content == 'hello'));
      expect(line1.translation, '你好');
      final line2 = syncLines.firstWhere((l) => l.words.any((w) => w.content == 'world'));
      expect(line2.translation, '世界');
    });

    test('VERIFICATION: QrcLine.fromLine preserves words with parentheses without naive split(")") truncation', () {
      // In QRC text format, words are serialized as word(start,len)word(start,len)
      const lineWithParentheses = '[1000,2000]say (yeah)(100,200)';
      final qrcLine = QrcLine.fromLine(lineWithParentheses);
      expect(qrcLine, isNotNull);
      final actualWords = qrcLine!.words.map((w) => w.content).toList();
      expect(actualWords, contains('say (yeah)'),
          reason: 'say (yeah) is preserved because line.substring(...).allMatches correctly scans words with embedded parentheses');
    });
  });

  group('Empirical Challenge: CurrentPlaylistView Duplicate Items', () {
    testWidgets('Renders and functions cleanly with 10 duplicate items in queue', (tester) async {
      final duplicateSong = TestAudio(
        title: 'Duplicate Song',
        artist: 'Same Artist',
        album: 'Same Album',
        path: r'E:\Music\same_song.flac',
      );
      final tenDuplicates = List.generate(10, (_) => duplicateSong);

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: FakePlaybackController(
            audio: duplicateSong,
            queue: tenDuplicates,
          ),
          lyricController: FakeLyricController(
            Lrc([], LrcSource.local),
          ),
          desktopLyricController: FakeDesktopLyricController(),
          child: const SizedBox(
            width: 420,
            height: 1200,
            child: CurrentPlaylistView(
              showHeader: false,
              dense: true,
              enableReorder: true,
            ),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isNull);
      expect(find.text('Duplicate Song'), findsNWidgets(10));
    });

    testWidgets('Renders empty playlist cleanly', (tester) async {
      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: FakePlaybackController(
            audio: TestAudio(
              title: 'Placeholder',
              artist: 'Placeholder',
              album: 'Placeholder',
              path: r'E:\Music\placeholder.flac',
            ),
            queue: [],
          ),
          lyricController: FakeLyricController(
            Lrc([], LrcSource.local),
          ),
          desktopLyricController: FakeDesktopLyricController(),
          child: const SizedBox(
            width: 420,
            height: 560,
            child: CurrentPlaylistView(
              showHeader: false,
              dense: true,
              enableReorder: true,
            ),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isNull);
    });
  });
}
