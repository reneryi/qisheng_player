import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/library/audio_library.dart';
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
import 'package:path/path.dart' as path;

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  String _normalizePathKey(String input) =>
      input.replaceAll('/', '\\').toLowerCase();

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
        final surfaces = context.surfaces;
        final motion = context.motion;
        final rowRadius = BorderRadius.circular(surfaces.radiusMd);
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
              title: Text(
                PLAYLISTS[i].name,
                softWrap: false,
                maxLines: 1,
              ),
              subtitle: Text(
                formatMusicCount(PLAYLISTS[i].audios.length),
                softWrap: false,
                maxLines: 1,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "编辑",
                    onPressed: () => editPlaylist(context, PLAYLISTS[i]),
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
                      PLAYLISTS.remove(PLAYLISTS[i]);
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
                extra: PLAYLISTS[i],
              ),
            ),
          ),
        );
      },
      primaryAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isEdit ? "为歌单指定一个更具辨识度的新名称" : "创建专属歌单，整理您的心仪音乐收藏",
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 12.0,
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
