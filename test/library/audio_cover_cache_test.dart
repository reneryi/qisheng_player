import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';

void main() {
  testWidgets('三档封面共享一次尺寸加载', (tester) async {
    var calls = 0;
    final pixel = Uint8List.fromList(<int>[1, 2, 3]);
    final audio = Audio(
      'title',
      'artist',
      'album',
      null,
      null,
      0,
      0,
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      r'C:\music\song.mp3',
      0,
      0,
      null,
      coverSizesLoaderForTesting: ({
        required path,
        required smallWidth,
        required smallHeight,
        required mediumWidth,
        required mediumHeight,
        required largeWidth,
        required largeHeight,
      }) async {
        calls++;
        return PictureSizes(small: pixel, medium: pixel, large: pixel);
      },
    );

    await Future.wait([audio.cover, audio.mediumCover, audio.largeCover]);

    expect(calls, 1);
  });
}
