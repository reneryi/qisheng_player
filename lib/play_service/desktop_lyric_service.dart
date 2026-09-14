// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_line_parser.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/installed_font.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:desktop_lyric/message.dart' as msg;

@visibleForTesting
String buildDesktopLyricMessageFrame(msg.Message message) =>
    "${message.buildMessageJson()}\n";

abstract class DesktopLyricController extends ChangeNotifier {
  Future<Process?> get desktopLyric;
  bool get isStarting;
  bool get isLocked;
  Future<bool> get canSendMessage;

  Future<void> startDesktopLyric();
  void killDesktopLyric({bool disablePreference = true});
  void sendUnlockMessage();
  void sendThemeModeMessage(bool darkMode);
  void sendThemeMessage(ColorScheme scheme);
  void sendPlayerStateMessage(bool isPlaying);
  void sendNowPlayingMessage(Audio nowPlaying);
  void sendLyricLineMessage(LyricLine line);
  void sendPlayerFontChangedMessage(String? fontFamily) {}
}

class DesktopLyricService extends DesktopLyricController {
  final PlayService? _playService;
  final PlaybackController? _testPlaybackService;
  final LyricController? _testLyricService;

  DesktopLyricService(PlayService playService)
      : _playService = playService,
        _testPlaybackService = null,
        _testLyricService = null;

  @visibleForTesting
  DesktopLyricService.forTest({
    PlaybackController? playbackService,
    LyricController? lyricService,
  })  : _playService = null,
        _testPlaybackService = playbackService,
        _testLyricService = lyricService;

  PlayService get playService => _playService!;

  PlaybackController get _playbackService =>
      _testPlaybackService ?? _playService!.playbackService;

  Future<Process?> desktopLyric = Future.value(null);
  StreamSubscription? _desktopLyricSubscription;
  StreamSubscription? _desktopLyricStderrSubscription;
  Timer? _positionSyncTimer;
  bool _isStarting = false;
  int? _desktopLyricPid;
  String _desktopLyricStdoutPending = "";

  @visibleForTesting
  Future<Process> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) processStarter = Process.start;

  @visibleForTesting
  List<String> Function()? candidatesResolverOverride;

  @visibleForTesting
  int? get desktopLyricPid => _desktopLyricPid;

  @visibleForTesting
  bool get isPositionSyncTimerActive =>
      _positionSyncTimer != null && _positionSyncTimer!.isActive;

  bool isLocked = false;

  bool get isStarting => _isStarting;

  void _saveDesktopLyricPreference({
    bool? enabled,
    bool? locked,
    bool clearPrimary = false,
    int? primary,
    int? surfaceContainer,
    int? onSurface,
    double? windowLeft,
    double? windowTop,
    String? lyricFontFamily,
    bool? followPlayerFont,
    bool updateLyricFontFamily = false,
    bool persist = true,
  }) {
    final pref = AppPreference.instance.desktopLyricPref;
    bool changed = false;

    if (enabled != null && pref.enabled != enabled) {
      pref.enabled = enabled;
      changed = true;
    }
    if (locked != null && pref.locked != locked) {
      pref.locked = locked;
      changed = true;
    }
    if (clearPrimary) {
      if (pref.primary != null) {
        pref.primary = null;
        changed = true;
      }
    } else if (primary != null && pref.primary != primary) {
      pref.primary = primary;
      changed = true;
    }
    if (surfaceContainer != null && pref.surfaceContainer != surfaceContainer) {
      pref.surfaceContainer = surfaceContainer;
      changed = true;
    }
    if (onSurface != null && pref.onSurface != onSurface) {
      pref.onSurface = onSurface;
      changed = true;
    }
    if (windowLeft != null && pref.windowLeft != windowLeft) {
      pref.windowLeft = windowLeft;
      changed = true;
    }
    if (windowTop != null && pref.windowTop != windowTop) {
      pref.windowTop = windowTop;
      changed = true;
    }
    if (updateLyricFontFamily || lyricFontFamily != null) {
      if (pref.lyricFontFamily != lyricFontFamily) {
        pref.lyricFontFamily = lyricFontFamily;
        changed = true;
      }
    }
    if (followPlayerFont != null && pref.followPlayerFont != followPlayerFont) {
      pref.followPlayerFont = followPlayerFont;
      changed = true;
    }

    if (changed && persist) {
      AppPreference.instance.save();
    }
  }

  List<String> _resolveDesktopLyricCandidates() {
    if (candidatesResolverOverride != null) {
      return candidatesResolverOverride!();
    }
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final repoRoot = _findAncestorContaining(exeDir, "pubspec.yaml");
    final workspaceRoot = repoRoot == null ? null : path.dirname(repoRoot);
    final candidates = <String>[
      path.join(exeDir, "desktop_lyric", "desktop_lyric.exe"),
      path.join(exeDir, "desktop_lyric.exe"),
    ];
    final buildConfig = path.basename(exeDir);
    if (buildConfig == "Debug" || buildConfig == "Release") {
      final runnerDir = path.dirname(exeDir);
      candidates.addAll([
        path.join(runnerDir, "Release", "desktop_lyric", "desktop_lyric.exe"),
        path.join(runnerDir, "Debug", "desktop_lyric", "desktop_lyric.exe"),
      ]);
    }
    if (repoRoot != null) {
      candidates.add(
        path.join(
          repoRoot,
          "third_party",
          "desktop_lyric",
          "build",
          "windows",
          "x64",
          "runner",
          "Release",
          "desktop_lyric.exe",
        ),
      );
    }
    if (workspaceRoot != null) {
      candidates.add(
        path.join(
          workspaceRoot,
          "desktop_lyric_verify",
          "build",
          "windows",
          "x64",
          "runner",
          "Release",
          "desktop_lyric.exe",
        ),
      );
    }

    final checked = <String>{};
    final valid = <String>[];
    for (final candidate in candidates) {
      if (!checked.add(candidate)) continue;
      if (_isDesktopLyricBundle(candidate)) {
        valid.add(candidate);
      }
    }
    if (valid.isEmpty) {
      LOGGER.i(
        "[desktop lyric] no bundled executable found. checked: ${checked.join(' ; ')}",
      );
    }
    return valid;
  }

  String? _findAncestorContaining(String startDir, String childName) {
    var current = Directory(startDir);
    while (true) {
      if (File(path.join(current.path, childName)).existsSync()) {
        return current.path;
      }
      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
  }

  bool _isDesktopLyricBundle(String exePath) {
    final exeFile = File(exePath);
    if (!exeFile.existsSync()) return false;

    // Flutter desktop bundle requires runtime files.
    final dir = path.dirname(exePath);
    final hasRuntime = File(path.join(dir, "flutter_windows.dll")).existsSync();
    final hasData = Directory(path.join(dir, "data")).existsSync();
    return hasRuntime && hasData;
  }

  Future<void> _syncDesktopLyricWindowPosition({bool forceSave = false}) async {
    if (!Platform.isWindows) return;
    if (_desktopLyricPid == null) {
      _stopPositionSyncTimer();
      return;
    }
    final pid = _desktopLyricPid!;
    final rect = await WindowControls.getDesktopLyricRect(pid: pid);
    if (_desktopLyricPid != pid) return;
    if (rect == null) {
      if (forceSave) {
        LOGGER.i(
          "[desktop lyric position] sync miss by pid: $pid",
        );
      }
      return;
    }

    final left = rect["left"]?.toDouble();
    final top = rect["top"]?.toDouble();
    if (left == null || top == null) return;

    final pref = AppPreference.instance.desktopLyricPref;
    if (!forceSave &&
        pref.windowLeft != null &&
        pref.windowTop != null &&
        (pref.windowLeft! - left).abs() < 0.5 &&
        (pref.windowTop! - top).abs() < 0.5) {
      return;
    }
    LOGGER.i(
      "[desktop lyric position] save left=${left.toStringAsFixed(1)} "
      "top=${top.toStringAsFixed(1)} force=$forceSave pid=$_desktopLyricPid",
    );
    _saveDesktopLyricPreference(windowLeft: left, windowTop: top);
  }

  void _startPositionSyncTimer() {
    _positionSyncTimer?.cancel();
    if (_desktopLyricPid == null) {
      LOGGER.i("[desktop lyric] skipping position sync timer: pid is null");
      return;
    }
    _positionSyncTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) {
        if (_desktopLyricPid == null) {
          _stopPositionSyncTimer();
          return;
        }
        unawaited(_syncDesktopLyricWindowPosition());
      },
    );
  }

  void _stopPositionSyncTimer() {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = null;
  }

  Future<bool> _animateDesktopLyricWindowTo({
    required int currentLeft,
    required int currentTop,
    required int targetLeft,
    required int targetTop,
    int? pid,
  }) async {
    final deltaX = targetLeft - currentLeft;
    final deltaY = targetTop - currentTop;
    if (deltaX.abs() <= 1 && deltaY.abs() <= 1) {
      return WindowControls.setDesktopLyricPosition(
        pid: pid,
        left: targetLeft,
        top: targetTop,
      );
    }

    final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    final steps =
        distance <= 80 ? 4 : (distance <= 220 ? 7 : 10); // ~56ms / 98ms / 140ms

    for (var step = 1; step <= steps; step++) {
      final t = step / steps;
      final easedT = 1 - math.pow(1 - t, 3).toDouble();
      final nextLeft = (currentLeft + deltaX * easedT).round();
      final nextTop = (currentTop + deltaY * easedT).round();
      final moved = await WindowControls.setDesktopLyricPosition(
        pid: pid,
        left: nextLeft,
        top: nextTop,
      );
      if (!moved) return false;
      if (step < steps) {
        await Future.delayed(const Duration(milliseconds: 14));
      }
    }
    return true;
  }

  Future<bool> _restoreDesktopLyricWindowPosition({int? targetPid}) async {
    if (!Platform.isWindows) return false;
    final expectedPid = targetPid ?? _desktopLyricPid;
    if (expectedPid == null) return false;

    final pref = AppPreference.instance.desktopLyricPref;
    final left = pref.windowLeft?.round();
    final top = pref.windowTop?.round();
    if (left == null || top == null) return false;
    LOGGER.i(
      "[desktop lyric position] restore target left=$left top=$top pid=$expectedPid",
    );

    for (var attempt = 0; attempt < 20; attempt++) {
      if (_desktopLyricPid == null || _desktopLyricPid != expectedPid) {
        LOGGER.i(
          "[desktop lyric position] restore aborted: process closed or pid mismatch (expected: $expectedPid, current: $_desktopLyricPid)",
        );
        return false;
      }

      Map<String, int>? currentRect =
          await WindowControls.getDesktopLyricRect(pid: expectedPid);
      int? routePid = expectedPid;

      if (currentRect == null && attempt >= 10) {
        currentRect = await WindowControls.getDesktopLyricRect();
        routePid = null;
      }

      if (_desktopLyricPid == null || _desktopLyricPid != expectedPid) {
        return false;
      }

      final currentLeft = currentRect?["left"];
      final currentTop = currentRect?["top"];
      if (currentLeft == null || currentTop == null) {
        await Future.delayed(const Duration(milliseconds: 120));
        continue;
      }

      final moved = await _animateDesktopLyricWindowTo(
        currentLeft: currentLeft,
        currentTop: currentTop,
        targetLeft: left,
        targetTop: top,
        pid: routePid,
      );
      if (moved) {
        if (routePid != null) {
          LOGGER.i(
            "[desktop lyric position] restore success by pid at attempt ${attempt + 1}",
          );
        } else {
          LOGGER.i(
            "[desktop lyric position] restore success by title at attempt ${attempt + 1}",
          );
        }
        return true;
      }
      if (_desktopLyricPid != null && _desktopLyricPid == expectedPid) {
        final movedByPid = await WindowControls.setDesktopLyricPosition(
          pid: expectedPid,
          left: left,
          top: top,
        );
        if (movedByPid) {
          LOGGER.i(
            "[desktop lyric position] restore success by pid at attempt ${attempt + 1}",
          );
          return true;
        }
      }
      if ((_desktopLyricPid == null || attempt >= 10) &&
          _desktopLyricPid == expectedPid) {
        final movedByTitle = await WindowControls.setDesktopLyricPosition(
          left: left,
          top: top,
        );
        if (movedByTitle) {
          LOGGER.i(
            "[desktop lyric position] restore success by title at attempt ${attempt + 1}",
          );
          return true;
        }
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
    LOGGER.i(
      "[desktop lyric position] restore failed left=$left top=$top pid=$expectedPid",
    );
    return false;
  }

  Future<void> _cleanupDesktopLyricProcess() async {
    _stopPositionSyncTimer();
    _desktopLyricPid = null;
    unawaited(WindowControls.setDesktopLyricProcess());
    _desktopLyricStdoutPending = "";
    desktopLyric = Future.value(null);
    final subscription = _desktopLyricSubscription;
    _desktopLyricSubscription = null;
    await subscription?.cancel();
    final stderrSubscription = _desktopLyricStderrSubscription;
    _desktopLyricStderrSubscription = null;
    await stderrSubscription?.cancel();
  }

  Future<void> _setDesktopLyricClosed() async {
    await _cleanupDesktopLyricProcess();
    _isStarting = false;
    isLocked = false;
    notifyListeners();
  }

  void restoreFromPreferenceIfNeeded() {
    // Compatibility no-op: desktop lyric no longer auto-opens on app startup.
  }

  void _handleDesktopLyricMessageMap(Map messageMap) {
    final String messageType = messageMap["type"];
    final messageContent = messageMap["message"] as Map<String, dynamic>;
    if (messageType == msg.getMessageTypeName<msg.ControlEventMessage>()) {
      final controlEvent = msg.ControlEventMessage.fromJson(messageContent);
      switch (controlEvent.event) {
        case msg.ControlEvent.pause:
          _playbackService.pause();
          break;
        case msg.ControlEvent.start:
          _playbackService.start();
          break;
        case msg.ControlEvent.previousAudio:
          _playbackService.lastAudio();
          break;
        case msg.ControlEvent.nextAudio:
          _playbackService.nextAudio();
          break;
        case msg.ControlEvent.lock:
          isLocked = true;
          _saveDesktopLyricPreference(locked: true);
          notifyListeners();
          break;
        case msg.ControlEvent.close:
          killDesktopLyric();
          break;
      }
    } else if (messageType ==
        msg.getMessageTypeName<msg.PreferenceChangedMessage>()) {
      final pref = msg.PreferenceChangedMessage.fromJson(messageContent);
      final desktopLyricPref = AppPreference.instance.desktopLyricPref;

      if (pref.hasSpecifiedColor == false || pref.primary == null) {
        desktopLyricPref.primary = null;
      } else if (pref.hasSpecifiedColor == true && pref.primary != null) {
        desktopLyricPref.primary = pref.primary;
      }

      desktopLyricPref.surfaceContainer = pref.surfaceContainer;
      desktopLyricPref.onSurface = pref.onSurface;

      if (pref.lyricFontFamily != null || pref.followPlayerFont != null) {
        desktopLyricPref.lyricFontFamily = pref.lyricFontFamily;
        desktopLyricPref.followPlayerFont = pref.followPlayerFont ?? false;
      }

      AppPreference.instance.save();
    }
  }

  void _parseDesktopLyricStdout(String chunk) {
    _desktopLyricStdoutPending += chunk;

    int newlineIndex = _desktopLyricStdoutPending.indexOf('\n');
    while (newlineIndex != -1) {
      final line = _desktopLyricStdoutPending.substring(0, newlineIndex).trim();
      _desktopLyricStdoutPending =
          _desktopLyricStdoutPending.substring(newlineIndex + 1);
      if (line.isNotEmpty) {
        try {
          _handleDesktopLyricMessageMap(json.decode(line) as Map);
        } on FormatException {
          // Ignore incomplete/non-JSON stdout fragments from desktop lyric.
        } catch (err) {
          LOGGER.e("[desktop lyric] $err");
        }
      }
      newlineIndex = _desktopLyricStdoutPending.indexOf('\n');
    }

    final pending = _desktopLyricStdoutPending.trim();
    if (pending.isEmpty) return;
    try {
      _handleDesktopLyricMessageMap(json.decode(pending) as Map);
      _desktopLyricStdoutPending = "";
    } catch (_) {
      // 等待后续分片拼接成完整 JSON。
    }
  }

  Future<void> startDesktopLyric() async {
    if (_isStarting) return;
    _isStarting = true;
    notifyListeners();

    try {
      if (await desktopLyric != null) {
        _isStarting = false;
        notifyListeners();
        return;
      }
      final candidates = _resolveDesktopLyricCandidates();
      if (candidates.isEmpty) {
        _isStarting = false;
        _saveDesktopLyricPreference(enabled: false, locked: false);
        showTextOnSnackBar("桌面歌词未找到");
        notifyListeners();
        return;
      }

      final nowPlaying = _playbackService.nowPlaying;
      final currScheme = ThemeProvider.instance.currScheme;
      final isDarkMode =
          ThemeProvider.instance.effectiveBrightness == Brightness.dark;
      final desktopLyricPref = AppPreference.instance.desktopLyricPref;
      final initialPrimary =
          desktopLyricPref.primary ?? currScheme.primary.toARGB32();
      final initialSurfaceContainer = currScheme.surfaceContainer.toARGB32();
      final initialOnSurface = currScheme.onSurface.toARGB32();
      _saveDesktopLyricPreference(
        surfaceContainer: initialSurfaceContainer,
        onSurface: initialOnSurface,
        persist: false,
      );
      Object? lastErr;
      StackTrace? lastTrace;
      for (final desktopLyricPath in candidates) {
        if (!_isStarting) return;
        try {
          desktopLyric = processStarter(
              desktopLyricPath,
              [
                json.encode(msg.InitArgsMessage(
                  _playbackService.playerState == PlayerState.playing,
                  nowPlaying?.title ?? "无",
                  nowPlaying?.artist ?? "无",
                  nowPlaying?.album ?? "无",
                  isDarkMode,
                  initialPrimary,
                  initialSurfaceContainer,
                  initialOnSurface,
                  lyricFontFamily: desktopLyricPref.lyricFontFamily,
                  followPlayerFont: desktopLyricPref.followPlayerFont,
                  hasSpecifiedColor: desktopLyricPref.primary != null,
                  playerFontFamily: AppSettings.instance.fontFamily,
                ).toJson())
              ],
              workingDirectory: path.dirname(desktopLyricPath));

          final process = await desktopLyric;
          if (!_isStarting) {
            try {
              process?.kill();
            } catch (_) {}
            await _cleanupDesktopLyricProcess();
            return;
          }
          if (process == null) {
            throw StateError("Process.start returned null for $desktopLyricPath");
          }

          _desktopLyricPid = process.pid;
          await WindowControls.setDesktopLyricProcess(
            pid: process.pid,
            executablePath: desktopLyricPath,
          );

          process.exitCode.then((exitCode) async {
            if (_desktopLyricPid == null || _desktopLyricPid != process.pid) {
              LOGGER.i(
                "[desktop lyric] ignoring exit of superseded process (pid: ${process.pid}, activePid: $_desktopLyricPid, exitCode: $exitCode)",
              );
              return;
            }
            final activeProc = await desktopLyric;
            if (activeProc != process) {
              LOGGER.i(
                "[desktop lyric] ignoring exit of mismatched process instance (pid: ${process.pid}, exitCode: $exitCode)",
              );
              return;
            }
            unawaited(_setDesktopLyricClosed());
          });

          _desktopLyricStderrSubscription =
              process.stderr.transform(utf8.decoder).listen((event) {
            LOGGER.e("[desktop lyric] $event");
          });

          _desktopLyricSubscription =
              process.stdout.transform(utf8.decoder).listen(
                    _parseDesktopLyricStdout,
                  );
          sendThemeMessage(currScheme);
          sendThemeModeMessage(isDarkMode);
          unawaited(_sendInstalledFontsToDesktopLyric());

          await _restoreDesktopLyricWindowPosition(targetPid: process.pid);

          if (!_isStarting || _desktopLyricPid == null || _desktopLyricPid != process.pid) {
            LOGGER.i(
              "[desktop lyric start] aborted after position restore (pid: ${process.pid}, activePid: $_desktopLyricPid)",
            );
            return;
          }
          final activeCheck = await desktopLyric;
          if (activeCheck != process) {
            return;
          }

          _startPositionSyncTimer();
          await _syncDesktopLyricWindowPosition(forceSave: true);
          Future.delayed(const Duration(milliseconds: 250), () {
            if (_desktopLyricPid == process.pid) {
              final testLyricService = _testLyricService;
              if (testLyricService != null) {
                testLyricService.refreshCurrentLyricLine();
              } else {
                _playService?.lyricService.refreshCurrentLyricLine();
              }
            }
          });

          _isStarting = false;
          _saveDesktopLyricPreference(
            enabled: true,
            locked: isLocked,
            primary: desktopLyricPref.primary,
            surfaceContainer: initialSurfaceContainer,
            onSurface: initialOnSurface,
          );
          notifyListeners();
          return;
        } catch (err, trace) {
          lastErr = err;
          lastTrace = trace;
          LOGGER.e(
            "[desktop lyric start] candidate failed: $desktopLyricPath, $err",
            stackTrace: trace,
          );
          try {
            final proc = await desktopLyric;
            proc?.kill();
          } catch (_) {}
          await _cleanupDesktopLyricProcess();
        }
      }

      _isStarting = false;
      await _setDesktopLyricClosed();
      _saveDesktopLyricPreference(enabled: false, locked: false);
      notifyListeners();
      if (lastErr != null) {
        LOGGER.e("[desktop lyric start] all candidates failed: $lastErr",
            stackTrace: lastTrace);
      }
      showTextOnSnackBar("桌面歌词启动失败");
    } catch (e, st) {
      LOGGER.e("[desktop lyric start] unexpected exception: $e", stackTrace: st);
      _isStarting = false;
      await _setDesktopLyricClosed();
      _saveDesktopLyricPreference(enabled: false, locked: false);
      notifyListeners();
    }
  }

  Future<bool> get canSendMessage => desktopLyric.then(
        (value) => value != null,
      );

  Future<void> _sendInstalledFontsToDesktopLyric() async {
    List<String> fontNames = [];
    try {
      final installedFonts = await getInstalledFonts();
      final set = <String>{};
      for (final font in installedFonts ?? <InstalledFont>[]) {
        final name = font.fullName.trim();
        if (name.isNotEmpty) {
          set.add(name);
        }
      }
      fontNames = set.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (err, trace) {
      LOGGER.e("[desktop lyric] load installed fonts failed: $err",
          stackTrace: trace);
    }

    await desktopLyric.then((value) {
      if (value == null) return;
      value.stdin.writeln(json.encode({
        "type": "InstalledFontsMessage",
        "message": {
          "fonts": fontNames,
          "currentFontFamily": AppSettings.instance.fontFamily,
        }
      }));
    });
  }

  void sendMessage(msg.Message message) {
    desktopLyric.then((value) {
      value?.stdin.write(buildDesktopLyricMessageFrame(message));
    }).catchError((err, trace) {
      LOGGER.e(err, stackTrace: trace);
    });
  }

  Future<void> stopDesktopLyric({
    bool disablePreference = true,
    bool persistPreference = true,
  }) async {
    try {
      final value = await desktopLyric;
      await _syncDesktopLyricWindowPosition(forceSave: true);
      try {
        value?.kill();
      } catch (_) {}
      if (disablePreference) {
        _saveDesktopLyricPreference(
          enabled: false,
          locked: false,
          persist: persistPreference,
        );
      }
      await _setDesktopLyricClosed();
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  void killDesktopLyric({bool disablePreference = true}) {
    unawaited(stopDesktopLyric(disablePreference: disablePreference));
  }

  void sendUnlockMessage() {
    sendMessage(const msg.UnlockMessage());
    isLocked = false;
    _saveDesktopLyricPreference(locked: false);
    notifyListeners();
  }

  void sendThemeModeMessage(bool darkMode) {
    sendMessage(msg.ThemeModeChangedMessage(darkMode));
  }

  void sendThemeMessage(ColorScheme scheme) {
    final desktopLyricPref = AppPreference.instance.desktopLyricPref;
    final int effectivePrimary =
        desktopLyricPref.primary ?? scheme.primary.toARGB32();

    _saveDesktopLyricPreference(
      surfaceContainer: scheme.surfaceContainer.toARGB32(),
      onSurface: scheme.onSurface.toARGB32(),
    );
    sendMessage(msg.ThemeChangedMessage(
      effectivePrimary,
      scheme.surfaceContainer.toARGB32(),
      scheme.onSurface.toARGB32(),
    ));
  }

  void sendPlayerStateMessage(bool isPlaying) {
    sendMessage(msg.PlayerStateChangedMessage(isPlaying));
  }

  void sendNowPlayingMessage(Audio nowPlaying) {
    sendMessage(msg.NowPlayingChangedMessage(
      nowPlaying.title,
      nowPlaying.artist,
      nowPlaying.album,
    ));
  }

  void sendLyricLineMessage(LyricLine line) {
    final showTranslation =
        AppPreference.instance.nowPlayingPagePref.showTranslation;
    if (line is SyncLyricLine) {
      sendMessage(msg.LyricLineChangedMessage(
        line.content,
        line.length,
        showTranslation ? line.translation : null,
      ));
    } else if (line is LrcLine) {
      final parsed = LyricLineParser.parse(line.content);
      final translation =
          showTranslation && !parsed.isCredit ? parsed.translation : null;
      sendMessage(msg.LyricLineChangedMessage(
        parsed.primary,
        line.length,
        translation,
      ));
    }
  }

  @override
  void sendPlayerFontChangedMessage(String? fontFamily) {
    sendMessage(msg.PlayerFontChangedMessage(fontFamily));
  }
}
