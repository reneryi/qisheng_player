import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/message.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LyricLineDisplayArea extends StatelessWidget {
  const LyricLineDisplayArea({super.key});

  @override
  Widget build(BuildContext context) {
    final textDisplayController = context.watch<TextDisplayController>();
    final theme = context.watch<ThemeChangedMessage>();

    final textColor = textDisplayController.hasSpecifiedColor
        ? textDisplayController.specifiedColor
        : Color(theme.primary);

    return ValueListenableBuilder(
      valueListenable: DesktopLyricController.instance.lyricLine,
      builder: (context, lyricLine, _) {
        final contentText = Text(
          key: LYRIC_TEXT_KEY,
          lyricLine.content,
          style: TextStyle(
            color: textColor,
            fontSize: textDisplayController.lyricFontSize,
            fontFamily: textDisplayController.lyricFontFamily,
            fontWeight: FontWeight.bold,
            shadows: kElevationToShadow[4],
          ),
          maxLines: 1,
        );

        final hasTranslation = textDisplayController.showTranslation &&
            lyricLine.translation != null &&
            lyricLine.translation!.trim().isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            contentText,
            if (hasTranslation) ...[
              const SizedBox(height: 4.0),
              Text(
                key: TRANSLATION_TEXT_KEY,
                lyricLine.translation!,
                style: TextStyle(
                  color: textColor,
                  fontSize: textDisplayController.translationFontSize,
                  fontFamily: textDisplayController.lyricFontFamily,
                  fontWeight: FontWeight.bold,
                  shadows: kElevationToShadow[4],
                ),
                maxLines: 1,
              ),
            ],
          ],
        );
      },
    );
  }
}
