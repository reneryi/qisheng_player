import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:path/path.dart' as path;

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  String _normalizePathKey(String input) =>
      input.replaceAll('/', '\\').toLowerCase();

  static String _formatPlaylistDuration(Iterable<Audio> audios) {
    var totalSeconds = 0;
    for (final a in audios) {
      totalSeconds += a.duration;
    }
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes 分钟';
  }

  Future<void> importM3u(BuildContext context) async {
    final picker = OpenFilePicker()
      ..title = "导入播放列表"
      ..filterSpecification = {
        "播放列表": "*.m3u;*.m3u8",
      };
    final selected = picker.getFile();
    if (selected == null) return;

    final m3uPath = selected.path;
    final m3uDir = path.dirname(m3uPath);
    final m3uName = path.basenameWithoutExtension(m3uPath).trim();
    final playlistName = m3uName.isEmpty ? "导入歌单" : m3uName;

    final pathToAudio = <String, Audio>{
      for (final audio in AudioLibrary.instance.audioCollection)
        _normalizePathKey(audio.path): audio
    };
    final matchedAudios = <Audio>[];
    final existed = <String>{};

    final lines = selected.readAsLinesSync();
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final resolvedPath =
          path.isAbsolute(line) ? line : path.join(m3uDir, line);
      final key = _normalizePathKey(path.normalize(resolvedPath));
      final audio = pathToAudio[key];
      if (audio == null) continue;
      if (existed.add(audio.path)) {
        matchedAudios.add(audio);
      }
    }

    if (matchedAudios.isEmpty) {
      showTextOnSnackBar("导入失败：未匹配到本地音乐库中的歌曲");
      return;
    }

    String finalName = playlistName;
    int suffix = 2;
    while (PLAYLISTS.any((item) => item.name == finalName)) {
      finalName = "$playlistName ($suffix)";
      suffix++;
    }

    setState(() {
      PLAYLISTS.add(Playlist(
        finalName,
        {for (final audio in matchedAudios) audio.path: audio},
      ));
    });
    scheduleSavePlaylists();
    showTextOnSnackBar("已导入歌单“$finalName”，共 ${matchedAudios.length} 首");
  }

  void newPlaylist(BuildContext context) async {
    final existingNames = PLAYLISTS.map((e) => e.name).toList();
    final name = await showModernDialog<String>(
      context: context,
      builder: (context) => _NewPlaylistDialog(existingNames: existingNames),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      PLAYLISTS.add(Playlist(name.trim(), {}));
    });
    scheduleSavePlaylists();
  }

  void openSmartMixDialog(BuildContext context) async {
    final created = await showModernDialog<Playlist>(
      context: context,
      builder: (context) => const _SmartPlaylistMixDialog(),
    );
    if (created == null || !mounted) return;
    setState(() {
      PLAYLISTS.add(created);
    });
    scheduleSavePlaylists();
    showTextOnSnackBar("已生成智能歌单“${created.name}”，共 ${created.audios.length} 首");
  }

  void editPlaylist(
    BuildContext context,
    Playlist playlist,
  ) async {
    final existingNames = PLAYLISTS.map((e) => e.name).toList();
    final name = await showModernDialog<String>(
      context: context,
      builder: (context) => _EditPlaylistDialog(
        initialName: playlist.name,
        existingNames: existingNames,
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      playlist.name = name.trim();
    });
    scheduleSavePlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return UniPage<Playlist>(
      pref: AppPreference.instance.playlistsPagePref,
      title: "歌单",
      subtitle: formatPlaylistCount(PLAYLISTS.length),
      contentList: PLAYLISTS,
      contentBuilder: (context, item, i, multiSelectController) {
        final playlist = PLAYLISTS[i];
        final surfaces = context.surfaces;
        final motion = context.motion;
        final rowRadius = BorderRadius.circular(surfaces.radiusMd);
        final durationStr = _formatPlaylistDuration(playlist.audios.values);
        final subtitleText = durationStr.isEmpty
            ? formatMusicCount(playlist.audios.length)
            : '${formatMusicCount(playlist.audios.length)} · $durationStr';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: AnimatedContainer(
            duration: motion.controlTransitionDuration,
            curve: motion.emphasized,
            decoration: BoxDecoration(
              color: surfaces.tileBackground,
              borderRadius: rowRadius,
              border: surfaces.tileBorderColor == Colors.transparent
                  ? null
                  : Border.all(color: surfaces.tileBorderColor, width: 0.5),
              boxShadow: surfaces.tileShadow,
            ),
            child: ListTile(
              leading: _PlaylistMosaicCover(
                playlist: playlist,
                size: 42,
              ),
              title: Text(
                playlist.name,
                softWrap: false,
                maxLines: 1,
              ),
              subtitle: Text(
                subtitleText,
                softWrap: false,
                maxLines: 1,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('play-playlist-${playlist.name}'),
                    tooltip: "播放歌单",
                    onPressed: () {
                      final audios = playlist.audios.values.toList();
                      if (audios.isEmpty) {
                        showTextOnSnackBar("歌单“${playlist.name}”为空，暂无歌曲可播放");
                        return;
                      }
                      PlayService.instance.playbackService.play(0, audios);
                      showTextOnSnackBar("开始播放歌单“${playlist.name}”");
                    },
                    icon: const Icon(Symbols.play_arrow_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ).copyWith(
                      overlayColor: WidgetStatePropertyAll(
                        scheme.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    tooltip: "编辑",
                    onPressed: () => editPlaylist(context, playlist),
                    icon: const Icon(Symbols.edit),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ).copyWith(
                      overlayColor: WidgetStatePropertyAll(
                        scheme.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    tooltip: "删除",
                    onPressed: () => setState(() {
                      PLAYLISTS.remove(playlist);
                      scheduleSavePlaylists();
                    }),
                    color: scheme.error,
                    icon: const Icon(Symbols.delete),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ).copyWith(
                      overlayColor: WidgetStatePropertyAll(
                        scheme.error.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: rowRadius,
              ),
              onTap: () => context.push(
                app_paths.PLAYLIST_DETAIL_PAGE,
                extra: playlist,
              ),
            ),
          ),
        );
      },
      primaryAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => openSmartMixDialog(context),
            icon: const Icon(Symbols.auto_awesome_rounded, size: 18),
            label: const Text("智能漫游"),
            style: const ButtonStyle(
              fixedSize: WidgetStatePropertyAll(Size.fromHeight(40)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => importM3u(context),
            icon: const Icon(Symbols.file_open),
            label: const Text("导入M3U"),
            style: const ButtonStyle(
              fixedSize: WidgetStatePropertyAll(Size.fromHeight(40)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => newPlaylist(context),
            icon: const Icon(Symbols.add),
            label: const Text("新建歌单"),
            style: const ButtonStyle(
              fixedSize: WidgetStatePropertyAll(Size.fromHeight(40)),
            ),
          ),
        ],
      ),
      enableShufflePlay: false,
      enableSortMethod: true,
      enableSortOrder: true,
      enableContentViewSwitch: true,
      sortMethods: [
        SortMethodDesc(
          icon: Symbols.title,
          name: "名称",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.name.localeCompareTo(b.name));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.name.localeCompareTo(a.name));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.music_note,
          name: "歌曲数量",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.audios.length.compareTo(b.audios.length));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.audios.length.compareTo(a.audios.length));
                break;
            }
          },
        ),
      ],
    );
  }
}

class _PlaylistMosaicCover extends StatelessWidget {
  const _PlaylistMosaicCover({
    required this.playlist,
    this.size = 42,
  });

  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final tracks = playlist.audios.values.take(4).toList(growable: false);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16),
          width: 0.8,
        ),
      ),
      child: tracks.isEmpty
          ? Icon(
              Symbols.queue_music_rounded,
              size: size * 0.52,
              color: scheme.primary,
            )
          : tracks.length < 4
              ? _SingleTrackCoverCell(audio: tracks.first, size: size)
              : Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SingleTrackCoverCell(
                              audio: tracks[0],
                              size: size / 2,
                            ),
                          ),
                          Expanded(
                            child: _SingleTrackCoverCell(
                              audio: tracks[1],
                              size: size / 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SingleTrackCoverCell(
                              audio: tracks[2],
                              size: size / 2,
                            ),
                          ),
                          Expanded(
                            child: _SingleTrackCoverCell(
                              audio: tracks[3],
                              size: size / 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SingleTrackCoverCell extends StatelessWidget {
  const _SingleTrackCoverCell({
    required this.audio,
    required this.size,
  });

  final Audio audio;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<ImageProvider?>(
      future: audio.cover,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        if (provider == null) {
          return Center(
            child: Icon(
              Symbols.music_note_rounded,
              size: (size * 0.48).clamp(10.0, 22.0),
              color: scheme.primary.withValues(alpha: 0.72),
            ),
          );
        }
        return Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Symbols.music_note_rounded,
              size: (size * 0.48).clamp(10.0, 22.0),
              color: scheme.primary.withValues(alpha: 0.72),
            ),
          ),
        );
      },
    );
  }
}

class _SmartMixSpec {
  const _SmartMixSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.audios,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<Audio> audios;
}

class _SmartPlaylistMixDialog extends StatelessWidget {
  const _SmartPlaylistMixDialog();

  List<_SmartMixSpec> _buildSpecs(ColorScheme scheme) {
    final all = List<Audio>.from(AudioLibrary.instance.audioCollection);
    final store = PlayCountStore.instance;

    // 1. 常听 Top 50
    final topPlayed = List<Audio>.from(all)
      ..sort((a, b) {
        final cmp = store.get(b).compareTo(store.get(a));
        if (cmp != 0) return cmp;
        return a.title.localeCompareTo(b.title);
      });
    final top50 = topPlayed.take(50).toList(growable: false);

    // 2. Hi-Res & 无损臻品馆
    final hiRes = all.where((a) {
      final sRate = a.sampleRate ?? 0;
      final ext = a.path.split('.').last.toLowerCase();
      final isLosslessExt =
          ext == 'flac' || ext == 'wav' || ext == 'ape' || ext == 'alac' || ext == 'dsf' || ext == 'dff';
      return sRate > 48000 || (isLosslessExt && (a.bitrate ?? 0) >= 900);
    }).toList(growable: false);

    // 3. 最近添加 100 首
    final recentAdded = List<Audio>.from(all)
      ..sort((a, b) => b.modified.compareTo(a.modified));
    final recent100 = recentAdded.take(100).toList(growable: false);

    // 4. 舒缓长曲漫游 (>= 4 分钟的沉浸慢听曲目)
    final immersiveFlow = all
        .where((a) => a.duration >= 240)
        .take(60)
        .toList(growable: false);

    // 5. 待完善元数据曲目
    final incompleteMeta = all.where((a) {
      final noAlbum = !a.hasKnownAlbum;
      final noArtist = !a.hasKnownArtist;
      return noAlbum || noArtist || a.duration <= 0;
    }).toList(growable: false);

    return [
      _SmartMixSpec(
        title: '常听 Top 50',
        subtitle: '依据本地播放频次自动汇聚的挚爱曲目',
        icon: Symbols.auto_awesome_rounded,
        accentColor: const Color(0xFFF59E0B),
        audios: top50,
      ),
      _SmartMixSpec(
        title: 'Hi-Res 臻品馆',
        subtitle: '高采样率 (>48kHz) 与高码率母带无损曲目合集',
        icon: Symbols.verified_rounded,
        accentColor: const Color(0xFFD97706),
        audios: hiRes,
      ),
      _SmartMixSpec(
        title: '最近入库 100 首',
        subtitle: '按文件修改时间倒序排列的新近收藏',
        icon: Symbols.schedule_rounded,
        accentColor: scheme.primary,
        audios: recent100,
      ),
      _SmartMixSpec(
        title: '沉浸慢听漫游',
        subtitle: '时长 4 分钟以上的舒展氛围与器乐叙事作品',
        icon: Symbols.dark_mode_rounded,
        accentColor: const Color(0xFF6366F1),
        audios: immersiveFlow,
      ),
      _SmartMixSpec(
        title: '待完善标签曲目',
        subtitle: '快速筛选缺失专辑名或艺术家信息的曲目以便整理',
        icon: Symbols.edit_note_rounded,
        accentColor: const Color(0xFF10B981),
        audios: incompleteMeta,
      ),
    ];
  }

  String _uniquePlaylistName(String base) {
    var candidate = base;
    var suffix = 2;
    while (PLAYLISTS.any((p) => p.name == candidate)) {
      candidate = '$base ($suffix)';
      suffix++;
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final specs = _buildSpecs(scheme);

    return ModernDialogFrame(
      maxWidth: 540,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Symbols.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '智能歌单与声学漫游',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '基于播放频次、声学规格与入库时间实时聚合，可一键畅听或存为歌单',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Symbols.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: specs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final spec = specs[index];
                final count = spec.audios.length;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.24 : 0.42,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: spec.accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          spec.icon,
                          color: spec.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    spec.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: spec.accentColor.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$count 首',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: spec.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spec.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '立即播放',
                        onPressed: count == 0
                            ? null
                            : () {
                                PlayService.instance.playbackService.play(
                                  0,
                                  spec.audios,
                                );
                                Navigator.pop(context);
                                showTextOnSnackBar(
                                  '正在播放“${spec.title}”（共 $count 首）',
                                );
                              },
                        icon: const Icon(Symbols.play_arrow_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: '保存为固定歌单',
                        onPressed: count == 0
                            ? null
                            : () {
                                final finalName = _uniquePlaylistName(
                                  spec.title,
                                );
                                final playlist = Playlist(
                                  finalName,
                                  {
                                    for (final audio in spec.audios)
                                      audio.path: audio,
                                  },
                                );
                                Navigator.pop(context, playlist);
                              },
                        icon: const Icon(Symbols.playlist_add_rounded, size: 20),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistFormDialog extends StatefulWidget {
  const _PlaylistFormDialog({
    this.initialName = '',
    this.existingNames = const [],
    this.isEdit = false,
  });

  final String initialName;
  final List<String> existingNames;
  final bool isEdit;

  @override
  State<_PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<_PlaylistFormDialog> {
  late final TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    if (widget.initialName.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = null;
      });
      return;
    }
    final isDuplicate = widget.existingNames.any(
      (name) => name == text && (!widget.isEdit || name != widget.initialName),
    );
    setState(() {
      _errorMessage = isDuplicate ? '歌单名称已存在' : null;
    });
  }

  bool get _canSubmit {
    final text = _controller.text.trim();
    if (text.isEmpty) return false;
    if (widget.isEdit && text == widget.initialName) return false;
    final isDuplicate = widget.existingNames.any(
      (name) => name == text && (!widget.isEdit || name != widget.initialName),
    );
    return !isDuplicate;
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return ModernDialogFrame(
      maxWidth: 420.0,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：精致图标徽标 + 标题与副标题 + 快速关闭
          Row(
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
                  widget.isEdit ? Symbols.edit_note_rounded : Symbols.playlist_add_rounded,
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
                      widget.isEdit ? "修改歌单" : "新建歌单",
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isEdit ? "为歌单指定一个更具辨识度的新名称" : "创建专属歌单，整理您的心仪音乐收藏",
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
          const SizedBox(height: 22.0),

          // 输入区域：半透明卡片圆角输入框 + 前缀图标 + 一键清空 + 实时重名校验
          Focus(
            onFocusChange: HotkeysHelper.onFocusChanges,
            child: TextField(
              autofocus: true,
              controller: _controller,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (_) => _validate(),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.25)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                hintText: "请输入歌单名称...",
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  fontSize: 13.5,
                ),
                prefixIcon: Icon(
                  Symbols.queue_music_rounded,
                  size: 20,
                  color: scheme.primary.withValues(alpha: 0.85),
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: "清空",
                        icon: const Icon(Symbols.clear_rounded, size: 16),
                        onPressed: () {
                          _controller.clear();
                          _validate();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: scheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22.0),

          // 底部操作栏：次级取消与主操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("取消"),
              ),
              const SizedBox(width: 10.0),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: _canSubmit ? _submit : null,
                icon: Icon(
                  widget.isEdit ? Symbols.check_rounded : Symbols.add_rounded,
                  size: 18,
                ),
                label: Text(widget.isEdit ? "保存" : "创建"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NewPlaylistDialog extends StatelessWidget {
  const NewPlaylistDialog({super.key, this.existingNames = const []});

  final List<String> existingNames;

  @override
  Widget build(BuildContext context) {
    return _PlaylistFormDialog(
      existingNames: existingNames,
      isEdit: false,
    );
  }
}

class EditPlaylistDialog extends StatelessWidget {
  const EditPlaylistDialog({
    super.key,
    this.initialName = '',
    this.existingNames = const [],
  });

  final String initialName;
  final List<String> existingNames;

  @override
  Widget build(BuildContext context) {
    return _PlaylistFormDialog(
      initialName: initialName,
      existingNames: existingNames,
      isEdit: true,
    );
  }
}

typedef _NewPlaylistDialog = NewPlaylistDialog;
typedef _EditPlaylistDialog = EditPlaylistDialog;
