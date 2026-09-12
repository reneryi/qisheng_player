import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/message.dart' as msg;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';

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

  FakeProcess({required this.pid, this.delayExit = false});

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  IOSink get stdin => IOSink(stdinController.sink);

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
}
