import 'package:desktop_lyric/component/foreground.dart';
import 'package:desktop_lyric/message.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NowPlayingInfo extends StatelessWidget {
  const NowPlayingInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeChangedMessage>();
    final (textColor, fontFamily) = context.select<TextDisplayController, (Color, String?)>(
      (c) => (
        c.hasSpecifiedColor ? c.specifiedColor : Color(theme.primary),
        c.lyricFontFamily,
      ),
    );
    final textStyle = TextStyle(
      color: textColor,
      fontFamily: fontFamily,
    );

    return SizedBox(
      height: 44.0,
      child: Center(
        child: ValueListenableBuilder(
          valueListenable: DesktopLyricController.instance.nowPlaying,
          builder: (context, nowPlaying, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nowPlaying.title,
                  style: textStyle.copyWith(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  "${nowPlaying.artist} - ${nowPlaying.album}",
                  style: textStyle.copyWith(
                    fontSize: 11.5,
                    color: textColor.withValues(alpha: 0.72),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
