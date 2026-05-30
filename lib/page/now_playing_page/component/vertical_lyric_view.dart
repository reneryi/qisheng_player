import 'dart:async';
import 'dart:math';

import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_controls_visibility.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerticalLyricView extends StatefulWidget {
  const VerticalLyricView({super.key});

  @override
  State<VerticalLyricView> createState() => _VerticalLyricViewState();
}

class _VerticalLyricViewState extends State<VerticalLyricView> {
  final lyricViewController = LyricViewController();
  late final LyricControlsVisibilityController visibilityController =
      LyricControlsVisibilityController();

  @override
  void dispose() {
    lyricViewController.dispose();
    visibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        visibilityController.setRegionHovered(true);
      },
      onExit: (_) {
        visibilityController.setRegionHovered(false);
      },
      child: Material(
        type: MaterialType.transparency,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: lyricViewController),
              ChangeNotifierProvider.value(value: visibilityController),
            ],
            child: ListenableBuilder(
              listenable: PlayService.instance.lyricService,
              builder: (context, _) => ListenableBuilder(
                listenable: visibilityController,
                builder: (context, __) {
                  final showControls = visibilityController.visible;
                  return FutureBuilder(
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
                                : _VerticalLyricScrollView(
                                    lyric: lyricNullable),
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

    _scrollCurrentLyricIntoView(animated: false);
  }

  @override
  void didUpdateWidget(covariant _VerticalLyricScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyric == widget.lyric) return;
    _lastSafeIndex = null;
    _lastLyricUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    _initLyricView();
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
        final isCurrent = i == mainLine;
        final isPast = i < mainLine;
        final distance = (i - mainLine).abs();
        final opacity = isCurrent
            ? 1.0
            : isPast
                ? (0.42 - distance * 0.045).clamp(0.22, 0.42).toDouble()
                : (0.34 - distance * 0.04).clamp(0.16, 0.34).toDouble();
        return LyricViewTile(
          key: i == mainLine ? currentLyricTileKey : null,
          line: widget.lyric.lines[i],
          opacity: opacity,
          isCurrentLine: isCurrent,
          isPastLine: isPast,
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

    _scrollCurrentLyricIntoView();
  }

  void _scrollCurrentLyricIntoView({bool animated = true, int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      if (!scrollController.hasClients) {
        _retryScrollCurrentLyricIntoView(animated: animated, attempt: attempt);
        return;
      }

      final targetContext = currentLyricTileKey.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        _retryScrollCurrentLyricIntoView(animated: animated, attempt: attempt);
        return;
      }

      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.25,
        duration: animated ? context.motion.lyricScrollDuration : Duration.zero,
        curve: context.motion.emphasized,
      );
    });
  }

  void _retryScrollCurrentLyricIntoView({
    required bool animated,
    required int attempt,
  }) {
    if (attempt >= 3) return;
    Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)), () {
      if (!mounted) return;
      _scrollCurrentLyricIntoView(animated: animated, attempt: attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomScrollView(
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
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
  }
}
