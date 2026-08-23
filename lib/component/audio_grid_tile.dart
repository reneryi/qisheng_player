import 'package:qisheng_player/component/audio_context_menu.dart';
import 'package:qisheng_player/component/cover_fade_image.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/scroll_aware_future_builder.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

/// 栖声播放器网格歌曲条目组件
/// 采用上封面、下文字的经典网格布局，彻底解决横向空间不足带来的溢出问题
class AudioGridTile extends StatefulWidget {
  const AudioGridTile({
    super.key,
    required this.audioIndex,
    required this.playlist,
    this.showPlayCount = false,
    this.focus = false,
    this.multiSelectController,
  });

  final int audioIndex;
  final List<Audio> playlist;
  final bool showPlayCount;
  final bool focus;
  final MultiSelectController? multiSelectController;

  @override
  State<AudioGridTile> createState() => _AudioGridTileState();
}

class _AudioGridTileState extends State<AudioGridTile> {
  bool _isHovered = false; // 监听鼠标悬浮状态
  final FocusNode _focusNode = FocusNode(debugLabel: 'audio-grid-tile');

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

  PlaybackController _resolvePlaybackController(BuildContext context) {
    try {
      return context.read<PlaybackController>();
    } catch (_) {
      return PlayService.instance.playbackService;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final audio = widget.playlist[widget.audioIndex];
    final playbackService = _resolvePlaybackController(context);
    final motion = context.motion;

    return ListenableBuilder(
      listenable: playbackService,
      builder: (context, _) {
        // 判断当前歌曲是否正在播放
        final isNowPlaying = playbackService.nowPlaying?.path == audio.path;
        final effectiveFocus = widget.focus || isNowPlaying;
        final selected =
            widget.multiSelectController?.selected.contains(audio) == true;

        // 占位封面图
        final placeholder = Container(
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Center(
            child: Icon(
              Symbols.music_note,
              size: 44.0,
              color: scheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        );

        // 网格的圆角和背景着色
        final tileRadius = BorderRadius.circular(16.0);
        final isDark = scheme.brightness == Brightness.dark;

        // 依据悬停/选中状态，给外层容器加一层极轻微的背景，增加立体感
        final Color targetBgColor = (effectiveFocus || selected)
            ? scheme.primary.withValues(alpha: isDark ? 0.06 : 0.04)
            : _isHovered
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015))
                : Colors.transparent;

        return AudioContextMenu(
          audio: audio,
          playlist: widget.playlist,
          audioIndex: widget.audioIndex,
          onEdit: () => showDialog(
            context: context,
            builder: (context) => AudioEditDialog(audio: audio),
          ),
          builder: (context, controller, _) {
            // 根据状态设置文字颜色，正在播放显示强调色，其余为 normal
            final textColor =
                effectiveFocus ? scheme.primary : scheme.onSurface;

            return MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: AnimatedContainer(
                duration: motion.controlTransitionDuration,
                curve: motion.emphasized,
                decoration: BoxDecoration(
                  color: targetBgColor,
                  borderRadius: tileRadius,
                ),
                child: CpMotionPressable(
                  borderRadius: tileRadius,
                  selected: effectiveFocus || selected,
                  border: false, // 无边框通透设计
                  hoverScale: 1.0,
                  pressScale: 0.97, // 按压时略微收缩以提供绝佳的触觉反馈
                  hoverShadow: false,
                  selectedGlow: false,
                  focusNode: _focusNode,
                  onFocusChanged: _handleFocusChanged,
                  padding: const EdgeInsets.all(8.0),
                  onTap: () {
                    if (controller.isOpen) {
                      controller.close();
                      return;
                    }

                    // 如果没有开启多选，点击直接播放当前歌曲
                    if (widget.multiSelectController == null ||
                        !widget.multiSelectController!.enableMultiSelectView) {
                      PlayService.instance.playbackService
                          .play(widget.audioIndex, widget.playlist);
                    } else {
                      // 开启多选时，切换选中状态
                      widget.multiSelectController!.toggleSelectionWithIndex(
                        index: widget.audioIndex,
                        item: audio,
                        items: widget.playlist,
                        shiftPressed: MultiSelectController.isShiftPressed(),
                      );
                    }
                  },
                  onSecondaryTapDown: (details) {
                    if (widget.multiSelectController?.enableMultiSelectView ==
                        true) {
                      return;
                    }
                    // 在鼠标右键点击处弹出菜单
                    controller.open(
                      position: details.localPosition,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. 封面图区域，保持 1:1 比例
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 封面图读取
                            ScrollAwareFutureBuilder(
                              futureKey: audio.path,
                              future: () => audio.cover,
                              builder: (context, snapshot) {
                                return CoverFadeImage(
                                  provider: snapshot.data,
                                  index: widget.audioIndex,
                                  borderRadius: 12,
                                  placeholder: placeholder,
                                );
                              },
                            ),
                            // 聚焦/播放时的轻微发光内边框
                            if (effectiveFocus)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: scheme.primary
                                            .withValues(alpha: 0.62),
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Hover 蒙层与居中缩放播放微光
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: motion.controlTransitionDuration,
                                  curve: motion.normal,
                                  opacity: (_isHovered &&
                                          !(widget.multiSelectController
                                                  ?.enableMultiSelectView ??
                                              false))
                                      ? 1.0
                                      : 0.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.42),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Center(
                                      child: AnimatedScale(
                                        scale: _isHovered ? 1.0 : 0.8,
                                        duration:
                                            motion.controlTransitionDuration,
                                        curve: motion.emphasized,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white
                                                .withValues(alpha: 0.9),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.16),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.black87,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 多选模式下的 Checkbox 覆盖层 (右上角)
                            if (widget.multiSelectController
                                    ?.enableMultiSelectView ==
                                true)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Checkbox(
                                    value: selected,
                                    activeColor: scheme.primary,
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
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      // 2. 歌曲标题
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          audio.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      // 3. 艺术家或播放次数
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          widget.showPlayCount
                              ? "播放 ${PlayCountStore.instance.get(audio)} 次"
                              : audio.artist,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 12.0,
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
