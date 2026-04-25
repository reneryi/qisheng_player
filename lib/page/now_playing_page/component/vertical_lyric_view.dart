import 'dart:async';
import 'dart:math';

import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

bool ALWAYS_SHOW_LYRIC_VIEW_CONTROLS = false;

class VerticalLyricView extends StatefulWidget {
  const VerticalLyricView({super.key});

  @override
  State<VerticalLyricView> createState() => _VerticalLyricViewState();
}

class _VerticalLyricViewState extends State<VerticalLyricView> {
  bool isHovering = false;
  final lyricViewController = LyricViewController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final showControls = isHovering || ALWAYS_SHOW_LYRIC_VIEW_CONTROLS;

    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovering = false;
        });
      },
      child: Material(
        type: MaterialType.transparency,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: ChangeNotifierProvider.value(
            value: lyricViewController,
            child: ListenableBuilder(
              listenable: PlayService.instance.lyricService,
              builder: (context, _) => FutureBuilder(
                future: PlayService.instance.lyricService.currLyricFuture,
                builder: (context, snapshot) {
                  final lyricNullable = snapshot.data;
                  final noLyricWidget = Center(
                    child: Text(
                      "暂无歌词",
                      style: TextStyle(
                        fontSize: 22,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  );

                  return Stack(
                    children: [
                      switch (snapshot.connectionState) {
                        ConnectionState.none => loadingWidget,
                        ConnectionState.waiting => loadingWidget,
                        ConnectionState.active => loadingWidget,
                        ConnectionState.done => lyricNullable == null
                            ? noLyricWidget
                            : _VerticalLyricScrollView(lyric: lyricNullable),
                      },
                      Align(
                        alignment: Alignment.bottomRight,
                        child: IgnorePointer(
                          ignoring: !showControls,
                          child: AnimatedSlide(
                            duration: motion.controlTransitionDuration,
                            curve: motion.normal,
                            offset: showControls
                                ? Offset.zero
                                : const Offset(0.04, 0.08),
                            child: AnimatedOpacity(
                              duration: motion.controlTransitionDuration,
                              curve: motion.fast,
                              opacity: showControls ? 1 : 0,
                              child: const LyricViewControls(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final LYRIC_VIEW_KEY = GlobalKey();

class _VerticalLyricScrollView extends StatefulWidget {
  const _VerticalLyricScrollView({required this.lyric});

  final Lyric lyric;

  @override
  State<_VerticalLyricScrollView> createState() =>
      _VerticalLyricScrollViewState();
}

class _VerticalLyricScrollViewState extends State<_VerticalLyricScrollView> {
  final playbackService = PlayService.instance.playbackService;
  final lyricService = PlayService.instance.lyricService;
  late StreamSubscription lyricLineStreamSubscription;
  final scrollController = ScrollController();

  List<LyricViewTile> lyricTiles = [
    LyricViewTile(line: LrcLine.defaultLine, opacity: 1.0)
  ];

  final currentLyricTileKey = GlobalKey();
  int? _lastSafeIndex;
  DateTime _lastLyricUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    _initLyricView();
    lyricLineStreamSubscription =
        lyricService.lyricLineStream.listen(_updateNextLyricLine);
  }

  void _initLyricView() {
    final next = widget.lyric.lines.indexWhere(
      (element) =>
          element.start.inMilliseconds / 1000 > playbackService.position,
    );
    final nextLyricLine = next == -1 ? widget.lyric.lines.length : next;
    lyricTiles = _generateLyricTiles(max(nextLyricLine - 1, 0));

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final targetContext = currentLyricTileKey.currentContext;
      if (targetContext == null) return;

      if (targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.25,
          duration: context.motion.lyricScrollDuration,
          curve: context.motion.normal,
        );
      }
    });
  }

  void _seekToLyricLine(int i) {
    playbackService.seek(widget.lyric.lines[i].start.inMilliseconds / 1000);
    setState(() {
      lyricTiles = _generateLyricTiles(i);
    });
  }

  List<LyricViewTile> _generateLyricTiles(int mainLine) {
    return List.generate(
      widget.lyric.lines.length,
      (i) {
        double opacity = 1.0;
        if ((mainLine >= 1 && i <= mainLine - 1) ||
            (mainLine < widget.lyric.lines.length - 1 && i >= mainLine + 1)) {
          opacity = 0.18;
        }
        return LyricViewTile(
          key: i == mainLine ? currentLyricTileKey : null,
          line: widget.lyric.lines[i],
          opacity: opacity,
          onTap: () => _seekToLyricLine(i),
        );
      },
    );
  }

  void _updateNextLyricLine(int lyricLine) {
    if (widget.lyric.lines.isEmpty) return;
    final safeIndex = lyricLine.clamp(0, widget.lyric.lines.length - 1).toInt();
    final now = DateTime.now();
    if (_lastSafeIndex == safeIndex &&
        now.difference(_lastLyricUpdateAt) <
            const Duration(milliseconds: 120)) {
      return;
    }
    _lastSafeIndex = safeIndex;
    _lastLyricUpdateAt = now;
    lyricTiles = _generateLyricTiles(safeIndex);
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final targetContext = currentLyricTileKey.currentContext;
      if (targetContext == null) return;

      if (targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.25,
          duration: context.motion.lyricScrollDuration,
          curve: context.motion.normal,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: LYRIC_VIEW_KEY,
      controller: scrollController,
      slivers: [
        const SliverFillRemaining(),
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lyricTiles,
            ),
          ),
        ),
        const SliverFillRemaining(),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
  }
}
