import 'dart:io';

import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart' as win32;

class ActionRow extends StatelessWidget {
  const ActionRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeChangedMessage>();
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        DesktopLyricController.instance.isDarkMode.value;
    final onSurfaceColor = Color(theme.onSurface);
    final iconColor = isDark
        ? (onSurfaceColor.computeLuminance() > 0.4 ? onSurfaceColor : Colors.white)
        : (onSurfaceColor.computeLuminance() < 0.6 ? onSurfaceColor : const Color(0xFF0F172A));

    const spacer = SizedBox(width: 8);
    final textDisplayController = context.read<TextDisplayController>();

    return ValueListenableBuilder<String?>(
      valueListenable: DesktopLyricController.instance.currentFontFamily,
      builder: (context, currentFontFromPlayer, _) {
        textDisplayController.initializeFontFamilyFromPlayer(
          currentFontFromPlayer,
        );
        return Stack(
          alignment: Alignment.centerRight,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () async {
                  hWnd = win32.GetForegroundWindow();

                  if (hWnd != null) {
                    final exStyle = win32.GetWindowLongPtr(
                      hWnd!,
                      win32.GWL_EXSTYLE,
                    );

                    win32.SetWindowLongPtr(
                      hWnd!,
                      win32.GWL_EXSTYLE,
                      exStyle |
                          win32.WS_EX_LAYERED |
                          win32.WS_EX_TRANSPARENT,
                    );

                    stdout.write(
                      "${const ControlEventMessage(ControlEvent.lock).buildMessageJson()}\n",
                    );
                  }
                },
                color: iconColor,
                icon: const Icon(Icons.lock),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: textDisplayController.increaseLyricFontSize,
                  color: iconColor,
                  icon: const Icon(Icons.text_increase),
                ),
                spacer,
                IconButton(
                  onPressed: textDisplayController.decreaseLyricFontSize,
                  color: iconColor,
                  icon: const Icon(Icons.text_decrease),
                ),
                spacer,
                IconButton(
                  onPressed: () => showLyricFontSelectorDialog(context),
                  color: iconColor,
                  tooltip: "歌词字体",
                  icon: const Icon(Icons.font_download),
                ),
                spacer,
                IconButton(
                  onPressed: () {
                    stdout.write(
                      "${const ControlEventMessage(ControlEvent.previousAudio).buildMessageJson()}\n",
                    );
                  },
                  color: iconColor,
                  icon: const Icon(Icons.skip_previous),
                ),
                spacer,
                ValueListenableBuilder(
                  valueListenable: DesktopLyricController.instance.isPlaying,
                  builder: (context, isPlaying, _) => IconButton(
                    onPressed: () {
                      stdout.write(
                        "${ControlEventMessage(isPlaying ? ControlEvent.pause : ControlEvent.start).buildMessageJson()}\n",
                      );
                    },
                    color: iconColor,
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                ),
                spacer,
                IconButton(
                  onPressed: () {
                    stdout.write(
                      "${const ControlEventMessage(ControlEvent.nextAudio).buildMessageJson()}\n",
                    );
                  },
                  color: iconColor,
                  icon: const Icon(Icons.skip_next),
                ),
                spacer,
                IconButton(
                  onPressed: () => showDesktopLyricColorDialog(context),
                  color: iconColor,
                  tooltip: "歌词颜色",
                  icon: const Icon(Icons.color_lens_outlined),
                ),
                spacer,
                IconButton(
                  onPressed: () async {
                    try {
                      stdout.write(
                        "${const ControlEventMessage(ControlEvent.close).buildMessageJson()}\n",
                      );
                      await stdout.flush();
                    } catch (_) {}
                    exit(0);
                  },
                  color: iconColor,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}


