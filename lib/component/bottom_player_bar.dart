import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/component/cp/cp_components.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

class BottomPlayerBarLayout {
  const BottomPlayerBarLayout({
    required this.compact,
    required this.dense,
  });

  final bool compact;
  final bool dense;
}

BottomPlayerBarLayout resolveBottomPlayerBarLayout(double maxWidth) {
  return BottomPlayerBarLayout(
    compact: maxWidth < 1320,
    dense: maxWidth < 1120,
  );
}

double resolveSliderThumbRadius({
  required bool hovering,
  required bool dragging,
  double visibleRadius = 6,
}) {
  return hovering || dragging ? visibleRadius : 0;
}

bool canPaintSliderAtWidth(double width) {
  return width.isFinite && width >= 8;
}

bool isNowPlayingRoute(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.toString() ==
        app_paths.NOW_PLAYING_PAGE;
  } on GoError {
    return false;
  }
}

class BottomPlayerBar extends StatelessWidget {
  const BottomPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.chrome.dockHeight,
      child: CpSurface(
        tone: CpSurfaceTone.floating,
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = resolveBottomPlayerBarLayout(constraints.maxWidth);

            return Row(
              children: [
                Expanded(
                  child: _BottomBarTrackSection(dense: layout.dense),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _BottomBarCenterSection(
                    compact: layout.compact,
                    dense: layout.dense,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _BottomBarActionsSection(
                    compact: layout.compact,
                    dense: layout.dense,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomBarTrackSection extends StatelessWidget {
  const _BottomBarTrackSection({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        final scheme = Theme.of(context).colorScheme;

        return CpMotionPressable(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          onTap: () {
            if (isNowPlayingRoute(context)) return;
            context.go(app_paths.NOW_PLAYING_PAGE);
          },
          child: Row(
            children: [
              _TrackCover(size: dense ? 52 : 58, audio: audio),
              SizedBox(width: dense ? 12 : 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audio?.title ?? 'Coriander Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: dense ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      audio == null ? 'No track playing' : audio.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: dense ? 12 : 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackCover extends StatelessWidget {
  const _TrackCover({
    required this.size,
    required this.audio,
  });

  final double size;
  final Audio? audio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Icon(
        Symbols.music_note,
        color: scheme.onSurface.withValues(alpha: 0.7),
        size: size * 0.42,
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: StreamBuilder<PlayerState>(
        stream: context.read<PlaybackController>().playerStateStream,
        initialData: context.read<PlaybackController>().playerState,
        builder: (context, snapshot) {
          final motion = context.motion;
          final spinning = snapshot.data == PlayerState.playing;
          final artwork = audio == null
              ? placeholder
              : FutureBuilder<ImageProvider?>(
                  future: audio!.cover,
                  builder: (context, coverSnapshot) {
                    final provider = coverSnapshot.data;
                    final cover = provider == null
                        ? placeholder
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image(
                              image: provider,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => placeholder,
                            ),
                          );

                    return AnimatedSwitcher(
                      duration: motion.controlTransitionDuration,
                      switchInCurve: motion.normal,
                      switchOutCurve: motion.fast,
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: motion.normal,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1)
                                .animate(curved),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey('${audio!.path}:${provider.hashCode}'),
                        child: cover,
                      ),
                    );
                  },
                );

          final cover = _SpinningArtwork(
            spinning: spinning,
            child: RepaintBoundary(child: artwork),
          );

          if (isNowPlayingRoute(context)) {
            return cover;
          }

          return Hero(
            tag: 'now-playing-artwork',
            child: cover,
          );
        },
      ),
    );
  }
}

class _SpinningArtwork extends StatefulWidget {
  const _SpinningArtwork({
    required this.spinning,
    required this.child,
  });

  final bool spinning;
  final Widget child;

  @override
  State<_SpinningArtwork> createState() => _SpinningArtworkState();
}

class _SpinningArtworkState extends State<_SpinningArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _SpinningArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.spinning) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0, end: 1).animate(_controller),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _BottomBarCenterSection extends StatelessWidget {
  const _BottomBarCenterSection({
    required this.compact,
    required this.dense,
  });

  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProgressStrip(compact: compact, dense: dense),
        SizedBox(height: dense ? 2 : 4),
        _PlaybackControls(dense: dense),
      ],
    );
  }
}

class _ProgressStrip extends StatefulWidget {
  const _ProgressStrip({
    required this.compact,
    required this.dense,
  });

  final bool compact;
  final bool dense;

  @override
  State<_ProgressStrip> createState() => _ProgressStripState();
}

class _ProgressStripState extends State<_ProgressStrip> {
  bool _hovering = false;
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    final playback = context.read<PlaybackController>();
    final duration = context.select<PlaybackController, double>(
      (service) => service.length,
    );
    final hasTrack = context.select<PlaybackController, bool>(
      (service) => service.nowPlaying != null,
    );

    return StreamBuilder<double>(
      stream: playback.positionStream,
      initialData: playback.position,
      builder: (context, snapshot) {
        final current = _dragging ? _dragValue : snapshot.data ?? 0;
        final clampedDuration =
            duration.isFinite && duration > 0 ? duration : 1.0;
        final clampedValue = current.isFinite
            ? current.clamp(0.0, clampedDuration).toDouble()
            : 0.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = constraints.maxWidth >= 360 && !widget.dense;
            final thumbRadius = resolveSliderThumbRadius(
              hovering: _hovering,
              dragging: _dragging,
            );

            return MouseRegion(
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: Row(
                children: [
                  if (showLabels)
                    SizedBox(
                      width: 48,
                      child: Text(
                        Duration(
                          milliseconds: (clampedValue * 1000).round(),
                        ).toStringHMMSS(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, sliderConstraints) {
                        if (!canPaintSliderAtWidth(
                          sliderConstraints.maxWidth,
                        )) {
                          return const SizedBox.shrink();
                        }

                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: thumbRadius),
                          duration: motion.microInteractionDuration,
                          curve: motion.fast,
                          builder: (context, animatedThumbRadius, _) {
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                activeTrackColor: accents.progressActive,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.16),
                                thumbColor: accents.progressActive,
                                overlayShape: SliderComponentShape.noOverlay,
                                thumbShape: _GlowSliderThumbShape(
                                  radius: animatedThumbRadius,
                                  color: accents.progressActive,
                                ),
                              ),
                              child: Slider(
                                min: 0,
                                max: clampedDuration,
                                value: clampedValue,
                                onChangeStart: hasTrack
                                    ? (value) {
                                        setState(() {
                                          _dragging = true;
                                          _dragValue = value;
                                        });
                                      }
                                    : null,
                                onChanged: hasTrack
                                    ? (value) =>
                                        setState(() => _dragValue = value)
                                    : null,
                                onChangeEnd: hasTrack
                                    ? (value) {
                                        setState(() => _dragging = false);
                                        playback.seek(value);
                                      }
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (showLabels)
                    SizedBox(
                      width: 48,
                      child: Text(
                        Duration(
                          milliseconds: (duration * 1000).round(),
                        ).toStringHMMSS(),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GlowSliderThumbShape extends SliderComponentShape {
  const _GlowSliderThumbShape({
    required this.radius,
    required this.color,
  });

  final double radius;
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(radius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (radius <= 0) return;

    final canvas = context.canvas;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final fillPaint = Paint()..color = color;

    canvas.drawCircle(center, radius + 1.5, glowPaint);
    canvas.drawCircle(center, radius, fillPaint);
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final buttonSize = dense ? 42.0 : 48.0;

    return StreamBuilder<PlayerState>(
      stream: playback.playerStateStream,
      initialData: playback.playerState,
      builder: (context, snapshot) {
        final playerState = snapshot.data ?? PlayerState.stopped;
        final isPlaying = playerState == PlayerState.playing;
        final icon = switch (playerState) {
          PlayerState.completed => Symbols.replay,
          PlayerState.playing => Symbols.pause,
          _ => Symbols.play_arrow,
        };
        final onPressed = switch (playerState) {
          PlayerState.completed => playback.playAgain,
          PlayerState.playing => playback.pause,
          _ => playback.start,
        };

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CpIconButton(
              tooltip: 'Previous',
              onPressed: playback.lastAudio,
              icon: const Icon(Symbols.skip_previous),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: motion.controlTransitionDuration,
              curve: motion.normal,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(
                      alpha: isPlaying ? 0.32 : 0.24,
                    ),
                    blurRadius: isPlaying ? 20 : 14,
                    spreadRadius: isPlaying ? 1.5 : 0.5,
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.square(buttonSize),
                  maximumSize: Size.square(buttonSize),
                  shape: const CircleBorder(),
                  backgroundColor: isPlaying
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.92),
                ),
                child: AnimatedSwitcher(
                  duration: motion.microInteractionDuration,
                  switchInCurve: motion.emphasized,
                  switchOutCurve: motion.fast,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: motion.emphasized,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale:
                            Tween<double>(begin: 0.78, end: 1).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(icon, key: ValueKey(icon)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CpIconButton(
              tooltip: 'Next',
              onPressed: playback.nextAudio,
              icon: const Icon(Symbols.skip_next),
            ),
          ],
        );
      },
    );
  }
}

class _BottomBarActionsSection extends StatelessWidget {
  const _BottomBarActionsSection({
    required this.compact,
    required this.dense,
  });

  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final constrained = dense || constraints.maxWidth < 330;
        final volumeWidth = constrained ? 0.0 : (compact ? 72.0 : 96.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const _ExclusiveModeControl(),
            SizedBox(width: constrained ? 2 : 6),
            _VolumeControl(width: volumeWidth),
            SizedBox(width: constrained ? 4 : 8),
            const _PlayModeControl(),
            SizedBox(width: constrained ? 2 : 6),
            _QueueEntryButton(dense: constrained),
          ],
        );
      },
    );
  }
}

class _ExclusiveModeControl extends StatelessWidget {
  const _ExclusiveModeControl();

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    if (playback is! PlaybackService) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: playback.wasapiExclusive,
      builder: (context, exclusive, _) => CpIconButton(
        tooltip: "独占模式：${exclusive ? '已启用' : '已禁用'}",
        onPressed: () => playback.useExclusiveMode(!exclusive),
        icon: Center(
          child: Text(
            exclusive ? 'Excl' : 'Shrd',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeControl extends StatefulWidget {
  const _VolumeControl({required this.width});

  final double width;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _hovering = false;
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return ValueListenableBuilder<double>(
      valueListenable: playback.volumeDspNotifier,
      builder: (context, value, _) {
        final rawCurrent = _dragging ? _dragValue : value;
        final current =
            rawCurrent.isFinite ? rawCurrent.clamp(0.0, 1.0).toDouble() : 0.0;
        const minInteractiveSliderWidth = 48.0;
        final effectiveWidth = widget.width > 0 || _hovering || _dragging
            ? (widget.width > 0 ? widget.width : 72.0)
            : 0.0;
        final showSlider = effectiveWidth >= minInteractiveSliderWidth;
        final icon = switch (current) {
          <= 0 => Symbols.volume_off,
          < 0.35 => Symbols.volume_down,
          _ => Symbols.volume_up,
        };

        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CpIconButton(
                tooltip: 'Volume',
                onPressed: () {
                  final next = current <= 0 ? 0.5 : 0.0;
                  playback.setVolumeDsp(next);
                },
                icon: AnimatedSwitcher(
                  duration: motion.microInteractionDuration,
                  switchInCurve: motion.emphasized,
                  switchOutCurve: motion.fast,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.82, end: 1)
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(icon, key: ValueKey(icon)),
                ),
              ),
              ClipRect(
                child: AnimatedContainer(
                  duration: motion.controlTransitionDuration,
                  curve: motion.normal,
                  width: effectiveWidth,
                  child: !showSlider
                      ? const SizedBox.shrink()
                      : LayoutBuilder(
                          builder: (context, sliderConstraints) {
                            if (!canPaintSliderAtWidth(
                              sliderConstraints.maxWidth,
                            )) {
                              return const SizedBox.shrink();
                            }

                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                end: resolveSliderThumbRadius(
                                  hovering: _hovering,
                                  dragging: _dragging,
                                  visibleRadius: 5,
                                ),
                              ),
                              duration: motion.microInteractionDuration,
                              curve: motion.fast,
                              builder: (context, animatedThumbRadius, _) {
                                return SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    activeTrackColor: scheme.primary,
                                    inactiveTrackColor:
                                        Colors.white.withValues(alpha: 0.14),
                                    thumbColor: scheme.primary,
                                    overlayShape:
                                        SliderComponentShape.noOverlay,
                                    thumbShape: _GlowSliderThumbShape(
                                      radius: animatedThumbRadius,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: 1,
                                    value: current,
                                    onChangeStart: (next) {
                                      setState(() {
                                        _dragging = true;
                                        _dragValue = next;
                                      });
                                    },
                                    onChanged: (next) {
                                      setState(() => _dragValue = next);
                                      playback.setVolumeDsp(next);
                                    },
                                    onChangeEnd: (_) =>
                                        setState(() => _dragging = false),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayModeControl extends StatelessWidget {
  const _PlayModeControl();

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return ValueListenableBuilder<PlayMode>(
      valueListenable: playback.playMode,
      builder: (context, playMode, _) {
        final (tooltip, icon) = switch (playMode) {
          PlayMode.forward => ('Sequential', Symbols.repeat),
          PlayMode.loop => ('Shuffle', Symbols.shuffle),
          PlayMode.singleLoop => ('Repeat one', Symbols.repeat_one_on),
        };

        return CpIconButton(
          tooltip: tooltip,
          onPressed: () {
            final next = switch (playMode) {
              PlayMode.forward => PlayMode.loop,
              PlayMode.loop => PlayMode.singleLoop,
              PlayMode.singleLoop => PlayMode.forward,
            };
            playback.setPlayMode(next);
          },
          icon: Icon(icon),
        );
      },
    );
  }
}

class _QueueEntryButton extends StatelessWidget {
  const _QueueEntryButton({required this.dense});

  final bool dense;

  Future<void> _openQueueDialog(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.42).clamp(420.0, 620.0).toDouble();
    final height = (size.height * 0.72).clamp(420.0, 680.0).toDouble();

    return showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: CpSurface(
            tone: CpSurfaceTone.floating,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: width,
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '播放队列',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      CpIconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Symbols.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Expanded(
                    child: CurrentPlaylistView(
                      showHeader: false,
                      dense: true,
                      enableReorder: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return ValueListenableBuilder<List<Audio>>(
      valueListenable: playback.playlist,
      builder: (context, playlist, _) {
        final label = dense ? '' : '队列 ${playlist.length}';
        final canOpenQueue = playlist.isNotEmpty || playback.nowPlaying != null;

        return Tooltip(
          message: canOpenQueue ? '打开播放队列' : '暂无播放队列',
          child: dense
              ? CpIconButton(
                  onPressed:
                      canOpenQueue ? () => _openQueueDialog(context) : null,
                  icon: Badge(
                    label: Text('${playlist.length}'),
                    child: const Icon(Symbols.queue_music),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed:
                      canOpenQueue ? () => _openQueueDialog(context) : null,
                  icon: const Icon(Symbols.queue_music),
                  label: Text(label),
                ),
        );
      },
    );
  }
}
