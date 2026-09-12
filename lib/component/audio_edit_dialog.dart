import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric_file_helper.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart' as tag_writer;
import 'package:qisheng_player/src/rust/api/utils.dart' as rust_utils;
import 'package:qisheng_player/utils.dart';

/// 栖声播放器现代风格音乐编辑与在线匹配对话框。
/// 视觉与交互规范深度对齐管理文件夹及新建/编辑歌单弹窗（ModernDialogFrame）。
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

  late Future<List<SongSearchResult>> _searchFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _searchFuture = uniSearch(widget.audio);
  }

  @override
  void dispose() {
    titleController.dispose();
    artistController.dispose();
    albumController.dispose();
    super.dispose();
  }

  /// 使用当前表单的标题和艺术家信息重新执行多平台在线检索。
  void _reSearch() {
    final queryAudio = Audio(
      titleController.text.trim().isNotEmpty
          ? titleController.text.trim()
          : widget.audio.title,
      artistController.text.trim().isNotEmpty
          ? artistController.text.trim()
          : widget.audio.artist,
      albumController.text.trim().isNotEmpty
          ? albumController.text.trim()
          : widget.audio.album,
      widget.audio.composer,
      widget.audio.arranger,
      widget.audio.disc,
      widget.audio.track,
      widget.audio.duration,
      widget.audio.bitrate,
      widget.audio.sampleRate,
      widget.audio.replayGainDb,
      widget.audio.sourcePath,
      widget.audio.cueStartMs,
      widget.audio.cueEndMs,
      widget.audio.path,
      widget.audio.modified,
      widget.audio.created,
      widget.audio.by,
    );

    setState(() {
      _searchFuture = uniSearch(queryAudio);
    });
  }

  /// 保存标签覆盖到 JSON 文件，并同步更新 index.json 使修改持久化。
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

  /// 设置在线歌词，并根据用户勾选的保存选项执行物理写入与播放器刷新。
  Future<void> _applyLyricSource(SongSearchResult result) async {
    final settings = AppSettings.instance;
    final isCue = widget.audio.isCueTrack;
    final effectiveWriteTag = !isCue && settings.lyricSaveWriteTag;
    final exportLrc = settings.lyricSaveExportLrc;
    final applyPlayer = settings.lyricSaveApplyPlayer;

    if (!effectiveWriteTag && !exportLrc && !applyPlayer) {
      if (isCue && settings.lyricSaveWriteTag) {
        showTextOnSnackBar("当前为 CUE 分轨（内嵌标签已禁用），请勾选保存.lrc或应用到播放器");
      } else {
        showTextOnSnackBar("请至少勾选一项设歌词处理方式（写入内嵌、保存.lrc或应用到播放器）");
      }
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      String? lrcText;
      if (effectiveWriteTag || exportLrc) {
        lrcText = await LyricFileHelper.fetchOnlineLrcText(result);
        if (lrcText == null || lrcText.trim().isEmpty) {
          LOGGER.w("未能从 ${result.source.name} 获取到有效歌词文本");
        }
      }

      // 如果物理保存被勾选但未能拉取到歌词文本
      if ((effectiveWriteTag || exportLrc) && (lrcText == null || lrcText.trim().isEmpty)) {
        if (applyPlayer) {
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

          final playbackService = PlayService.instance.playbackService;
          if (playbackService.nowPlaying?.path == widget.audio.path) {
            PlayService.instance.lyricService.updateLyric();
          }

          showTextOnSnackBar("已设置在线歌词映射（物理歌词文本拉取失败）");
        } else {
          showTextOnSnackBar("未能从 ${result.source.name} 拉取到有效歌词文本，物理保存未生效");
        }
        return;
      }

      final successActions = <String>[];
      final failedActions = <String>[];

      // 1. 写入音频内嵌标签（Lofty: ID3v2/FLAC/MP4等）。对 CUE 轨道做好保护，禁止写入母带文件。
      if (effectiveWriteTag && lrcText != null && lrcText.isNotEmpty) {
        final ok = await LyricFileHelper.writeEmbeddedLyric(widget.audio, lrcText);
        if (ok) {
          successActions.add("内嵌标签");
        } else {
          failedActions.add("内嵌标签");
        }
      }

      // 2. 生成同级外挂 .lrc 文件。支持普通音频及 CUE 分轨命名。
      if (exportLrc && lrcText != null && lrcText.isNotEmpty) {
        final ok = await LyricFileHelper.saveLrcToFile(widget.audio, lrcText);
        if (ok) {
          successActions.add("同级.lrc");
        } else {
          failedActions.add("同级.lrc");
        }
      }

      // 3. 应用到播放器在线歌词映射。
      if (applyPlayer) {
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
        successActions.add("播放器");
      }

      // 如果当前正在播放该歌曲，立即刷新歌词显示
      final playbackService = PlayService.instance.playbackService;
      if (playbackService.nowPlaying?.path == widget.audio.path) {
        if (lrcText != null && lrcText.trim().isNotEmpty) {
          final parsed = Lrc.fromLrcText(lrcText, LrcSource.local);
          if (parsed != null && parsed.lines.isNotEmpty) {
            PlayService.instance.lyricService.useSpecificLyric(parsed);
          } else {
            PlayService.instance.lyricService.updateLyric();
          }
        } else {
          PlayService.instance.lyricService.updateLyric();
        }
      }

      if (successActions.isNotEmpty && failedActions.isEmpty) {
        showTextOnSnackBar("已设歌词：${successActions.join(' + ')}");
      } else if (successActions.isNotEmpty && failedActions.isNotEmpty) {
        showTextOnSnackBar(
          "已设歌词：${successActions.join(' + ')}（${failedActions.join('、')}失败）",
        );
      } else if (failedActions.isNotEmpty) {
        showTextOnSnackBar("设歌词失败：${failedActions.join('、')}写入失败");
      } else {
        showTextOnSnackBar("歌词处理完成");
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  /// 应用在线封面，下载成功后刷新列表和播放页的封面显示。
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
    if (!widget.audio.isCueTrack && cover is FileImage) {
      try {
        if (cover.file.existsSync()) {
          final coverBytes = await cover.file.readAsBytes();
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

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    required bool isDark,
    required ColorScheme scheme,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.28)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.48),
            labelText: label,
            labelStyle: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.80),
              fontSize: 13.0,
            ),
            floatingLabelStyle: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13.0,
            ),
            prefixIcon: Icon(
              prefixIcon,
              size: 19,
              color: scheme.primary.withValues(alpha: 0.85),
            ),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    tooltip: "清空",
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Symbols.clear_rounded, size: 16),
                    onPressed: () => controller.clear(),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: scheme.primary,
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionChip({
    required String label,
    required IconData icon,
    required bool selected,
    bool disabled = false,
    required bool isDark,
    required ColorScheme scheme,
    VoidCallback? onTap,
  }) {
    final activeColor = scheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            color: disabled
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.03))
                : selected
                    ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: disabled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06))
                  : selected
                      ? activeColor.withValues(alpha: isDark ? 0.50 : 0.38)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10)),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                disabled
                    ? Symbols.block_rounded
                    : selected
                        ? Symbols.check_box_rounded
                        : Symbols.check_box_outline_blank_rounded,
                size: 15,
                color: disabled
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                    : selected
                        ? activeColor
                        : scheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 5),
              Text(
                disabled ? "$label(CUE保护)" : label,
                style: TextStyle(
                  color: disabled
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                      : selected
                          ? (isDark ? Colors.white : scheme.onSurface)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricPreferencesBar({
    required bool isDark,
    required ColorScheme scheme,
  }) {
    final settings = AppSettings.instance;
    final isCue = widget.audio.isCueTrack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.20)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.tune_rounded,
            size: 16,
            color: scheme.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 6),
          Text(
            "设歌词动作：",
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          // 方案 A：写入内嵌标签 (Lofty)
          Tooltip(
            message: isCue
                ? "CUE 分轨保护：禁止修改母带物理文件标签"
                : "将在线歌词写入音频文件内嵌元数据（ID3v2 USLT / FLAC / MP4）",
            child: _buildOptionChip(
              label: "写入音频内嵌标签",
              icon: Symbols.save_rounded,
              selected: !isCue && settings.lyricSaveWriteTag,
              disabled: isCue,
              isDark: isDark,
              scheme: scheme,
              onTap: isCue
                  ? null
                  : () {
                      setState(() {
                        settings.lyricSaveWriteTag = !settings.lyricSaveWriteTag;
                      });
                      settings.scheduleSaveSettings();
                    },
            ),
          ),
          const SizedBox(width: 6),
          // 方案 B：生成同级 .lrc 文件
          Tooltip(
            message: isCue
                ? "在母带同级目录生成分轨名称的外挂 .lrc 歌词文件"
                : "在音频同级目录生成同名的 .lrc 外挂歌词文件",
            child: _buildOptionChip(
              label: "保存同级 .lrc 文件",
              icon: Symbols.description_rounded,
              selected: settings.lyricSaveExportLrc,
              isDark: isDark,
              scheme: scheme,
              onTap: () {
                setState(() {
                  settings.lyricSaveExportLrc = !settings.lyricSaveExportLrc;
                });
                settings.scheduleSaveSettings();
              },
            ),
          ),
          const SizedBox(width: 6),
          // 方案 C：应用到播放器
          Tooltip(
            message: "将歌词设定为播放器在线歌词来源并立即刷新播放器显示",
            child: _buildOptionChip(
              label: "应用到播放器",
              icon: Symbols.play_circle_rounded,
              selected: settings.lyricSaveApplyPlayer,
              isDark: isDark,
              scheme: scheme,
              onTap: () {
                setState(() {
                  settings.lyricSaveApplyPlayer = !settings.lyricSaveApplyPlayer;
                });
                settings.scheduleSaveSettings();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogHeight =
        math.min(630.0, math.max(450.0, screenHeight - 96.0));

    return ModernDialogFrame(
      maxWidth: 800.0,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 20),
      child: SizedBox(
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：现代图标徽标 + 标题与副标题 + 优雅关闭按钮
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary
                        .withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: scheme.primary
                          .withValues(alpha: isDark ? 0.28 : 0.20),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    Symbols.edit_note_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "音乐编辑",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "修改本地音频元数据标签，或检索匹配在线歌词与高清封面",
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: isDark ? 0.82 : 0.90,
                          ),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "关闭",
                  icon: Icon(
                    Symbols.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // 表单区域：半透明圆角输入框 + 热键监听隔离
            Focus(
              onFocusChange: HotkeysHelper.onFocusChanges,
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernField(
                      controller: titleController,
                      label: "标题",
                      prefixIcon: Symbols.music_note_rounded,
                      isDark: isDark,
                      scheme: scheme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernField(
                      controller: artistController,
                      label: "艺术家",
                      prefixIcon: Symbols.person_rounded,
                      isDark: isDark,
                      scheme: scheme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernField(
                      controller: albumController,
                      label: "专辑",
                      prefixIcon: Symbols.album_rounded,
                      isDark: isDark,
                      scheme: scheme,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),

            // 操作栏：保存元信息覆盖按钮 + 交互式路径信息卡片
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : _saveOverride,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Symbols.save_rounded, size: 18),
                  label: const Text(
                    "保存元信息覆盖",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final opened = await rust_utils.showInExplorer(
                          path: widget.audio.mediaPath,
                        );
                        if (!opened) {
                          showTextOnSnackBar("无法在资源管理器中定位：${widget.audio.mediaPath}");
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Symbols.folder_open_rounded,
                              size: 16,
                              color: scheme.primary.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Tooltip(
                                message: "${widget.audio.path}\n(点击在资源管理器中定位)",
                                child: Text(
                                  widget.audio.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                    fontSize: 12.0,
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
              ],
            ),
            const SizedBox(height: 16.0),

            // 在线匹配结果区域标题与检索按钮
            Row(
              children: [
                Icon(
                  Symbols.travel_explore_rounded,
                  size: 19,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "在线匹配结果",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color:
                        scheme.primary.withValues(alpha: isDark ? 0.15 : 0.09),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "多源检索",
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.primary,
                    side: BorderSide(
                      color: scheme.primary
                          .withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _busy ? null : _reSearch,
                  icon: const Icon(Symbols.refresh_rounded, size: 15),
                  label: const Text(
                    "重新检索",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),

            // 歌词物理保存与应用自由选择配置栏
            _buildLyricPreferencesBar(isDark: isDark, scheme: scheme),
            const SizedBox(height: 8.0),

            // 结果展示列表
            Expanded(
              child: FutureBuilder<List<SongSearchResult>>(
                future: _searchFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "正在多平台检索匹配歌曲元数据、高清封面与歌词...",
                            style: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.85),
                              fontSize: 13.0,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final result = snapshot.data;
                  if (result == null || result.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Symbols.search_off_rounded,
                            size: 42,
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "未检索到匹配的在线元数据",
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "可调整上方标题或艺术家信息后点击“重新检索”",
                            style: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: result.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = result[i];
                      return SearchResultCard(
                        item: item,
                        isDark: isDark,
                        scheme: scheme,
                        busy: _busy,
                        onApplyLyric: () => _applyLyricSource(item),
                        onApplyCover: () => _applyCover(item),
                        onFillForm: () {
                          setState(() {
                            titleController.text = item.title;
                            artistController.text = item.artists;
                            albumController.text = item.album;
                          });
                          showTextOnSnackBar("已填入到表单");
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12.0),

            // 底部操作栏：提示与关闭按钮
            Row(
              children: [
                Icon(
                  Symbols.lightbulb_rounded,
                  size: 16,
                  color: scheme.primary.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "提示：修改上方标签需点击“保存元信息覆盖”生效；“设歌词”按上方勾选方式（内嵌标签/同级.lrc/播放器）自定义处理",
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 9,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "关闭",
                    style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 在线匹配结果项卡片，支持悬浮态、网络封面缩略图渲染及放大的操作按钮。
@visibleForTesting
class SearchResultCard extends StatefulWidget {
  const SearchResultCard({
    required this.item,
    required this.isDark,
    required this.scheme,
    required this.busy,
    required this.onApplyLyric,
    required this.onApplyCover,
    required this.onFillForm,
    super.key,
  });

  final SongSearchResult item;
  final bool isDark;
  final ColorScheme scheme;
  final bool busy;
  final VoidCallback onApplyLyric;
  final VoidCallback onApplyCover;
  final VoidCallback onFillForm;

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _isHovered = false;

  (String name, Color brandColor) get _platformInfo => switch (widget.item.source) {
        ResultSource.qq => ("QQ音乐", const Color(0xFF10B981)),
        ResultSource.kugou => ("酷狗", const Color(0xFF0C82FF)),
        ResultSource.netease => ("网易云", const Color(0xFFEF4444)),
      };

  Widget _buildCoverThumbnail() {
    final hasCover = widget.item.coverUrl != null &&
        widget.item.coverUrl!.trim().isNotEmpty;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.isDark ? 0.35 : 0.12,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: widget.scheme.primary.withValues(
              alpha: widget.isDark ? 0.08 : 0.04,
            ),
            blurRadius: 14,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: hasCover
            ? Image.network(
                widget.item.coverUrl!,
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildCoverPlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildCoverLoading();
                },
              )
            : _buildCoverPlaceholder(),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.scheme.primaryContainer.withValues(
              alpha: widget.isDark ? 0.35 : 0.22,
            ),
            widget.scheme.surfaceContainerHighest.withValues(
              alpha: widget.isDark ? 0.45 : 0.35,
            ),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Symbols.album_rounded,
          size: 28,
          color: widget.scheme.primary.withValues(
            alpha: widget.isDark ? 0.75 : 0.65,
          ),
        ),
      ),
    );
  }

  Widget _buildCoverLoading() {
    return Container(
      width: 56,
      height: 56,
      color: widget.scheme.surfaceContainerHighest.withValues(
        alpha: widget.isDark ? 0.35 : 0.50,
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: widget.scheme.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (sourceName, brandColor) = _platformInfo;
    final isHighMatch = widget.item.score >= 0.8;
    final hasCover = widget.item.coverUrl != null &&
        widget.item.coverUrl!.trim().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.isDark
                  ? widget.scheme.surfaceContainerHighest.withValues(alpha: 0.42)
                  : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.70))
              : (widget.isDark
                  ? widget.scheme.surfaceContainerHighest.withValues(alpha: 0.22)
                  : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.42)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered
                ? widget.scheme.primary.withValues(
                    alpha: widget.isDark ? 0.45 : 0.35,
                  )
                : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
            width: _isHovered ? 1.2 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.24 : 0.08,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
        child: Row(
          children: [
            // 左侧封面缩略图（有封面展示在线封面，无封面展示精致占位图）
            _buildCoverThumbnail(),
            const SizedBox(width: 14),

            // 歌曲标题、作者、专辑及匹配信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.scheme.onSurface,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (widget.item.artists.trim().isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7.0),
                          child: Text(
                            "·",
                            style: TextStyle(
                              color: widget.scheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                              fontWeight: FontWeight.w900,
                              fontSize: 13.0,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            widget.item.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.scheme.onSurfaceVariant
                                  .withValues(alpha: 0.85),
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 平台标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(
                            alpha: widget.isDark ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: brandColor.withValues(
                              alpha: widget.isDark ? 0.38 : 0.25,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          sourceName,
                          style: TextStyle(
                            color: brandColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 匹配度标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isHighMatch
                              ? Colors.green.withValues(
                                  alpha: widget.isDark ? 0.20 : 0.12,
                                )
                              : widget.scheme.primary.withValues(
                                  alpha: widget.isDark ? 0.18 : 0.09,
                                ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isHighMatch
                                ? Colors.green.withValues(
                                    alpha: widget.isDark ? 0.35 : 0.25,
                                  )
                                : widget.scheme.primary.withValues(
                                    alpha: widget.isDark ? 0.30 : 0.20,
                                  ),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isHighMatch) ...[
                              Icon(
                                Symbols.verified_rounded,
                                size: 11.5,
                                color: widget.isDark
                                    ? Colors.greenAccent
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 3.5),
                            ],
                            Text(
                              "${(widget.item.score * 100).toStringAsFixed(0)}% 匹配",
                              style: TextStyle(
                                color: isHighMatch
                                    ? (widget.isDark
                                        ? Colors.greenAccent
                                        : Colors.green.shade700)
                                    : widget.scheme.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 专辑
                      Expanded(
                        child: Tooltip(
                          message: widget.item.album.isNotEmpty
                              ? widget.item.album
                              : "未知专辑",
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.album_rounded,
                                size: 13,
                                color: widget.scheme.onSurfaceVariant
                                    .withValues(alpha: 0.50),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.item.album.isNotEmpty
                                      ? widget.item.album
                                      : "未知专辑",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.scheme.onSurfaceVariant
                                        .withValues(alpha: 0.70),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // 操作按钮组：设歌词、设封面、填入表单 (调大字号与按钮手感)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark
                        ? Colors.white.withValues(alpha: 0.90)
                        : widget.scheme.onSurface,
                    backgroundColor: widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    side: BorderSide(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.12),
                      width: 1.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8.5,
                    ),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: widget.busy ? null : widget.onApplyLyric,
                  icon: Icon(
                    Symbols.lyrics_rounded,
                    size: 17,
                    color: widget.scheme.primary.withValues(alpha: 0.9),
                  ),
                  label: const Text(
                    "设歌词",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark
                        ? Colors.white.withValues(alpha: 0.90)
                        : widget.scheme.onSurface,
                    backgroundColor: widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    side: BorderSide(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.12),
                      width: 1.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8.5,
                    ),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: widget.busy ? null : widget.onApplyCover,
                  icon: Icon(
                    Symbols.image_rounded,
                    size: 17,
                    color: hasCover
                        ? const Color(0xFFF59E0B)
                        : widget.scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  label: const Text(
                    "设封面",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.scheme.primary.withValues(
                      alpha: widget.isDark ? 0.24 : 0.14,
                    ),
                    foregroundColor: widget.scheme.primary,
                    side: BorderSide(
                      color: widget.scheme.primary.withValues(
                        alpha: widget.isDark ? 0.40 : 0.28,
                      ),
                      width: 1.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8.5,
                    ),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: widget.busy ? null : widget.onFillForm,
                  icon: const Icon(
                    Symbols.edit_note_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    "填入表单",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

