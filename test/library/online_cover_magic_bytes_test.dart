import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/online_cover_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online cover MIME type and Magic Bytes validation', () {
    test('isSupportedOnlineCoverContentType restricts to image/jpeg, image/jpg, and image/png', () {
      expect(isSupportedOnlineCoverContentType(ContentType('image', 'jpeg')), isTrue);
      expect(isSupportedOnlineCoverContentType(ContentType('image', 'jpg')), isTrue);
      expect(isSupportedOnlineCoverContentType(ContentType('image', 'png')), isTrue);

      // 拒绝其他非标或不支持直接写入音频标签的格式
      expect(isSupportedOnlineCoverContentType(ContentType('image', 'webp')), isFalse);
      expect(isSupportedOnlineCoverContentType(ContentType('image', 'gif')), isFalse);
      expect(isSupportedOnlineCoverContentType(ContentType('image', 'svg+xml')), isFalse);
      expect(isSupportedOnlineCoverContentType(ContentType('text', 'html')), isFalse);
      expect(isSupportedOnlineCoverContentType(ContentType('application', 'octet-stream')), isFalse);
      expect(isSupportedOnlineCoverContentType(null), isFalse);
    });

    test('isJpegBytes detects JPEG magic bytes and rejects others', () {
      final validJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
      expect(isJpegBytes(validJpeg), isTrue);

      final shortBytes = Uint8List.fromList([0xFF, 0xD8]);
      expect(isJpegBytes(shortBytes), isFalse);

      final invalidBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(isJpegBytes(invalidBytes), isFalse);
    });

    test('isPngBytes detects PNG magic bytes and rejects others', () {
      final validPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(isPngBytes(validPng), isTrue);

      final shortPng = Uint8List.fromList([0x89, 0x50, 0x4E]);
      expect(isPngBytes(shortPng), isFalse);

      // WebP header: RIFF....WEBP
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      expect(isPngBytes(webpBytes), isFalse);

      // GIF header: GIF89a
      final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
      expect(isPngBytes(gifBytes), isFalse);

      // HTML error page: <html>...
      final htmlBytes = Uint8List.fromList('<html lang="en">'.codeUnits);
      expect(isPngBytes(htmlBytes), isFalse);
    });

    test('detectCoverExtension returns correct extension or null for non-JPEG/PNG', () {
      final validJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB]);
      expect(detectCoverExtension(validJpeg), equals('.jpg'));

      final validPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      expect(detectCoverExtension(validPng), equals('.png'));

      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x10, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      expect(detectCoverExtension(webpBytes), isNull);

      final randomGarbage = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(detectCoverExtension(randomGarbage), isNull);
    });
  });

  group('AudioCoverCache DPI adaptation and invalidation tests', () {
    setUp(() {
      AudioCoverCache.clearAll();
      final baseRatio = PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ?? 1.0;
      AudioCoverCache.checkDpiAdaptation(baseRatio);
    });

    tearDown(() {
      AudioCoverCache.clearAll();
    });

    test('AudioCoverCache clears providers cache when devicePixelRatio changes > 0.05', () async {
      final baseRatio = PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ?? 1.0;
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio));

      // 放入测试缓存项
      await AudioCoverCache.getProviders(
        'test_song_path.flac',
        () async => const AudioCoverProviders(null, null, null),
      );
      expect(AudioCoverCache.providersCacheCount, equals(1));

      // 微小 DPI 变动 (0.02 <= 0.05) 不应清空缓存
      AudioCoverCache.checkDpiAdaptation(baseRatio + 0.02);
      expect(AudioCoverCache.providersCacheCount, equals(1));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio));

      // 显著 DPI 变动 (差距 0.5 > 0.05)，必须使缓存失效清空
      AudioCoverCache.checkDpiAdaptation(baseRatio + 0.5);
      expect(AudioCoverCache.providersCacheCount, equals(0));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio + 0.5));

      // 再次填充缓存
      await AudioCoverCache.getProviders(
        'test_song_path_2.flac',
        () async => const AudioCoverProviders(null, null, null),
      );
      expect(AudioCoverCache.providersCacheCount, equals(1));

      // 再次发生显著 DPI 变动
      AudioCoverCache.checkDpiAdaptation(baseRatio + 1.0);
      expect(AudioCoverCache.providersCacheCount, equals(0));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio + 1.0));
    });
  });
}
