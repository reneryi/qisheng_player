import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/page/playlists_page.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/smtc_flutter.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/utils.dart';

import '../test_helpers/media_test_harness.dart';

class _TestFakeSmtc implements SmtcFlutter {
  final _controller = StreamController<SMTCControlEvent>.broadcast();
  bool _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> close() async => _controller.close();

  @override
  Stream<SMTCControlEvent> subscribeToControlEvents() => _controller.stream;

  @override
  Future<void> updateDisplay({
    required String title,
    required String artist,
    required String album,
    required int duration,
    required String path,
  }) async {}

  @override
  Future<void> updateState({required SMTCState state}) async {}

  @override
  Future<void> updateTimeProperties({required int progress}) async {}
}

ThemeData _buildTestTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _TestFakeSmtc fakeSmtc;
  late PlaybackService testPlayback;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qisheng_playlist_btn_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    PLAYLISTS.clear();

    fakeSmtc = _TestFakeSmtc();
    testPlayback = PlaybackService(
      PlayService.instance,
      player: BassPlayer(),
      smtc: fakeSmtc,
      preferenceOverride: PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      ),
    );
    PlayService.setPlaybackServiceForTesting(testPlayback);
  });

  tearDown(() async {
    PlayService.setPlaybackServiceForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    PLAYLISTS.clear();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('PlaylistsPage renders Play button for each playlist', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final testAudio = TestAudio(
      path: r'E:\Music\song1.flac',
      title: 'Song 1',
      artist: 'Artist 1',
      album: 'Album 1',
    );

    PLAYLISTS.addAll([
      Playlist('我的最爱', {testAudio.path: testAudio}),
      Playlist('空白歌单', {}),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: SCAFFOLD_MESSAGER,
        theme: _buildTestTheme(),
        home: const Scaffold(
          body: PlaylistsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 验证播放按钮存在
    expect(find.byKey(const ValueKey('play-playlist-我的最爱')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-playlist-空白歌单')), findsOneWidget);

    // 点击非空歌单播放
    await tester.tap(find.byKey(const ValueKey('play-playlist-我的最爱')));
    await tester.pumpAndSettle();

    // 验证播放列表已加载
    expect(PlayService.instance.playbackService.playlist.value, isNotEmpty);
    expect(PlayService.instance.playbackService.playlist.value.first.title, 'Song 1');
    expect(find.text('开始播放歌单“我的最爱”'), findsOneWidget);

    // 点击空歌单播放，触发阻断提示
    await tester.tap(find.byKey(const ValueKey('play-playlist-空白歌单')));
    await tester.pumpAndSettle();

    expect(find.text('歌单“空白歌单”为空，暂无歌曲可播放'), findsOneWidget);
  });
}
