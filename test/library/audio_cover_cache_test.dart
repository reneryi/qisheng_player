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

  testWidgets('同一媒体路径的多个音轨（如CUE分轨）共享封面缓存', (tester) async {
    var calls = 0;
    final pixel = Uint8List.fromList(<int>[1, 2, 3]);
    Future<PictureSizes?> loader({
      required String path,
      required int smallWidth,
      required int smallHeight,
      required int mediumWidth,
      required int mediumHeight,
      required int largeWidth,
      required int largeHeight,
    }) async {
      calls++;
      return PictureSizes(small: pixel, medium: pixel, large: pixel);
    }

    final track1 = Audio(
      'track 1',
      'artist',
      'album',
      null,
      null,
      0,
      1,
      180,
      null,
      null,
      null,
      r'C:\music\album.flac',
      0,
      180000,
      r'C:\music\album.cue#track1',
      0,
      0,
      null,
      coverSizesLoaderForTesting: loader,
    );

    final track2 = Audio(
      'track 2',
      'artist',
      'album',
      null,
      null,
      0,
      2,
      200,
      null,
      null,
      null,
      r'C:\music\album.flac',
      180000,
      380000,
      r'C:\music\album.cue#track2',
      0,
      0,
      null,
      coverSizesLoaderForTesting: loader,
    );

    await track1.cover;
    await track2.cover;
    await track2.largeCover;

    expect(calls, 1);

    track1.clearCoverCache();
    await track2.cover;
    expect(calls, 2);
  });

  testWidgets('clearCoverCacheForTesting 清空所有封面缓存', (tester) async {
    var calls = 0;
    final pixel = Uint8List.fromList(<int>[1, 2, 3]);
    Future<PictureSizes?> loader({
      required String path,
      required int smallWidth,
      required int smallHeight,
      required int mediumWidth,
      required int mediumHeight,
      required int largeWidth,
      required int largeHeight,
    }) async {
      calls++;
      return PictureSizes(small: pixel, medium: pixel, large: pixel);
    }

    final track1 = Audio(
      'track 1',
      'artist',
      'album',
      null,
      null,
      0,
      1,
      180,
      null,
      null,
      null,
      null,
      null,
      null,
      r'C:\music\song1.mp3',
      0,
      0,
      null,
      coverSizesLoaderForTesting: loader,
    );

    await track1.cover;
    expect(calls, 1);

    Audio.clearCoverCacheForTesting();
    await track1.cover;
    expect(calls, 2);
  });
}
