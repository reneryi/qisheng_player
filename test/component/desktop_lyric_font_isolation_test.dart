import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/message.dart' as msg;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/theme_provider.dart';

import '../test_helpers/media_test_harness.dart';

class IsolationFakeProcess implements Process {
  @override
  final int pid;
  final StreamController<List<int>> stdoutController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stdinController =
      StreamController<List<int>>();
  final Completer<int> exitCompleter = Completer<int>();
  final List<String> stdinLines = [];

  IsolationFakeProcess({required this.pid}) {
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
    if (!exitCompleter.isCompleted) {
      exitCompleter.complete(0);
    }
    return true;
  }
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
            return {'left': 120, 'top': 120, 'width': 500, 'height': 90};
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

  group('Desktop Lyric Font & Theme Strict Isolation Tests', () {
    const String hostOriginalFont = 'HostMainExclusiveFont';

    late DesktopLyricService service;
    late IsolationFakeProcess fakeProcess;

    setUp(() async {
      // 1. Establish strict host player baseline
      AppSettings.instance.fontFamily = hostOriginalFont;
      ThemeProvider.instance.fontFamily = hostOriginalFont;

      final audio = TestAudio(
        title: 'Isolation Song',
        artist: 'Isolation Artist',
        album: 'Isolation Album',
        path: r'E:\Music\isolation.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      fakeProcess = IsolationFakeProcess(pid: 9901);
      service.processStarter = (exe, args, {workingDirectory}) async =>
          fakeProcess;

      await service.startDesktopLyric();
    });

    tearDown(() async {
      await service.stopDesktopLyric(persistPreference: false);
    });

    test('Isolation Requirement 1: Selecting custom font in desktop lyric NEVER modifies host AppSettings or ThemeProvider',
        () async {
      const customFontName = 'SourceHanSansCN-Heavy';

      // Desktop lyric subprocess sends custom font change
      const fontMsg = msg.PreferenceChangedMessage(
        null,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: false,
        lyricFontFamily: customFontName,
        followPlayerFont: false,
      );
      fakeProcess.stdoutController
          .add(utf8.encode(buildDesktopLyricMessageFrame(fontMsg)));
      await pumpEventQueue();

      // Verify desktop lyric preference was updated
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
          equals(customFontName));
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // Verify ABSOLUTE ISOLATION: Host AppSettings and ThemeProvider strictly unchanged!
      expect(AppSettings.instance.fontFamily, equals(hostOriginalFont));
      expect(ThemeProvider.instance.fontFamily, equals(hostOriginalFont));
    });

    test('Isolation Requirement 2: Switching to System Default in desktop lyric NEVER modifies host font',
        () async {
      // First set a custom font
      AppPreference.instance.desktopLyricPref.lyricFontFamily = 'SomeOldFont';
      AppPreference.instance.desktopLyricPref.followPlayerFont = false;

      // Subprocess switches to System Default (lyricFontFamily: null, followPlayerFont: false)
      const defaultMsg = msg.PreferenceChangedMessage(
        null,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: false,
        lyricFontFamily: null,
        followPlayerFont: false,
      );
      fakeProcess.stdoutController
          .add(utf8.encode(buildDesktopLyricMessageFrame(defaultMsg)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, isNull);
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // Verify host font remains completely isolated
      expect(AppSettings.instance.fontFamily, equals(hostOriginalFont));
      expect(ThemeProvider.instance.fontFamily, equals(hostOriginalFont));
    });

    test('Isolation Requirement 3: Switching to Follow Player in desktop lyric NEVER mutates host font',
        () async {
      // Subprocess switches to Follow Player (lyricFontFamily: null, followPlayerFont: true)
      const followMsg = msg.PreferenceChangedMessage(
        null,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: false,
        lyricFontFamily: null,
        followPlayerFont: true,
      );
      fakeProcess.stdoutController
          .add(utf8.encode(buildDesktopLyricMessageFrame(followMsg)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, isNull);
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isTrue);

      // Verify host font remains completely isolated
      expect(AppSettings.instance.fontFamily, equals(hostOriginalFont));
      expect(ThemeProvider.instance.fontFamily, equals(hostOriginalFont));
    });

    test('Isolation Requirement 4: Custom colors & fonts combined NEVER contaminate host ThemeProvider',
        () async {
      const customColor = 0xFFFF0055;
      const customFont = 'SimSun-ExtB';

      const combinedMsg = msg.PreferenceChangedMessage(
        customColor,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: true,
        lyricFontFamily: customFont,
        followPlayerFont: false,
      );
      fakeProcess.stdoutController
          .add(utf8.encode(buildDesktopLyricMessageFrame(combinedMsg)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.primary, equals(customColor));
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
          equals(customFont));
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // Strict isolation assertions
      expect(AppSettings.instance.fontFamily, equals(hostOriginalFont));
      expect(ThemeProvider.instance.fontFamily, equals(hostOriginalFont));
    });

    test('Isolation Requirement 5: Stress test with rapid stream of diverse font IPC messages preserves host font',
        () async {
      final testFonts = [
        'FontAlpha',
        'FontBeta',
        null,
        'FontGamma',
        'FontDelta',
        '霞鹜文楷',
        null,
        'MiSans Bold',
      ];

      for (int i = 0; i < testFonts.length; i++) {
        final font = testFonts[i];
        final follow = i % 2 == 0;
        final message = msg.PreferenceChangedMessage(
          null,
          0xFF1E293B,
          0xFFFFFFFF,
          hasSpecifiedColor: false,
          lyricFontFamily: font,
          followPlayerFont: follow,
        );
        fakeProcess.stdoutController
            .add(utf8.encode(buildDesktopLyricMessageFrame(message)));
        await pumpEventQueue();

        expect(AppSettings.instance.fontFamily, equals(hostOriginalFont),
            reason: 'Host AppSettings.fontFamily was contaminated at iteration $i');
        expect(ThemeProvider.instance.fontFamily, equals(hostOriginalFont),
            reason: 'Host ThemeProvider.fontFamily was contaminated at iteration $i');
      }
    });

    test('Isolation Requirement 6: 60+ consecutive adversarial font switches & resets guarantee 100% host player font and theme isolation',
        () async {
      final initialScheme = ThemeProvider.instance.currScheme;
      final initialPrimary = initialScheme.primary;

      final List<String?> stressFonts = [
        'Segoe UI', 'Arial', 'Roboto', 'Times New Roman', 'Microsoft YaHei',
        'PingFang SC', 'SimSun', 'SimHei', 'KaiTi', 'FangSong',
        '霞鹜文楷', '思源黑体 Heavy', '思源宋体 Light', 'HarmonyOS Sans', 'MiSans',
        'Fira Code', 'JetBrains Mono', 'Cascadia Code', 'Consolas', 'Courier New',
        'Comic Sans MS', 'Papyrus', 'Impact', 'Trebuchet MS', 'Century Gothic',
        'Georgia', 'Garamond', 'Palatino', 'Bookman', 'Avant Garde',
        'Ubuntu', 'Cantarell', 'DejaVu Sans', 'Liberation Mono', 'Open Sans',
        'Lato', 'Montserrat', 'Oswald', 'Raleway', 'PT Sans',
        'Merriweather', 'Noto Sans CJK SC', 'Noto Serif CJK SC', 'Source Han Sans', 'Source Han Serif',
        '汉仪旗黑', '方正兰亭黑', '文泉驿微米黑', '苹方-简', '冬青黑体',
        'Hiragino Sans', 'Yu Gothic', 'Meiryo', 'Malgun Gothic', 'Nanum Gothic',
        null, '', '   ', 'FontWithEmojis 🎵🚀', 'Unicode_𠮷野家',
        null, 'FinalStressFont2026',
      ];

      expect(stressFonts.length, greaterThanOrEqualTo(50));

      for (int i = 0; i < stressFonts.length; i++) {
        final font = stressFonts[i];
        final follow = (i % 3 == 0);
        final color = 0xFF000000 | ((i * 0x050709) & 0x00FFFFFF);

        final message = msg.PreferenceChangedMessage(
          color,
          0xFF1E293B,
          0xFFFFFFFF,
          hasSpecifiedColor: true,
          lyricFontFamily: font,
          followPlayerFont: follow,
        );

        fakeProcess.stdoutController
            .add(utf8.encode(buildDesktopLyricMessageFrame(message)));
        await pumpEventQueue();

        // 1. Desktop lyric preference is properly updated
        expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, equals(font),
            reason: 'Iteration $i: desktopLyricPref.lyricFontFamily should be $font');
        expect(AppPreference.instance.desktopLyricPref.followPlayerFont, equals(follow),
            reason: 'Iteration $i: desktopLyricPref.followPlayerFont should be $follow');

        // 2. CRITICAL ISOLATION: Host AppSettings and ThemeProvider 100% UNTOUCHED
        expect(AppSettings.instance.fontFamily, equals(hostOriginalFont),
            reason: 'Contamination detected in AppSettings.fontFamily at iteration $i with font $font');
        expect(ThemeProvider.instance.fontFamily, equals(hostOriginalFont),
            reason: 'Contamination detected in ThemeProvider.fontFamily at iteration $i with font $font');
        expect(ThemeProvider.instance.currScheme.primary, equals(initialPrimary),
            reason: 'Contamination detected in ThemeProvider primary color at iteration $i with font $font');
      }
    });

    test('Host-to-Child Sync: When host updates its font, child receives PlayerFontChangedMessage only if followPlayerFont is true',
        () async {
      ThemeProvider.instance.desktopLyricServiceOverride = service;

      // Case A: followPlayerFont is true
      AppPreference.instance.desktopLyricPref.followPlayerFont = true;
      fakeProcess.stdinLines.clear();

      ThemeProvider.instance.changeFontFamily('NewHostFont2026');
      await pumpEventQueue();

      final fontMessages = fakeProcess.stdinLines.where((line) {
        try {
          return json.decode(line)['type'] ==
              msg.getMessageTypeName<msg.PlayerFontChangedMessage>();
        } catch (_) {
          return false;
        }
      }).toList();

      expect(fontMessages, isNotEmpty);
      final lastContent =
          json.decode(fontMessages.last)['message'] as Map<String, dynamic>;
      expect(lastContent['fontFamily'], equals('NewHostFont2026'));

      // Case B: followPlayerFont is false
      AppPreference.instance.desktopLyricPref.followPlayerFont = false;
      fakeProcess.stdinLines.clear();

      ThemeProvider.instance.changeFontFamily('AnotherHostFont');
      await pumpEventQueue();

      final fontMessagesBlocked = fakeProcess.stdinLines.where((line) {
        try {
          return json.decode(line)['type'] ==
              msg.getMessageTypeName<msg.PlayerFontChangedMessage>();
        } catch (_) {
          return false;
        }
      }).toList();

      expect(fontMessagesBlocked, isEmpty);

      // Restore baseline
      ThemeProvider.instance.desktopLyricServiceOverride = null;
    });
  });
}
