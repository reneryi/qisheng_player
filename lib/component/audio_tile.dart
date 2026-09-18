import 'dart:math' as math;

import 'package:qisheng_player/component/audio_context_menu.dart';
import 'package:qisheng_player/component/audio_edit_dialog.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/cover_fade_image.dart';
import 'package:qisheng_player/component/scroll_aware_future_builder.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/component/ui/audio_format_badge.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

export 'package:qisheng_player/component/audio_edit_dialog.dart';

/// 展示 `playlist[audioIndex]` 对应的歌曲条目。
/// 可通过 [leading]/[action] 注入额外的前后缀组件。
class AudioTile extends StatefulWidget {
  const AudioTile({
    super.key,
    required this.audioIndex,
    required this.playlist,
    this.showPlayCount = false,
    this.focus = false,
    this.leading,
    this.action,
    this.multiSelectController,
  });

  final int audioIndex;
  final List<Audio> playlist;
  final bool showPlayCount;
  final bool focus;
  final Widget? leading;
  final Widget? action;
  final MultiSelectController? multiSelectController;

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'audio-tile');

  void _handleFocusChanged(bool focused) {
    if (!focused || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final audio = widget.playlist[widget.audioIndex];
    // 使用 Selector 精细化监听：仅当当前歌曲的播放状态与自身切实相关时才重绘，避免全列表无差别刷新
    return Selector<PlaybackController, bool>(
      selector: (context, controller) =>
          controller.nowPlaying?.path == audio.path,
      builder: (context, isNowPlaying, _) {
        final effectiveFocus = widget.focus || isNowPlaying;
        return AudioContextMenu(
          audio: audio,
          playlist: widget.playlist,
          audioIndex: widget.audioIndex,
          onEdit: () => showModernDialog(
            context: context,
            builder: (context) => AudioEditDialog(audio: audio),
          ),
          builder: (context, controller, _) {
            final textColor =
                effectiveFocus ? scheme.primary : scheme.onSurface;
            final placeholder = Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.45),
                    scheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Symbols.music_note_rounded,
                  size: 24.0,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.65),
                ),
              ),
            );

            final selected =
                widget.multiSelectController?.selected.contains(audio) == true;

            final rowRadius = BorderRadius.circular(14.0);
            final isDark = scheme.brightness == Brightness.dark;
            final surfaces = context.surfaces;
            // 依据风格模式、悬停与选中状态自适应计算实体卡片 / 无界浮动背景与边框
            final isHighlight = effectiveFocus || selected;
            final highlightBgColor =
                scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10);
            final highlightBorderColor =
                scheme.primary.withValues(alpha: isDark ? 0.45 : 0.35);

            final normalDecoration = BoxDecoration(
              color: isHighlight ? highlightBgColor : surfaces.tileBackground,
              borderRadius: rowRadius,
              border: (isHighlight ? highlightBorderColor : surfaces.tileBorderColor) ==
                      Colors.transparent
                  ? null
                  : Border.all(
                      color: isHighlight
                          ? highlightBorderColor
                          : surfaces.tileBorderColor,
                      width: 0.5,
                    ),
              boxShadow: isHighlight
                  ? [
                      BoxShadow(
                        color: scheme.primary
                            .withValues(alpha: isDark ? 0.20 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : surfaces.tileShadow,
            );

            final hoverDecoration = BoxDecoration(
              color: isHighlight ? highlightBgColor : surfaces.tileHoverBackground,
              borderRadius: rowRadius,
              border: (isHighlight
                          ? highlightBorderColor
                          : surfaces.tileHoverBorderColor) ==
                      Colors.transparent
                  ? null
                  : Border.all(
                      color: isHighlight
                          ? highlightBorderColor
                          : surfaces.tileHoverBorderColor,
                      width: 0.5,
                    ),
              boxShadow: isHighlight
                  ? [
                      BoxShadow(
                        color: scheme.primary
                            .withValues(alpha: isDark ? 0.20 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : surfaces.tileShadow,
            );

            // 采用弹性最小高度约束替代原本写死的 height: 64.0，在大字号与高 DPI 下自适应容纳文本防溢出
            // 移除了外层冗余的 MouseRegion(setState) 与外层 AnimatedContainer，全量收拢至 CpMotionPressable，消除双重渲染
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: CpMotionPressable(
                  borderRadius: rowRadius,
                  decoration: normalDecoration,
                  hoverDecoration: hoverDecoration,
                  selected: effectiveFocus || selected,
                  border: false, // 禁用自带的硬边框，由 decoration 精准控制
                  hoverScale: 1.0,
                  pressScale: 0.985, // 按压时轻微内敛提供实体触感
                  hoverShadow: false,
                  selectedGlow: false,
                  focusNode: _focusNode,
                  onFocusChanged: _handleFocusChanged,
                        onTap: () {
                          if (AudioContextMenuManager.hasActive) {
                            AudioContextMenuManager.closeActive();
                            return;
                          }
                          if (controller.isOpen) {
                            controller.close();
                            return;
                          }

                          if (widget.multiSelectController == null ||
                              !widget.multiSelectController!
                                  .enableMultiSelectView) {
                            PlayService.instance.playbackService
                                .play(widget.audioIndex, widget.playlist);
                          } else {
                            widget.multiSelectController!
                                .toggleSelectionWithIndex(
                              index: widget.audioIndex,
                              item: audio,
                              items: widget.playlist,
                              shiftPressed:
                                  MultiSelectController.isShiftPressed(),
                            );
                          }
                        },
                        onSecondaryTapDown: (details) {
                          if (widget.multiSelectController
                                  ?.enableMultiSelectView ==
                              true) {
                            return;
                          }
                          AudioContextMenuManager.closeActive(
                            except: controller,
                          );
                          controller.open(position: details.localPosition);
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: LayoutBuilder(
                          builder: (context, tileConstraints) {
                            final showDuration =
                                tileConstraints.maxWidth >= 220;

                            return Row(
                              children: [
                                if (widget.leading != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: widget.leading!,
                                  ),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ScrollAwareFutureBuilder(
                                      futureKey: audio.path,
                                      future: () => audio.cover,
                                      builder: (context, snapshot) {
                                        return CoverFadeImage(
                                          provider: snapshot.data,
                                          index: widget.audioIndex,
                                          width: 48,
                                          height: 48,
                                          borderRadius: 10,
                                          placeholder:
                                              Center(child: placeholder),
                                        );
                                      },
                                    ),
                                    // 正在播放时展示右下角微型动态跳动均衡器徽章
                                    if (effectiveFocus)
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: scheme.primary
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const EqualizerPlayingBars(
                                            barColor: Colors.white,
                                            height: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16.0),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        audio.title,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          height: 1.25,
                                          letterSpacing: 0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4.0),
                                      LayoutBuilder(
                                        builder: (context, subtitleConstraints) {
                                          final showBadge = subtitleConstraints
                                                  .maxWidth >=
                                              150;

                                          return Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  widget.showPlayCount
                                                      ? "${audio.artist} - ${audio.album} | 播放 ${PlayCountStore.instance.get(audio)} 次"
                                                      : "${audio.artist} - ${audio.album}",
                                                  style: TextStyle(
                                                    color: textColor.withValues(
                                                      alpha:
                                                          isDark ? 0.82 : 0.90,
                                                    ),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.25,
                                                    letterSpacing: 0,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (showBadge) ...[
                                                const SizedBox(width: 8.0),
                                                AudioFormatBadge(
                                                  audio: audio,
                                                  compact: true,
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 220),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showDuration) ...[
                                        // 极简锐利模式下展示右侧彩色 Pill 胶囊徽章（自适应空间）
                                        Text(
                                          Duration(seconds: audio.duration)
                                              .toStringHMMSS(),
                                          style: TextStyle(
                                            color: effectiveFocus
                                                ? scheme.primary
                                                : scheme.onSurface
                                                    .withValues(alpha: 0.72),
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                      ],
                                      AudioContextMenu(
                                        audio: audio,
                                        playlist: widget.playlist,
                                        audioIndex: widget.audioIndex,
                                        onEdit: () => showModernDialog(
                                          context: context,
                                          builder: (context) => AudioEditDialog(
                                              audio: audio),
                                        ),
                                        builder: (context, moreMenuController,
                                            _) {
                                          return Semantics(
                                            label: '更多',
                                            button: true,
                                            child: Focus(
                                              skipTraversal: true,
                                              canRequestFocus: false,
                                              child: IconButton(
                                                tooltip: '更多',
                                                onPressed: () {
                                                  if (moreMenuController
                                                      .isOpen) {
                                                    moreMenuController.close();
                                                  } else {
                                                    AudioContextMenuManager
                                                        .closeActive(
                                                      except:
                                                          moreMenuController,
                                                    );
                                                    moreMenuController.open();
                                                  }
                                                },
                                                icon: const Icon(
                                                    Symbols.more_vert),
                                                color: textColor.withValues(
                                                  alpha: 0.76,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                style: IconButton.styleFrom(
                                                  minimumSize:
                                                      const Size(36, 36),
                                                  fixedSize: const Size(36, 36),
                                                  padding: EdgeInsets.zero,
                                                  elevation: 0,
                                                  shadowColor:
                                                      Colors.transparent,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  side: BorderSide.none,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ).copyWith(
                                                  overlayColor:
                                                      WidgetStatePropertyAll(
                                                    scheme.primary.withValues(
                                                      alpha: 0.08,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.multiSelectController
                                        ?.enableMultiSelectView ==
                                    true)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Checkbox(
                                      value: widget
                                          .multiSelectController!.selected
                                          .contains(audio),
                                      onChanged: (_) {
                                        widget.multiSelectController!
                                            .toggleSelectionWithIndex(
                                          index: widget.audioIndex,
                                          item: audio,
                                          items: widget.playlist,
                                          shiftPressed: MultiSelectController
                                              .isShiftPressed(),
                                        );
                                      },
                                    ),
                                  ),
                                if (widget.action != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: widget.action!,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
  }



/// 播放律动跳跃均衡器条组件
/// 用于在正在播放的歌曲列表项上呈现灵动的 3 柱波形跳动反馈
class EqualizerPlayingBars extends StatelessWidget {
  const EqualizerPlayingBars({
    super.key,
    this.barColor = Colors.white,
    this.height = 12.0,
    this.width = 10.0,
  });

  final Color barColor;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final isPlaying = playback.playerState == PlayerState.playing;

    return StreamBuilder<double>(
      stream: playback.positionStream,
      initialData: playback.position,
      builder: (context, snapshot) {
        final posMs = isPlaying ? ((snapshot.data ?? 0) * 1000).toInt() : 0;
        final t = (posMs % 900) / 900.0;
        final h1 = isPlaying
            ? (0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 * math.pi))).clamp(0.25, 1.0)
            : 0.45;
        final h2 = isPlaying
            ? (0.2 + 0.8 * (0.5 + 0.5 * math.cos(t * 2 * math.pi))).clamp(0.25, 1.0)
            : 0.8;
        final h3 = isPlaying
            ? (0.4 + 0.6 * (0.5 + 0.5 * math.sin((t + 0.3) * 2 * math.pi))).clamp(0.25, 1.0)
            : 0.35;

        return SizedBox(
          width: width,
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1),
              _buildBar(h2),
              _buildBar(h3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double fraction) {
    return Container(
      width: 2.0,
      height: height * fraction,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(1.0),
      ),
    );
  }
}
