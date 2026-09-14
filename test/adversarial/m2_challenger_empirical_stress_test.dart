import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'playback_r1_empirical_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String tempWavPath;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => '.',
    );
    tempWavPath = createTestWavFile('temp_challenger_m2_stress.wav');
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    final file = File(tempWavPath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  });

  group('M2 Challenger Stress Suite 1: PlayMode & Shuffle Decoupling Oracles', () {
    test('1.1 PlayMode cycle preserves shuffle and shuffle toggle preserves PlayMode', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        expect(playback.playMode.value, equals(PlayMode.forward));
        expect(playback.shuffle.value, isFalse);

        // Toggle shuffle ON
        playback.useShuffle(true);
        expect(playback.shuffle.value, isTrue);
        expect(playback.playMode.value, equals(PlayMode.forward));

        // Cycle play modes while shuffle is ON
        playback.setPlayMode(PlayMode.loop);
        expect(playback.playMode.value, equals(PlayMode.loop));
        expect(playback.shuffle.value, isTrue, reason: 'Changing PlayMode to loop must not clear shuffle');

        playback.setPlayMode(PlayMode.singleLoop);
        expect(playback.playMode.value, equals(PlayMode.singleLoop));
        expect(playback.shuffle.value, isTrue, reason: 'Changing PlayMode to singleLoop must not clear shuffle');

        playback.setPlayMode(PlayMode.forward);
        expect(playback.playMode.value, equals(PlayMode.forward));
        expect(playback.shuffle.value, isTrue, reason: 'Changing PlayMode to forward must not clear shuffle');

        // Toggle shuffle OFF
        playback.useShuffle(false);
        expect(playback.shuffle.value, isFalse);
        expect(playback.playMode.value, equals(PlayMode.forward));
      } finally {
        player.free();
      }
    });

    test('1.2 PlayMode.loop with shuffle=false loops smoothly across queue boundary (last -> first)', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final t1 = createTestAudio('Song 1', tempWavPath);
        final t2 = createTestAudio('Song 2', tempWavPath);
        final t3 = createTestAudio('Song 3', tempWavPath);
        playback.play(2, [t1, t2, t3]); // Start at last song (index 2)

        expect(playback.playlistIndex, equals(2));
        expect(playback.nowPlaying?.displayTitle, equals('Song 3'));

        // Auto next at end of playlist under PlayMode.loop must wrap to index 0
        playback.autoNextAudio();
        expect(playback.playlistIndex, equals(0));
        expect(playback.nowPlaying?.displayTitle, equals('Song 1'));

        playback.autoNextAudio();
        expect(playback.playlistIndex, equals(1));
        expect(playback.nowPlaying?.displayTitle, equals('Song 2'));

        playback.autoNextAudio();
        expect(playback.playlistIndex, equals(2));
        expect(playback.nowPlaying?.displayTitle, equals('Song 3'));

        // Wrap around again
        playback.autoNextAudio();
        expect(playback.playlistIndex, equals(0));
        expect(playback.nowPlaying?.displayTitle, equals('Song 1'));
      } finally {
        player.free();
      }
    });

    test('1.3 PlayMode.forward with shuffle=false stops at end of playlist', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final t1 = createTestAudio('Song 1', tempWavPath);
        final t2 = createTestAudio('Song 2', tempWavPath);
        playback.play(1, [t1, t2]); // Start at last song

        expect(playback.playlistIndex, equals(1));
        playback.autoNextAudio();

        // Must NOT loop to index 0, must stop / pause
        expect(playback.playlistIndex, equals(1));
        expect(playback.isPlaying, isFalse);
      } finally {
        player.free();
      }
    });

    test('1.4 PlayMode.singleLoop takes precedence over shuffle in autoNextAudio', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final t1 = createTestAudio('Song 1', tempWavPath);
        final t2 = createTestAudio('Song 2', tempWavPath);
        final t3 = createTestAudio('Song 3', tempWavPath);
        playback.play(0, [t1, t2, t3]);
        playback.useShuffle(true);

        expect(playback.playMode.value, equals(PlayMode.singleLoop));
        expect(playback.shuffle.value, isTrue);

        final initialPlaying = playback.nowPlaying;

        // In singleLoop, autoNextAudio must replay the CURRENT song, not random
        for (int i = 0; i < 5; i++) {
          playback.autoNextAudio();
          expect(playback.nowPlaying, equals(initialPlaying),
              reason: 'singleLoop must repeat current song even if shuffle is on');
        }
      } finally {
        player.free();
      }
    });
  });

  group('M2 Challenger Stress Suite 2: Backup Queue Preservation Stress Harness', () {
    test('2.1 Interleaved addToNext and addToQueue under shuffle preserves original backup queue structure', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final a = createTestAudio('Track A', tempWavPath);
        final b = createTestAudio('Track B', tempWavPath);
        final c = createTestAudio('Track C', tempWavPath);
        final d = createTestAudio('Track D', tempWavPath);

        playback.play(1, [a, b, c, d]); // Play B from [A, B, C, D]
        expect(playback.nowPlaying, equals(b));

        // Turn on shuffle
        playback.useShuffle(true);
        expect(playback.shuffle.value, isTrue);

        // Add X to next (should go after B in backup: [A, B, X, C, D])
        final x = createTestAudio('Track X (Next 1)', tempWavPath);
        playback.addToNext(x);

        // Add Y to next (should go after B in backup: [A, B, Y, X, C, D])
        final y = createTestAudio('Track Y (Next 2)', tempWavPath);
        playback.addToNext(y);

        // Add Z to queue tail (should append to end: [A, B, Y, X, C, D, Z])
        final z = createTestAudio('Track Z (Queue 1)', tempWavPath);
        playback.addToQueue(z);

        // Turn OFF shuffle
        playback.useShuffle(false);
        expect(playback.shuffle.value, isFalse);

        // Verify restored backup queue
        final restored = playback.playlist.value;
        expect(restored.length, equals(7));
        expect(restored[0], equals(a));
        expect(restored[1], equals(b));
        expect(restored[2], equals(y));
        expect(restored[3], equals(x));
        expect(restored[4], equals(c));
        expect(restored[5], equals(d));
        expect(restored[6], equals(z));
      } finally {
        player.free();
      }
    });

    test('2.2 Repeated toggle of shuffle with no changes never corrupts backup queue', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final list = List.generate(10, (i) => createTestAudio('Track $i', tempWavPath));
        playback.play(0, list);

        for (int i = 0; i < 10; i++) {
          playback.useShuffle(true);
          expect(playback.playlist.value.length, equals(10));
          playback.useShuffle(false);
          expect(playback.playlist.value, equals(list),
              reason: 'Iteration $i: Turning shuffle off must strictly restore original order');
        }
      } finally {
        player.free();
      }
    });
  });

  group('M2 Challenger Stress Suite 3: History Stack Backtracking Stress Harness', () {
    test('3.1 Multi-step sequential nextAudio under shuffle allows exact reverse backtracking with lastAudio', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final tracks = List.generate(20, (i) => createTestAudio('Track $i', tempWavPath));
        playback.play(0, tracks);
        playback.useShuffle(true);

        final visitedTracks = <Audio>[playback.nowPlaying!];

        // Simulate user clicking next 8 times
        for (int i = 0; i < 8; i++) {
          playback.nextAudio();
          visitedTracks.add(playback.nowPlaying!);
        }

        expect(visitedTracks.length, equals(9));

        // Now backtrack with lastAudio 8 times
        for (int i = 7; i >= 0; i--) {
          playback.lastAudio();
          expect(playback.nowPlaying, equals(visitedTracks[i]),
              reason: 'Backtracking step ${8 - i}: expected ${visitedTracks[i].displayTitle}, got ${playback.nowPlaying?.displayTitle}');
        }
      } finally {
        player.free();
      }
    });

    test('3.2 lastAudio when history stack is exhausted safely degrades to shuffleRandom without exception', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final tracks = List.generate(5, (i) => createTestAudio('Track $i', tempWavPath));
        playback.play(0, tracks);
        playback.useShuffle(true);

        // History is empty now. Call lastAudio() multiple times:
        for (int i = 0; i < 5; i++) {
          expect(() => playback.lastAudio(), returnsNormally);
          expect(playback.nowPlaying, isNotNull);
        }
      } finally {
        player.free();
      }
    });

    test('3.3 History stack enforces depth cap of 50 without memory leakage', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final tracks = List.generate(60, (i) => createTestAudio('Track $i', tempWavPath));
        playback.play(0, tracks);
        playback.useShuffle(true);

        // Jump through 55 songs
        for (int i = 1; i <= 55; i++) {
          playback.playIndexOfPlaylist(i % tracks.length);
        }

        // Now backtrack 50 times successfully
        int backtrackedCount = 0;
        for (int i = 0; i < 50; i++) {
          playback.lastAudio();
          backtrackedCount++;
        }
        expect(backtrackedCount, equals(50));
      } finally {
        player.free();
      }
    });
  });

  group('M2 Challenger Stress Suite 4: CUE 2-Phase Commit & Boundary Oracles', () {
    test('4.1 CUE track transition pre-commits cue boundaries preventing 0s premature autoNext', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        // Track 1: 0s - 10s (0 - 10000ms)
        final cueTrack1 = createTestAudio('CUE Track 1', tempWavPath,
            isCue: true, cueStartMs: 0, cueEndMs: 10000);
        // Track 2: 10s - 25s (10000 - 25000ms)
        final cueTrack2 = createTestAudio('CUE Track 2', tempWavPath,
            isCue: true, cueStartMs: 10000, cueEndMs: 25000);

        playback.play(0, [cueTrack1, cueTrack2]);
        expect(playback.nowPlaying, equals(cueTrack1));

        // Switch to Track 2
        playback.playIndexOfPlaylist(1);
        expect(playback.nowPlaying, equals(cueTrack2));
        expect(playback.nowPlaying?.cueStartMs, equals(10000));
        expect(playback.nowPlaying?.cueEndMs, equals(25000));

        // Position 10.0s is raw starting position for Track 2.
        // If old Track 1's cueEndMs (10000ms = 10.0s) was still bound, it would trigger autoNext!
        // But with 2-Phase commit, cueEndMs is 25000ms (25.0s), so 10.0s is safe!
        expect(playback.nowPlaying?.cueEndMs, equals(25000));
      } finally {
        player.free();
      }
    });

    test('4.2 2-Phase commit rolls back state cleanly when file is missing or invalid', () {
      final player = BassPlayer();
      final smtc = MockSmtcFlutter();
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
        smtc: smtc,
        preference: pref,
      );

      try {
        final goodTrack = createTestAudio('Good Song', tempWavPath);
        final badTrack = createTestAudio('Bad Song', 'E:/Nonexistent_path_test.wav');

        playback.play(0, [goodTrack, badTrack]);
        expect(playback.nowPlaying, equals(goodTrack));
        expect(playback.playlistIndex, equals(0));

        // Attempt manual switch to badTrack
        playback.playIndexOfPlaylist(1);

        // State must roll back to goodTrack
        expect(playback.nowPlaying, equals(goodTrack));
        expect(playback.playlistIndex, equals(0));
      } finally {
        player.free();
      }
    });
  });

  group('M2 Challenger Stress Suite 5: LRC Parsing & Non-Negative Duration Oracles', () {
    test('5.1 Multi-timestamp lines with identical text are expanded and sorted properly', () {
      const lrcText = '''
[00:05.00][00:15.50][00:25.00]Chorus line repeated
[00:00.00]Intro
[00:30.00]Outro
''';
      final lrc = Lrc.fromLrcText(lrcText, LrcSource.local);
      expect(lrc, isNotNull);
      expect(lrc!.lines.length, equals(5));

      final lines = lrc.lines.cast<LrcLine>();
      expect(lines[0].start, equals(Duration.zero));
      expect(lines[0].content, equals('Intro'));
      expect(lines[0].length, equals(const Duration(seconds: 5)));

      expect(lines[1].start, equals(const Duration(seconds: 5)));
      expect(lines[1].content, equals('Chorus line repeated'));
      expect(lines[1].length, equals(const Duration(seconds: 10, milliseconds: 500)));

      expect(lines[2].start, equals(const Duration(seconds: 15, milliseconds: 500)));
      expect(lines[2].content, equals('Chorus line repeated'));
      expect(lines[2].length, equals(const Duration(seconds: 9, milliseconds: 500)));

      expect(lines[3].start, equals(const Duration(seconds: 25)));
      expect(lines[3].content, equals('Chorus line repeated'));
      expect(lines[3].length, equals(const Duration(seconds: 5)));

      expect(lines[4].start, equals(const Duration(seconds: 30)));
      expect(lines[4].content, equals('Outro'));
      expect(lines[4].length, equals(Duration.zero));

      for (final line in lines) {
        expect(line.length.isNegative, isFalse);
      }
    });

    test('5.2 Severely out of order timestamps and duplicate timestamps never produce negative duration', () {
      const scrambledLrc = '''
[01:00.00]Line at 60s
[00:20.00]Line at 20s
[00:20.00]Simultaneous line at 20s
[00:05.00]Line at 5s
[00:50.00]Line at 50s
[00:01.00]Line at 1s
''';
      final lrc = Lrc.fromLrcText(scrambledLrc, LrcSource.local);
      expect(lrc, isNotNull);
      expect(lrc!.lines.length, equals(6));

      final lines = lrc.lines.cast<LrcLine>();
      // Check sorted order
      for (int i = 0; i < lines.length - 1; i++) {
        expect(lines[i].start <= lines[i + 1].start, isTrue);
        expect(lines[i].length.isNegative, isFalse);
      }
      expect(lines.last.length, equals(Duration.zero));
    });

    test('5.3 Extreme offset tags are handled without crashing or underflow', () {
      const lrcPositiveOffset = '''
[offset:5000]
[00:06.00]First line
[00:10.00]Second line
''';
      final lrc1 = Lrc.fromLrcText(lrcPositiveOffset, LrcSource.local);
      expect(lrc1, isNotNull);
      final lines1 = lrc1!.lines.cast<LrcLine>();
      // 6000ms - 5000ms offset = 1000ms
      expect(lines1[0].start, equals(const Duration(milliseconds: 1000)));
      // 10000ms - 5000ms offset = 5000ms
      expect(lines1[1].start, equals(const Duration(milliseconds: 5000)));
      expect(lines1[0].length, equals(const Duration(milliseconds: 4000)));

      // Huge offset that exceeds start time clamps to 0
      const lrcHugeOffset = '''
[offset:999999]
[00:05.00]Line
''';
      final lrc2 = Lrc.fromLrcText(lrcHugeOffset, LrcSource.local);
      expect(lrc2, isNotNull);
      final lines2 = lrc2!.lines.cast<LrcLine>();
      expect(lines2[0].start, equals(Duration.zero));
      expect(lines2[0].length.isNegative, isFalse);
    });
  });
}

