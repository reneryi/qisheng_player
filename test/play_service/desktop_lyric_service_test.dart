import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/message.dart' as msg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/theme_provider.dart';

import '../test_helpers/media_test_harness.dart';

class FakeProcess implements Process {
  @override
  final int pid;
  final bool delayExit;
  final StreamController<List<int>> stdoutController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stdinController =
      StreamController<List<int>>();
  final Completer<int> exitCompleter = Completer<int>();
  bool killed = false;
  final List<String> stdinLines = [];

  FakeProcess({required this.pid, this.delayExit = false}) {
    stdinController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdinLines.add(line);
    });
  }

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  late final IOSink _stdin = IOSink(stdinController.sink);

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => exitCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigkill]) {
    killed = true;
    if (!delayExit && !exitCompleter.isCompleted) {
      exitCompleter.complete(signal == ProcessSignal.sigkill ? -9 : 0);
    }
    return true;
  }
}

class FailingStdoutProcess extends FakeProcess {
  FailingStdoutProcess({required super.pid, super.delayExit});

  @override
  Stream<List<int>> get stdout =>
      throw StateError('Failed to attach stdout pipe');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      (MethodCall call) async {
        switch (call.method) {
          case 'set_desktop_lyric_process':
            return null;
          case 'get_desktop_lyric_rect':
            return {'left': 100, 'top': 100, 'width': 400, 'height': 80};
          case 'set_desktop_lyric_position':
            return true;
          default:
            return null;
        }
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => '.',
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  test('desktop lyric messages are newline-delimited JSON frames', () {
    final playerStateFrame = buildDesktopLyricMessageFrame(
      const msg.PlayerStateChangedMessage(true),
    );
    final nowPlayingFrame = buildDesktopLyricMessageFrame(
      const msg.NowPlayingChangedMessage('Title', 'Artist', 'Album'),
    );
    final lyricFrame = buildDesktopLyricMessageFrame(
      const msg.LyricLineChangedMessage(
        'current lyric',
        Duration(seconds: 4),
      ),
    );

    final frames = const LineSplitter().convert(
      playerStateFrame + nowPlayingFrame + lyricFrame,
    );

    expect(playerStateFrame, endsWith('\n'));
    expect(nowPlayingFrame, endsWith('\n'));
    expect(lyricFrame, endsWith('\n'));
    expect(frames, hasLength(3));
    expect(
      json.decode(frames[0])['type'],
      msg.getMessageTypeName<msg.PlayerStateChangedMessage>(),
    );
    expect(
      json.decode(frames[1])['type'],
      msg.getMessageTypeName<msg.NowPlayingChangedMessage>(),
    );
    expect(
      json.decode(frames[2])['type'],
      msg.getMessageTypeName<msg.LyricLineChangedMessage>(),
    );
  });

  test('startDesktopLyric prevents concurrent double process launch (anti-reentrancy)', () async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.mp3',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final service = DesktopLyricService.forTest(playbackService: playback);
    service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

    var starterCallCount = 0;
    final procCompleter = Completer<Process>();
    final proc = FakeProcess(pid: 1234);

    service.processStarter = (exe, args, {workingDirectory}) {
      starterCallCount++;
      return procCompleter.future;
    };

    // First launch call
    final f1 = service.startDesktopLyric();
    // Synchronously set isStarting
    expect(service.isStarting, isTrue);

    // Second launch call while starting
    final f2 = service.startDesktopLyric();
    expect(service.isStarting, isTrue);

    // Let the first call proceed past await desktopLyric
    await pumpEventQueue();
    expect(starterCallCount, equals(1));

    procCompleter.complete(proc);
    await Future.wait([f1, f2]);

    expect(starterCallCount, equals(1));
    expect(service.desktopLyricPid, equals(1234));
    expect(service.isStarting, isFalse);

    await service.stopDesktopLyric(persistPreference: false);
  });

  test('multi-candidate retry: delayed exit of superseded candidate does not kill active candidate', () async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.mp3',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final service = DesktopLyricService.forTest(playbackService: playback);
    service.candidatesResolverOverride = () => [
          '/fake/cand1.exe',
          '/fake/cand2.exe',
        ];

    final proc1 = FailingStdoutProcess(pid: 1001, delayExit: true);
    final proc2 = FakeProcess(pid: 1002);
    var callCount = 0;

    service.processStarter = (exe, args, {workingDirectory}) async {
      callCount++;
      if (callCount == 1) {
        return proc1;
      } else {
        return proc2;
      }
    };

    await service.startDesktopLyric();

    expect(service.desktopLyricPid, equals(1002));
    final activeProc = await service.desktopLyric;
    expect(activeProc, equals(proc2));

    // Trigger delayed candidate 1 exitCode
    proc1.exitCompleter.complete(1);
    await pumpEventQueue();

    // Active candidate 2 must not be killed or reset by candidate 1 exit
    expect(service.desktopLyricPid, equals(1002));
    expect(await service.desktopLyric, equals(proc2));

    // Candidate 2 exits normally
    proc2.exitCompleter.complete(0);
    await pumpEventQueue();

    // Reset clean
    expect(service.desktopLyricPid, isNull);
    expect(await service.desktopLyric, isNull);
  });

  test('closing desktop lyric during position restore cancels timer and prevents timer leakage', () async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.mp3',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final service = DesktopLyricService.forTest(playbackService: playback);
    service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

    final proc = FakeProcess(pid: 2001);
    service.processStarter = (exe, args, {workingDirectory}) async => proc;

    // Start lyric
    final startFuture = service.startDesktopLyric();

    // Stop while in progress
    await service.stopDesktopLyric(persistPreference: false);
    await startFuture;

    expect(service.isPositionSyncTimerActive, isFalse);
    expect(service.desktopLyricPid, isNull);
  });

  test('stderr stream subscription is cancelled on cleanup', () async {
    final audio = TestAudio(
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\song.mp3',
    );
    final playback = FakePlaybackController(audio: audio, queue: [audio]);
    final service = DesktopLyricService.forTest(playbackService: playback);
    service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

    final proc = FakeProcess(pid: 3001);
    service.processStarter = (exe, args, {workingDirectory}) async => proc;

    await service.startDesktopLyric();
    expect(proc.stderrController.hasListener, isTrue);

    await service.stopDesktopLyric(persistPreference: false);
    expect(proc.stderrController.hasListener, isFalse);
  });

  group('IPC Message Protocol Serialization & Decoding Tests', () {
    test('InitArgsMessage serializes and deserializes with font and color flags', () {
      const original = msg.InitArgsMessage(
        true,
        'Test Title',
        'Test Artist',
        'Test Album',
        false,
        0xFF112233,
        0xFF223344,
        0xFF334455,
        lyricFontFamily: 'PingFang SC',
        followPlayerFont: false,
        hasSpecifiedColor: true,
        playerFontFamily: 'Segoe UI',
      );

      final jsonMap = original.toJson();
      expect(jsonMap['isPlaying'], isTrue);
      expect(jsonMap['lyricFontFamily'], 'PingFang SC');
      expect(jsonMap['followPlayerFont'], isFalse);
      expect(jsonMap['hasSpecifiedColor'], isTrue);
      expect(jsonMap['playerFontFamily'], 'Segoe UI');

      final restored = msg.InitArgsMessage.fromJson(jsonMap);
      expect(restored.isPlaying, isTrue);
      expect(restored.title, 'Test Title');
      expect(restored.primary, 0xFF112233);
      expect(restored.lyricFontFamily, 'PingFang SC');
      expect(restored.followPlayerFont, isFalse);
      expect(restored.hasSpecifiedColor, isTrue);
      expect(restored.playerFontFamily, 'Segoe UI');
    });

    test('InitArgsMessage backward compatibility with missing optional fields', () {
      final legacyJson = {
        'isPlaying': false,
        'title': 'Legacy Song',
        'artist': 'Legacy Artist',
        'album': 'Legacy Album',
        'darkMode': true,
        'primary': 0xFF998877,
        'surfaceContainer': 0xFF1E293B,
        'onSurface': 0xFFFFFFFF,
      };

      final restored = msg.InitArgsMessage.fromJson(legacyJson);
      expect(restored.lyricFontFamily, isNull);
      expect(restored.followPlayerFont, isTrue);
      expect(restored.hasSpecifiedColor, isFalse);
      expect(restored.playerFontFamily, isNull);
    });

    test('PreferenceChangedMessage handles null primary (follow theme) and font fields', () {
      const msgFollowTheme = msg.PreferenceChangedMessage(
        null,
        0xFF121212,
        0xFFE0E0E0,
        hasSpecifiedColor: false,
        lyricFontFamily: 'MiSans',
        followPlayerFont: false,
      );

      final frame = buildDesktopLyricMessageFrame(msgFollowTheme);
      expect(frame, endsWith('\n'));

      final jsonMap = json.decode(frame.trim()) as Map<String, dynamic>;
      expect(jsonMap['type'], msg.getMessageTypeName<msg.PreferenceChangedMessage>());
      final messageContent = jsonMap['message'] as Map<String, dynamic>;
      expect(messageContent['primary'], isNull);
      expect(messageContent['hasSpecifiedColor'], isFalse);
      expect(messageContent['lyricFontFamily'], 'MiSans');
      expect(messageContent['followPlayerFont'], isFalse);

      final restored = msg.PreferenceChangedMessage.fromJson(messageContent);
      expect(restored.primary, isNull);
      expect(restored.hasSpecifiedColor, isFalse);
      expect(restored.lyricFontFamily, 'MiSans');
      expect(restored.followPlayerFont, isFalse);
    });

    test('PlayerFontChangedMessage encoding and frame formatting', () {
      const fontMsg = msg.PlayerFontChangedMessage('HarmonyOS Sans');
      final frame = buildDesktopLyricMessageFrame(fontMsg);
      expect(frame, endsWith('\n'));

      final decoded = json.decode(frame.trim()) as Map<String, dynamic>;
      expect(decoded['type'], msg.getMessageTypeName<msg.PlayerFontChangedMessage>());
      final content = decoded['message'] as Map<String, dynamic>;
      expect(content['fontFamily'], 'HarmonyOS Sans');

      final restored = msg.PlayerFontChangedMessage.fromJson(content);
      expect(restored.fontFamily, 'HarmonyOS Sans');
    });
  });

  group('DesktopLyricService Protocol & Feature Tests', () {
    test('startDesktopLyric injects font and color parameters into InitArgsMessage', () async {
      final audio = TestAudio(
        title: 'LyricSong',
        artist: 'LyricArtist',
        album: 'LyricAlbum',
        path: r'E:\Music\lyric.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      AppPreference.instance.desktopLyricPref
        ..lyricFontFamily = 'CustomInjectedFont'
        ..followPlayerFont = false
        ..primary = 0xFF334455;
      AppSettings.instance.fontFamily = 'PlayerGlobalFont';

      List<String>? capturedArgs;
      final proc = FakeProcess(pid: 4001);
      service.processStarter = (exe, args, {workingDirectory}) async {
        capturedArgs = args;
        return proc;
      };

      await service.startDesktopLyric();

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.isNotEmpty, isTrue);

      final initJson = json.decode(capturedArgs![0]) as Map<String, dynamic>;
      final initArgs = msg.InitArgsMessage.fromJson(initJson);

      expect(initArgs.title, 'LyricSong');
      expect(initArgs.lyricFontFamily, 'CustomInjectedFont');
      expect(initArgs.followPlayerFont, isFalse);
      expect(initArgs.hasSpecifiedColor, isTrue);
      expect(initArgs.primary, 0xFF334455);
      expect(initArgs.playerFontFamily, 'PlayerGlobalFont');

      await service.stopDesktopLyric(persistPreference: false);
    });

    test('sendThemeMessage preserves primary == null when following player theme', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      // Scenario 1: User has NOT specified a fixed color (desktopLyricPref.primary == null)
      AppPreference.instance.desktopLyricPref.primary = null;

      final proc = FakeProcess(pid: 4002);
      service.processStarter = (exe, args, {workingDirectory}) async => proc;

      await service.startDesktopLyric();

      const testScheme1 = ColorScheme.dark(
        primary: Color(0xFF00F5D4),
        surfaceContainer: Color(0xFF131822),
        onSurface: Color(0xFFFFFFFF),
      );

      service.sendThemeMessage(testScheme1);

      // desktopLyricPref.primary MUST stay null so that subsequent theme changes still work!
      expect(AppPreference.instance.desktopLyricPref.primary, isNull);

      // Verify what was sent to subprocess stdin
      await pumpEventQueue();
      final themeLine = proc.stdinLines.lastWhere(
        (line) => json.decode(line)['type'] == msg.getMessageTypeName<msg.ThemeChangedMessage>(),
      );
      final themeMsg = msg.ThemeChangedMessage.fromJson(
        json.decode(themeLine)['message'] as Map<String, dynamic>,
      );
      expect(themeMsg.primary, const Color(0xFF00F5D4).toARGB32());

      // Scenario 2: User specified a fixed color (desktopLyricPref.primary != null)
      AppPreference.instance.desktopLyricPref.primary = 0xFFB388FF;

      const testScheme2 = ColorScheme.dark(
        primary: Color(0xFFFF5722),
        surfaceContainer: Color(0xFF131822),
        onSurface: Color(0xFFFFFFFF),
      );

      service.sendThemeMessage(testScheme2);

      // Fixed primary is retained
      expect(AppPreference.instance.desktopLyricPref.primary, 0xFFB388FF);

      await pumpEventQueue();
      final themeLine2 = proc.stdinLines.lastWhere(
        (line) => json.decode(line)['type'] == msg.getMessageTypeName<msg.ThemeChangedMessage>(),
      );
      final themeMsg2 = msg.ThemeChangedMessage.fromJson(
        json.decode(themeLine2)['message'] as Map<String, dynamic>,
      );
      expect(themeMsg2.primary, 0xFFB388FF);

      await service.stopDesktopLyric(persistPreference: false);
    });

    test('_handleDesktopLyricMessageMap handles PreferenceChangedMessage for color and font', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      final proc = FakeProcess(pid: 4003);
      service.processStarter = (exe, args, {workingDirectory}) async => proc;

      await service.startDesktopLyric();

      // Case 1: Custom color and font specified
      const msg1 = msg.PreferenceChangedMessage(
        0xFF00E5FF,
        0xFF111111,
        0xFFEEEEEE,
        hasSpecifiedColor: true,
        lyricFontFamily: 'Fira Code',
        followPlayerFont: false,
      );
      proc.stdoutController.add(utf8.encode(buildDesktopLyricMessageFrame(msg1)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.primary, 0xFF00E5FF);
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, 'Fira Code');
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // Case 2: Reset to follow player theme
      const msg2 = msg.PreferenceChangedMessage(
        null,
        0xFF111111,
        0xFFEEEEEE,
        hasSpecifiedColor: false,
      );
      proc.stdoutController.add(utf8.encode(buildDesktopLyricMessageFrame(msg2)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.primary, isNull);
      // Font should remain unchanged since msg2 didn't specify font
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, 'Fira Code');

      // Case 3: Switch font to follow player
      const msg3 = msg.PreferenceChangedMessage(
        null,
        0xFF111111,
        0xFFEEEEEE,
        hasSpecifiedColor: false,
        lyricFontFamily: null,
        followPlayerFont: true,
      );
      proc.stdoutController.add(utf8.encode(buildDesktopLyricMessageFrame(msg3)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, isNull);
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isTrue);

      await service.stopDesktopLyric(persistPreference: false);
    });

    test('STRICT ISOLATION: Desktop lyric font/color changes NEVER modify host player font or settings', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      final proc = FakeProcess(pid: 4004);
      service.processStarter = (exe, args, {workingDirectory}) async => proc;

      await service.startDesktopLyric();

      // Establish host player font baseline
      const hostInitialFont = 'HostMainPlayerFont';
      AppSettings.instance.fontFamily = hostInitialFont;
      ThemeProvider.instance.fontFamily = hostInitialFont;

      // Simulate desktop lyric subprocess sending font & color modifications
      const desktopLyricMsg = msg.PreferenceChangedMessage(
        0xFFFF0055,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: true,
        lyricFontFamily: 'DesktopIsolatedFont',
        followPlayerFont: false,
      );
      proc.stdoutController.add(utf8.encode(buildDesktopLyricMessageFrame(desktopLyricMsg)));
      await pumpEventQueue();

      // Desktop lyric preference must be updated
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, 'DesktopIsolatedFont');
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);
      expect(AppPreference.instance.desktopLyricPref.primary, 0xFFFF0055);

      // CRITICAL AUDIT ASSERTION: Host player settings and theme MUST remain untouched!
      expect(AppSettings.instance.fontFamily, hostInitialFont);
      expect(ThemeProvider.instance.fontFamily, hostInitialFont);

      await service.stopDesktopLyric(persistPreference: false);
    });

    test('sendPlayerFontChangedMessage writes PlayerFontChangedMessage frame to child stdin', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      final proc = FakeProcess(pid: 4005);
      service.processStarter = (exe, args, {workingDirectory}) async => proc;

      await service.startDesktopLyric();

      service.sendPlayerFontChangedMessage('NewPlayerFont');
      await pumpEventQueue();

      final fontLine = proc.stdinLines.lastWhere(
        (line) => json.decode(line)['type'] == msg.getMessageTypeName<msg.PlayerFontChangedMessage>(),
      );
      final fontMsg = msg.PlayerFontChangedMessage.fromJson(
        json.decode(fontLine)['message'] as Map<String, dynamic>,
      );
      expect(fontMsg.fontFamily, 'NewPlayerFont');

      await service.stopDesktopLyric(persistPreference: false);
    });

    test('ThemeProvider.changeFontFamily sends font change when followPlayerFont is true', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];
      final proc = FakeProcess(pid: 4006);
      service.processStarter = (exe, args, {workingDirectory}) async => proc;

      ThemeProvider.instance.desktopLyricServiceOverride = service;
      AppPreference.instance.desktopLyricPref.followPlayerFont = true;

      await service.startDesktopLyric();

      ThemeProvider.instance.changeFontFamily('NewHostFontLinked');
      await pumpEventQueue();

      final fontLine = proc.stdinLines.lastWhere(
        (line) => json.decode(line)['type'] == msg.getMessageTypeName<msg.PlayerFontChangedMessage>(),
      );
      final fontMsg = msg.PlayerFontChangedMessage.fromJson(
        json.decode(fontLine)['message'] as Map<String, dynamic>,
      );
      expect(fontMsg.fontFamily, 'NewHostFontLinked');

      await service.stopDesktopLyric(persistPreference: false);
      ThemeProvider.instance.desktopLyricServiceOverride = null;
    });

    test('ThemeProvider.changeFontFamily does NOT send font change when followPlayerFont is false', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];
      final proc = FakeProcess(pid: 4007);
      service.processStarter = (exe, args, {workingDirectory}) async => proc;

      ThemeProvider.instance.desktopLyricServiceOverride = service;
      AppPreference.instance.desktopLyricPref.followPlayerFont = false;

      await service.startDesktopLyric();

      final initialStdinCount = proc.stdinLines.length;

      ThemeProvider.instance.changeFontFamily('AnotherHostFontNotLinked');
      await pumpEventQueue();

      final hasFontMsg = proc.stdinLines.skip(initialStdinCount).any(
        (line) => json.decode(line)['type'] == msg.getMessageTypeName<msg.PlayerFontChangedMessage>(),
      );
      expect(hasFontMsg, isFalse);

      await service.stopDesktopLyric(persistPreference: false);
      ThemeProvider.instance.desktopLyricServiceOverride = null;
    });

    test('When desktop lyric is closed, switching theme updates preference and restart launches with new theme', () async {
      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];
      List<String>? capturedArgs;
      FakeProcess? capturedProc;
      service.processStarter = (exe, args, {workingDirectory}) async {
        capturedArgs = args;
        capturedProc = FakeProcess(pid: 4008);
        return capturedProc!;
      };

      ThemeProvider.instance.desktopLyricServiceOverride = service;

      // 1. Initially closed, switch to light mode
      ThemeProvider.instance.applyThemeMode(ThemeMode.light);
      await pumpEventQueue();
      final lightSurface = AppPreference.instance.desktopLyricPref.surfaceContainer;
      final lightOnSurface = AppPreference.instance.desktopLyricPref.onSurface;
      expect(lightSurface, isNotNull);
      expect(lightOnSurface, isNotNull);

      // 2. While still closed, switch to dark mode
      ThemeProvider.instance.applyThemeMode(ThemeMode.dark);
      await pumpEventQueue();
      final darkSurface = AppPreference.instance.desktopLyricPref.surfaceContainer;
      final darkOnSurface = AppPreference.instance.desktopLyricPref.onSurface;
      expect(darkSurface, isNotNull);
      expect(darkOnSurface, isNotNull);
      // Dark and light surfaces/onSurfaces should differ
      expect(darkOnSurface, isNot(equals(lightOnSurface)));

      // 3. Start desktop lyric in dark mode
      await service.startDesktopLyric();
      await pumpEventQueue();

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.isNotEmpty, isTrue);
      final initJson = json.decode(capturedArgs![0]) as Map<String, dynamic>;
      final initArgs = msg.InitArgsMessage.fromJson(initJson);
      expect(initArgs.darkMode, isTrue);
      expect(initArgs.surfaceContainer, equals(darkSurface));
      expect(initArgs.onSurface, equals(darkOnSurface));

      final hasThemeModeMsg = capturedProc!.stdinLines.any((line) {
        final decoded = json.decode(line);
        return decoded['type'] == msg.getMessageTypeName<msg.ThemeModeChangedMessage>() &&
            decoded['message']['darkMode'] == true;
      });
      expect(hasThemeModeMsg, isTrue);

      final themeLine = capturedProc!.stdinLines.lastWhere(
        (line) => json.decode(line)['type'] == msg.getMessageTypeName<msg.ThemeChangedMessage>(),
      );
      final themeMsg = msg.ThemeChangedMessage.fromJson(
        json.decode(themeLine)['message'] as Map<String, dynamic>,
      );
      expect(themeMsg.surfaceContainer, equals(darkSurface));
      expect(themeMsg.onSurface, equals(darkOnSurface));

      await service.stopDesktopLyric(persistPreference: false);
      ThemeProvider.instance.desktopLyricServiceOverride = null;
    });
  });
}
