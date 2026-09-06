import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/app_brand.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/spectrum_progress_slider.dart';
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
        return Row(
          children: [
            Expanded(
              child: _BottomBarTrackSection(
                dense: layout.dense,
                disableHero: disableHero,
              ),
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

        return CpMotionPressable(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                size: dense ? 52 : 58,
                audio: audio,
                disableHero: disableHero,
              ),
              SizedBox(width: dense ? 12 : 16),
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
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontSize: dense ? 12 : 13,
                              fontWeight: FontWeight.w400,
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
        final progressHeight = dense ? 14.0 : 20.0;
        final controlsHeight = dense ? 52.0 : 56.0;
        final preferredGap = dense ? 2.0 : 2.0;
        final availableGap = constraints.hasBoundedHeight
            ? constraints.maxHeight - progressHeight - controlsHeight
            : preferredGap;
        final gap = availableGap.clamp(0.0, preferredGap).toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressStrip(compact: compact, dense: dense),
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
                      child: ValueListenableBuilder<double>(
                        valueListenable: playback.volumeDspNotifier,
                        builder: (context, volume, _) {
                          return SpectrumProgressSlider(
                            spectrum: playback.audioSpectrum,
                            value: clampedValue,
                            max: clampedDuration,
                            height: widget.dense ? 14.0 : 20.0,
                            spectrumActive: isPlaying &&
                                hasTrack &&
                                volume > 0 &&
                                context.surfaces.effectsLevel !=
                                    UiEffectsLevel.performance,
                            onChanged: hasTrack
                                ? (value) {
                                    setState(() {
                                      _dragging = true;
                                      _dragValue = value;
                                    });
                                  }
                                : null,
                            onChangeEnd: hasTrack
                                ? (value) {
                                    setState(() => _dragging = false);
                                    playback.seek(value);
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                    if (showLabels)
                      // 音频总时长标签
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
              PlayerState.completed => Symbols.replay,
              PlayerState.playing => Symbols.pause,
              _ => Symbols.play_arrow,
            };
            final tooltip = switch (playerState) {
              PlayerState.completed => '重新播放',
              PlayerState.playing => '暂停',
              _ => '播放',
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
                    tooltip: '上一首',
                    onPressed: playback.lastAudio,
                    icon: Symbols.skip_previous,
                    dense: dense,
                  ),
                  SizedBox(width: innerGap),
                  _PrimaryTransportButton(
                    icon: icon,
                    tooltip: tooltip,
                    onPressed: onPressed,
                    isPlaying: isPlaying,
                    size: primaryButtonSize,
                  ),
                  SizedBox(width: innerGap),
                  _TransportIconButton(
                    tooltip: '下一首',
                    onPressed: playback.nextAudio,
                    icon: Symbols.skip_next,
                    dense: dense,
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
    return ValueListenableBuilder<PlayMode>(
      valueListenable: playback.playMode,
      builder: (context, playMode, _) {
        final selected = playMode == PlayMode.loop;
        return _TransportIconButton(
          tooltip: selected ? '关闭随机播放' : '随机播放',
          onPressed: () => playback.setPlayMode(
            selected ? PlayMode.forward : PlayMode.loop,
          ),
          icon: Symbols.shuffle,
          dense: dense,
          selected: selected,
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
    return ValueListenableBuilder<PlayMode>(
      valueListenable: playback.playMode,
      builder: (context, playMode, _) {
        final single = playMode == PlayMode.singleLoop;
        final next = switch (playMode) {
          PlayMode.loop => PlayMode.forward,
          PlayMode.forward => PlayMode.singleLoop,
          PlayMode.singleLoop => PlayMode.forward,
        };
        return _TransportIconButton(
          tooltip: single ? '单曲循环' : '顺序播放',
          onPressed: () => playback.setPlayMode(next),
          icon: single ? Symbols.repeat_one_on : Symbols.repeat,
          dense: dense,
          selected: single || playMode == PlayMode.forward,
        );
      },
    );
  }
}

class _TransportIconButton extends StatefulWidget {
  const _TransportIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.dense,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool dense;
  final bool selected;

  @override
  State<_TransportIconButton> createState() => _TransportIconButtonState();
}

class _TransportIconButtonState extends State<_TransportIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    // 视觉圆形尺寸：根据 dense 模式在 34dp 与 40dp 间切换
    final visualSize = widget.dense ? 34.0 : 40.0;
    final radius = BorderRadius.circular(999);
    final iconColor = !_enabled
        ? scheme.onSurface.withValues(alpha: 0.34)
        : widget.selected
            ? accents.accent
            : scheme.onSurface.withValues(alpha: _hovered ? 0.96 : 0.82);

    final button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      // 扩展外层透明点击热区，在常规模式下 >= 44x44 dp，dense 紧凑模式下为 36x36 dp
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.dense ? 36.0 : 44.0,
          minHeight: widget.dense ? 36.0 : 44.0,
        ),
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.95 : (_hovered ? 1.06 : 1),
            duration: motion.microInteractionDuration,
            curve: motion.fast,
            child: AnimatedContainer(
              duration: motion.controlTransitionDuration,
              curve: motion.normal,
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.selected
                    ? accents.accent.withValues(alpha: 0.13)
                    : _hovered
                        ? Colors.white.withValues(alpha: 0.045)
                        : Colors.transparent,
                boxShadow: [
                  if (widget.selected)
                    BoxShadow(
                      color: accents.accentGlow.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: -8,
                    ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  enableFeedback: false,
                  borderRadius: radius,
                  onTap: widget.onPressed,
                  // 统一由 InkWell 响应按压高亮状态，移除外层手势竞争
                  onHighlightChanged: _enabled
                      ? (highlighted) => setState(() => _pressed = highlighted)
                      : null,
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: widget.dense ? 18 : 22,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Tooltip(message: widget.tooltip, child: button);
  }
}

class _PrimaryTransportButton extends StatefulWidget {
  const _PrimaryTransportButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isPlaying,
    required this.size,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isPlaying;
  final double size;

  @override
  State<_PrimaryTransportButton> createState() =>
      _PrimaryTransportButtonState();
}

class _PrimaryTransportButtonState extends State<_PrimaryTransportButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accents = context.accents;
    final motion = context.motion;
    final glowAlpha = widget.isPlaying ? 0.38 : 0.26;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.95 : (_hovered ? 1.035 : 1),
            duration: motion.microInteractionDuration,
            curve: motion.fast,
            child: AnimatedContainer(
              duration: motion.controlTransitionDuration,
              curve: motion.normal,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(accents.accent, Colors.white, 0.18)!,
                    accents.accent,
                    Color.lerp(accents.accent, Colors.black, 0.08)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accents.accentGlow.withValues(
                      alpha: _hovered ? glowAlpha + 0.06 : glowAlpha - 0.04,
                    ),
                    blurRadius: widget.isPlaying ? 28 : 22,
                    spreadRadius: widget.isPlaying ? 3 : 1,
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  enableFeedback: false,
                  customBorder: const CircleBorder(),
                  onTap: widget.onPressed,
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
                          scale: Tween<double>(begin: 0.78, end: 1)
                              .animate(curved),
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      color: accents.onAccent,
                      size: widget.size < 60 ? 24 : 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
    if (playback is! PlaybackService) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: playback.wasapiExclusive,
      builder: (context, exclusive, _) => CpIconButton(
        variant: CpButtonVariant.immersive,
        tooltip: "独占模式：${exclusive ? '已启用' : '已禁用'}",
        onPressed: () => playback.useExclusiveMode(!exclusive),
        icon: Center(
          child: Text(
            exclusive ? '独占' : '共享',
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
  double _lastNonZeroVolume = 0.2;

  void _setVolume(PlaybackController playback, double value) {
    final normalized = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    if (normalized > 0.0001) {
      _lastNonZeroVolume = normalized;
    }
    playback.setVolumeDsp(normalized);
  }

  void _handleScroll(PointerScrollEvent event, PlaybackController playback, double current) {
    // 鼠标滚轮向上滚动增加音量，向下滚动减小音量
    final delta = event.scrollDelta.dy < 0 ? 0.04 : -0.04;
    final next = (current + delta).clamp(0.0, 1.0).toDouble();
    _setVolume(playback, next);
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
          <= 0 => Symbols.volume_off,
          < 0.35 => Symbols.volume_down,
          _ => Symbols.volume_up,
        };

        return Listener(
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
                      variant: CpButtonVariant.immersive,
                      tooltip: '音量（支持鼠标滚轮无级调节）: ${(current * 100).round()}%',
                      onPressed: () {
                        if (current > 0.0001) {
                          _lastNonZeroVolume = current;
                        }
                        final next = current <= 0.0001 ? _lastNonZeroVolume : 0.0;
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
                                    builder: (context, animatedThumbRadius, _) {
                                      return SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2,
                                          activeTrackColor:
                                              accents.progressActive,
                                          inactiveTrackColor:
                                              accents.progressInactive,
                                          thumbColor: accents.accent,
                                          overlayShape:
                                              SliderComponentShape.noOverlay,
                                          thumbShape: _GlowSliderThumbShape(
                                            radius: animatedThumbRadius,
                                            color: accents.accent,
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
                                            _setVolume(playback, next);
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
                          ? Symbols.lock
                          : Symbols.toast,
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
      transitionDuration: const Duration(milliseconds: 320),
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              CpIconButton(
                                variant: CpButtonVariant.immersive,
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
          curve: const Cubic(0.16, 1.0, 0.3, 1.0),
          reverseCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
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
          variant: CpButtonVariant.immersive,
          tooltip: canOpenQueue ? '打开播放队列' : '暂无播放队列',
          onPressed: canOpenQueue ? () => _openQueueDrawer(context) : null,
          icon: Badge(
            label: Text('${playlist.length}'),
            child: const Icon(Symbols.queue_music),
          ),
        );
      },
    );
  }
}
