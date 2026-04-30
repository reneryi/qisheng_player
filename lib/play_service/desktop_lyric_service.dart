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
}

class DesktopLyricService extends DesktopLyricController {
  final PlayService playService;
  DesktopLyricService(this.playService);

  PlaybackService get _playbackService => playService.playbackService;

  Future<Process?> desktopLyric = Future.value(null);
  StreamSubscription? _desktopLyricSubscription;
  Timer? _positionSyncTimer;
  bool _isStarting = false;
  int? _desktopLyricPid;
  String _desktopLyricStdoutPending = "";

  bool isLocked = false;

  bool get isStarting => _isStarting;

  void _saveDesktopLyricPreference({
    bool? enabled,
    bool? locked,
    int? primary,
    int? surfaceContainer,
    int? onSurface,
    double? windowLeft,
    double? windowTop,
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
    if (primary != null && pref.primary != primary) {
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

    if (changed) {
      AppPreference.instance.save();
    }
  }

  List<String> _resolveDesktopLyricCandidates() {
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final candidates = <String>[
      path.join(exeDir, "desktop_lyric", "desktop_lyric.exe"),
      path.join(exeDir, "desktop_lyric.exe"),
    ];

    final checked = <String>{};
    final valid = <String>[];
    for (final candidate in candidates) {
      if (!checked.add(candidate)) continue;
      if (_isDesktopLyricBundle(candidate)) {
        valid.add(candidate);
      }
    }
    return valid;
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
    Map<String, int>? rect;
    if (_desktopLyricPid != null) {
      rect = await WindowControls.getDesktopLyricRect(pid: _desktopLyricPid);
      if (rect == null) {
        if (forceSave) {
          LOGGER.i(
            "[desktop lyric position] sync miss by pid: $_desktopLyricPid",
          );
        }
        return;
      }
    } else {
      rect = await WindowControls.getDesktopLyricRect();
    }
    if (rect == null) return;

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
    _positionSyncTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(_syncDesktopLyricWindowPosition()),
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

  Future<bool> _restoreDesktopLyricWindowPosition() async {
    if (!Platform.isWindows) return false;

    final pref = AppPreference.instance.desktopLyricPref;
    final left = pref.windowLeft?.round();
    final top = pref.windowTop?.round();
    if (left == null || top == null) return false;
    LOGGER.i(
      "[desktop lyric position] restore target left=$left top=$top pid=$_desktopLyricPid",
    );

    for (var attempt = 0; attempt < 20; attempt++) {
      Map<String, int>? currentRect;
      int? routePid;

      if (_desktopLyricPid != null) {
        currentRect =
            await WindowControls.getDesktopLyricRect(pid: _desktopLyricPid);
        if (currentRect != null) {
          routePid = _desktopLyricPid;
        }
      }

      if (currentRect == null && (_desktopLyricPid == null || attempt >= 10)) {
        currentRect = await WindowControls.getDesktopLyricRect();
        routePid = null;
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
      if (_desktopLyricPid != null) {
        final movedByPid = await WindowControls.setDesktopLyricPosition(
          pid: _desktopLyricPid,
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
      if (_desktopLyricPid == null || attempt >= 10) {
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
      "[desktop lyric position] restore failed left=$left top=$top pid=$_desktopLyricPid",
    );
    return false;
  }

  void _setDesktopLyricClosed() {
    _stopPositionSyncTimer();
    _desktopLyricPid = null;
    unawaited(WindowControls.setDesktopLyricProcess());
    _desktopLyricStdoutPending = "";
    desktopLyric = Future.value(null);
    _desktopLyricSubscription?.cancel();
    _desktopLyricSubscription = null;
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
      _saveDesktopLyricPreference(
        primary: pref.primary,
        surfaceContainer: pref.surfaceContainer,
        onSurface: pref.onSurface,
      );
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
    if (await desktopLyric != null) return;
    final candidates = _resolveDesktopLyricCandidates();
    if (candidates.isEmpty) {
      _saveDesktopLyricPreference(enabled: false, locked: false);
      showTextOnSnackBar("桌面歌词未找到");
      return;
    }
    _isStarting = true;
    notifyListeners();

    final nowPlaying = _playbackService.nowPlaying;
    final currScheme = ThemeProvider.instance.currScheme;
    final isDarkMode = ThemeProvider.instance.themeMode == ThemeMode.dark;
    final desktopLyricPref = AppPreference.instance.desktopLyricPref;
    final initialPrimary =
        desktopLyricPref.primary ?? currScheme.primary.toARGB32();
    final initialSurfaceContainer = desktopLyricPref.surfaceContainer ??
        currScheme.surfaceContainer.toARGB32();
    final initialOnSurface =
        desktopLyricPref.onSurface ?? currScheme.onSurface.toARGB32();
    Object? lastErr;
    StackTrace? lastTrace;
    for (final desktopLyricPath in candidates) {
      try {
        desktopLyric = Process.start(
            desktopLyricPath,
            [
              json.encode(msg.InitArgsMessage(
                _playbackService.playerState == PlayerState.playing,
                nowPlaying?.title ?? "旀",
                nowPlaying?.artist ?? "旀",
                nowPlaying?.album ?? "旀",
                isDarkMode,
                initialPrimary,
                initialSurfaceContainer,
                initialOnSurface,
              ).toJson())
            ],
            workingDirectory: path.dirname(desktopLyricPath));

        final process = await desktopLyric;
        _desktopLyricPid = process?.pid;
        if (process != null) {
          await WindowControls.setDesktopLyricProcess(
            pid: process.pid,
            executablePath: desktopLyricPath,
          );
        }
        process?.exitCode.then((_) {
          _setDesktopLyricClosed();
        });

        process?.stderr.transform(utf8.decoder).listen((event) {
          LOGGER.e("[desktop lyric] $event");
        });

        _desktopLyricSubscription =
            process?.stdout.transform(utf8.decoder).listen(
                  _parseDesktopLyricStdout,
                );
        await _sendInstalledFontsToDesktopLyric();

        _isStarting = false;
        _saveDesktopLyricPreference(
          enabled: true,
          locked: isLocked,
          primary: initialPrimary,
          surfaceContainer: initialSurfaceContainer,
          onSurface: initialOnSurface,
        );
        await _restoreDesktopLyricWindowPosition();
        _startPositionSyncTimer();
        await _syncDesktopLyricWindowPosition(forceSave: true);
        Future.delayed(const Duration(milliseconds: 250), () {
          playService.lyricService.refreshCurrentLyricLine();
        });

        notifyListeners();
        return;
      } catch (err, trace) {
        lastErr = err;
        lastTrace = trace;
        LOGGER.e(
          "[desktop lyric start] candidate failed: $desktopLyricPath, $err",
          stackTrace: trace,
        );
      }
    }

    _isStarting = false;
    _saveDesktopLyricPreference(enabled: false, locked: false);
    notifyListeners();
    if (lastErr != null) {
      LOGGER.e("[desktop lyric start] all candidates failed: $lastErr",
          stackTrace: lastTrace);
    }
    showTextOnSnackBar("桌面歌词启动失败");
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
      value?.stdin.write(message.buildMessageJson());
    }).catchError((err, trace) {
      LOGGER.e(err, stackTrace: trace);
    });
  }

  void killDesktopLyric({bool disablePreference = true}) {
    desktopLyric.then((value) async {
      await _syncDesktopLyricWindowPosition(forceSave: true);
      value?.kill(ProcessSignal.sigterm);
      if (disablePreference) {
        _saveDesktopLyricPreference(enabled: false, locked: false);
      }
      _setDesktopLyricClosed();
    }).catchError((err, trace) {
      LOGGER.e(err, stackTrace: trace);
    });
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
    _saveDesktopLyricPreference(
      primary: scheme.primary.toARGB32(),
      surfaceContainer: scheme.surfaceContainer.toARGB32(),
      onSurface: scheme.onSurface.toARGB32(),
    );
    sendMessage(msg.ThemeChangedMessage(
      scheme.primary.toARGB32(),
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
      final splitted = line.content.split("\u2503");
      final content = splitted.first;
      final translation =
          showTranslation && splitted.length > 1 ? splitted[1] : null;
      sendMessage(msg.LyricLineChangedMessage(
        content,
        line.length,
        translation,
      ));
    }
  }
}
