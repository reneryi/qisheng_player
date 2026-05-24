import 'dart:convert';
import 'dart:io';

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

  String _stdinPending = "";

  static void initWithArgs(List<String> args) {
    if (args.length != 1) return;

    _instance = DesktopLyricController._();
    try {
      final initArgs = InitArgsMessage.fromJson(json.decode(args.first));
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
    } else if (type == getMessageTypeName<ThemeChangedMessage>()) {
      final themeMessage = ThemeChangedMessage.fromJson(content);
      theme.value = themeMessage;
    } else if (type == getMessageTypeName<UnlockMessage>()) {
      if (hWnd != null) {
        final exStyle = win32.GetWindowLongPtr(
          hWnd!,
          win32.WINDOW_LONG_PTR_INDEX.GWL_EXSTYLE,
        );

        win32.SetWindowLongPtr(
          hWnd!,
          win32.WINDOW_LONG_PTR_INDEX.GWL_EXSTYLE,
          exStyle &
              ~win32.WINDOW_EX_STYLE.WS_EX_LAYERED &
              ~win32.WINDOW_EX_STYLE.WS_EX_TRANSPARENT,
        );
      }
    } else if (type == "InstalledFontsMessage") {
      final current =
          _normalizedFontName(content["currentFontFamily"] as String?);
      installedFonts.value = _buildFontList(
        rawFonts: content["fonts"] as List<dynamic>? ?? const [],
        currentFont: current,
      );
      currentFontFamily.value = current;
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
