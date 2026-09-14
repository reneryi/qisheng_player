import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/build_index_state_view.dart';
import 'package:qisheng_player/component/fluid_gradient_background.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/page/updating_page.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/window_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appDataDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_adversarial_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    appDataDir = await getAppDataDir();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // =========================================================================
  // R3: Stream Lifecycle & Scan Dialog Rapid Open/Close Stress Harness
  // =========================================================================
  group('R3: Stream Lifecycle & Scan Dialog Rapid Open/Close Stress Harness', () {
    testWidgets(
      'Rapid dialog open and close (50 cycles) under high-speed active stream emissions '
      'causes NO memory leaks, NO setState on unmounted, and NO unhandled exceptions',
      (WidgetTester tester) async {
        int whenIndexBuiltCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Root'),
                ),
              ),
            ),
          ),
        );

        // Run 50 rapid mount/unmount stress iterations
        for (int iteration = 0; iteration < 50; iteration++) {
          final streamController = StreamController<IndexActionState>.broadcast();
          bool dialogCompleted = false;

          final BuildContext rootContext = tester.element(find.byType(Scaffold));

          // Open dialog
          showDialog(
            context: rootContext,
            builder: (dialogCtx) => Dialog(
              child: BuildIndexStateView(
                indexPath: Directory('${tempDir.path}\\dummy_index_$iteration'),
                folders: ['folder_$iteration'],
                whenIndexBuilt: () {
                  dialogCompleted = true;
                  whenIndexBuiltCalls++;
                  if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) {
                    Navigator.of(dialogCtx, rootNavigator: true).pop();
                  }
                },
                streamOverride: streamController.stream,
              ),
            ),
          );

          await tester.pump();
          expect(find.byType(BuildIndexStateView), findsOneWidget);

          // Emit rapid burst of events
          for (int eventIdx = 0; eventIdx < 10; eventIdx++) {
            streamController.add(
              IndexActionState(
                progress: (eventIdx + 1) / 10.0,
                message: 'Scanning chunk $eventIdx for iter $iteration',
              ),
            );
          }
          await tester.pump();

          if (iteration % 2 == 0) {
            // Adversarial branch A: User cancels/closes dialog while stream is still running
            Navigator.of(rootContext, rootNavigator: true).pop();
            await tester.pump();
            expect(find.byType(BuildIndexStateView), findsNothing);

            // Stream continues to emit AFTER dialog was closed
            streamController.add(
              const IndexActionState(progress: 0.95, message: 'Late event'),
            );
            if (iteration % 4 == 0) {
              // Inject error post-dispose
              streamController.addError(
                const FileSystemException('Post-dispose IO error', '/path'),
              );
            }
            await streamController.close();
            await tester.pump();

            // Callback must NOT have fired because dialog was prematurely closed
            expect(dialogCompleted, isFalse);
          } else {
            // Adversarial branch B: Stream completes normally
            await streamController.close();
            await tester.pump();
            expect(dialogCompleted, isTrue);
          }

          // Ensure zero uncaught FlutterError occurred during this cycle
          expect(tester.takeException(), isNull);
        }

        expect(whenIndexBuiltCalls, equals(25));
      },
    );

    testWidgets(
      'UpdatingStateView rapid mount/unmount churn with concurrent stream errors and done '
      'guards against unmounted setState and context navigation',
      (WidgetTester tester) async {
        for (int i = 0; i < 30; i++) {
          final streamController = StreamController<IndexActionState>.broadcast();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: UpdatingStateView(
                  indexPath: tempDir,
                  streamOverride: streamController.stream,
                ),
              ),
            ),
          );

          expect(find.byType(UpdatingStateView), findsOneWidget);

          // Emit progress
          streamController.add(
            const IndexActionState(progress: 0.3, message: 'Updating index...'),
          );
          await tester.pump();

          // Immediately unmount
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: SizedBox()),
            ),
          );
          await tester.pump();
          expect(find.byType(UpdatingStateView), findsNothing);

          // Post-unmount emissions: error and close
          if (i % 2 == 0) {
            streamController.addError(
              Exception('Network share disconnected mid-update'),
            );
          }
          await streamController.close();
          await tester.pump();

          // Ensure zero uncaught exceptions
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  // =========================================================================
  // R4: Performance & Dynamic Shader Ticker Invalidation Harness
  // =========================================================================
  group('R4: Performance & Dynamic Shader Ticker Invalidation Harness', () {
    testWidgets(
      'FluidGradientBackground ticker strictly halts on static background, hidden app, '
      'and minimized window, and survives complex combinatorial state transitions',
      (WidgetTester tester) async {
        final provider = ThemeProvider.instance;
        final prevBackdrop = provider.windowBackdropMode;
        final prevEffects = provider.uiEffectsLevel;
        final prevBgPath = AppSettings.instance.backgroundImagePath;

        final dummyImageFile = File('${tempDir.path}\\custom_bg.png')
          ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

        addTearDown(() {
          provider.windowBackdropMode = prevBackdrop;
          provider.uiEffectsLevel = prevEffects;
          AppSettings.instance.backgroundImagePath = prevBgPath;
          AppSettings.instance.notifyBackgroundChanged();
          WindowControls.isWindowVisible.value = true;
        });

        provider.windowBackdropMode = WindowBackdropMode.meshFlow;
        AppSettings.instance.backgroundImagePath = null;
        WindowControls.isWindowVisible.value = true;

        Widget buildApp() {
          return ChangeNotifierProvider<ThemeProvider>.value(
            value: provider,
            child: MaterialApp(
              theme: AppTheme.build(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
                effectsLevel: UiEffectsLevel.balanced,
                windowBackdropMode: WindowBackdropMode.meshFlow,
              ),
              home: const FluidGradientBackground(
                child: SizedBox(key: ValueKey('test_surface')),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildApp());
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 50));

        final state = tester.state<FluidGradientBackgroundState>(
          find.byType(FluidGradientBackground),
        );
        expect(state.isTickerActive, isTrue);

        // 1. Static background image stops ticker
        AppSettings.instance.backgroundImagePath = dummyImageFile.path;
        AppSettings.instance.notifyBackgroundChanged();
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        // 2. Clear static background restores ticker
        AppSettings.instance.backgroundImagePath = null;
        AppSettings.instance.notifyBackgroundChanged();
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isTrue);

        // 3. AppLifecycleState.hidden stops ticker
        state.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        // 4. AppLifecycleState.resumed restores ticker
        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isTrue);

        // 5. AppLifecycleState.paused stops ticker
        state.didChangeAppLifecycleState(AppLifecycleState.paused);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isTrue);

        // 6. WindowControls.isWindowVisible = false stops ticker
        WindowControls.isWindowVisible.value = false;
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        // 7. Window restore restores ticker
        WindowControls.isWindowVisible.value = true;
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isTrue);

        // 8. Combinatorial test: Minimized + Hidden + Static Background
        WindowControls.isWindowVisible.value = false;
        state.didChangeAppLifecycleState(AppLifecycleState.hidden);
        AppSettings.instance.backgroundImagePath = dummyImageFile.path;
        AppSettings.instance.notifyBackgroundChanged();
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        // Partially restore: unhide app (still minimized and still static image)
        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        // Partially restore: restore window (still static image)
        WindowControls.isWindowVisible.value = true;
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isFalse);

        // Final restore: remove static image -> now all conditions clear -> ticker resumes!
        AppSettings.instance.backgroundImagePath = null;
        AppSettings.instance.notifyBackgroundChanged();
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isTickerActive, isTrue);
      },
    );

    test('Stress test compute(parseIndexInIsolate) with 5,000 tracks across 50 albums', () async {
      final largeIndexPath = '${tempDir.path}\\large_index.json';
      final roots = [r'D:\Music\HiRes', r'E:\Lossless\Library'];

      final folders = <Map<String, dynamic>>[];
      int trackIdCounter = 0;

      for (int f = 0; f < 50; f++) {
        final audios = <Map<String, dynamic>>[];
        for (int a = 0; a < 100; a++) {
          trackIdCounter++;
          audios.add({
            'title': 'Track $trackIdCounter',
            'artist': 'Artist ${f % 10} / Featured ${a % 5}',
            'album': 'Album $f',
            'disc': 1,
            'track': a + 1,
            'duration': 180 + (a % 60),
            'bitrate': 1411,
            'sample_rate': 44100,
            'path': 'D:\\Music\\HiRes\\Album_$f\\track_$a.flac',
            'modified': 1726000000 + trackIdCounter,
            'created': 1726000000,
            'by': 'Lofty',
          });
        }
        folders.add({
          'path': 'D:\\Music\\HiRes\\Album_$f',
          'modified': 1726000000 + f,
          'latest': 1726000000 + f * 10,
          'pending_retry': f % 5 == 0, // 10 out of 50 folders are pending retry
          'audios': audios,
        });
      }

      final largeIndexJson = {
        'version': 114,
        'roots': roots,
        'folders': folders,
      };

      File(largeIndexPath).writeAsStringSync(json.encode(largeIndexJson));

      final stopwatch = Stopwatch()..start();
      final payload = IndexParsePayload(largeIndexPath, r'[、/]');
      final result = await compute(parseIndexInIsolate, payload);
      stopwatch.stop();

      expect(result.isEmpty, isFalse);
      expect(result.version, equals(114));
      expect(result.roots, equals(roots));
      expect(result.folders.length, equals(50));

      // Verify total audio count parsed across isolates
      final totalAudios = result.folders.fold<int>(
        0,
        (sum, folder) => sum + folder.audios.length,
      );
      expect(totalAudios, equals(5000));

      // Verify pendingRetry was preserved
      final pendingRetryFolders =
          result.folders.where((f) => f.pendingRetry).length;
      expect(pendingRetryFolders, equals(10));

      // Verify multi-artist splitting occurred properly across isolates
      final firstAudio = result.folders.first.audios.first;
      expect(firstAudio.splitedArtists, contains('Artist 0'));
      expect(firstAudio.splitedArtists, contains('Featured 0'));

      // Ensure execution time is reasonable for 5,000 items in isolate
      expect(stopwatch.elapsedMilliseconds, lessThan(8000));
    });

    test('compute(parseIndexInIsolate) adversarial payload rejection', () async {
      // 1. Missing folders array
      final brokenPath1 = '${tempDir.path}\\broken_no_folders.json';
      File(brokenPath1).writeAsStringSync(json.encode({'version': 114}));
      expect(
        () => compute(parseIndexInIsolate, IndexParsePayload(brokenPath1, r'[、/]')),
        throwsA(isA<FormatException>()),
      );

      // 2. Corrupted JSON syntax
      final brokenPath2 = '${tempDir.path}\\broken_syntax.json';
      File(brokenPath2).writeAsStringSync('{invalid_json: 1234');
      expect(
        () => compute(parseIndexInIsolate, IndexParsePayload(brokenPath2, r'[、/]')),
        throwsA(isA<FormatException>()),
      );

      // 3. Invalid audio entry in folder
      final brokenPath3 = '${tempDir.path}\\broken_audio_entry.json';
      File(brokenPath3).writeAsStringSync(json.encode({
        'version': 114,
        'folders': [
          {
            'path': r'C:\Music',
            'audios': ['not_a_map_object'],
          }
        ]
      }));
      expect(
        () => compute(parseIndexInIsolate, IndexParsePayload(brokenPath3, r'[、/]')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // =========================================================================
  // R5: Store Robustness & Cover Validation Adversarial Harness
  // =========================================================================
  group('R5: Store Robustness & Cover Validation Adversarial Harness', () {
    test('PlayCountStore: corrupted JSON blocks save overwrite and recovers on valid read', () async {
      final filePath = '${appDataDir.path}\\play_count.json';
      final file = File(filePath);

      const corruptedContent = '<<<CORRUPTED_PLAY_COUNT_JSON>>!';
      file.writeAsStringSync(corruptedContent);

      final store = PlayCountStore.instance;
      store.resetLoadedForTesting(loaded: false);

      // 1. Attempt read -> fails cleanly, isLoaded stays false
      await store.read();
      expect(store.isLoaded, isFalse);

      // 2. Attempt save while not loaded -> blocked, disk file untouched
      await store.save();
      expect(file.readAsStringSync(), equals(corruptedContent));

      // 3. Provide valid JSON on disk
      file.writeAsStringSync(json.encode({'song_alpha.flac': 88}));

      // 4. Retry read -> succeeds, isLoaded becomes true
      await store.read();
      expect(store.isLoaded, isTrue);
      expect(store.getByPath('song_alpha.flac'), equals(88));

      // 5. Subsequent save works
      await store.increaseByPath('song_alpha.flac');
      await store.save();
      final saved = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(saved['song_alpha.flac'], equals(89));
    });

    test('AudioMetadataOverrideStore: corrupted JSON blocks save and recovers on valid read', () async {
      final filePath = '${appDataDir.path}\\audio_override.json';
      final file = File(filePath);

      const corruptedContent = '[INVALID_ARRAY_INSTEAD_OF_MAP]';
      file.writeAsStringSync(corruptedContent);

      final store = AudioMetadataOverrideStore.instance;
      store.resetLoadedForTesting(loaded: false);

      await store.read();
      expect(store.isLoaded, isFalse);

      await store.save();
      expect(file.readAsStringSync(), equals(corruptedContent));

      // Provide valid override data
      file.writeAsStringSync(json.encode({
        r'C:\Music\song.mp3': {
          'title': 'New Title',
          'artist': 'New Artist',
        }
      }));

      await store.read();
      expect(store.isLoaded, isTrue);
    });

    test('OnlineCoverStore: corrupted JSON blocks save and recovers on valid read', () async {
      final filePath = '${appDataDir.path}\\cover_cache.json';
      final file = File(filePath);

      const corruptedContent = '<html>502 Bad Gateway</html>';
      file.writeAsStringSync(corruptedContent);

      final store = OnlineCoverStore.instance;
      store.resetLoadedForTesting(loaded: false);

      await store.read();
      expect(store.isLoaded, isFalse);

      await store.save();
      expect(file.readAsStringSync(), equals(corruptedContent));

      file.writeAsStringSync(json.encode({
        r'C:\Music\song.mp3': r'C:\Cache\song.jpg',
      }));

      await store.read();
      expect(store.isLoaded, isTrue);
    });

    test('Magic bytes rejection matrix: HTML, GIF, WebP, truncated buffers safely rejected', () {
      // 1. Truncated 0-byte, 1-byte, 2-byte, 3-byte buffers
      expect(isJpegBytes(Uint8List(0)), isFalse);
      expect(isJpegBytes(Uint8List.fromList([0xFF])), isFalse);
      expect(isJpegBytes(Uint8List.fromList([0xFF, 0xD8])), isFalse);

      expect(isPngBytes(Uint8List(0)), isFalse);
      expect(isPngBytes(Uint8List.fromList([0x89])), isFalse);
      expect(isPngBytes(Uint8List.fromList([0x89, 0x50, 0x4E])), isFalse);

      // 2. HTML document bytes
      final htmlBytes = Uint8List.fromList('<!DOCTYPE html><html><head></head></html>'.codeUnits);
      expect(isJpegBytes(htmlBytes), isFalse);
      expect(isPngBytes(htmlBytes), isFalse);
      expect(detectCoverExtension(htmlBytes), isNull);

      // 3. GIF89a / GIF87a bytes
      final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00]);
      expect(isJpegBytes(gifBytes), isFalse);
      expect(isPngBytes(gifBytes), isFalse);
      expect(detectCoverExtension(gifBytes), isNull);

      // 4. WebP bytes (RIFF....WEBP)
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x20, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      expect(isJpegBytes(webpBytes), isFalse);
      expect(isPngBytes(webpBytes), isFalse);
      expect(detectCoverExtension(webpBytes), isNull);

      // 5. Valid JPEG bytes
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
      expect(isJpegBytes(jpegBytes), isTrue);
      expect(isPngBytes(jpegBytes), isFalse);
      expect(detectCoverExtension(jpegBytes), equals('.jpg'));

      // 6. Valid PNG bytes
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(isJpegBytes(pngBytes), isFalse);
      expect(isPngBytes(pngBytes), isTrue);
      expect(detectCoverExtension(pngBytes), equals('.png'));
    });

    test('OnlineCoverStore.setCoverFromUrl rejects invalid streams and accepts valid JPEG/PNG via live loopback server', () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;

      // Start a real loopback HTTP server to empirically test network stream handling
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverPort = server.port;

      final validJpegData = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0xFF, 0xD9,
      ]);
      final validPngData = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      ]);
      final fakeJpegHtmlData = Uint8List.fromList('<html>Error 404</html>'.codeUnits);
      final gifData = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00]);
      final webpData = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);

      server.listen((HttpRequest request) {
        final path = request.uri.path;
        if (path == '/valid_jpeg') {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add(validJpegData);
        } else if (path == '/valid_png') {
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(validPngData);
        } else if (path == '/fake_jpeg_html') {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add(fakeJpegHtmlData);
        } else if (path == '/gif') {
          request.response.headers.contentType = ContentType('image', 'gif');
          request.response.add(gifData);
        } else if (path == '/webp') {
          request.response.headers.contentType = ContentType('image', 'webp');
          request.response.add(webpData);
        } else if (path == '/truncated_1byte') {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add([0xFF]);
        } else if (path == '/html_content_type') {
          request.response.headers.contentType = ContentType('text', 'html');
          request.response.add(fakeJpegHtmlData);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        request.response.close();
      });

      addTearDown(() async {
        HttpOverrides.global = prevHttpOverrides;
        await server.close(force: true);
      });

      final store = OnlineCoverStore.instance;
      final dummyAudio = Audio(
        'Sample Track',
        'Sample Artist',
        'Sample Album',
        null,
        null,
        1,
        1,
        200,
        null,
        null,
        null,
        null,
        null,
        null,
        '${tempDir.path}\\sample.flac',
        1700000000,
        1700000000,
        null,
      );

      // 1. Rejects ContentType text/html
      final resHtml = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/html_content_type',
        targetPath: '${dummyAudio.path}_html',
      );
      expect(resHtml, isNull);

      // 2. Rejects ContentType image/gif
      final resGif = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/gif',
        targetPath: '${dummyAudio.path}_gif',
      );
      expect(resGif, isNull);

      // 3. Rejects ContentType image/webp
      final resWebp = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/webp',
        targetPath: '${dummyAudio.path}_webp',
      );
      expect(resWebp, isNull);

      // 4. Rejects fake JPEG with HTML body despite image/jpeg header
      final resFakeJpeg = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/fake_jpeg_html',
        targetPath: '${dummyAudio.path}_fake_jpeg',
      );
      expect(resFakeJpeg, isNull);

      // 5. Rejects truncated 1-byte buffer
      final resTruncated = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/truncated_1byte',
        targetPath: '${dummyAudio.path}_truncated',
      );
      expect(resTruncated, isNull);

      // 6. Accepts genuine JPEG
      final resValidJpeg = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/valid_jpeg',
        targetPath: '${dummyAudio.path}_valid_jpeg',
      );
      expect(resValidJpeg, isNotNull);
      expect(resValidJpeg, isA<FileImage>());
      final jpegFile = (resValidJpeg as FileImage).file;
      expect(jpegFile.existsSync(), isTrue);
      expect(jpegFile.path.endsWith('.jpg'), isTrue);

      // 7. Accepts genuine PNG
      final resValidPng = await store.setCoverFromUrl(
        audio: dummyAudio,
        url: 'http://127.0.0.1:$serverPort/valid_png',
        targetPath: '${dummyAudio.path}_valid_png',
      );
      expect(resValidPng, isNotNull);
      expect(resValidPng, isA<FileImage>());
      final pngFile = (resValidPng as FileImage).file;
      expect(pngFile.existsSync(), isTrue);
      expect(pngFile.path.endsWith('.png'), isTrue);
    });

    test('AudioCoverCache DPI adaptation threshold and LRU capacity under stress', () async {
      AudioCoverCache.clearAll();
      final baseRatio = ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ?? 1.0;
      AudioCoverCache.checkDpiAdaptation(baseRatio);
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio));

      // Fill 5 entries
      for (int i = 0; i < 5; i++) {
        await AudioCoverCache.getProviders(
          'item_$i',
          () async => const AudioCoverProviders(null, null, null),
        );
      }
      expect(AudioCoverCache.providersCacheCount, equals(5));

      // Delta 0.04 <= 0.05 -> cache preserved
      AudioCoverCache.checkDpiAdaptation(baseRatio + 0.04);
      expect(AudioCoverCache.providersCacheCount, equals(5));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio));

      // Delta exactly 0.05 <= 0.05 -> cache preserved
      AudioCoverCache.checkDpiAdaptation(baseRatio + 0.05);
      expect(AudioCoverCache.providersCacheCount, equals(5));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio));

      // Delta 0.05001 > 0.05 -> cache cleared!
      AudioCoverCache.checkDpiAdaptation(baseRatio + 0.05001);
      expect(AudioCoverCache.providersCacheCount, equals(0));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio + 0.05001));

      // Re-populate and jump to another DPI (diff > 0.05) -> cleared!
      await AudioCoverCache.getProviders(
        'item_retina',
        () async => const AudioCoverProviders(null, null, null),
      );
      expect(AudioCoverCache.providersCacheCount, equals(1));

      AudioCoverCache.checkDpiAdaptation(baseRatio + 1.0);
      expect(AudioCoverCache.providersCacheCount, equals(0));
      expect(AudioCoverCache.lastDpiRatio, equals(baseRatio + 1.0));

      // LRU stress test: fill 320 items, assert maxProvidersEntries (300) bound holds
      for (int i = 0; i < 320; i++) {
        await AudioCoverCache.getProviders(
          'lru_key_$i',
          () async => const AudioCoverProviders(null, null, null),
        );
      }
      expect(AudioCoverCache.providersCacheCount, equals(AudioCoverCache.maxProvidersEntries));
      expect(AudioCoverCache.providersCacheCount, equals(300));
    });
  });
}
