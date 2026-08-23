import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/audio_library.dart';

void main() {
  test('CUE tracks expose the source media path for file operations', () {
    final audio = Audio(
      'Track',
      'Artist',
      'Album',
      null,
      null,
      1,
      1,
      120,
      null,
      null,
      null,
      r'E:\Music\album.flac',
      0,
      1000,
      r'E:\Music\album.flac#CUE:1:0',
      0,
      0,
      null,
    );

    expect(audio.isCueTrack, isTrue);
    expect(audio.mediaPath, r'E:\Music\album.flac');
  });
}
