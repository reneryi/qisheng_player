import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/album_context_menu.dart';
import 'package:qisheng_player/library/audio_library.dart';

Audio _audio(String title, int disc, int track) {
  return Audio(
    title,
    'Artist',
    'Album',
    null,
    null,
    disc,
    track,
    120,
    null,
    null,
    null,
    null,
    null,
    null,
    'E:\\Music\\$title.flac',
    0,
    0,
    null,
  );
}

void main() {
  test('album queue order is stable by disc, track, then title', () {
    final album = Album(name: 'Album')
      ..works.addAll([
        _audio('C', 2, 1),
        _audio('B', 1, 2),
        _audio('A', 1, 1),
      ]);

    expect(
      orderedAlbumWorks(album).map((audio) => audio.title),
      ['A', 'B', 'C'],
    );
  });
}
