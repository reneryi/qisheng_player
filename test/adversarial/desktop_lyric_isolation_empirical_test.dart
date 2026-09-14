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

/// Mock child process for desktop lyric IPC communication.
class AdversarialFakeProcess implements Process {
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

  AdversarialFakeProcess({required this.pid}) {
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

  late Directory tempStorageDir;

  setUpAll(() async {
    tempStorageDir =
        await Directory.systemTemp.createTemp('qisheng_isolation_empirical_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      (MethodCall call) async {
        switch (call.method) {
          case 'set_desktop_lyric_process':
            return null;
          case 'get_desktop_lyric_rect':
            return {'left': 150, 'top': 150, 'width': 600, 'height': 100};
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
      (MethodCall call) async => tempStorageDir.path,
    );
  });

  tearDownAll(() async {
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
    try {
      if (tempStorageDir.existsSync()) {
        await tempStorageDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Adversarial Challenge 1: High-Frequency Font Switching & Absolute Host Isolation', () {
    const String hostBaselineFont = 'HostImmortalFont_Omega2026';

    late DesktopLyricService service;
    late AdversarialFakeProcess fakeProcess;

    setUp(() async {
      // Establish strict host player baseline
      AppSettings.instance.fontFamily = hostBaselineFont;
      ThemeProvider.instance.fontFamily = hostBaselineFont;

      final audio = TestAudio(
        title: 'Empirical Isolation Song',
        artist: 'Adversarial Artist',
        album: 'Isolation Benchmark',
        path: r'E:\Music\isolation_empirical.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      fakeProcess = AdversarialFakeProcess(pid: 8801);
      service.processStarter = (exe, args, {workingDirectory}) async =>
          fakeProcess;

      await service.startDesktopLyric();
    });

    tearDown(() async {
      await service.stopDesktopLyric(persistPreference: false);
    });

    test('Empirical Test 1.1: 65+ consecutive adversarial font switches never mutate host AppSettings or ThemeProvider',
        () async {
      // Comprehensive adversarial dataset:
      // - Standard fonts
      // - CJK, rare, and ancient unicode fonts
      // - Empty, whitespace, newline, tab
      // - Code injection, SQL, XSS, escape payloads
      // - Ultra-long font names, special ASCII characters
      // - Foreign alphabets (Arabic RTL, Russian, Korean, Japanese)
      // - Emojis & null
      final List<String?> adversarialFonts = [
        'Segoe UI',
        'Arial',
        'Roboto',
        'Microsoft YaHei',
        'PingFang SC',
        'Consolas',
        'Courier New',
        'Times New Roman',
        '霞鹜文楷',
        '思源黑体 Heavy',
        '思源宋体 ExtraLight',
        'Noto Color Emoji',
        '𠮷野家',
        '𝔉𝔯𝔞𝔨𝔱𝔲𝔯',
        '𝒳𝓎𝓏',
        '﷽',
        '你',
        '', // empty string
        ' ', // single space
        '   \t\r\n   ', // whitespace and control characters
        'Font\nNewlineBreak',
        'Font\r\nCRLFBreak',
        'Font\tTabSeparated',
        'Font\u0000NullByteInjection',
        'Font"Quotes\'And\\Backslashes',
        '<script>alert("xss")</script>',
        r'${AppSettings.instance.fontFamily}',
        r'#{process.exitCode}',
        '../../../../windows/system32/fonts',
        '; DROP TABLE fonts; --',
        '--!@#\$%^&*()_+~|}{[]:;?><,./-=',
        'A' * 500, // 500-character buffer stress
        'Русский шрифт гарнитура',
        'خط الرقعة العربي الفاخر',
        '日本語フォント・源ノ明朝',
        '한글 고딕 폰트 테스트',
        'Emoji 🎵🔥🚀✨💎🏆',
        null, // System default / null reset
        'HarmonyOS Sans SC',
        'Alibaba PuHuiTi 3.0',
        'Fira Code Retina',
        'JetBrains Mono Bold',
        'Cascadia Code PL',
        'MiSans Latin',
        'Oswald Regular',
        'Montserrat Black',
        'Lato Light',
        'Ubuntu Condensed',
        'Baskerville Old Face',
        'Garamond Premier Pro',
        null,
        'Comic Sans MS',
        'Papyrus',
        'Impact',
        'Trebuchet MS',
        'Century Gothic',
        'Franklin Gothic Medium',
        'Palatino Linotype',
        'Book Antiqua',
        'Lucida Console',
        'Copperplate Gothic Bold',
        null,
        'Modern Adversarial Font End',
        'FinalStressFontOmega',
      ];

      expect(adversarialFonts.length, greaterThanOrEqualTo(50),
          reason: 'Must test 50+ adversarial font switches');

      for (int i = 0; i < adversarialFonts.length; i++) {
        final font = adversarialFonts[i];
        final follow = (i % 3 == 0); // Alternate followPlayerFont states
        final color = 0xFF000000 | (i * 0x030507) & 0x00FFFFFF;

        final msgFrame = msg.PreferenceChangedMessage(
          color,
          0xFF1E293B,
          0xFFFFFFFF,
          hasSpecifiedColor: true,
          lyricFontFamily: font,
          followPlayerFont: follow,
        );

        fakeProcess.stdoutController
            .add(utf8.encode(buildDesktopLyricMessageFrame(msgFrame)));
        await pumpEventQueue();

        // 1. Verify desktop lyric preference took the update
        expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
            equals(font),
            reason: 'Iteration $i: desktopLyricPref.lyricFontFamily mismatch');
        expect(AppPreference.instance.desktopLyricPref.followPlayerFont,
            equals(follow),
            reason: 'Iteration $i: desktopLyricPref.followPlayerFont mismatch');

        // 2. ABSOLUTE HOST ISOLATION: Host font MUST remain strictly unchanged!
        expect(
          AppSettings.instance.fontFamily,
          equals(hostBaselineFont),
          reason:
              'Iteration $i ($font): Host AppSettings.fontFamily was contaminated!',
        );
        expect(
          ThemeProvider.instance.fontFamily,
          equals(hostBaselineFont),
          reason:
              'Iteration $i ($font): Host ThemeProvider.fontFamily was contaminated!',
        );
      }
    });

    test('Empirical Test 1.2: Burst flooding attack (50 messages in zero-tick burst) maintains host isolation',
        () async {
      // Flooding queue without awaiting between writes
      for (int i = 1; i <= 50; i++) {
        final burstFont = 'BurstFont_${i.toString().padLeft(3, '0')}';
        final message = msg.PreferenceChangedMessage(
          null,
          0xFF1E293B,
          0xFFFFFFFF,
          hasSpecifiedColor: false,
          lyricFontFamily: burstFont,
          followPlayerFont: false,
        );
        fakeProcess.stdoutController
            .add(utf8.encode(buildDesktopLyricMessageFrame(message)));
      }

      // Now pump all pending events in event queue
      await pumpEventQueue();

      // Final state should reflect the 50th font
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
          equals('BurstFont_050'));
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // Host player settings strictly preserved
      expect(AppSettings.instance.fontFamily, equals(hostBaselineFont));
      expect(ThemeProvider.instance.fontFamily, equals(hostBaselineFont));
    });

    test('Empirical Test 1.3: Bidirectional flow - Host updates notify child ONLY when followPlayerFont == true',
        () async {
      ThemeProvider.instance.desktopLyricServiceOverride = service;

      // When followPlayerFont is true: Child must receive PlayerFontChangedMessage
      AppPreference.instance.desktopLyricPref.followPlayerFont = true;
      fakeProcess.stdinLines.clear();

      ThemeProvider.instance.changeFontFamily('HostFont_Alpha');
      await pumpEventQueue();

      final receivedAlpha = fakeProcess.stdinLines.where((line) {
        try {
          return json.decode(line)['type'] ==
              msg.getMessageTypeName<msg.PlayerFontChangedMessage>();
        } catch (_) {
          return false;
        }
      }).toList();

      expect(receivedAlpha, isNotEmpty);
      final alphaData =
          json.decode(receivedAlpha.last)['message'] as Map<String, dynamic>;
      expect(alphaData['fontFamily'], equals('HostFont_Alpha'));

      // When followPlayerFont is false: Child must NOT receive any message
      AppPreference.instance.desktopLyricPref.followPlayerFont = false;
      fakeProcess.stdinLines.clear();

      ThemeProvider.instance.changeFontFamily('HostFont_Beta');
      await pumpEventQueue();

      final receivedBeta = fakeProcess.stdinLines.where((line) {
        try {
          return json.decode(line)['type'] ==
              msg.getMessageTypeName<msg.PlayerFontChangedMessage>();
        } catch (_) {
          return false;
        }
      }).toList();

      expect(receivedBeta, isEmpty,
          reason: 'Child received font message when followPlayerFont was false!');

      // Clean up override
      ThemeProvider.instance.desktopLyricServiceOverride = null;
    });
  });

  group('Adversarial Challenge 2: Reboot Persistence Fidelity & Tri-State Machine', () {
    test('Empirical Test 2.1: Tri-State Machine abrupt reboot persistence fidelity 100%',
        () async {
      // Initial save to establish preferences file on disk
      await AppPreference.instance.save();

      // --- State 1: Specific Custom Font & Custom Color ---
      AppPreference.instance.desktopLyricPref
        ..enabled = true
        ..locked = true
        ..primary = 0xFFFF3366
        ..surfaceContainer = 0xFF121826
        ..onSurface = 0xFFE2E8F0
        ..lyricFontFamily = 'Alibaba-PuHuiTi-Heavy'
        ..followPlayerFont = false;

      await AppPreference.instance.save();

      // Simulate power cut / sudden process shutdown by wiping memory instance
      AppPreference.instance.desktopLyricPref = DesktopLyricPreference(
        false,
        false,
        null,
        null,
        null,
        null,
        null,
        lyricFontFamily: 'CORRUPTED_IN_MEMORY',
        followPlayerFont: true,
      );

      // Reload from disk
      await AppPreference.read();

      expect(AppPreference.instance.desktopLyricPref.enabled, isTrue);
      expect(AppPreference.instance.desktopLyricPref.locked, isTrue);
      expect(AppPreference.instance.desktopLyricPref.primary, 0xFFFF3366);
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
          'Alibaba-PuHuiTi-Heavy');
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // --- State 2: System Default (lyricFontFamily == null, followPlayerFont == false) ---
      AppPreference.instance.desktopLyricPref
        ..lyricFontFamily = null
        ..followPlayerFont = false
        ..primary = 0xFF00F5D4;

      await AppPreference.instance.save();

      // Wipe memory instance
      AppPreference.instance.desktopLyricPref = DesktopLyricPreference(
        true,
        true,
        null,
        null,
        null,
        null,
        null,
        lyricFontFamily: 'CORRUPTED_VALUE',
        followPlayerFont: true,
      );

      // Reload from disk
      await AppPreference.read();

      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, isNull);
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);
      expect(AppPreference.instance.desktopLyricPref.primary, 0xFF00F5D4);

      // --- State 3: Follow Host Player Font & Theme (lyricFontFamily == null, followPlayerFont == true, primary == null) ---
      AppPreference.instance.desktopLyricPref
        ..lyricFontFamily = null
        ..followPlayerFont = true
        ..primary = null;

      await AppPreference.instance.save();

      // Wipe memory instance
      AppPreference.instance.desktopLyricPref = DesktopLyricPreference(
        true,
        true,
        0xFF999999,
        null,
        null,
        null,
        null,
        lyricFontFamily: 'SOME_STALE_FONT',
        followPlayerFont: false,
      );

      // Reload from disk
      await AppPreference.read();

      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, isNull);
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isTrue);
      expect(AppPreference.instance.desktopLyricPref.primary, isNull);
    });

    test('Empirical Test 2.2: 25 rapid cyclic reboot & random state transitions preserve exact fidelity',
        () async {
      final List<Map<String, dynamic>> testConfigs = [
        {
          'font': 'CustomFont_1',
          'follow': false,
          'primary': 0xFF112233,
        },
        {
          'font': null,
          'follow': false,
          'primary': 0xFF223344,
        },
        {
          'font': null,
          'follow': true,
          'primary': null,
        },
        {
          'font': '霞鹜文楷',
          'follow': false,
          'primary': 0xFFB388FF,
        },
        {
          'font': 'Consolas',
          'follow': false,
          'primary': null,
        },
        {
          'font': null,
          'follow': true,
          'primary': 0xFF00F5D4,
        },
      ];

      for (int cycle = 0; cycle < 25; cycle++) {
        final config = testConfigs[cycle % testConfigs.length];
        final font = config['font'] as String?;
        final follow = config['follow'] as bool;
        final primary = config['primary'] as int?;

        // Write configuration
        AppPreference.instance.desktopLyricPref
          ..lyricFontFamily = font
          ..followPlayerFont = follow
          ..primary = primary;

        await AppPreference.instance.save();

        // Deliberately corrupt memory state
        AppPreference.instance.desktopLyricPref
          ..lyricFontFamily = 'CORRUPTED_CYCLE_$cycle'
          ..followPlayerFont = !follow
          ..primary = primary == null ? 0xFF000000 : null;

        // Reboot / deserialize
        await AppPreference.read();

        // Exact fidelity assertion
        expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
            equals(font),
            reason: 'Reboot cycle $cycle: lyricFontFamily lost fidelity!');
        expect(AppPreference.instance.desktopLyricPref.followPlayerFont,
            equals(follow),
            reason: 'Reboot cycle $cycle: followPlayerFont lost fidelity!');
        expect(AppPreference.instance.desktopLyricPref.primary, equals(primary),
            reason: 'Reboot cycle $cycle: primary lost fidelity!');
      }
    });

    test('Empirical Test 2.3: Backward compatibility with legacy app_preference.json format',
        () async {
      await AppPreference.instance.save();

      final appDataDir = Directory('${tempStorageDir.path}\\qisheng_player');
      final prefFile = File('${appDataDir.path}\\app_preference.json');
      final currentMap =
          json.decode(await prefFile.readAsString()) as Map<String, dynamic>;

      // Write legacy desktopLyricPref with missing font fields
      currentMap['desktopLyricPref'] = {
        'enabled': true,
        'locked': false,
        'primary': 0xFF336699,
        'surfaceContainer': 0xFF121212,
        'onSurface': 0xFFFFFFFF,
        'windowLeft': 100.0,
        'windowTop': 200.0,
        // 'lyricFontFamily' and 'followPlayerFont' are deliberately absent!
      };
      await prefFile.writeAsString(json.encode(currentMap));

      // Reset memory state before reading
      AppPreference.instance.desktopLyricPref
        ..lyricFontFamily = 'STALE_PRE_READ'
        ..followPlayerFont = false;

      // Execute read
      await AppPreference.read();

      // Assert safe fallback values
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily, isNull);
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isTrue,
          reason: 'Legacy config must default followPlayerFont to true');
      expect(AppPreference.instance.desktopLyricPref.primary, 0xFF336699);
      expect(AppPreference.instance.desktopLyricPref.enabled, isTrue);
    });
  });

  group('Adversarial Challenge 3: Theme Follow Dynamic Linkage & History Non-Locking', () {
    late DesktopLyricService service;
    late AdversarialFakeProcess fakeProcess;

    setUp(() async {
      final audio = TestAudio(
        title: 'Theme Song',
        artist: 'Theme Artist',
        album: 'Theme Album',
        path: r'E:\Music\theme.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      fakeProcess = AdversarialFakeProcess(pid: 8802);
      service.processStarter = (exe, args, {workingDirectory}) async =>
          fakeProcess;

      await service.startDesktopLyric();
      ThemeProvider.instance.desktopLyricServiceOverride = service;
    });

    tearDown(() async {
      await service.stopDesktopLyric(persistPreference: false);
      ThemeProvider.instance.desktopLyricServiceOverride = null;
    });

    test('Empirical Test 3.1: 10 consecutive theme color switches dynamically update desktop lyric without history lock-in',
        () async {
      // Set desktop lyric to Follow Theme mode (primary == null)
      AppPreference.instance.desktopLyricPref.primary = null;

      final List<Color> themeSeedColors = [
        const Color(0xFFE91E63), // 1. Deep Pink
        const Color(0xFF00E676), // 2. Spring Green
        const Color(0xFF2979FF), // 3. Royal Blue
        const Color(0xFFFF9100), // 4. Sunset Orange
        const Color(0xFFD500F9), // 5. Vivid Fuchsia
        const Color(0xFF00E5FF), // 6. Electric Cyan
        const Color(0xFFFFEA00), // 7. Solar Gold
        const Color(0xFF651FFF), // 8. Deep Violet
        const Color(0xFF00B0FF), // 9. Sky Azure
        const Color(0xFFFF1744), // 10. Crimson Red
      ];

      int? previousSentColor;

      for (int i = 0; i < themeSeedColors.length; i++) {
        final seed = themeSeedColors[i];
        fakeProcess.stdinLines.clear();

        // Host player applies new theme
        ThemeProvider.instance.applyTheme(seedColor: seed);
        await pumpEventQueue();

        // CRITICAL CHECK: primary MUST remain strictly null in preference!
        expect(
          AppPreference.instance.desktopLyricPref.primary,
          isNull,
          reason:
              'Theme switch $i: desktopLyricPref.primary was locked into non-null integer!',
        );

        // Find the ThemeChangedMessage in child process stdin
        final themeLines = fakeProcess.stdinLines.where((line) {
          try {
            return json.decode(line)['type'] ==
                msg.getMessageTypeName<msg.ThemeChangedMessage>();
          } catch (_) {
            return false;
          }
        }).toList();

        expect(
          themeLines,
          isNotEmpty,
          reason: 'Theme switch $i ($seed): Child received NO ThemeChangedMessage!',
        );

        final lastThemePayload =
            json.decode(themeLines.last)['message'] as Map<String, dynamic>;
        final sentPrimary = lastThemePayload['primary'] as int;

        // Verify sent color matches current ThemeProvider scheme
        final expectedPrimary =
            ThemeProvider.instance.currScheme.primary.toARGB32();
        expect(
          sentPrimary,
          equals(expectedPrimary),
          reason:
              'Theme switch $i: Sent primary ($sentPrimary) does not match ThemeProvider ($expectedPrimary)!',
        );

        // Verify no history lock-in: must differ from previous theme color
        if (previousSentColor != null) {
          expect(
            sentPrimary,
            isNot(equals(previousSentColor)),
            reason:
                'Theme switch $i: Sent color is identical to previous theme color! Stale color locked in.',
          );
        }

        previousSentColor = sentPrimary;
      }
    });

    test('Empirical Test 3.2: Reversible transition between custom color and follow-theme mode',
        () async {
      // Phase 1: Child locks a custom color
      const customColor = 0xFFFF0055;
      const specifyMsg = msg.PreferenceChangedMessage(
        customColor,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: true,
      );
      fakeProcess.stdoutController
          .add(utf8.encode(buildDesktopLyricMessageFrame(specifyMsg)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.primary, equals(customColor));

      // Host switches theme -> Child receives theme update with fixed custom color
      fakeProcess.stdinLines.clear();
      ThemeProvider.instance.applyTheme(seedColor: const Color(0xFF00FF00));
      await pumpEventQueue();

      final lockedLine = fakeProcess.stdinLines.lastWhere(
        (line) =>
            json.decode(line)['type'] ==
            msg.getMessageTypeName<msg.ThemeChangedMessage>(),
      );
      final lockedPayload =
          json.decode(lockedLine)['message'] as Map<String, dynamic>;
      expect(lockedPayload['primary'], equals(customColor),
          reason: 'When custom color is locked, sent primary should remain the custom color');

      // Phase 2: User clicks "Follow Theme" in child -> primary becomes null
      const resetMsg = msg.PreferenceChangedMessage(
        null,
        0xFF1E293B,
        0xFFFFFFFF,
        hasSpecifiedColor: false,
      );
      fakeProcess.stdoutController
          .add(utf8.encode(buildDesktopLyricMessageFrame(resetMsg)));
      await pumpEventQueue();

      expect(AppPreference.instance.desktopLyricPref.primary, isNull);

      // Phase 3: Host switches theme again -> Child immediately starts following live theme!
      fakeProcess.stdinLines.clear();
      ThemeProvider.instance.applyTheme(seedColor: const Color(0xFF00E5FF));
      await pumpEventQueue();

      final unlockedLine = fakeProcess.stdinLines.lastWhere(
        (line) =>
            json.decode(line)['type'] ==
            msg.getMessageTypeName<msg.ThemeChangedMessage>(),
      );
      final unlockedPayload =
          json.decode(unlockedLine)['message'] as Map<String, dynamic>;
      final livePrimary =
          ThemeProvider.instance.currScheme.primary.toARGB32();
      expect(unlockedPayload['primary'], equals(livePrimary));
      expect(AppPreference.instance.desktopLyricPref.primary, isNull);
    });
  });

  group('Adversarial Challenge 4: Corrupted, Malformed & Hostile IPC Stream Resilience', () {
    const String hostBaselineFont = 'HostUntouchableFont';

    late DesktopLyricService service;
    late AdversarialFakeProcess fakeProcess;

    setUp(() async {
      AppSettings.instance.fontFamily = hostBaselineFont;
      ThemeProvider.instance.fontFamily = hostBaselineFont;

      final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.mp3',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      service = DesktopLyricService.forTest(playbackService: playback);
      service.candidatesResolverOverride = () => ['/fake/desktop_lyric.exe'];

      fakeProcess = AdversarialFakeProcess(pid: 8803);
      service.processStarter = (exe, args, {workingDirectory}) async =>
          fakeProcess;

      await service.startDesktopLyric();
    });

    tearDown(() async {
      await service.stopDesktopLyric(persistPreference: false);
    });

    test('Empirical Test 4.1: Garbage data, fragmented frames and invalid JSON do not crash host or corrupt settings',
        () async {
      final hostilePayloads = [
        'NOT_A_JSON_AT_ALL\n',
        '{"type": "UnknownMessage", "message": {}}\n',
        '{"type": "PreferenceChangedMessage", "message": "invalid_type"}\n',
        '{"type": "PreferenceChangedMessage", "message": {"primary": "string_not_int"}}\n',
        '\n\n\n', // Empty lines
        '${utf8.decode([0xFF, 0xFE, 0xFD], allowMalformed: true)}\n', // Malformed utf-8
      ];

      for (final payload in hostilePayloads) {
        fakeProcess.stdoutController.add(utf8.encode(payload));
      }
      await pumpEventQueue();

      // Test chunked streaming: partial fragment without newline followed by completion
      const chunk1 =
          '{"type": "PreferenceChangedMessage", "message": {"primary": null, "surfaceContainer": 4280231464, "onSurface": 4294967295, "hasSpecifiedColor": false, "lyricFontFamily": "Frag';
      const chunk2 = 'mentedFont", "followPlayerFont": false}}\n';
      fakeProcess.stdoutController.add(utf8.encode(chunk1));
      await pumpEventQueue();

      fakeProcess.stdoutController.add(utf8.encode(chunk2));
      await pumpEventQueue();

      // FragmentedFont was successfully parsed when completed
      expect(AppPreference.instance.desktopLyricPref.lyricFontFamily,
          equals('FragmentedFont'));
      expect(AppPreference.instance.desktopLyricPref.followPlayerFont, isFalse);

      // Host settings remain 100% stable and intact
      expect(AppSettings.instance.fontFamily, equals(hostBaselineFont));
      expect(ThemeProvider.instance.fontFamily, equals(hostBaselineFont));
    });
  });
}
