import 'package:coriander_player/library/audio_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Audio.fromMap keeps composer and arranger nullable for old index data',
      () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': 'Artist',
      'album': 'Album',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.composer, isNull);
    expect(audio.arranger, isNull);
  });

  test('Audio.fromMap reads composer and arranger from new index data', () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': 'Artist',
      'album': 'Album',
      'composer': 'Joe Hisaishi',
      'arranger': 'Yvan Cassar',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.composer, 'Joe Hisaishi');
    expect(audio.arranger, 'Yvan Cassar');
  });
}
