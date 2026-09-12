import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

Audio createCueTrack({
  required String path,
  required String sourcePath,
  required int cueStartMs,
  required int cueEndMs,
}) {
  return Audio(
    'CUE Track Title',
    'Artist',
    'Album',
    null,
    null,
    1,
    1,
    ((cueEndMs - cueStartMs) / 1000).round(),
    320,
    44100,
    null,
    sourcePath,
    cueStartMs,
    cueEndMs,
    path,
    1,
    1,
    'CUE',
  );
}

void main() {
  group('CUE Relative Position & SMTC Progress Calculations (R1 & R5)', () {
    final cueTrack = createCueTrack(
      path: r'E:\Music\album.cue#2',
      sourcePath: r'E:\Music\album.flac',
      cueStartMs: 60000, // 60s
      cueEndMs: 180000, // 180s (track length 120s)
    );

    test('calculateCueDisplayPosition accurately computes relative time', () {
      // 物理时间 75.5s 相当于分轨开始后 15.5s
      final displaySec = calculateCueDisplayPosition(
        audio: cueTrack,
        rawPosition: 75.5,
        playerLength: 600.0,
      );
      expect(displaySec, closeTo(15.5, 0.001));
      expect((displaySec * 1000).floor(), equals(15500));
    });

    test('reproducing double _toDisplayPosition regression bug vs fix', () {
      const relativePos = 15.5; // 这是 this.position 已经返回的相对秒数

      // 旧代码逻辑：将 relativePos 再次传入 calculateCueDisplayPosition
      final brokenDisplaySec = calculateCueDisplayPosition(
        audio: cueTrack,
        rawPosition: relativePos,
        playerLength: 600.0,
      );
      // 15.5 - 60.0 = -44.5，被 clamp 为 0.0
      expect(brokenDisplaySec, equals(0.0));
      expect((brokenDisplaySec * 1000).floor(), equals(0)); // 复现清零 Bug

      // 新代码逻辑：直接使用 (position * 1000).floor()
      final fixedMs = (relativePos * 1000).floor();
      expect(fixedMs, equals(15500)); // 修复后保持正确时间轴
    });

    test('calculateCueDisplayPosition clamps out-of-boundary positions', () {
      final underflow = calculateCueDisplayPosition(
        audio: cueTrack,
        rawPosition: 50.0,
        playerLength: 600.0,
      );
      expect(underflow, equals(0.0));

      final overflow = calculateCueDisplayPosition(
        audio: cueTrack,
        rawPosition: 195.0,
        playerLength: 600.0,
      );
      expect(overflow, equals(120.0));
    });

    test('resolveCueTrackLength accurately resolves segment lengths and fallbacks', () {
      final segmentLen = resolveCueTrackLength(
        audio: cueTrack,
        playerLength: 600.0,
      );
      expect(segmentLen, equals(120.0));

      // Fallback to duration if cueEndMs equals cueStartMs
      final zeroSegmentTrack = Audio(
        'Zero Seg',
        'Artist',
        'Album',
        null,
        null,
        1,
        1,
        210,
        320,
        44100,
        null,
        r'E:\Music\album.flac',
        10000,
        10000,
        r'E:\Music\album.cue#1',
        1,
        1,
        'CUE',
      );
      expect(
        resolveCueTrackLength(audio: zeroSegmentTrack, playerLength: 600.0),
        equals(210.0),
      );
    });

    test('regular non-cue audios are passed through without modification', () {
      final regularAudio = Audio(
        'Regular Song',
        'Artist',
        'Album',
        null,
        null,
        1,
        1,
        240,
        320,
        44100,
        null,
        null,
        null,
        null,
        r'E:\Music\song.mp3',
        1,
        1,
        'ID3v2',
      );
      final displaySec = calculateCueDisplayPosition(
        audio: regularAudio,
        rawPosition: 45.2,
        playerLength: 240.0,
      );
      expect(displaySec, equals(45.2));
      expect((displaySec * 1000).floor(), equals(45200));

      expect(
        resolveCueTrackLength(audio: regularAudio, playerLength: 240.0),
        equals(240.0),
      );
    });
  });
}
