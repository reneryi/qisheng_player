import 'dart:async';
import 'dart:math';

import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

class LyricViewTile extends StatelessWidget {
  const LyricViewTile({
    super.key,
    required this.line,
    required this.opacity,
    this.isCurrentLine = false,
    this.isPastLine = false,
    this.onTap,
  });

  final LyricLine line;
  final double opacity;
  final bool isCurrentLine;
  final bool isPastLine;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final lyricViewController = context.watch<LyricViewController>();
    final motion = context.motion;
    final isMainLine = isCurrentLine || opacity == 1.0;
    return Align(
      alignment: switch (lyricViewController.lyricTextAlign) {
        LyricTextAlign.left => Alignment.centerLeft,
        LyricTextAlign.center => Alignment.center,
        LyricTextAlign.right => Alignment.centerRight,
      },
      child: AnimatedOpacity(
        duration: motion.controlTransitionDuration,
        curve: motion.fast,
        opacity: opacity,
        child: AnimatedScale(
          duration: motion.controlTransitionDuration,
          curve: motion.normal,
          scale: isMainLine ? 1 : 0.985,
          alignment: switch (lyricViewController.lyricTextAlign) {
            LyricTextAlign.left => Alignment.centerLeft,
            LyricTextAlign.center => Alignment.center,
            LyricTextAlign.right => Alignment.centerRight,
          },
          child: AnimatedPadding(
            duration: motion.controlTransitionDuration,
            curve: motion.normal,
            padding: EdgeInsets.symmetric(vertical: isMainLine ? 4 : 0),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14.0),
              child: line is SyncLyricLine
                  ? _SyncLineContent(
                      syncLine: line as SyncLyricLine,
                      isMainLine: isMainLine,
                      isPastLine: isPastLine,
                    )
                  : _LrcLineContent(
                      lrcLine: line as LrcLine,
                      isMainLine: isMainLine,
                      isPastLine: isPastLine,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncLineContent extends StatelessWidget {
  const _SyncLineContent({
    required this.syncLine,
    required this.isMainLine,
    required this.isPastLine,
  });

  final SyncLyricLine syncLine;
  final bool isMainLine;
  final bool isPastLine;

  @override
  Widget build(BuildContext context) {
    if (syncLine.words.isEmpty) {
      if (syncLine.length > const Duration(seconds: 5) && isMainLine) {
        return LyricTransitionTile(syncLine: syncLine);
      } else {
        return const SizedBox.shrink();
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    final lyricFontSize = lyricViewController.lyricFontSize;
    final translationFontSize = lyricViewController.translationFontSize;
    final alignment = lyricViewController.lyricTextAlign;
    final showTranslation = lyricViewController.showTranslation;

    if (!isMainLine) {
      if (syncLine.words.isEmpty) {
        return const SizedBox.shrink();
      }

      final List<Text> contents = [
        buildPrimaryText(syncLine.content, scheme, alignment, lyricFontSize),
      ];
      if (showTranslation && syncLine.translation != null) {
        contents.add(buildSecondaryText(
          syncLine.translation!,
          scheme,
          alignment,
          translationFontSize,
        ));
      }

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: switch (alignment) {
            LyricTextAlign.left => CrossAxisAlignment.start,
            LyricTextAlign.center => CrossAxisAlignment.center,
            LyricTextAlign.right => CrossAxisAlignment.end,
          },
          children: contents,
        ),
      );
    }

    final List<Widget> contents = [
      StreamBuilder(
        stream: PlayService.instance.playbackService.positionStream,
        builder: (context, snapshot) {
          final posInMs = (snapshot.data ?? 0) * 1000;
          return RichText(
            textAlign: switch (alignment) {
              LyricTextAlign.left => TextAlign.left,
              LyricTextAlign.center => TextAlign.center,
              LyricTextAlign.right => TextAlign.right,
            },
            text: TextSpan(
              children: List.generate(
                syncLine.words.length,
                (i) {
                  final posFromWordStart = max(
                    posInMs - syncLine.words[i].start.inMilliseconds,
                    0,
                  );
                  final progress = min(
                    posFromWordStart / syncLine.words[i].length.inMilliseconds,
                    1.0,
                  );
                  return WidgetSpan(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.10),
                            scheme.primary.withValues(alpha: 0.10),
                          ],
                          stops: [0, progress, progress, 1],
                        ).createShader(bounds);
                      },
                      child: Text(
                        syncLine.words[i].content,
                        style: _primaryStyle(
                          scheme,
                          lyricFontSize,
                          isMainLine: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      )
    ];
    if (showTranslation && syncLine.translation != null) {
      contents.add(buildSecondaryText(
        syncLine.translation!,
        scheme,
        alignment,
        translationFontSize,
      ));
    }
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: switch (alignment) {
          LyricTextAlign.left => CrossAxisAlignment.start,
          LyricTextAlign.center => CrossAxisAlignment.center,
          LyricTextAlign.right => CrossAxisAlignment.end,
        },
        children: contents,
      ),
    );
  }

  Text buildPrimaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
  ) {
    return Text(
      text,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: TextStyle(
        color: scheme.onSecondaryContainer.withValues(
          alpha: isPastLine ? 0.88 : 0.72,
        ),
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Text buildSecondaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
  ) {
    return Text(
      text,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: TextStyle(
        color: scheme.onSecondaryContainer.withValues(
          alpha: isPastLine ? 0.7 : 0.58,
        ),
        fontSize: fontSize,
        height: 1.24,
      ),
    );
  }

  TextStyle _primaryStyle(
    ColorScheme scheme,
    double fontSize, {
    required bool isMainLine,
  }) {
    if (!isMainLine) {
      return TextStyle(
        color: scheme.onSecondaryContainer.withValues(
          alpha: isPastLine ? 0.88 : 0.72,
        ),
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      );
    }

    return TextStyle(
      color: scheme.onSecondaryContainer,
      fontSize: fontSize + 4,
      fontWeight: FontWeight.w800,
      height: 1.16,
      shadows: [
        Shadow(
          color: scheme.primary.withValues(alpha: 0.34),
          blurRadius: 16,
        ),
      ],
    );
  }
}

class _LrcLineContent extends StatelessWidget {
  const _LrcLineContent({
    required this.lrcLine,
    required this.isMainLine,
    required this.isPastLine,
  });

  final LrcLine lrcLine;
  final bool isMainLine;
  final bool isPastLine;

  @override
  Widget build(BuildContext context) {
    if (lrcLine.isBlank) {
      if (lrcLine.length > const Duration(seconds: 5) && isMainLine) {
        return LyricTransitionTile(lrcLine: lrcLine);
      } else {
        return const SizedBox.shrink();
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    final lyricFontSize = lyricViewController.lyricFontSize;
    final translationFontSize = lyricViewController.translationFontSize;
    final alignment = lyricViewController.lyricTextAlign;
    final showTranslation = lyricViewController.showTranslation;

    final splited = lrcLine.content.split("┃");
    final List<Text> contents = [
      buildPrimaryText(splited.first, scheme, alignment, lyricFontSize),
    ];
    if (showTranslation) {
      for (var i = 1; i < splited.length; i++) {
        contents.add(buildSecondaryText(
          splited[i],
          scheme,
          alignment,
          translationFontSize,
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: switch (alignment) {
          LyricTextAlign.left => CrossAxisAlignment.start,
          LyricTextAlign.center => CrossAxisAlignment.center,
          LyricTextAlign.right => CrossAxisAlignment.end,
        },
        children: contents,
      ),
    );
  }

  Text buildPrimaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
  ) {
    return Text(
      text,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: TextStyle(
        color: isMainLine
            ? scheme.onSecondaryContainer
            : scheme.onSecondaryContainer.withValues(
                alpha: isPastLine ? 0.88 : 0.72,
              ),
        fontSize: isMainLine ? fontSize + 4 : fontSize,
        fontWeight: isMainLine ? FontWeight.w800 : FontWeight.w500,
        height: isMainLine ? 1.16 : 1.22,
        shadows: isMainLine
            ? [
                Shadow(
                  color: scheme.primary.withValues(alpha: 0.34),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
    );
  }

  Text buildSecondaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
  ) {
    return Text(
      text,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: TextStyle(
        color: isMainLine
            ? scheme.onSecondaryContainer.withValues(alpha: 0.76)
            : scheme.onSecondaryContainer.withValues(
                alpha: isPastLine ? 0.7 : 0.58,
              ),
        fontSize: fontSize,
        height: 1.24,
      ),
    );
  }
}

/// 歌词间奏表示
/// lrcLine 和 syncLine 必须有且只有一个不为空
class LyricTransitionTile extends StatefulWidget {
  final LrcLine? lrcLine;
  final SyncLyricLine? syncLine;
  const LyricTransitionTile({super.key, this.lrcLine, this.syncLine});

  @override
  State<LyricTransitionTile> createState() => _LyricTransitionTileState();
}

class _LyricTransitionTileState extends State<LyricTransitionTile> {
  late LyricTransitionTileController controller;

  @override
  void initState() {
    super.initState();
    controller = LyricTransitionTileController(widget.lrcLine, widget.syncLine);
  }

  @override
  void didUpdateWidget(covariant LyricTransitionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lrcLine == widget.lrcLine &&
        oldWidget.syncLine == widget.syncLine) {
      return;
    }
    controller.dispose();
    controller = LyricTransitionTileController(widget.lrcLine, widget.syncLine);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40.0,
      width: 80.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
        child: CustomPaint(
          painter: LyricTransitionPainter(
            scheme,
            controller,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class LyricTransitionPainter extends CustomPainter {
  final ColorScheme scheme;
  final LyricTransitionTileController controller;

  final Paint circlePaint1 = Paint();
  final Paint circlePaint2 = Paint();
  final Paint circlePaint3 = Paint();

  final double radius = 6;

  LyricTransitionPainter(this.scheme, this.controller)
      : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    circlePaint1.color = scheme.onSecondaryContainer.withValues(
      alpha: 0.05 + min(controller.progress * 3, 1) * 0.95,
    );
    circlePaint2.color = scheme.onSecondaryContainer.withValues(
      alpha: 0.05 + min(max(controller.progress - 1 / 3, 0) * 3, 1) * 0.95,
    );
    circlePaint3.color = scheme.onSecondaryContainer.withValues(
      alpha: 0.05 + min(max(controller.progress - 2 / 3, 0) * 3, 1) * 0.95,
    );

    final rWithFactor = radius + controller.sizeFactor;
    final c1 = Offset(rWithFactor, 8);
    final c2 = Offset(4 * rWithFactor, 8);
    final c3 = Offset(7 * rWithFactor, 8);

    canvas.drawCircle(c1, rWithFactor, circlePaint1);
    canvas.drawCircle(c2, rWithFactor, circlePaint2);
    canvas.drawCircle(c3, rWithFactor, circlePaint3);
  }

  @override
  bool shouldRepaint(LyricTransitionPainter oldDelegate) {
    return oldDelegate.scheme != scheme || oldDelegate.controller != controller;
  }

  @override
  bool shouldRebuildSemantics(LyricTransitionPainter oldDelegate) => false;
}

class LyricTransitionTileController extends ChangeNotifier {
  final LrcLine? lrcLine;
  final SyncLyricLine? syncLine;

  final playbackService = PlayService.instance.playbackService;

  double progress = 0;
  late final StreamSubscription positionStreamSub;

  double sizeFactor = 0;
  double k = 1;
  late final Ticker factorTicker;
  bool _disposed = false;

  LyricTransitionTileController([this.lrcLine, this.syncLine]) {
    positionStreamSub = playbackService.positionStream.listen(_updateProgress);
    factorTicker = Ticker((elapsed) {
      sizeFactor += k * 1 / 180;
      if (sizeFactor > 1) {
        k = -1;
        sizeFactor = 1;
      } else if (sizeFactor < 0) {
        k = 1;
        sizeFactor = 0;
      }
      notifyListeners();
    });
    factorTicker.start();
  }

  void _updateProgress(double position) {
    late int startInMs;
    late int lengthInMs;
    if (lrcLine != null) {
      startInMs = lrcLine!.start.inMilliseconds;
      lengthInMs = lrcLine!.length.inMilliseconds;
    } else {
      startInMs = syncLine!.start.inMilliseconds;
      lengthInMs = syncLine!.length.inMilliseconds;
    }
    final sinceStart = position * 1000 - startInMs;
    progress = max(sinceStart, 0) / lengthInMs;
    notifyListeners();

    if (progress >= 1) {
      dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    positionStreamSub.cancel();
    factorTicker.dispose();
    super.dispose();
  }
}
