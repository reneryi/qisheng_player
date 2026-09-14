import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/lyric/krc.dart';
import 'package:qisheng_player/lyric/qrc.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/window_controls.dart';
import '../test_helpers/media_test_harness.dart';
import 'playback_r1_empirical_test.dart';

void main() {
  late String tempWavPath;

  setUpAll(() {
    tempWavPath = path.join(Directory.current.path, 'test_sample_challenger.wav');
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

  group('1. KRC Lyric Parser Vulnerabilities', () {
    test('1.1 Krc.fromKrcText with empty line parses successfully without RangeError', () {
      const krcWithEmptyLine = '[ar:test]\n\n[1000,2000]<0,2000,0>test';
      final krc = Krc.fromKrcText(krcWithEmptyLine);
      expect(krc.lines, isNotEmpty);
      expect(krc.lines.any((l) => (l as KrcLine).words.any((w) => w.content == 'test')), isTrue);
    });

    test('1.2 Krc.fromKrcText without language tag ending with newline parses successfully', () {
      const normalKrcEndingNewline = '[ti:song]\n[1000,2000]<0,2000,0>word\n';
      final krc = Krc.fromKrcText(normalKrcEndingNewline);
      expect(krc.lines, isNotEmpty);
      expect(krc.lines.any((l) => (l as KrcLine).words.any((w) => w.content == 'word')), isTrue);
    });

    test('1.3 Krc.fromKrcText translation mismatch (lines > trans) safely handles mismatched count', () {
      // Encode a valid language frame with 1 translation line
      final langJson = json.encode({
        "content": [
          {
            "type": 1,
            "lyricContent": [
              ["Trans Line 1"]
            ]
          }
        ]
      });
      final b64Lang = base64.encode(utf8.encode(langJson));
      
      // KRC text has 2 lyric lines, but only 1 translation line
      final krcText = '[language:$b64Lang]\n'
          '[1000,2000]<0,2000,0>Lyric 1\n'
          '[3000,2000]<0,2000,0>Lyric 2\n';

      final krc = Krc.fromKrcText(krcText);
      final syncLines = krc.lines.cast<KrcLine>();
      expect(syncLines.firstWhere((l) => l.words.any((w) => w.content == 'Lyric 1')).translation, equals('Trans Line 1'));
      expect(syncLines.firstWhere((l) => l.words.any((w) => w.content == 'Lyric 2')).translation, isNull);
    });

    test('1.4 Krc.fromKrcText translation mismatch (trans > lines) safely ignores extra translations', () {
      // Encode a valid language frame with 2 translation lines
      final langJson = json.encode({
        "content": [
          {
            "type": 1,
            "lyricContent": [
              ["Trans Line 1"],
              ["Trans Line 2"]
            ]
          }
        ]
      });
      final b64Lang = base64.encode(utf8.encode(langJson));
      
      // KRC text has 1 lyric line, but 2 translation lines
      final krcText = '[language:$b64Lang]\n'
          '[1000,2000]<0,2000,0>Lyric 1\n';

      final krc = Krc.fromKrcText(krcText);
      final syncLines = krc.lines.cast<KrcLine>();
      expect(syncLines.firstWhere((l) => l.words.any((w) => w.content == 'Lyric 1')).translation, equals('Trans Line 1'));
    });
  });

  group('2. QRC Lyric Parser Vulnerabilities', () {
    test('2.1 Qrc.fromQrcText with empty translation line parses successfully without RangeError', () {
      const qrcText = '[1000,2000]hello(0,2000)';
      const transWithLeadingEmptyLine = '\n[00:01.00]Hello';

      final qrc = Qrc.fromQrcText(qrcText, transWithLeadingEmptyLine);
      final syncLines = qrc.lines.cast<QrcLine>();
      expect(syncLines.first.translation, equals('Hello'));
    });

    test('2.2 QrcWord.fromWord correctly parses words containing parentheses', () {
      // A word with parentheses, e.g. "(Yeah)(100,200)" or "say (yeah)(100,200)"
      final wordWithParen = QrcWord.fromWord("say (yeah)(100,200)");
      expect(wordWithParen, isNotNull);
      expect(wordWithParen!.content, equals('say (yeah)'));
      expect(wordWithParen.start, equals(const Duration(milliseconds: 100)));
      expect(wordWithParen.length, equals(const Duration(milliseconds: 200)));

      // Normal word works
      final normalWord = QrcWord.fromWord("hello(100,200)");
      expect(normalWord, isNotNull);
      expect(normalWord!.content, equals('hello'));
      expect(normalWord.start, equals(const Duration(milliseconds: 100)));
      expect(normalWord.length, equals(const Duration(milliseconds: 200)));
    });

    test('2.3 QrcLine.fromLine correctly parses words containing parentheses without truncation', () {
      final line = QrcLine.fromLine('[1000,2000]say (yeah)(100,200)hello(300,400)');
      expect(line, isNotNull);
      expect(line!.words.length, equals(2));
      expect(line.words[0].content, equals('say (yeah)'));
      expect(line.words[0].start, equals(const Duration(milliseconds: 100)));
      expect(line.words[0].length, equals(const Duration(milliseconds: 200)));
      expect(line.words[1].content, equals('hello'));
      expect(line.words[1].start, equals(const Duration(milliseconds: 300)));
      expect(line.words[1].length, equals(const Duration(milliseconds: 400)));
    });
  });

  group('3. LRC Lyric Parser Vulnerabilities', () {
    test('3.1 Lrc.fromLrcText preserves all timestamps on multi-timestamp lines', () {
      const multiTimestampLrc = '[01:05.20][02:30.40]Chorus line';
      final lrc = Lrc.fromLrcText(multiTimestampLrc, LrcSource.local);
      expect(lrc, isNotNull);
      expect(lrc!.lines.length, equals(2));
      final l0 = lrc.lines[0] as LrcLine;
      final l1 = lrc.lines[1] as LrcLine;
      expect(l0.start, equals(const Duration(minutes: 1, seconds: 5, milliseconds: 200)));
      expect(l0.content, equals('Chorus line'));
      expect(l1.start, equals(const Duration(minutes: 2, seconds: 30, milliseconds: 400)));
      expect(l1.content, equals('Chorus line'));
    });

    test('3.2 Lrc.fromLrcText calculates non-negative length after sort', () {
      // Out of order timestamps
      const outOfOrderLrc = '[00:10.00]Second in time, first in file\n'
          '[00:05.00]First in time, second in file';
      final lrc = Lrc.fromLrcText(outOfOrderLrc, LrcSource.local);
      expect(lrc, isNotNull);
      expect(lrc!.lines.length, equals(2));
      
      // lines are sorted by start:
      // index 0 is 00:05.00, index 1 is 00:10.00
      final line0 = lrc.lines[0] as LrcLine; // start 5s
      final line1 = lrc.lines[1] as LrcLine; // start 10s
      
      expect(line0.start, equals(const Duration(seconds: 5)));
      expect(line1.start, equals(const Duration(seconds: 10)));
      
      // Sorted order length: line0 is 5s, line1 is 0s (last line)
      expect(line0.length, equals(const Duration(seconds: 5)));
      expect(line1.length, equals(Duration.zero));
      expect(line0.length.isNegative, isFalse);
      expect(line1.length.isNegative, isFalse);
    });
  });

  group('4. BASS Handle Lifecycle and Teardown Order Verification', () {
    test('4.1 freeFStream nulls _fstream and hasSource becomes false immediately', () {
      final player = BassPlayer();
      try {
        expect(player.hasSource, isFalse);
        player.setSource(tempWavPath);
        expect(player.hasSource, isTrue);

        // Call freeFStream
        player.freeFStream();

        // After fix: player.hasSource MUST be false!
        expect(player.hasSource, isFalse,
            reason: 'BASS-01 fixed: freeFStream immediately clears _fstream and _fPath');

        // Calling freeFStream again safely no-ops without double-free
        expect(() => player.freeFStream(), returnsNormally);
        expect(player.hasSource, isFalse);
      } finally {
        player.free();
      }
    });
  });

  group('5. UI, Lifecycle, and Duplicate Key Verification', () {
    testWidgets('5.1 CurrentPlaylistView renders cleanly without duplicate key exception when duplicate songs exist', (tester) async {
      final duplicateSong = TestAudio(
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        path: r'E:\Music\song1.flac',
      );
      final queueWithDuplicates = [duplicateSong, duplicateSong];

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: FakePlaybackController(
            audio: duplicateSong,
            queue: queueWithDuplicates,
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

      // Verify that NO exception occurred
      final error = tester.takeException();
      expect(error, isNull, reason: 'Duplicate keys are resolved by compound key ValueKey("\${item.path}_\$index")');

      // Verify that both items are rendered
      expect(find.text('Song 1'), findsNWidgets(2));
    });

    testWidgets('5.2 WindowControlls dispose verification (EXPOSING FALSE POSITIVE IN ui_render_report.md)', (tester) async {
      // The explorer report claimed WindowControlls "完全缺失 dispose() 导致全局监听永久泄漏".
      // Let's verify empirically if WindowControllsState implements dispose() and removes its layoutMode listener.

      // Initial listener count
      // ignore: invalid_use_of_protected_member
      final hadListenersBefore = WindowControls.layoutMode.hasListeners;

      // Pump WindowControlls inside a stateful wrapper
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                WindowControlls(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // WindowControlls added a listener to layoutMode
      // ignore: invalid_use_of_protected_member
      expect(WindowControls.layoutMode.hasListeners, isTrue);

      // Now unmount / dispose WindowControlls by pumping an empty container
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      // If WindowControllsState lacked dispose(), the listener would still be there.
      // But title_bar.dart:466-478 implements dispose()!
      // So layoutMode listener was removed!
      // ignore: invalid_use_of_protected_member
      expect(WindowControls.layoutMode.hasListeners, equals(hadListenersBefore),
          reason: 'WindowControlls properly cleans up its listener on dispose; ISSUE-LIFE-01 is a FALSE POSITIVE!');
    });
  });

  group('6. Playback Flow and State Logic Verification', () {
    test('6.1 PlayMode and shuffle are decoupled and list loop behaves correctly', () {
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
        expect(playback.playMode.value, PlayMode.forward);
        expect(playback.shuffle.value, isFalse);

        // Setting PlayMode.loop keeps shuffle FALSE
        playback.setPlayMode(PlayMode.loop);
        expect(playback.playMode.value, PlayMode.loop);
        expect(playback.shuffle.value, isFalse,
            reason: 'FLOW-01: PlayMode.loop and shuffle are decoupled');

        // Setting shuffle independently
        playback.useShuffle(true);
        expect(playback.shuffle.value, isTrue);
        expect(playback.playMode.value, PlayMode.loop);

        playback.useShuffle(false);
        expect(playback.shuffle.value, isFalse);

        // Setting PlayMode.forward
        playback.setPlayMode(PlayMode.forward);
        expect(playback.playMode.value, PlayMode.forward);
        expect(playback.shuffle.value, isFalse);
      } finally {
        player.free();
      }
    });

    test('6.2 addToNext / addToQueue during shuffle preserves _playlistBackup original order', () {
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
        final a = createTestAudio('Track A', tempWavPath);
        final b = createTestAudio('Track B', tempWavPath);
        final c = createTestAudio('Track C', tempWavPath);
        final d = createTestAudio('Track D', tempWavPath);
        final extra = createTestAudio('Track Extra', tempWavPath);

        // Start playback with 4 songs: A, B, C, D
        playback.play(0, [a, b, c, d]);
        expect(playback.playlist.value, [a, b, c, d]);

        // Enable shuffle
        playback.useShuffle(true);
        expect(playback.shuffle.value, isTrue);

        // While in shuffle, add a song to next
        playback.addToNext(extra);

        // Turn OFF shuffle
        playback.useShuffle(false);
        expect(playback.shuffle.value, isFalse);

        // FLOW-02: _playlistBackup was protected:
        // original list was [a, b, c, d], currently playing was a,
        // so addToNext inserted extra right after a in _playlistBackup: [a, extra, b, c, d]
        expect(playback.playlist.value, equals([a, extra, b, c, d]),
            reason: 'FLOW-02: original queue order is preserved with extra inserted after nowPlaying');
      } finally {
        player.free();
      }
    });

    test('6.3 lastAudio in shuffle mode backtracks through _playbackHistory', () {
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
        final a = createTestAudio('Track A', tempWavPath);
        final b = createTestAudio('Track B', tempWavPath);
        final c = createTestAudio('Track C', tempWavPath);

        playback.play(0, [a, b, c]);
        playback.useShuffle(true);

        // Switch to track at index 1
        playback.playIndexOfPlaylist(1);
        final currentAudio = playback.nowPlaying;

        // Switch to track at index 2
        playback.playIndexOfPlaylist(2);
        expect(playback.nowPlaying, isNot(equals(currentAudio)));

        // Call lastAudio in shuffle mode: should backtrack to index 1 (currentAudio)
        playback.lastAudio();
        expect(playback.nowPlaying, equals(currentAudio),
            reason: 'FLOW-03: lastAudio under shuffle mode backtracks through history stack');
      } finally {
        player.free();
      }
    });
  });
}
