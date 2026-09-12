import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/animated_menu_content.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_file_helper.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_controls_visibility.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/utils.dart';

class SetLyricSourceBtn extends StatelessWidget {
  const SetLyricSourceBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlayService.instance.lyricService,
      builder: (context, _) => FutureBuilder(
        future: PlayService.instance.lyricService.currLyricFuture,
        builder: (context, snapshot) {
          const loadingWidget = IconButton(
            onPressed: null,
            icon: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(),
            ),
          );
          final lyricNullable = snapshot.data;
          final isLocal = lyricNullable == null
              ? null
              : (lyricNullable is Lrc &&
                  lyricNullable.source == LrcSource.local);
          return switch (snapshot.connectionState) {
            ConnectionState.none => loadingWidget,
            ConnectionState.waiting => loadingWidget,
            ConnectionState.active => loadingWidget,
            ConnectionState.done => _SetLyricSourceBtn(isLocal: isLocal),
          };
        },
      ),
    );
  }
}

class _SetLyricSourceBtn extends StatelessWidget {
  final bool? isLocal;
  const _SetLyricSourceBtn({this.isLocal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricService = PlayService.instance.lyricService;
    final visibilityController =
        context.read<LyricControlsVisibilityController>();
    return MenuAnchor(
      onOpen: () {
        visibilityController.setMenuOpen(true);
      },
      onClose: () {
        visibilityController.setMenuOpen(false);
      },
      menuChildren: animatedMenuChildren(context, [
        MenuItemButton(
          onPressed: () {
            final nowPlaying = PlayService.instance.playbackService.nowPlaying;
            if (nowPlaying == null) return;
            showModernDialog<void>(
              context: context,
              builder: (context) => SetLyricSourceDialog(audio: nowPlaying),
            );
          },
          child: const Text("指定默认歌词"),
        ),
        MenuItemButton(
          onPressed: lyricService.useOnlineLyric,
          leadingIcon: isLocal == false ? const Icon(Symbols.check) : null,
          child: const Text("在线"),
        ),
        MenuItemButton(
          onPressed: lyricService.useLocalLyric,
          leadingIcon: isLocal == true ? const Icon(Symbols.check) : null,
          child: const Text("本地"),
        ),
      ]),
      builder: (context, controller, _) => Tooltip(
        message: "选择歌词来源",
        child: IconButton(
          enableFeedback: false,
          onPressed: PlayService.instance.playbackService.nowPlaying == null
              ? null
              : () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
          icon: const Icon(Symbols.lyrics),
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

enum LyricSourceTab { online, local }

/// 现代风格歌词设置对话框（基于 ModernDialogFrame）
class SetLyricSourceDialog extends StatefulWidget {
  const SetLyricSourceDialog({
    required this.audio,
    this.initialSearchFuture,
    this.initialLocalLyricFuture,
    this.onlineLyricBuilder,
    super.key,
  });

  final Audio audio;
  final Future<List<SongSearchResult>>? initialSearchFuture;
  final Future<Lrc?>? initialLocalLyricFuture;
  final Future<Lyric?> Function(SongSearchResult result)? onlineLyricBuilder;

  @override
  State<SetLyricSourceDialog> createState() => _SetLyricSourceDialogState();
}

class _SetLyricSourceDialogState extends State<SetLyricSourceDialog> {
  late LyricSourceTab _currentTab;
  late Future<List<SongSearchResult>> _searchFuture;
  late Future<Lrc?> _localLyricFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final current = LYRIC_SOURCES[widget.audio.path];
    _currentTab = current?.source == LyricSourceType.local
        ? LyricSourceTab.local
        : LyricSourceTab.online;
    _searchFuture = widget.initialSearchFuture ?? uniSearch(widget.audio);
    _localLyricFuture =
        widget.initialLocalLyricFuture ?? Lrc.fromAudioPath(widget.audio);
  }

  void _reSearch() {
    setState(() {
      _searchFuture = uniSearch(widget.audio);
    });
  }

  Future<void> _applyOnlineLyric(SongSearchResult result, Lyric lyric) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
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

      final playbackService = PlayService.existingInstance?.playbackService;
      if (playbackService?.nowPlaying?.path == widget.audio.path) {
        PlayService.existingInstance?.lyricService.useSpecificLyric(lyric);
      }
      if (mounted) {
        showTextOnSnackBar("已指定默认歌词：${result.title}");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTextOnSnackBar("设置默认歌词失败: $e");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyLocalLyric() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      LYRIC_SOURCES[widget.audio.path] = LyricSource(LyricSourceType.local);
      await saveLyricSources();

      final playbackService = PlayService.existingInstance?.playbackService;
      if (playbackService?.nowPlaying?.path == widget.audio.path) {
        PlayService.existingInstance?.lyricService.useLocalLyric();
      }
      if (mounted) {
        showTextOnSnackBar("已将默认歌词指定为：本地歌词");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTextOnSnackBar("设置本地歌词失败: $e");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetToAuto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      LYRIC_SOURCES.remove(widget.audio.path);
      await saveLyricSources();

      final playbackService = PlayService.existingInstance?.playbackService;
      if (playbackService?.nowPlaying?.path == widget.audio.path) {
        PlayService.existingInstance?.lyricService.updateLyric();
      }
      if (mounted) {
        showTextOnSnackBar("已恢复为系统自动匹配");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTextOnSnackBar("重置失败: $e");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isResultSelected(SongSearchResult result) {
    final current = LYRIC_SOURCES[widget.audio.path];
    if (current == null) return false;
    return switch (result.source) {
      ResultSource.qq => current.source == LyricSourceType.qq &&
          current.qqSongId != null &&
          current.qqSongId == result.qqSongId,
      ResultSource.kugou => current.source == LyricSourceType.kugou &&
          current.kugouSongHash != null &&
          current.kugouSongHash == result.kugouSongHash,
      ResultSource.netease => current.source == LyricSourceType.netease &&
          current.neteaseSongId != null &&
          current.neteaseSongId == result.neteaseSongId,
    };
  }

  bool get _isLocalSelected {
    final current = LYRIC_SOURCES[widget.audio.path];
    return current?.source == LyricSourceType.local;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final textScale = mediaQuery.textScaler.scale(1.0);

    // 严密弹性视口计算：
    // ModernDialogFrame 外边距 vertical 32*2=64px，内边距 vertical 20+18=38px，边框 2px，合计 104px。
    // 保留 108.0px 边距安全余量，杜绝子容器高度超出视口导致 RenderFlex overflow
    final availableHeight = math.max(60.0, screenHeight - 108.0);
    final dialogHeight = math.min(620.0, availableHeight);

    // 当可用高度较小 (< 220px，如 400x300 或 300x200) 或大字号矮屏复合场景 (availableHeight < 320 且 textScale > 1.3) 时，
    // 采用外层 SingleChildScrollView 自适应滚动包裹，杜绝在极限视口与超大字号下的任何 RenderFlex overflow
    final isConstrained =
        availableHeight < 220.0 || (availableHeight < 320.0 && textScale > 1.3);

    return ModernDialogFrame(
      maxWidth: 640.0,
      padding: screenHeight < 360
          ? const EdgeInsets.fromLTRB(20, 14, 20, 12)
          : const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: isConstrained
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: dialogHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, scheme, isDark),
                    const SizedBox(height: 8.0),
                    _buildTabBar(context, scheme, isDark),
                    const SizedBox(height: 8.0),
                    _currentTab == LyricSourceTab.online
                        ? _buildOnlineTabView(context, scheme, isDark,
                            shrinkWrap: true)
                        : _buildLocalTabView(context, scheme, isDark,
                            shrinkWrap: true),
                    const SizedBox(height: 8.0),
                    _buildFooter(context, scheme, isDark),
                  ],
                ),
              ),
            )
          : SizedBox(
              height: dialogHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 顶部 Header：现代图标徽标 + 标题/副标题 + 关闭按钮
                  _buildHeader(context, scheme, isDark),
                  const SizedBox(height: 12.0),

                  // 2. 切换导航栏：SegmentedButton (在线匹配歌词 / 本地音频歌词)
                  _buildTabBar(context, scheme, isDark),
                  const SizedBox(height: 10.0),

                  // 3. 主体内容区：Expanded 弹性包裹，杜绝溢出
                  Expanded(
                    child: _currentTab == LyricSourceTab.online
                        ? _buildOnlineTabView(context, scheme, isDark)
                        : _buildLocalTabView(context, scheme, isDark),
                  ),
                  const SizedBox(height: 8.0),

                  // 4. 底部偏好状态指示与恢复自动匹配动作
                  _buildFooter(context, scheme, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.20),
              width: 1.0,
            ),
          ),
          child: Icon(
            Symbols.lyrics_rounded,
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
                "歌词源偏好设置",
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "为当前播放歌曲指定特定平台或本地歌词源",
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 12.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: "关闭",
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.close_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context, ColorScheme scheme, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<LyricSourceTab>(
            segments: const [
              ButtonSegment<LyricSourceTab>(
                value: LyricSourceTab.online,
                label: Text("在线匹配歌词"),
                icon: Icon(Icons.cloud_outlined, size: 16),
              ),
              ButtonSegment<LyricSourceTab>(
                value: LyricSourceTab.local,
                label: Text("本地音频歌词"),
                icon: Icon(Icons.audio_file_outlined, size: 16),
              ),
            ],
            selected: {_currentTab},
            onSelectionChanged: (newSelection) {
              setState(() {
                _currentTab = newSelection.first;
              });
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (_currentTab == LyricSourceTab.online) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: "重新检索在线歌词",
              icon:
                  Icon(Icons.refresh_rounded, size: 18, color: scheme.primary),
              onPressed: _busy ? null : _reSearch,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineTabView(
      BuildContext context, ColorScheme scheme, bool isDark,
      {bool shrinkWrap = false}) {
    return FutureBuilder<List<SongSearchResult>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(
                  "正在检索在线歌词库...",
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 38,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  "未找到匹配的在线歌词",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "可尝试重新检索或使用本地歌词",
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _reSearch,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("重新检索"),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final result = results[i];
            final isSelected = _isResultSelected(result);
            return _LyricSourceCard(
              audio: widget.audio,
              searchResult: result,
              isSelected: isSelected,
              isBusy: _busy,
              onSelect: (r, lyric) => _applyOnlineLyric(r, lyric),
              lyricFuture: widget.onlineLyricBuilder?.call(result),
            );
          },
        );
      },
    );
  }

  Widget _buildLocalTabView(
      BuildContext context, ColorScheme scheme, bool isDark,
      {bool shrinkWrap = false}) {
    return FutureBuilder<Lrc?>(
      future: _localLyricFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(
                  "正在读取本地音频歌词...",
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        }

        final localLrc = snapshot.data;
        final hasLocalLyric = localLrc != null && localLrc.lines.isNotEmpty;
        final siblingLrcPath = LyricFileHelper.getLrcFilePath(widget.audio);
        final siblingLrcExists = File(siblingLrcPath).existsSync();

        final contentColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // 本地歌词状态卡片
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isLocalSelected
                      ? scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10)
                      : scheme.surfaceContainerHighest
                          .withValues(alpha: isDark ? 0.22 : 0.35),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _isLocalSelected
                        ? scheme.primary
                        : scheme.outlineVariant
                            .withValues(alpha: isDark ? 0.25 : 0.18),
                    width: _isLocalSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasLocalLyric
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.info_outline_rounded,
                              size: 20,
                              color: hasLocalLyric
                                  ? Colors.green
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hasLocalLyric ? "已检测到本地歌词" : "未检测到本地歌词",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (_isLocalSelected)
                          FilledButton.tonalIcon(
                            onPressed: null,
                            icon: const Icon(Icons.check_circle_rounded, size: 15),
                            label: const Text("当前默认",
                                style: TextStyle(fontSize: 12.5)),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              minimumSize: const Size(0, 36),
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _busy ? null : _applyLocalLyric,
                            icon: const Icon(Icons.check_rounded, size: 15),
                            label: const Text("设为本地歌词",
                                style: TextStyle(fontSize: 12.5)),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 来源明细
                    Text(
                      "同级外挂 .lrc 文件：${siblingLrcExists ? '存在' : '未检测到'}",
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.audio.isCueTrack)
                      Text(
                        "音频类型：CUE 关联分轨（优先匹配分轨同名 .lrc）",
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                        ),
                      ),
                    if (hasLocalLyric) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${localLrc.lines.length} 行歌词",
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "标准 LRC 格式",
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 歌词内容预览
              if (hasLocalLyric) ...[
                Text(
                  "歌词内容预览：",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: isDark ? 0.18 : 0.30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.outlineVariant
                          .withValues(alpha: isDark ? 0.20 : 0.14),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      localLrc.lines
                          .take(30)
                          .map((l) => l is LrcLine
                              ? l.content
                              : (l as SyncLyricLine).content)
                          .join("\n"),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    "提示：可将与音频文件同名的 .lrc 歌词文件放置在音频所在目录，或使用“音乐编辑”弹窗搜索并保存同级 .lrc 歌词。",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          );

        if (shrinkWrap) return contentColumn;
        return SingleChildScrollView(child: contentColumn);
      },
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme scheme, bool isDark) {
    final current = LYRIC_SOURCES[widget.audio.path];
    final statusText = switch (current?.source) {
      LyricSourceType.local => "当前偏好：指定使用本地歌词",
      LyricSourceType.qq => "当前偏好：绑定 QQ 音乐源",
      LyricSourceType.kugou => "当前偏好：绑定酷狗音乐源",
      LyricSourceType.netease => "当前偏好：绑定网易云音乐源",
      null =>
        "当前偏好：系统自动匹配（优先${AppSettings.instance.localLyricFirst ? '本地' : '在线'}）",
    };

    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          size: 14,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 12.0,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (current != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _busy ? null : _resetToAuto,
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text("恢复自动匹配", style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
          ),
        ],
      ],
    );
  }
}

class _LyricSourceCard extends StatefulWidget {
  const _LyricSourceCard({
    required this.audio,
    required this.searchResult,
    required this.isSelected,
    required this.isBusy,
    required this.onSelect,
    this.lyricFuture,
  });

  final Audio audio;
  final SongSearchResult searchResult;
  final bool isSelected;
  final bool isBusy;
  final void Function(SongSearchResult result, Lyric lyric) onSelect;
  final Future<Lyric?>? lyricFuture;

  @override
  State<_LyricSourceCard> createState() => _LyricSourceCardState();
}

class _LyricSourceCardState extends State<_LyricSourceCard> {
  late final Future<Lyric?> _lyricFuture = widget.lyricFuture ??
      getOnlineLyric(
        qqSongId: widget.searchResult.qqSongId,
        kugouSongHash: widget.searchResult.kugouSongHash,
        neteaseSongId: widget.searchResult.neteaseSongId,
      );

  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final (sourceName, brandColor) = switch (widget.searchResult.source) {
      ResultSource.qq => ("QQ音乐", const Color(0xFF10B981)),
      ResultSource.kugou => ("酷狗音乐", const Color(0xFF0C82FF)),
      ResultSource.netease => ("网易云音乐", const Color(0xFFEF4444)),
    };

    final isHighMatch = widget.searchResult.score >= 0.8;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10)
              : _isHovered
                  ? scheme.surfaceContainerHighest
                      .withValues(alpha: isDark ? 0.42 : 0.55)
                  : scheme.surfaceContainerHighest
                      .withValues(alpha: isDark ? 0.22 : 0.35),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: widget.isSelected
                ? scheme.primary
                : _isHovered
                    ? scheme.primary.withValues(alpha: 0.45)
                    : scheme.outlineVariant
                        .withValues(alpha: isDark ? 0.25 : 0.18),
            width: widget.isSelected ? 1.5 : 1.0,
          ),
        ),
        child: FutureBuilder<Lyric?>(
          future: _lyricFuture,
          builder: (context, snapshot) {
            final lyric = snapshot.data;
            final isLyricLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title & Artist & Album
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.searchResult.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (widget.searchResult.artists.trim().isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text(
                                "·",
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.0,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                widget.searchResult.artists,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Badges Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 平台微徽标
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: brandColor.withValues(
                                    alpha: isDark ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: brandColor.withValues(
                                      alpha: isDark ? 0.38 : 0.25),
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

                            // 匹配度微徽标
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isHighMatch
                                    ? Colors.green.withValues(
                                        alpha: isDark ? 0.20 : 0.12)
                                    : scheme.primary.withValues(
                                        alpha: isDark ? 0.18 : 0.09),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isHighMatch
                                      ? Colors.green.withValues(
                                          alpha: isDark ? 0.35 : 0.25)
                                      : scheme.primary.withValues(
                                          alpha: isDark ? 0.30 : 0.20),
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
                                      color: isDark
                                          ? Colors.greenAccent
                                          : Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    "${(widget.searchResult.score * 100).toStringAsFixed(0)}% 匹配",
                                    style: TextStyle(
                                      color: isHighMatch
                                          ? (isDark
                                              ? Colors.greenAccent
                                              : Colors.green.shade700)
                                          : scheme.primary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 歌词格式微徽标
                            if (lyric != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  lyric is Lrc ? "LRC" : "逐字",
                                  style: TextStyle(
                                    color: scheme.onSecondaryContainer,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 实时播放进度歌词预览
                      if (lyric != null && lyric.lines.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        StreamBuilder(
                          stream: PlayService
                              .existingInstance?.playbackService.positionStream,
                          builder: (context, positionSnapshot) {
                            final pos = positionSnapshot.data ?? 0;
                            final currLineIndex = math.max(
                              lyric.lines.lastIndexWhere(
                                (element) =>
                                    element.start.inMilliseconds <= pos * 1000,
                              ),
                              0,
                            );
                            final currLine = lyric.lines[currLineIndex];
                            final String content = currLine is LrcLine
                                ? currLine.content
                                : (currLine as SyncLyricLine).content;

                            return Row(
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 13,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "当前：$content",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 操作按钮 / 当前选中指示
                if (isLyricLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (lyric != null && lyric.lines.isNotEmpty)
                  widget.isSelected
                      ? FilledButton.tonalIcon(
                          onPressed: null,
                          icon: const Icon(Icons.check_circle_rounded, size: 15),
                          label: const Text("当前默认",
                              style: TextStyle(fontSize: 12.5)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: widget.isBusy
                              ? null
                              : () => widget.onSelect(
                                  widget.searchResult, lyric),
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: const Text("设为默认",
                              style: TextStyle(fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        )
                else
                  Text(
                    "暂无歌词",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
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
