import 'dart:async';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/play_service/lyric_service.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HorizontalLyricView extends StatelessWidget {
  const HorizontalLyricView({super.key});

  LyricController _resolveLyricController(BuildContext context) {
    try {
      return context.read<LyricController>();
    } catch (_) {
      return PlayService.instance.lyricService;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricController = _resolveLyricController(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ListenableBuilder(
        listenable: lyricController,
        builder: (context, _) => FutureBuilder(
          future: lyricController.currLyricFuture,
          builder: (context, snapshot) {
            if (snapshot.data == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Enjoy Music",
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            return _LyricHorizontalScrollArea(
              snapshot.data!,
              lyricController: lyricController,
            );
          },
        ),
      ),
    );
  }
}

class _LyricHorizontalScrollArea extends StatefulWidget {
  const _LyricHorizontalScrollArea(
    this.lyric, {
    required this.lyricController,
  });

  final Lyric lyric;
  final LyricController lyricController;

  @override
  State<_LyricHorizontalScrollArea> createState() =>
      _LyricHorizontalScrollAreaState();
}

class _LyricHorizontalScrollAreaState
    extends State<_LyricHorizontalScrollArea> {
  final waitFor = const Duration(milliseconds: 300);
  final scrollController = ScrollController();
  late StreamSubscription lyricLineStreamSubscription;
  Timer? _pendingScrollTimer;

  var currContent = "Enjoy Music";
  var _scrollGeneration = 0;

  String _lineText(LyricLine line) {
    final showTranslation =
        AppPreference.instance.nowPlayingPagePref.showTranslation;
    if (line is LrcLine) {
      if (showTranslation) return line.content;
      return line.content.split("┃").first;
    }
    if (line is SyncLyricLine) {
      if (!showTranslation || line.translation == null) return line.content;
      return "${line.content}┃${line.translation}";
    }
    return "Enjoy Music";
  }

  @override
  void initState() {
    super.initState();
    if (widget.lyric.lines.isNotEmpty) {
      currContent = _lineText(widget.lyric.lines.first);
    }

    lyricLineStreamSubscription = widget.lyricController.lyricLineStream.listen(
      (line) {
        if (widget.lyric.lines.isEmpty) return;
        final safeIndex = line.clamp(0, widget.lyric.lines.length - 1).toInt();
        final currLine = widget.lyric.lines[safeIndex];

        setState(() {
          currContent = _lineText(currLine);
        });
        final generation = ++_scrollGeneration;
        _pendingScrollTimer?.cancel();

        late final Duration lastTime;
        if (currLine is LrcLine) {
          lastTime = currLine.length - waitFor - waitFor;
        } else if (currLine is SyncLyricLine) {
          lastTime = currLine.length - waitFor - waitFor;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _scrollGeneration) return;
          if (!scrollController.hasClients) return;

          scrollController.jumpTo(0);
          if (scrollController.position.maxScrollExtent > 0) {
            if (lastTime.isNegative) return;

            _pendingScrollTimer = Timer(waitFor, () {
              if (!mounted || generation != _scrollGeneration) return;
              if (!scrollController.hasClients) return;

              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: lastTime,
                curve: Curves.easeOutCubic,
              );
            });
          }
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant _LyricHorizontalScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyric == widget.lyric) return;
    _scrollGeneration++;
    _pendingScrollTimer?.cancel();
    currContent = widget.lyric.lines.isEmpty
        ? "Enjoy Music"
        : _lineText(widget.lyric.lines.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: motion.controlTransitionDuration,
              switchInCurve: motion.normal,
              switchOutCurve: motion.fast,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: motion.normal,
                  reverseCurve: motion.fast,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: Text(
                currContent,
                key: ValueKey(currContent),
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: scheme.primary.withValues(alpha: 0.22),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollGeneration++;
    _pendingScrollTimer?.cancel();
    super.dispose();
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
  }
}
