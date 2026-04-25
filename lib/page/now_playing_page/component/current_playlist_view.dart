import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CurrentPlaylistView extends StatefulWidget {
  const CurrentPlaylistView({
    super.key,
    this.showHeader = true,
    this.dense = false,
    this.enableReorder = true,
  });

  final bool showHeader;
  final bool dense;
  final bool enableReorder;

  @override
  State<CurrentPlaylistView> createState() => _CurrentPlaylistViewState();
}

class _CurrentPlaylistViewState extends State<CurrentPlaylistView> {
  late final PlaybackController playbackService;
  late final ScrollController scrollController;

  double get _itemExtent => widget.dense ? 64.0 : 68.0;

  void _toNowPlaying() {
    if (!scrollController.hasClients) return;
    final target = playbackService.playlistIndex * _itemExtent;
    final max = scrollController.position.maxScrollExtent;
    scrollController.animateTo(
      target.clamp(0.0, max),
      duration: context.motion.controlTransitionDuration,
      curve: context.motion.normal,
    );
  }

  @override
  void initState() {
    super.initState();
    playbackService = context.read<PlaybackController>();
    scrollController = ScrollController(
      initialScrollOffset: playbackService.playlistIndex * _itemExtent,
    );
    playbackService.addListener(_toNowPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 10),
              child: Text(
                '当前队列',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: widget.dense ? 18 : 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: playbackService,
              builder: (context, _) {
                final queue = playbackService.playlist.value;
                final canReorder = widget.enableReorder && queue.length <= 120;
                return Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: canReorder
                      ? ReorderableListView.builder(
                          scrollController: scrollController,
                          buildDefaultDragHandles: false,
                          itemCount: queue.length,
                          itemExtent: _itemExtent,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              color: Colors.transparent,
                              child: child,
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            playbackService.reorderPlaylist(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            return _PlaylistViewItem(
                              key: ValueKey(item.path),
                              index: index,
                              dense: widget.dense,
                              isCurrent: index == playbackService.playlistIndex,
                              enableReorder: true,
                            );
                          },
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: queue.length,
                          itemExtent: _itemExtent,
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            return _PlaylistViewItem(
                              key: ValueKey(item.path),
                              index: index,
                              dense: widget.dense,
                              isCurrent: index == playbackService.playlistIndex,
                              enableReorder: false,
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    playbackService.removeListener(_toNowPlaying);
    scrollController.dispose();
    super.dispose();
  }
}

class _PlaylistViewItem extends StatelessWidget {
  const _PlaylistViewItem({
    super.key,
    required this.index,
    required this.dense,
    required this.isCurrent,
    required this.enableReorder,
  });

  final int index;
  final bool dense;
  final bool isCurrent;
  final bool enableReorder;

  @override
  Widget build(BuildContext context) {
    final playbackService = context.read<PlaybackController>();
    final item = playbackService.playlist.value[index];
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    final isPlaying = context.select<PlaybackController, bool>(
      (service) => service.playerState == PlayerState.playing,
    );

    final itemTile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedContainer(
        duration: motion.listTransitionDuration,
        curve: motion.normal,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isCurrent
              ? accents.selectionTint.withValues(alpha: 0.95)
              : Colors.transparent,
          border: Border.all(
            color: isCurrent
                ? accents.accent.withValues(alpha: 0.24)
                : Colors.transparent,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => playbackService.playIndexOfPlaylist(index),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 10 : 12,
                vertical: dense ? 8 : 10,
              ),
              child: Row(
                children: [
                  RepaintBoundary(
                    child: _PlaylistWaveformIndicator(
                      active: isCurrent && isPlaying,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: dense ? 13 : 14,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.58),
                            fontSize: dense ? 11 : 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enableReorder)
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: dense ? 18 : 20,
                        color: scheme.onSurface.withValues(alpha: 0.42),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!enableReorder) return itemTile;
    return ReorderableDelayedDragStartListener(
      index: index,
      child: itemTile,
    );
  }
}

class _PlaylistWaveformIndicator extends StatefulWidget {
  const _PlaylistWaveformIndicator({required this.active});

  final bool active;

  @override
  State<_PlaylistWaveformIndicator> createState() =>
      _PlaylistWaveformIndicatorState();
}

class _PlaylistWaveformIndicatorState extends State<_PlaylistWaveformIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PlaylistWaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 18,
      height: 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = widget.active ? _controller.value : 0.0;
          return CustomPaint(
            painter: _PlaylistWaveformPainter(
              progress: progress,
              active: widget.active,
              activeColor: scheme.primary,
              inactiveColor: scheme.onSurface.withValues(alpha: 0.22),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PlaylistWaveformPainter extends CustomPainter {
  const _PlaylistWaveformPainter({
    required this.progress,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double progress;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final heights = [
      8.0 + (active ? 8.0 * (0.5 + 0.5 * progress) : 0.0),
      12.0 + (active ? 10.0 * (0.5 + 0.5 * (1 - progress)) : 0.0),
      7.0 +
          (active
              ? 9.0 *
                  (0.5 +
                      0.5 *
                          (0.5 +
                              0.5 *
                                  (progress < 0.5
                                      ? progress * 2
                                      : (1 - progress) * 2)))
              : 0.0),
    ];
    const barWidth = 4.0;
    final gap = (size.width - barWidth * heights.length) / (heights.length - 1);
    final paint = Paint()..color = active ? activeColor : inactiveColor;

    for (var index = 0; index < heights.length; index++) {
      final height = heights[index].clamp(0.0, size.height).toDouble();
      final left = index * (barWidth + gap);
      final rect = Rect.fromLTWH(left, size.height - height, barWidth, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(999)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlaylistWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
