import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';

enum LyricConfigType { font, color }

/// 桌面歌词独立无边框配置子窗口调度器
///
/// 保持桌面歌词悬浮条固定尺寸不拉伸，通过子进程唤起独立子窗口，
/// 消除 DWM 重绘导致的白底闪烁。
class DesktopLyricConfigLauncher {
  static Process? _activeProcess;
  static StreamSubscription<String>? _stdoutSub;

  /// 用于单元测试或 Mock 的子进程启动器
  static Future<Process> Function(String executable, List<String> arguments)?
      processStarterOverride;

  static bool get isConfigWindowOpen => _activeProcess != null;

  static Future<void> open([BuildContext? context, LyricConfigType type = LyricConfigType.font]) async {
    // 单元测试中未注入 processStarterOverride 时，优雅降级为原位 Dialog
    if (processStarterOverride == null &&
        (Platform.environment.containsKey('FLUTTER_TEST') ||
            Platform.resolvedExecutable.contains('flutter_tester') ||
            Platform.resolvedExecutable.isEmpty)) {
      if (context != null) {
        if (type == LyricConfigType.font) {
          await showLyricFontSelectorDialog(context);
        } else {
          await showDesktopLyricColorDialog(context);
        }
      }
      return;
    }

    await _launchConfigWindow(type);
  }

  static int _launchSeq = 0;

  static Future<void> _launchConfigWindow(LyricConfigType type) async {
    final currentSeq = ++_launchSeq;

    // 若已有配置子窗口处于打开状态，先平滑终止旧窗口再唤起新模式
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (_) {}
      _activeProcess = null;
    }
    _stdoutSub?.cancel();
    _stdoutSub = null;

    isDialogOpen.value = true;

    final payload = {
      'isConfigWindow': true,
      'configType': type == LyricConfigType.font ? 'font' : 'color',
      'isDarkMode': DesktopLyricController.instance.isDarkMode.value,
      'theme': {
        'primary': DesktopLyricController.instance.theme.value.primary,
        'surfaceContainer':
            DesktopLyricController.instance.theme.value.surfaceContainer,
        'onSurface': DesktopLyricController.instance.theme.value.onSurface,
      },
      'hasSpecifiedColor': TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor,
      'specifiedColor': TEXT_DISPLAY_CONTROLLER.hasSpecifiedColor
          ? TEXT_DISPLAY_CONTROLLER.specifiedColor.toARGB32()
          : null,
      'lyricFontSize': TEXT_DISPLAY_CONTROLLER.lyricFontSize,
      'translationFontSize': TEXT_DISPLAY_CONTROLLER.translationFontSize,
      'showTranslation': TEXT_DISPLAY_CONTROLLER.showTranslation,
      'lyricFontFamily': TEXT_DISPLAY_CONTROLLER.preferenceLyricFontFamily,
      'followPlayerFont': TEXT_DISPLAY_CONTROLLER.followPlayerFont,
      'playerFontFamily':
          DesktopLyricController.instance.playerFontFamily.value,
      'installedFonts': DesktopLyricController.instance.installedFonts.value,
      'lyricLine': {
        'lyric': DesktopLyricController.instance.lyricLine.value.content,
        'translation':
            DesktopLyricController.instance.lyricLine.value.translation,
      },
    };

    final jsonPayload = json.encode(payload);
    final args = [
      '--config-window',
      type == LyricConfigType.font ? 'font' : 'color',
      jsonPayload,
    ];

    try {
      final starter = processStarterOverride;
      final Process process;
      if (starter != null) {
        process = await starter(Platform.resolvedExecutable, args);
      } else {
        final executableDir = File(Platform.resolvedExecutable).parent.path;
        process = await Process.start(
          Platform.resolvedExecutable,
          args,
          workingDirectory: executableDir,
        );
      }
      if (currentSeq != _launchSeq) {
        try {
          process.kill();
        } catch (_) {}
        return;
      }
      _activeProcess = process;

      _stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          _handleChildOutput(line);
        },
        onDone: () {
          if (_activeProcess == process) {
            _activeProcess = null;
            _stdoutSub = null;
            isDialogOpen.value = false;
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      process.exitCode.then((_) {
        if (_activeProcess == process) {
          _activeProcess = null;
          _stdoutSub?.cancel();
          _stdoutSub = null;
          isDialogOpen.value = false;
        }
      });
    } catch (_) {
      if (currentSeq == _launchSeq) {
        isDialogOpen.value = false;
        _activeProcess = null;
      }
    }
  }

  static void _handleChildOutput(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    try {
      final map = json.decode(trimmed) as Map<String, dynamic>;
      final typeStr = map['type'] as String?;
      final content = map['message'] as Map<String, dynamic>?;

      if (typeStr == 'ConfigWindowClosed') {
        if (_activeProcess != null) {
          try {
            _activeProcess!.kill();
          } catch (_) {}
          _activeProcess = null;
        }
        _stdoutSub?.cancel();
        _stdoutSub = null;
        isDialogOpen.value = false;
        return;
      }

      if (typeStr == getMessageTypeName<PreferenceChangedMessage>() &&
          content != null) {
        final pref = PreferenceChangedMessage.fromJson(content);
        if (pref.hasSpecifiedColor == true && pref.primary != null) {
          TEXT_DISPLAY_CONTROLLER.spcifiyColor(Color(pref.primary!));
        } else if (pref.hasSpecifiedColor == false) {
          TEXT_DISPLAY_CONTROLLER.usePlayerTheme();
        }
        if (pref.lyricFontFamily != null || pref.followPlayerFont != null) {
          TEXT_DISPLAY_CONTROLLER.applyFont(
            family: pref.lyricFontFamily,
            followPlayer: pref.followPlayerFont ?? false,
          );
        }
      }
    } catch (_) {}
  }

  static Future<void> closeActiveConfig() async {
    _launchSeq++;
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (_) {}
      _activeProcess = null;
    }
    _stdoutSub?.cancel();
    _stdoutSub = null;
    isDialogOpen.value = false;
  }
}
