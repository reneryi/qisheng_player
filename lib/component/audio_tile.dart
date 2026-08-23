import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/audio_context_menu.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/cover_fade_image.dart';
import 'package:qisheng_player/component/scroll_aware_future_builder.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart' as tag_writer;
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/component/ui/audio_format_badge.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

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
  bool _isHovered = false; // 跟踪悬浮状态以支持右滑 4px 呼吸动画
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
    final motion = context.motion; // 获取全局主题动效参数
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
          onEdit: () => showDialog(
            context: context,
            builder: (context) => AudioEditDialog(audio: audio),
          ),
          builder: (context, controller, _) {
            final textColor =
                effectiveFocus ? scheme.primary : scheme.onSurface;
            final placeholder = Icon(
              Symbols.broken_image,
              size: 48.0,
              color: scheme.onSurface,
            );

            final selected =
                widget.multiSelectController?.selected.contains(audio) == true;

            final rowRadius = BorderRadius.circular(14.0);
            final isDark = scheme.brightness == Brightness.dark;
            // 依据悬停与选中状态计算平滑的背景色彩，避免死板的突变，同时取消原本固定卡片的硬边框
            final Color targetBgColor = (effectiveFocus || selected)
                ? scheme.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                : _isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent;

            return MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              // 采用弹性最小高度约束替代原本写死的 height: 64.0，在大字号与高 DPI 下自适应容纳文本防溢出
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: AnimatedContainer(
                    duration: motion.controlTransitionDuration,
                    curve: motion.emphasized,
                    decoration: BoxDecoration(
                      color: targetBgColor,
                      borderRadius: rowRadius,
                    ),
                    child: CpMotionPressable(
                      borderRadius: rowRadius,
                      selected: effectiveFocus || selected,
                      border: false, // 禁用自带的硬边框，实现真正的 borderless 呼吸质感
                      hoverScale: 1.0,
                      pressScale: 0.985, // 按压时轻微内敛提供实体触感
                      hoverShadow: false, // 禁用自带的 hover 阴影，让流体背景更通透地露出
                      selectedGlow: false,
                      focusNode: _focusNode,
                      onFocusChanged: _handleFocusChanged,
                        onTap: () {
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
                          controller.open(position: details.localPosition);
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
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
                                      placeholder: Center(child: placeholder),
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
                                        borderRadius: BorderRadius.circular(6),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    audio.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3.0),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.showPlayCount
                                              ? "${audio.artist} - ${audio.album} | 播放 ${PlayCountStore.instance.get(audio)} 次"
                                              : "${audio.artist} - ${audio.album}",
                                          style: TextStyle(
                                            color: textColor.withValues(alpha: 0.72),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      AudioFormatBadge(
                                        audio: audio,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 极简锐利模式下展示右侧彩色 Pill 胶囊徽章（自适应空间）
                                  Text(
                                    Duration(seconds: audio.duration)
                                        .toStringHMMSS(),
                                    style: TextStyle(
                                      color: effectiveFocus
                                          ? scheme.primary
                                          : scheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Semantics(
                                    label: '更多',
                                    button: true,
                                    child: Focus(
                                      skipTraversal: true,
                                      canRequestFocus: false,
                                      child: IconButton(
                                        tooltip: '更多',
                                        onPressed: () => controller.open(),
                                        icon: const Icon(Symbols.more_vert),
                                        color:
                                            textColor.withValues(alpha: 0.76),
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(36, 36),
                                          padding: EdgeInsets.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ).copyWith(
                                          backgroundColor:
                                              const WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
                                          overlayColor: WidgetStatePropertyAll(
                                            textColor.withValues(alpha: 0.08),
                                          ),
                                        ),
                                      ),
                                    ),
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
                                  value: widget.multiSelectController!.selected
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
                        ),
                      ),
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

class AudioEditDialog extends StatefulWidget {
  const AudioEditDialog({required this.audio, super.key});

  final Audio audio;

  @override
  State<AudioEditDialog> createState() => _AudioEditDialogState();
}

class _AudioEditDialogState extends State<AudioEditDialog> {
  late final titleController = TextEditingController(text: widget.audio.title);
  late final artistController =
      TextEditingController(text: widget.audio.artist);
  late final albumController = TextEditingController(text: widget.audio.album);
  late final Future<List<SongSearchResult>> _searchFuture =
      uniSearch(widget.audio);
  bool _busy = false;

  /// 淇濆瓨鏍囩瑕嗙洊鍒?JSON 文件，并同步更新 index.json 浣夸慨鏀规寔涔呭寲
  Future<void> _saveOverride() async {
    final title = titleController.text.trim();
    final artist = artistController.text.trim();
    final album = albumController.text.trim();
    if (title.isEmpty || artist.isEmpty || album.isEmpty) {
      showTextOnSnackBar("标题、艺术家、专辑不能为空");
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await AudioMetadataOverrideStore.instance.setOverride(
        audio: widget.audio,
        title: title,
        artist: artist,
        album: album,
      );

      // 直接写入音乐文件的元数据标签（非 CUE 轨道）。
      if (!widget.audio.isCueTrack) {
        final wrote = await tag_writer.writeTagToFile(
          path: widget.audio.path,
          title: title,
          artist: artist,
          album: album,
        );
        if (!wrote) {
          LOGGER.e("标签写入文件失败: ${widget.audio.path}");
        }
      }

      // 统一由 Rust 端串行更新 index.json，避免与启动扫描交错覆盖。
      final supportPath = (await getAppDataDir()).path;
      await tag_writer.updateAudioMetadataInIndex(
        indexPath: supportPath,
        audioPath: widget.audio.path,
        title: title,
        artist: artist,
        album: album,
      );

      AudioLibrary.instance.rebuildCollectionsFromCurrentFolders();

      // 如果当前正在播放该歌曲，刷新播放界面
      final playbackService = PlayService.instance.playbackService;
      if (playbackService.nowPlaying?.path == widget.audio.path) {
        playbackService.refreshNowPlaying();
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }

    if (mounted) {
      showTextOnSnackBar("已保存音频标签");
      Navigator.pop(context);
    }
  }

  /// 设置在线歌词来源，保存后刷新正在播放的歌词。
  Future<void> _applyLyricSource(SongSearchResult result) async {
    final source = switch (result.source) {
      ResultSource.qq => LyricSourceType.qq,
      ResultSource.kugou => LyricSourceType.kugou,
      ResultSource.netease => LyricSourceType.netease,
    };
    LYRIC_SOURCES[widget.audio.path] = LyricSource(
      source,
      qqSongId: result.qqSongId,
      kugouSongHash: result.kugouSongHash,
      neteaseSongId: result.neteaseSongId,
    );
    await saveLyricSources();

    // 如果当前正在播放该歌曲，立即刷新歌词显示
    final playbackService = PlayService.instance.playbackService;
    if (playbackService.nowPlaying?.path == widget.audio.path) {
      PlayService.instance.lyricService.updateLyric();
    }
    showTextOnSnackBar("已设置在线歌词来源");
  }

  /// 应用在线封面，下载成功后刷新列表和播放页的封面显示
  Future<void> _applyCover(SongSearchResult result) async {
    final url = result.coverUrl;
    if (url == null || url.isEmpty) {
      showTextOnSnackBar("该匹配结果没有可用封面");
      return;
    }
    setState(() {
      _busy = true;
    });
    final cover = await OnlineCoverStore.instance.setCoverFromUrl(
      audio: widget.audio,
      url: url,
    );
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
    if (cover == null) {
      showTextOnSnackBar("在线封面应用失败");
      return;
    }
    // 清除封面缓存并通知播放服务刷新 UI。
    widget.audio.clearCoverCache();

    // 将封面写入音乐文件的元数据标签（非 CUE 轨道）。
    if (!widget.audio.isCueTrack) {
      try {
        // 从 setCoverFromUrl 返回的缓存路径读取封面数据。
        final supportPath = (await getAppDataDir()).path;
        final coverDir = "$supportPath\\cover_cache";
        // 使用与 OnlineCoverStore 相同的命名规则找到缓存文件。
        final cacheBytes = utf8.encode(widget.audio.path);
        final cacheNameBuilder = StringBuffer();
        for (final item in cacheBytes) {
          cacheNameBuilder.write(item.toRadixString(16).padLeft(2, '0'));
        }
        final coverCachePath = "$coverDir\\${cacheNameBuilder.toString()}.jpg";
        final coverFile = File(coverCachePath);
        if (coverFile.existsSync()) {
          final coverBytes = await coverFile.readAsBytes();
          await tag_writer.writeCoverToFile(
            path: widget.audio.path,
            coverData: coverBytes,
          );
        }
      } catch (err, trace) {
        LOGGER.e("封面写入文件失败", error: err, stackTrace: trace);
      }
    }

    final playbackService = PlayService.instance.playbackService;
    if (playbackService.nowPlaying?.path == widget.audio.path) {
      playbackService.refreshNowPlaying();
    }
    showTextOnSnackBar("已应用在线封面");
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "音乐编辑",
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "标题",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: artistController,
                      decoration: const InputDecoration(
                        labelText: "艺术家",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: albumController,
                      decoration: const InputDecoration(
                        labelText: "专辑",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _saveOverride,
                    icon: const Icon(Symbols.save),
                    label: const Text("保存元信息覆盖"),
                  ),
                  const SizedBox(width: 8),
                  if (_busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "在线匹配结果",
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    final result = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (result == null || result.isEmpty) {
                      return const Center(child: Text("无在线匹配结果"));
                    }
                    return ListView.builder(
                      itemCount: result.length,
                      itemBuilder: (context, i) {
                        final item = result[i];
                        return ListTile(
                          dense: true,
                          title: Text("${item.title} - ${item.artists}"),
                          subtitle: Text(
                            "${item.album} | 匹配概率 ${(item.score * 100).toStringAsFixed(1)}%",
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _applyLyricSource(item),
                                child: const Text("设歌词"),
                              ),
                              OutlinedButton(
                                onPressed:
                                    _busy ? null : () => _applyCover(item),
                                child: const Text("设封面"),
                              ),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        titleController.text = item.title;
                                        artistController.text = item.artists;
                                        albumController.text = item.album;
                                      },
                                child: const Text("填入到表单"),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("关闭"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
