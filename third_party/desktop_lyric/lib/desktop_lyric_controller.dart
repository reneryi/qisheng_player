import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart' as win32;

int? hWnd;

class DesktopLyricController {
  ValueNotifier<bool> isPlaying = ValueNotifier(false);
  ValueNotifier<bool> isDarkMode = ValueNotifier(false);
  ValueNotifier<ThemeChangedMessage> theme = ValueNotifier(
    ThemeChangedMessage(
      Colors.blue.toARGB32(),
      Colors.white.toARGB32(),
      Colors.black.toARGB32(),
    ),
  );
  ValueNotifier<NowPlayingChangedMessage> nowPlaying = ValueNotifier(
    const NowPlayingChangedMessage("无", "无", "无"),
  );
  ValueNotifier<LyricLineChangedMessage> lyricLine = ValueNotifier(
    const LyricLineChangedMessage("无", Duration.zero, "无"),
  );
  ValueNotifier<List<String>> installedFonts = ValueNotifier(const []);
  ValueNotifier<String?> currentFontFamily = ValueNotifier(null);
  ValueNotifier<String?> playerFontFamily = ValueNotifier(null);
  ValueNotifier<String?> initialLyricFontFamily = ValueNotifier(null);
  ValueNotifier<bool> initialFollowPlayerFont = ValueNotifier(true);

  String _stdinPending = "";

  static void initWithArgs(List<String> args) {
    if (args.isEmpty) return;

    _instance ??= DesktopLyricController._();
    try {
      String rawJson = '';
      if (args.length == 1) {
        rawJson = args.first;
      } else {
        final candidate = args.firstWhere(
          (a) => a.trim().startsWith('{') && a.trim().endsWith('}'),
          orElse: () => args.join(' '),
        );
        rawJson = candidate;
      }
      final initArgs = InitArgsMessage.fromJson(
        json.decode(rawJson) as Map<String, dynamic>,
      );
      _instance!.isPlaying.value = initArgs.isPlaying;
      _instance!.nowPlaying.value = NowPlayingChangedMessage(
        initArgs.title,
        initArgs.artist,
        initArgs.album,
      );

      _instance!.isDarkMode.value = initArgs.darkMode;
      _instance!.theme.value = ThemeChangedMessage(
        initArgs.primary,
        initArgs.surfaceContainer,
        initArgs.onSurface,
      );

      final normalizedPlayerFont =
          _instance!._normalizedFontName(initArgs.playerFontFamily);
      _instance!.currentFontFamily.value = normalizedPlayerFont;
      _instance!.playerFontFamily.value = normalizedPlayerFont;
      final normalizedLyricFont =
          _instance!._normalizedFontName(initArgs.lyricFontFamily);
      _instance!.initialLyricFontFamily.value = normalizedLyricFont;
      _instance!.initialFollowPlayerFont.value = initArgs.followPlayerFont;

      TEXT_DISPLAY_CONTROLLER.initializeFromInitArgs(
        playerFont: normalizedPlayerFont,
        savedFont: normalizedLyricFont,
        followPlayer: initArgs.followPlayerFont,
        hasSpecifiedColor: initArgs.hasSpecifiedColor,
        specifiedColor:
            initArgs.hasSpecifiedColor ? Color(initArgs.primary) : null,
      );
    } catch (err, stack) {
      stderr.writeln(err);
      stderr.writeln(stack);
    }
  }

  static DesktopLyricController? _instance;
  static DesktopLyricController get instance {
    _instance ??= DesktopLyricController._();
    return _instance!;
  }

  static DesktopLyricController createForTest() => DesktopLyricController._(
        listenToStdin: false,
      );

  String? _normalizedFontName(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  List<String> _buildFontList({
    required List<dynamic> rawFonts,
    required String? currentFont,
  }) {
    final unique = <String, String>{};

    for (final item in rawFonts) {
      if (item is! String) continue;
      final name = _normalizedFontName(item);
      if (name == null) continue;
      unique.putIfAbsent(name.toLowerCase(), () => name);
    }
    if (currentFont != null) {
      unique.putIfAbsent(currentFont.toLowerCase(), () => currentFont);
    }

    final fonts = unique.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return fonts;
  }

  void _handleMessageMap(Map messageMap) {
    final String type = messageMap["type"];
    final content = messageMap["message"] as Map<String, dynamic>;

    if (type == getMessageTypeName<PlayerStateChangedMessage>()) {
      final playerState = PlayerStateChangedMessage.fromJson(content);
      isPlaying.value = playerState.playing;
    } else if (type == getMessageTypeName<NowPlayingChangedMessage>()) {
      final nowPlayingMessage = NowPlayingChangedMessage.fromJson(content);
      nowPlaying.value = nowPlayingMessage;
      lyricLine.value = const LyricLineChangedMessage("", Duration.zero);
    } else if (type == getMessageTypeName<LyricLineChangedMessage>()) {
      final lyricLineMessage = LyricLineChangedMessage.fromJson(content);
      lyricLine.value = lyricLineMessage;
    } else if (type == getMessageTypeName<ThemeModeChangedMessage>()) {
      final themeMode = ThemeModeChangedMessage.fromJson(content);
      isDarkMode.value = themeMode.darkMode;
      final currentTheme = theme.value;
      final lum = Color(currentTheme.onSurface).computeLuminance();
      if (themeMode.darkMode && lum < 0.5) {
        theme.value = ThemeChangedMessage(
          currentTheme.primary,
          const Color(0xFF1E2022).toARGB32(),
          Colors.white.toARGB32(),
        );
      } else if (!themeMode.darkMode && lum > 0.5) {
        theme.value = ThemeChangedMessage(
          currentTheme.primary,
          Colors.white.toARGB32(),
          const Color(0xFF0F172A).toARGB32(),
        );
      }
    } else if (type == getMessageTypeName<ThemeChangedMessage>()) {
      final themeMessage = ThemeChangedMessage.fromJson(content);
      theme.value = themeMessage;
      final lum = Color(themeMessage.onSurface).computeLuminance();
      isDarkMode.value = lum > 0.5;
    } else if (type == getMessageTypeName<UnlockMessage>()) {
      if (hWnd != null) {
        final exStyle = win32.GetWindowLongPtr(
          hWnd!,
          win32.GWL_EXSTYLE,
        );

        win32.SetWindowLongPtr(
          hWnd!,
          win32.GWL_EXSTYLE,
          exStyle &
              ~win32.WS_EX_LAYERED &
              ~win32.WS_EX_TRANSPARENT,
        );
      }
    } else if (type == getMessageTypeName<PlayerFontChangedMessage>()) {
      final playerFontMessage = PlayerFontChangedMessage.fromJson(content);
      final current = _normalizedFontName(playerFontMessage.fontFamily);
      currentFontFamily.value = current;
      playerFontFamily.value = current;
      TEXT_DISPLAY_CONTROLLER.onPlayerFontChanged(current);
    } else if (type == "InstalledFontsMessage") {
      final current =
          _normalizedFontName(content["currentFontFamily"] as String?);
      installedFonts.value = _buildFontList(
        rawFonts: content["fonts"] as List<dynamic>? ?? const [],
        currentFont: current,
      );
      if (current != null) {
        currentFontFamily.value = current;
        playerFontFamily.value = current;
      }
      if (content.containsKey("savedLyricFontFamily") ||
          content.containsKey("followPlayerFont")) {
        final saved =
            _normalizedFontName(content["savedLyricFontFamily"] as String?);
        final follow = content["followPlayerFont"] as bool? ?? true;
        TEXT_DISPLAY_CONTROLLER.initializeFontPreferences(
          playerFont: current,
          savedFont: saved,
          followPlayer: follow,
        );
      }
    }
  }

  void _handleMessageLine(String line) {
    try {
      _handleMessageMap(json.decode(line) as Map);
    } catch (err, stack) {
      stderr.writeln(err);
      stderr.writeln(stack);
    }
  }

  void parseStdinChunkForTest(String chunk) => _parseStdinChunk(chunk);

  void _parseStdinChunk(String chunk) {
    _stdinPending += chunk;

    int newlineIndex = _stdinPending.indexOf('\n');
    while (newlineIndex != -1) {
      final line = _stdinPending.substring(0, newlineIndex).trim();
      _stdinPending = _stdinPending.substring(newlineIndex + 1);
      if (line.isNotEmpty) {
        _handleMessageLine(line);
      }
      newlineIndex = _stdinPending.indexOf('\n');
    }

    final pending = _stdinPending.trim();
    if (pending.isEmpty) return;
    try {
      _handleMessageMap(json.decode(pending) as Map);
      _stdinPending = "";
    } catch (_) {
      // Wait for more chunks.
    }
  }

  DesktopLyricController._({bool listenToStdin = true}) {
    if (listenToStdin) {
      stdin.transform(utf8.decoder).listen((event) {
        try {
          _parseStdinChunk(event);
        } catch (err, stack) {
          stderr.writeln(err);
          stderr.writeln(stack);
        }
      });
    }
  }
}
