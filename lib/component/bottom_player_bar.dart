import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_brand.dart';
import 'package:qisheng_player/component/ui/modern_tooltip.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';
import 'package:qisheng_player/component/adaptive_waveform_slider.dart';
import 'package:qisheng_player/component/dual_layer_rhythm_slider.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/component/marquee_text.dart';
import 'package:qisheng_player/component/now_playing_navigation.dart';
import 'package:qisheng_player/component/ui/audio_format_badge.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
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

class BottomPlayerBar extends StatelessWidget {
  const BottomPlayerBar({
    super.key,
    this.transparent = false,
    this.disableHero = false,
  });

  final bool transparent;
  final bool disableHero;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 6,
    );
    final childWidget = LayoutBuilder(
      builder: (context, constraints) {
        final layout = resolveBottomPlayerBarLayout(constraints.maxWidth);
        final gap = constraints.maxWidth < 600 ? 8.0 : 24.0;
        return Row(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: _BottomBarTrackSection(
                  dense: layout.dense,
                  disableHero: disableHero,
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 2,
              child: RepaintBoundary(
                child: _BottomBarCenterSection(
                  compact: layout.compact,
                  dense: layout.dense,
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: RepaintBoundary(
                child: _BottomBarActionsSection(
                  compact: layout.compact,
                  dense: layout.dense,
                ),
              ),
            ),
          ],
        );
      },
    );
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 全宽轻薄毛玻璃通栏：融入全局流体背景，并带微弱顶部高光分界线防止滚动内容视觉干扰
    return Container(
      height: context.chrome.dockHeight,
      decoration: transparent
          ? null
          : BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.35),
              border: Border(
                top: BorderSide(
                  color: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                  spreadRadius: 0,
                ),
              ],
            ),
      padding: padding,
      child: childWidget,
    );
  }
}

class _BottomBarTrackSection extends StatelessWidget {
  const _BottomBarTrackSection({
    required this.dense,
    required this.disableHero,
  });

  final bool dense;
  final bool disableHero;

  @override
  Widget build(BuildContext context) {
    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        final scheme = Theme.of(context).colorScheme;
        final isDark = scheme.brightness == Brightness.dark;

        return Align(
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isConstrained = constraints.maxWidth < 80;
              final coverSize = isConstrained ? 38.0 : (dense ? 52.0 : 58.0);
              final coverGap = isConstrained ? 6.0 : (dense ? 12.0 : 16.0);
              final horizPadding = isConstrained ? 3.0 : (dense ? 6.0 : 8.0);

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: dense ? 64.0 : 70.0,
                ),
                child: CpMotionPressable(
                  borderRadius: BorderRadius.circular(16),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizPadding,
                    vertical: dense ? 4 : 6,
                  ),
                  onTap: () {
                    if (isNowPlayingRoute(context)) {
                      final navigation = AppNavigationState.instance;
                      navigation.closeNowPlaying(
                        context,
                        fallback: navigation.lastShellLocation,
                      );
                      return;
                    }
                    openNowPlayingRoute(context);
                  },
                  child: Row(
                    children: [
                      _TrackCover(
                        size: coverSize,
                        audio: audio,
                        disableHero: disableHero,
                      ),
                      SizedBox(width: coverGap),
                      Expanded(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarqueeText(
                          text: audio?.displayTitle ?? AppBrand.displayName,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: dense ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                audio?.displayArtist ?? '暂无播放',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurface.withValues(
                                    alpha: isDark ? 0.82 : 0.90,
                                  ),
                                  fontSize: dense ? 12 : 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (audio != null && !dense) ...[
                              const SizedBox(width: 8),
                              AudioFormatBadge(
                                audio: audio,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    required this.disableHero,
  });

  final double size;
  final Audio? audio;
  final bool disableHero;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: StreamBuilder<PlayerState>(
        stream: context.read<PlaybackController>().playerStateStream,
        initialData: context.read<PlaybackController>().playerState,
        builder: (context, snapshot) {
          final spinning = snapshot.data == PlayerState.playing;
          final artworkCard = NowPlayingArtworkCard(
            key: ValueKey(audio?.path),
            audio: audio,
            coverProvider: NowPlayingArtworkCard.getSyncCover(audio),
            radius: nowPlayingArtworkHeroRadius,
            elevation: 0.8,
            showShadow: false,
          );

          if (disableHero) {
            // 如果禁用 Hero，直接返回微呼吸动画子树，避免多 Hero 重复 Tag 冲突
            return SpinningArtwork(
              spinning: spinning,
              child: artworkCard,
            );
          }

          return SpinningArtwork(
            spinning: spinning,
            child: Hero(
              tag: nowPlayingArtworkHeroTag,
              createRectTween: (begin, end) =>
                  NowPlayingArtworkRectTween(begin: begin, end: end),
              flightShuttleBuilder: nowPlayingArtworkFlightShuttleBuilder,
              child: artworkCard,
            ),
          );
        },
      ),
    );
  }
}

class SpinningArtwork extends StatelessWidget {
  const SpinningArtwork({
    super.key,
    required this.spinning,
    required this.child,
  });

  final bool spinning;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final accents = context.accents;

    // 现代画册模式：用优雅的微呼吸缩放与多层弥散外发光替代生硬旋转，营造通透生动的视听氛围
    return AnimatedScale(
      scale: spinning ? 1.03 : 1.0,
      duration: motion.controlTransitionDuration,
      curve: motion.emphasized,
      child: AnimatedContainer(
        duration: motion.controlTransitionDuration,
        curve: motion.normal,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(nowPlayingArtworkHeroRadius),
          boxShadow: [
            if (spinning) ...[
              // 关键高亮光晕
              BoxShadow(
                color: accents.accentGlow.withValues(alpha: 0.36),
                blurRadius: 20,
                spreadRadius: -1,
                offset: const Offset(0, 4),
              ),
              // 环境漫反射柔光
              BoxShadow(
                color: accents.accent.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: -4,
              ),
            ] else ...[
              // 静止时的自然轻微投影
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ],
        ),
        child: child,
      ),
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final progressHeight = dense ? 22.0 : 36.0;
        final controlsHeight = dense ? 52.0 : 56.0;
        final preferredGap = dense ? 2.0 : 4.0;
        final availableGap = constraints.hasBoundedHeight
            ? constraints.maxHeight - progressHeight - controlsHeight
            : preferredGap;
        final gap = availableGap.clamp(0.0, preferredGap).toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: _ProgressStrip(compact: compact, dense: dense),
            ),
            SizedBox(height: gap),
            _PlaybackControls(dense: dense),
          ],
        );
      },
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
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final playback = context.read<PlaybackController>();
    final duration = context.select<PlaybackController, double>(
      (service) => service.length,
    );
    final hasTrack = context.select<PlaybackController, bool>(
      (service) => service.nowPlaying != null,
    );
    return StreamBuilder<PlayerState>(
      stream: playback.playerStateStream,
      initialData: playback.playerState,
      builder: (context, stateSnapshot) {
        final isPlaying = stateSnapshot.data == PlayerState.playing;

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
                return Row(
                  children: [
                    if (showLabels)
                      // 已经过播放时间标签
                      SizedBox(
                        width: 62.0,
                        child: Text(
                          Duration(
                            milliseconds: (clampedValue * 1000).round(),
                          ).toStringHMMSS(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(
                              alpha: isDark ? 0.78 : 0.88,
                            ),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    Expanded(
                      child: ValueListenableBuilder<ProgressBarType>(
                        valueListenable:
                            AppSettings.instance.progressBarTypeNotifier,
                        builder: (context, progressType, _) {
                          return ValueListenableBuilder<double>(
                            valueListenable: playback.volumeDspNotifier,
                            builder: (context, volume, _) {
                              final sliderHeight = widget.dense ? 22.0 : 36.0;
                              final onChangedCallback = hasTrack
                                  ? (double value) {
                                      setState(() {
                                        _dragging = true;
                                        _dragValue = value;
                                      });
                                    }
                                  : null;
                              final onChangeEndCallback = hasTrack
                                  ? (double value) {
                                      setState(() => _dragging = false);
                                      playback.seek(value);
                                    }
                                  : null;

                              switch (progressType) {
                                case ProgressBarType.fluidGlow:
                                  return FluidGlowProgressSlider(
                                    value: clampedValue,
                                    max: clampedDuration,
                                    height: sliderHeight,
                                    onChanged: onChangedCallback,
                                    onChangeEnd: onChangeEndCallback,
                                  );
                                case ProgressBarType.adaptiveWaveform:
                                  return AdaptiveWaveformSlider(
                                    spectrum: playback.audioSpectrum,
                                    spectrumActive: isPlaying &&
                                        hasTrack &&
                                        volume > 0 &&
                                        context.surfaces.effectsLevel !=
                                            UiEffectsLevel.performance,
                                    value: clampedValue,
                                    max: clampedDuration,
                                    height: sliderHeight,
                                    audio: playback.nowPlaying,
                                    isPlaying: isPlaying,
                                    onChanged: onChangedCallback,
                                    onChangeEnd: onChangeEndCallback,
                                  );
                                case ProgressBarType.dualLayerRhythm:
                                  return DualLayerRhythmSlider(
                                    spectrum: playback.audioSpectrum,
                                    value: clampedValue,
                                    max: clampedDuration,
                                    height: sliderHeight,
                                    isPlaying: isPlaying,
                                    spectrumActive: isPlaying &&
                                        hasTrack &&
                                        volume > 0 &&
                                        context.surfaces.effectsLevel !=
                                            UiEffectsLevel.performance,
                                    onChanged: onChangedCallback,
                                    onChangeEnd: onChangeEndCallback,
                                  );
                              }
                            },
                          );
                        },
                      ),
                    ),
                    if (showLabels)
                      // 音频总时长标签
                      SizedBox(
                        width: 62.0,
                        child: Text(
                          Duration(
                            milliseconds: (duration * 1000).round(),
                          ).toStringHMMSS(),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(
                              alpha: isDark ? 0.78 : 0.88,
                            ),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                );
              },
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

enum _TransportMotionDirection {
  none,
  left,
  right,
  spin,
  vertical,
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final primaryButtonSize = dense ? 50.0 : 56.0;
    final outerGap = dense ? 10.0 : 20.0;
    final innerGap = dense ? 12.0 : 26.0;
    final clusterWidth = dense ? 264.0 : 336.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return StreamBuilder<PlayerState>(
          stream: playback.playerStateStream,
          initialData: playback.playerState,
          builder: (context, snapshot) {
            final playerState = snapshot.data ?? PlayerState.stopped;
            final isPlaying = playerState == PlayerState.playing;
            final icon = switch (playerState) {
              PlayerState.completed => Symbols.replay_rounded,
              PlayerState.playing => Symbols.pause_rounded,
              _ => Symbols.play_arrow_rounded,
            };
            final onPressed = switch (playerState) {
              PlayerState.completed => playback.playAgain,
              PlayerState.playing => playback.pause,
              _ => playback.start,
            };
            final controls = SizedBox(
              width: clusterWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ShuffleModeControl(dense: dense),
                  SizedBox(width: outerGap),
                  _TransportIconButton(
                    key: const ValueKey('bottom-player-bar-prev-button'),
                    onPressed: playback.lastAudio,
                    icon: Symbols.skip_previous_rounded,
                    dense: dense,
                    motionDirection: _TransportMotionDirection.left,
                  ),
                  SizedBox(width: innerGap),
                  _PrimaryTransportButton(
                    key: const ValueKey('bottom-player-bar-play-button'),
                    icon: icon,
                    onPressed: onPressed,
                    isPlaying: isPlaying,
                    size: primaryButtonSize,
                  ),
                  SizedBox(width: innerGap),
                  _TransportIconButton(
                    key: const ValueKey('bottom-player-bar-next-button'),
                    onPressed: playback.nextAudio,
                    icon: Symbols.skip_next_rounded,
                    dense: dense,
                    motionDirection: _TransportMotionDirection.right,
                  ),
                  SizedBox(width: outerGap),
                  _SequenceModeControl(dense: dense),
                ],
              ),
            );

            if (!constraints.hasBoundedWidth ||
                constraints.maxWidth >= clusterWidth) {
              return controls;
            }

            return SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: controls,
              ),
            );
          },
        );
      },
    );
  }
}

class _ShuffleModeControl extends StatelessWidget {
  const _ShuffleModeControl({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    return ValueListenableBuilder<bool>(
      valueListenable: playback.shuffle,
      builder: (context, shuffle, _) {
        return _TransportIconButton(
          key: const ValueKey('bottom-player-bar-shuffle-button'),
          onPressed: () {
            if (!shuffle) {
              playback.setPlayMode(PlayMode.forward);
              playback.useShuffle(true);
            } else {
              playback.useShuffle(false);
            }
          },
          icon: Symbols.shuffle,
          dense: dense,
          selected: shuffle,
          motionDirection: _TransportMotionDirection.spin,
        );
      },
    );
  }
}

class _SequenceModeControl extends StatelessWidget {
  const _SequenceModeControl({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    return ValueListenableBuilder<bool>(
      valueListenable: playback.shuffle,
      builder: (context, shuffle, _) {
        return ValueListenableBuilder<PlayMode>(
          valueListenable: playback.playMode,
          builder: (context, playMode, _) {
            final next = switch (playMode) {
              PlayMode.forward => PlayMode.loop,
              PlayMode.loop => PlayMode.singleLoop,
              PlayMode.singleLoop => PlayMode.forward,
            };
            final (icon, selected) = shuffle
                ? (Symbols.repeat, false)
                : switch (playMode) {
                    PlayMode.forward => (Symbols.repeat, false),
                    PlayMode.loop => (Symbols.repeat, true),
                    PlayMode.singleLoop => (Symbols.repeat_one_on, true),
                  };
            return _TransportIconButton(
              key: const ValueKey('bottom-player-bar-sequence-button'),
              onPressed: () {
                if (shuffle) {
                  // 在随机播放下点击顺序/循环按钮：
                  // 第一次点击：退出随机播放（随机灭掉），响应顺序播放（列表循环）
                  playback.useShuffle(false);
                  playback.setPlayMode(PlayMode.loop);
                } else {
                  playback.setPlayMode(next);
                }
              },
              icon: icon,
              dense: dense,
              selected: selected,
              motionDirection: _TransportMotionDirection.vertical,
            );
          },
        );
      },
    );
  }
}

class _TransportIconButton extends StatefulWidget {
  const _TransportIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.dense,
    this.selected = false,
    this.motionDirection = _TransportMotionDirection.none,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final bool dense;
  final bool selected;
  final _TransportMotionDirection motionDirection;

  @override
  State<_TransportIconButton> createState() => _TransportIconButtonState();
}

class _TransportIconButtonState extends State<_TransportIconButton>
    with TickerProviderStateMixin {
  AnimationController? _pressController;
  late Animation<double> _pressScaleAnimation;
  late Animation<double> _pressOffsetAnimation;
  AnimationController? _hoverController;
  late Animation<double> _hoverScaleAnimation;
  bool _hovered = false;
  Timer? _releaseTimer;
  DateTime? _tapDownTime;

  bool get _enabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
  }

  void _initAnimations() {
    if (_pressController == null) {
      final pressController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 240),
      );
      _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(
          parent: pressController,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
      _pressOffsetAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: pressController,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
      _pressController = pressController;
    }

    if (_hoverController == null) {
      final hoverController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 160),
      );
      _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(
          parent: hoverController,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutCubic,
        ),
      );
      _hoverController = hoverController;
    }
  }

  @override
  void didUpdateWidget(covariant _TransportIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _hovered) {
      _hovered = false;
      _hoverController?.reverse();
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _pressController?.dispose();
    _hoverController?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_enabled) return;
    _initAnimations();
    _releaseTimer?.cancel();
    _tapDownTime = DateTime.now();
    _pressController?.forward();
  }

  void _handleRelease() {
    if (!_enabled) return;
    final elapsed = _tapDownTime != null
        ? DateTime.now().difference(_tapDownTime!).inMilliseconds
        : 90;
    final remaining = (60 - elapsed).clamp(0, 60);
    _releaseTimer?.cancel();
    if (remaining > 0) {
      _releaseTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) _pressController?.reverse();
      });
    } else {
      _pressController?.reverse();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_enabled) return;
    _handleRelease();
  }

  void _handleTapCancel() {
    if (!_enabled) return;
    _handleRelease();
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    final visualSize = widget.dense ? 34.0 : 40.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseIconColor = !_enabled
        ? scheme.onSurface.withValues(alpha: 0.30)
        : widget.selected
            ? accents.accent
            : scheme.onSurface.withValues(alpha: _hovered ? 0.98 : 0.78);

    final double offsetDx = switch (widget.motionDirection) {
      _TransportMotionDirection.left => -2.5,
      _TransportMotionDirection.right => 2.5,
      _ => 0.0,
    };
    final double offsetDy = switch (widget.motionDirection) {
      _TransportMotionDirection.vertical => -2.0,
      _ => 0.0,
    };
    final double spinAngle = widget.motionDirection == _TransportMotionDirection.spin
        ? -0.25 * 2 * math.pi
        : 0.0;

    Widget button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (!_enabled) return;
        setState(() => _hovered = true);
        _initAnimations();
        _hoverController?.forward();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
          _handleRelease();
        });
        _hoverController?.reverse();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.dense ? 36.0 : 44.0,
          minHeight: widget.dense ? 36.0 : 44.0,
        ),
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onPressed,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pressController!, _hoverController!]),
              builder: (context, child) {
                final pressScale = _pressScaleAnimation.value;
                final hoverScale = _hoverScaleAnimation.value;
                final combinedScale = pressScale * hoverScale;
                final currentDx = offsetDx * _pressOffsetAnimation.value;
                final currentDy = offsetDy * _pressOffsetAnimation.value;
                final currentAngle = spinAngle * _pressOffsetAnimation.value;

                return Transform.translate(
                  offset: Offset(currentDx, currentDy),
                  child: Transform.rotate(
                    angle: currentAngle,
                    child: Transform.scale(
                      scale: combinedScale,
                      child: child,
                    ),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: motion.controlTransitionDuration,
                curve: motion.normal,
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected
                      ? accents.accent.withValues(alpha: isDark ? 0.16 : 0.12)
                      : _hovered
                          ? scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06)
                          : Colors.transparent,
                  border: Border.all(
                    color: widget.selected
                        ? accents.accent.withValues(alpha: isDark ? 0.35 : 0.28)
                        : _hovered
                            ? scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.08)
                            : Colors.transparent,
                    width: 1.0,
                  ),
                  boxShadow: [
                    if (widget.selected)
                      BoxShadow(
                        color: accents.accentGlow.withValues(alpha: 0.26),
                        blurRadius: 12,
                        spreadRadius: -4,
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildIconTransition(context, baseIconColor),
                    Positioned(
                      bottom: widget.dense ? 2.5 : 3.5,
                      child: AnimatedOpacity(
                        duration: motion.controlTransitionDuration,
                        curve: motion.normal,
                        opacity: widget.selected ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: motion.controlTransitionDuration,
                          curve: motion.emphasized,
                          scale: widget.selected ? 1.0 : 0.0,
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accents.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: accents.accentGlow.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return button;
  }

  Widget _buildIconTransition(BuildContext context, Color iconColor) {
    final iconWidget = Icon(
      widget.icon,
      key: ValueKey(widget.icon),
      size: widget.dense ? 19 : 22,
      color: iconColor,
      fill: 1.0,
      weight: 600,
      grade: 0.25,
      opticalSize: 24,
    );

    if (widget.motionDirection == _TransportMotionDirection.vertical) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.35),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

class _PrimaryTransportButton extends StatefulWidget {
  const _PrimaryTransportButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.isPlaying,
    required this.size,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isPlaying;
  final double size;

  @override
  State<_PrimaryTransportButton> createState() =>
      _PrimaryTransportButtonState();
}

class _PrimaryTransportButtonState extends State<_PrimaryTransportButton>
    with TickerProviderStateMixin {
  AnimationController? _pressController;
  late Animation<double> _pressAnimation;
  AnimationController? _hoverController;
  late Animation<double> _hoverAnimation;
  bool _hovered = false;
  Timer? _releaseTimer;
  DateTime? _tapDownTime;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
  }

  void _initAnimations() {
    if (_pressController == null) {
      final pressController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 260),
      );
      _pressAnimation = Tween<double>(begin: 1.0, end: 0.91).animate(
        CurvedAnimation(
          parent: pressController,
          curve: Curves.easeOutQuad,
          reverseCurve: Curves.easeOutBack,
        ),
      );
      _pressController = pressController;
    }

    if (_hoverController == null) {
      final hoverController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
      );
      _hoverAnimation = Tween<double>(begin: 1.0, end: 1.045).animate(
        CurvedAnimation(
          parent: hoverController,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutCubic,
        ),
      );
      _hoverController = hoverController;
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _pressController?.dispose();
    _hoverController?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _initAnimations();
    _releaseTimer?.cancel();
    _tapDownTime = DateTime.now();
    _pressController?.forward();
  }

  void _handleRelease() {
    final elapsed = _tapDownTime != null
        ? DateTime.now().difference(_tapDownTime!).inMilliseconds
        : 90;
    final remaining = (65 - elapsed).clamp(0, 65);
    _releaseTimer?.cancel();
    if (remaining > 0) {
      _releaseTimer = Timer(Duration(milliseconds: remaining), () {
        if (mounted) _pressController?.reverse();
      });
    } else {
      _pressController?.reverse();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _handleRelease();
  }

  void _handleTapCancel() {
    _handleRelease();
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
    final accents = context.accents;
    final motion = context.motion;

    final dynamicGlowAlpha = widget.isPlaying
        ? (_hovered ? 0.44 : 0.36)
        : (_hovered ? 0.28 : 0.18);
    final dynamicBlurRadius = widget.isPlaying
        ? (_hovered ? 28.0 : 22.0)
        : (_hovered ? 20.0 : 16.0);
    final dynamicSpreadRadius = widget.isPlaying ? 1.5 : 0.5;

    Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        _initAnimations();
        _hoverController?.forward();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
          _handleRelease();
        });
        _hoverController?.reverse();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pressController!, _hoverController!]),
          builder: (context, child) {
            final pressScale = _pressAnimation.value;
            final hoverScale = _hoverAnimation.value;
            final combinedScale = pressScale * hoverScale;

            return Transform.scale(
              scale: combinedScale,
              child: AnimatedContainer(
                duration: motion.controlTransitionDuration,
                curve: motion.normal,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(accents.accent, Colors.white, 0.24)!,
                      accents.accent,
                      Color.lerp(accents.accent, Colors.black, 0.10)!,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accents.accentGlow.withValues(alpha: dynamicGlowAlpha),
                      blurRadius: dynamicBlurRadius,
                      spreadRadius: dynamicSpreadRadius,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              reverseDuration: const Duration(milliseconds: 200),
              switchInCurve: Curves.linear,
              switchOutCurve: Curves.linear,
              transitionBuilder: (child, animation) {
                final isPlay = (child.key as ValueKey?)?.value == Symbols.play_arrow_rounded ||
                    (child.key as ValueKey?)?.value == Symbols.play_arrow;
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.68, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: RotationTransition(
                      turns: Tween<double>(
                        begin: isPlay ? -0.08 : 0.08,
                        end: 0.0,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: _buildPrimaryIcon(accents),
            ),
          ),
        ),
      ),
    );

    return button;
  }

  Widget _buildPrimaryIcon(dynamic accents) {
    final isPlay = widget.icon == Symbols.play_arrow_rounded ||
        widget.icon == Symbols.play_arrow;
    final iconSize = widget.size < 60 ? 26.0 : 30.0;

    return Transform.translate(
      key: ValueKey(widget.icon),
      offset: Offset(isPlay ? 1.5 : 0.0, 0.0),
      child: Icon(
        widget.icon,
        key: ValueKey(widget.icon),
        color: accents.onAccent,
        size: iconSize,
        fill: 1.0,
        weight: 700,
        grade: 0.25,
        opticalSize: 28,
      ),
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
        final volumeWidth = constrained ? 0.0 : (compact ? 84.0 : 112.0);
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const _ExclusiveModeControl(),
            SizedBox(width: constrained ? 2 : 10),
            _VolumeControl(width: volumeWidth),
            SizedBox(width: constrained ? 4 : 16),
            const _DesktopLyricControl(),
            SizedBox(width: constrained ? 4 : 16),
            _QueueEntryButton(dense: constrained),
          ],
        );

        if (!constraints.hasBoundedWidth) return actions;

        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: actions,
          ),
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

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: playback.wasapiExclusive,
      builder: (context, exclusive, _) {
        final activeColor = scheme.primary;
        final inactiveColor = scheme.onSurface.withValues(alpha: 0.70);

        return Tooltip(
          message: "音频输出模式：${exclusive ? 'WASAPI 独占（高保真源码输出）' : '系统共享（常规音频混合）'}",
          child: CpMotionPressable(
            onTap: () => playback.useExclusiveMode(!exclusive),
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            border: false,
            hoverScale: 1.05,
            pressScale: 0.95,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: exclusive
                    ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05)),
                border: Border.all(
                  color: exclusive
                      ? activeColor.withValues(alpha: isDark ? 0.55 : 0.40)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.12)),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    exclusive ? Symbols.lock_outline : Symbols.graphic_eq,
                    size: 15,
                    color: exclusive ? activeColor : inactiveColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    exclusive ? '独占' : '共享',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: exclusive ? FontWeight.w700 : FontWeight.w600,
                      color: exclusive ? activeColor : inactiveColor,
                      letterSpacing: 0,
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
}

class _VolumeControl extends StatefulWidget {
  const _VolumeControl({required this.width});

  final double width;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _dragging = false;
  double _dragValue = 0;
  double _lastNonZeroVolume = 0.2;

  final OverlayPortalController _indicatorOverlayController =
      OverlayPortalController();
  late final AnimationController _indicatorAnimationController;
  Timer? _indicatorHideTimer;

  @override
  void initState() {
    super.initState();
    _indicatorAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _indicatorHideTimer?.cancel();
    _indicatorAnimationController.dispose();
    super.dispose();
  }

  void _showScrollIndicator() {
    if (_dragging) return;
    _indicatorHideTimer?.cancel();
    if (!_indicatorOverlayController.isShowing) {
      _indicatorOverlayController.show();
      _indicatorAnimationController.forward(from: 0.0);
    } else {
      _indicatorAnimationController.forward();
    }
    _indicatorHideTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        _indicatorAnimationController.reverse().then((_) {
          if (mounted &&
              _indicatorAnimationController.value == 0 &&
              _indicatorOverlayController.isShowing) {
            _indicatorOverlayController.hide();
          }
        });
      }
    });
  }

  void _setVolume(PlaybackController playback, double value) {
    final normalized = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    if (normalized > 0.0001) {
      _lastNonZeroVolume = normalized;
    }
    playback.setVolumeDsp(normalized);
  }

  void _handleScroll(PointerScrollEvent event, PlaybackController playback, double current) {
    if (event.scrollDelta.dy == 0) return;
    // 鼠标滚轮向上滚动增加音量，向下滚动减小音量
    final delta = event.scrollDelta.dy < 0 ? 0.04 : -0.04;
    final next = (current + delta).clamp(0.0, 1.0).toDouble();
    _setVolume(playback, next);
    _showScrollIndicator();
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final motion = context.motion;
    final accents = context.accents;

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
          <= 0 => Symbols.volume_off_rounded,
          < 0.35 => Symbols.volume_down_rounded,
          _ => Symbols.volume_up_rounded,
        };

        final double targetX = showSlider
            ? 40.0 +
                12.0 +
                current * (effectiveWidth - 24.0).clamp(0.0, double.infinity)
            : 20.0;
        final isLight = accents.accent.computeLuminance() > 0.45;
        final textColor = isLight ? const Color(0xFF1C1B1F) : Colors.white;

        return OverlayPortal.overlayChildLayoutBuilder(
          controller: _indicatorOverlayController,
          overlayChildBuilder: (context, layoutInfo) {
            if (layoutInfo.childPaintTransform.determinant() == 0.0) {
              return const SizedBox.shrink();
            }
            final target = MatrixUtils.transformPoint(
              layoutInfo.childPaintTransform,
              Offset(targetX, 0),
            );
            return Positioned.fill(
              child: IgnorePointer(
                child: CustomSingleChildLayout(
                  delegate: _VolumeIndicatorLayoutDelegate(target: target),
                  child: AnimatedBuilder(
                    animation: _indicatorAnimationController,
                    builder: (context, _) {
                      final curved = Curves.easeOutCubic.transform(
                        _indicatorAnimationController.value,
                      );
                      final scale = 0.82 + 0.18 * curved;
                      final opacity =
                          _indicatorAnimationController.value.clamp(0.0, 1.0);

                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: ShapeDecoration(
                              color: accents.accent,
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.24),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              shape: const BubbleShapeBorder(
                                arrowDirection: BubbleArrowDirection.down,
                                borderRadius: 6.0,
                                arrowWidth: 11.0,
                                arrowHeight: 6.0,
                              ),
                            ),
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 4.5,
                              bottom: 9.5,
                            ),
                            child: Text(
                              '${(current * 100).round()}%',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          child: Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  _handleScroll(signal, playback, current);
                }
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) => setState(() => _hovering = false),
                child: SizedBox(
                  height: 42,
                  child: Padding(
                    padding: EdgeInsets.only(right: showSlider ? 8 : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CpIconButton(
                          key: const ValueKey('bottom-player-bar-volume-button'),
                          variant: CpButtonVariant.immersive,
                          onPressed: () {
                            if (current > 0.0001) {
                              _lastNonZeroVolume = current;
                            }
                            final next =
                                current <= 0.0001 ? _lastNonZeroVolume : 0.0;
                            _setVolume(playback, next);
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
                                        builder:
                                            (context, animatedThumbRadius, _) {
                                          return SliderTheme(
                                            data:
                                                SliderTheme.of(context).copyWith(
                                              trackHeight: 2,
                                              activeTrackColor:
                                                  accents.progressActive,
                                              inactiveTrackColor:
                                                  accents.progressInactive,
                                              thumbColor: accents.accent,
                                              overlayShape: SliderComponentShape
                                                  .noOverlay,
                                              thumbShape: _GlowSliderThumbShape(
                                                radius: animatedThumbRadius,
                                                color: accents.accent,
                                              ),
                                              showValueIndicator:
                                                  ShowValueIndicator.onDrag,
                                              valueIndicatorShape:
                                                  const RectangularSliderValueIndicatorShape(),
                                              valueIndicatorColor: accents.accent,
                                            ),
                                            child: Slider(
                                              min: 0,
                                              max: 1,
                                              value: current,
                                              label:
                                                  '${(current * 100).round()}%',
                                              onChangeStart: (next) {
                                                _indicatorHideTimer?.cancel();
                                                if (_indicatorOverlayController
                                                    .isShowing) {
                                                  _indicatorOverlayController
                                                      .hide();
                                                }
                                                setState(() {
                                                  _dragging = true;
                                                  _dragValue = next;
                                                });
                                              },
                                              onChanged: (next) {
                                                setState(
                                                    () => _dragValue = next);
                                                _setVolume(playback, next);
                                              },
                                              onChangeEnd: (_) => setState(
                                                  () => _dragging = false),
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
                  ),
                ),
              ),
            ),
          );
        },
      );
  }
}

class _DesktopLyricControl extends StatelessWidget {
  const _DesktopLyricControl();

  @override
  Widget build(BuildContext context) {
    return Consumer<DesktopLyricController>(
      builder: (context, desktopLyricService, _) {
        return FutureBuilder(
          future: desktopLyricService.desktopLyric,
          builder: (context, snapshot) {
            final ready = !desktopLyricService.isStarting &&
                snapshot.connectionState == ConnectionState.done;
            final enabled = snapshot.data != null;
            return CpIconButton(
              variant: CpButtonVariant.immersive,
              tooltip: '桌面歌词${enabled ? "已开启" : "已关闭"}',
              tooltipDirection: ModernTooltipDirection.top,
              onPressed: ready
                  ? enabled
                      ? desktopLyricService.isLocked
                          ? desktopLyricService.sendUnlockMessage
                          : desktopLyricService.killDesktopLyric
                      : desktopLyricService.startDesktopLyric
                  : null,
              icon: ready
                  ? Icon(
                      desktopLyricService.isLocked
                          ? Symbols.lock_rounded
                          : Symbols.toast_rounded,
                      fill: enabled ? 1 : 0,
                    )
                  : const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            );
          },
        );
      },
    );
  }
}

class _QueueEntryButton extends StatelessWidget {
  const _QueueEntryButton({required this.dense});

  final bool dense;

  // 优化：右侧滑出的高质感毛玻璃播放队列抽屉，带自适应半透明底色、高斯模糊与丝滑双向缓动
  Future<void> _openQueueDrawer(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.36).clamp(380.0, 520.0).toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '播放队列',
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) {
        final scheme = Theme.of(context).colorScheme;
        const blurSigma = 24.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width,
              height: double.infinity,
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isDark
                          ? Color.alphaBlend(
                              scheme.primary.withValues(alpha: 0.08),
                              const Color(0xFF131822).withValues(alpha: 0.82),
                            )
                          : Color.alphaBlend(
                              scheme.primary.withValues(alpha: 0.04),
                              Colors.white.withValues(alpha: 0.86),
                            ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withValues(alpha: 0.06),
                                scheme.primary.withValues(alpha: 0.03),
                                Colors.transparent,
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.65),
                                scheme.surfaceContainerLowest
                                    .withValues(alpha: 0.4),
                              ],
                        stops: isDark ? const [0.0, 0.45, 1.0] : null,
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.42 : 0.12),
                          blurRadius: 40,
                          offset: const Offset(-8, 14),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: scheme.primary
                              .withValues(alpha: isDark ? 0.12 : 0.05),
                          blurRadius: 28,
                          offset: const Offset(-2, 4),
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              CpIconButton(
                                variant: CpButtonVariant.immersive,
                                tooltip: '关闭',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Symbols.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Expanded(
                            child: CurrentPlaylistView(
                              showHeader: false,
                              dense: true,
                              enableReorder: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.12, 0.96, 0.20, 1.0),
          reverseCurve: const Cubic(0.16, 0.92, 0.24, 1.0),
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
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
        final canOpenQueue = playlist.isNotEmpty || playback.nowPlaying != null;

        return CpIconButton(
          key: const ValueKey('bottom-player-bar-queue-button'),
          variant: CpButtonVariant.immersive,
          onPressed: canOpenQueue ? () => _openQueueDrawer(context) : null,
          icon: Badge(
            label: Text('${playlist.length}'),
            child: const Icon(Symbols.queue_music_rounded),
          ),
        );
      },
    );
  }
}

class _VolumeIndicatorLayoutDelegate extends SingleChildLayoutDelegate {
  _VolumeIndicatorLayoutDelegate({required this.target});

  final Offset target;

  static const double gap = 8.0;
  static const double margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (target.dx - childSize.width / 2).clamp(
      margin,
      (size.width - childSize.width - margin).clamp(margin, double.infinity),
    );
    final y = target.dy - childSize.height - gap;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _VolumeIndicatorLayoutDelegate oldDelegate) {
    return oldDelegate.target != target;
  }
}
