import 'dart:io';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/build_index_state_view.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/library_reload_service.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:qisheng_player/app_paths.dart' as app_paths;

({String title, String subtitle}) parseFolderDisplay(String absolutePath) {
  final segments = absolutePath
      .split(RegExp(r'[\\/]+'))
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return (title: absolutePath, subtitle: '根目录');
  }
  if (segments.length == 1) {
    return (title: segments.first, subtitle: '根目录');
  }
  return (
    title: segments.last,
    subtitle: segments[segments.length - 2],
  );
}

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  Future<void> _openFolderManager({required bool allowFolderEdit}) async {
    await showModernDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FolderLibraryManagerDialog(
        allowFolderEdit: allowFolderEdit,
        initialFolders:
            AudioLibrary.instance.folders.map((e) => e.path).toList(),
        onIndexBuilt: () async {
          final status = await libraryReloadCoordinator.reload(
            afterReload:
                PlayService.instance.playbackService.reconcileLibraryReferences,
          );
          if (status != AudioLibraryLoadStatus.loaded) {
            showTextOnSnackBar("曲库索引加载失败，请重新扫描音乐文件夹");
            return;
          }
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentList = List<AudioFolder>.from(AudioLibrary.instance.folders);
    return UniPage<AudioFolder>(
      pref: AppPreference.instance.foldersPagePref,
      title: "文件夹",
      subtitle: formatFolderCount(contentList.length),
      contentList: contentList,
      contentRevision: AudioLibrary.revision.value,
      contentBuilder: (context, item, i, multiSelectController) =>
          _CompactAudioFolderTile(audioFolder: item),
      primaryAction: Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _openFolderManager(allowFolderEdit: true),
            icon: const Icon(Symbols.folder_managed),
            label: const Text("管理文件夹"),
          ),
          FilledButton.icon(
            onPressed: () => _openFolderManager(allowFolderEdit: false),
            icon: const Icon(Symbols.scan),
            label: const Text("扫描音乐库"),
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
          name: "路径",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.path.localeCompareTo(b.path));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.path.localeCompareTo(a.path));
                break;
            }
          },
        ),
        SortMethodDesc(
          icon: Symbols.edit,
          name: "修改日期",
          method: (list, order) {
            switch (order) {
              case SortOrder.ascending:
                list.sort((a, b) => a.modified.compareTo(b.modified));
                break;
              case SortOrder.descending:
                list.sort((a, b) => b.modified.compareTo(a.modified));
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

class _FolderLibraryManagerDialog extends StatefulWidget {
  const _FolderLibraryManagerDialog({
    required this.initialFolders,
    required this.allowFolderEdit,
    required this.onIndexBuilt,
  });

  final List<String> initialFolders;
  final bool allowFolderEdit;
  final Future<void> Function() onIndexBuilt;

  @override
  State<_FolderLibraryManagerDialog> createState() =>
      _FolderLibraryManagerDialogState();
}

class _FolderLibraryManagerDialogState
    extends State<_FolderLibraryManagerDialog> {
  late final List<String> folders = List<String>.from(widget.initialFolders);
  final applicationSupportDirectory = getAppDataDir();
  bool editing = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return ModernDialogFrame(
      maxWidth: 540.0,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: SizedBox(
        height: 460.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标徽标 + 标题与副标题 + 关闭按钮
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
                    widget.allowFolderEdit
                        ? Symbols.folder_managed_rounded
                        : Symbols.scan_rounded,
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
                        widget.allowFolderEdit ? "管理文件夹" : "扫描音乐库",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.allowFolderEdit
                            ? "选择并维护本地音乐文件夹，自动构建歌曲索引"
                            : "重新扫描并更新选定文件夹中的音频元数据",
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (editing)
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
            const SizedBox(height: 18.0),

            // 主体区域：编辑列表态或扫描构建态
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: editing
                    ? (folders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Symbols.folder_off_rounded,
                                  size: 44,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.35),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "尚未添加任何音乐文件夹",
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "点击左下方“添加文件夹”将本地歌曲纳入曲库",
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: folders.length,
                            separatorBuilder: (context, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, i) => Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.22)
                                    : scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                                  width: 1.0,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.folder_rounded,
                                    size: 20,
                                    color: scheme.primary
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      folders[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (widget.allowFolderEdit)
                                    IconButton(
                                      tooltip: "移除此文件夹",
                                      color: scheme.error,
                                      iconSize: 18,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() {
                                          folders.removeAt(i);
                                        });
                                      },
                                      icon: const Icon(
                                        Symbols.delete_outline_rounded,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ))
                    : FutureBuilder<Directory>(
                        future: applicationSupportDirectory,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: Text("无法获取应用数据目录。"),
                            );
                          }

                          return Center(
                            child: BuildIndexStateView(
                              indexPath: snapshot.data!,
                              folders: folders,
                              whenIndexBuilt: () {
                                Navigator.pop(context);
                                widget.onIndexBuilt();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 18.0),

            // 底部操作栏
            Row(
              children: [
                if (widget.allowFolderEdit && editing)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () async {
                      final dirPicker = DirectoryPicker();
                      dirPicker.title = "选择文件夹";

                      final dir = dirPicker.getDirectory();
                      if (dir == null) return;
                      if (folders.contains(dir.path)) {
                        showTextOnSnackBar("该文件夹已添加");
                        return;
                      }
                      setState(() {
                        folders.add(dir.path);
                      });
                    },
                    icon: const Icon(Symbols.add_rounded, size: 18),
                    label: const Text("添加文件夹"),
                  ),
                const Spacer(),
                if (editing) ...[
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("取消"),
                  ),
                  const SizedBox(width: 8.0),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: folders.isEmpty
                        ? null
                        : () {
                            setState(() {
                              editing = false;
                            });
                          },
                    icon: Icon(
                      widget.allowFolderEdit
                          ? Symbols.sync_saved_locally_rounded
                          : Symbols.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(widget.allowFolderEdit ? "保存并扫描" : "开始扫描"),
                  ),
                ],
              ],
            )
          ],
        ),
      ),
    );
  }
}

class AudioFolderTile extends StatefulWidget {
  final AudioFolder audioFolder;
  const AudioFolderTile({
    super.key,
    required this.audioFolder,
  });

  @override
  State<AudioFolderTile> createState() => _AudioFolderTileState();
}

class _AudioFolderTileState extends State<AudioFolderTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final surfaces = context.surfaces;
    final display = parseFolderDisplay(widget.audioFolder.path);
    final modified = DateTime.fromMillisecondsSinceEpoch(
      widget.audioFolder.modified * 1000,
    );
    final isDark = scheme.brightness == Brightness.dark;
    final rowRadius = BorderRadius.circular(surfaces.radiusLg);

    final targetBgColor = _isHovered
        ? surfaces.tileHoverBackground
        : surfaces.tileBackground;
    final targetBorderColor = _isHovered
        ? surfaces.tileHoverBorderColor
        : surfaces.tileBorderColor;

    final decoration = BoxDecoration(
      color: targetBgColor,
      borderRadius: rowRadius,
      border: targetBorderColor == Colors.transparent
          ? null
          : Border.all(color: targetBorderColor, width: 0.5),
      boxShadow: surfaces.tileShadow,
    );

    return Semantics(
      label: widget.audioFolder.path,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: AnimatedContainer(
          duration: motion.controlTransitionDuration,
          curve: motion.emphasized,
          decoration: decoration,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              enableFeedback: false,
              borderRadius: rowRadius,
              onHover: (hovered) => setState(() => _isHovered = hovered),
              onTap: () => context.push(
                app_paths.FOLDER_DETAIL_PAGE,
                extra: widget.audioFolder,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        color: scheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            display.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.64),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '更新于 ${modified.toLocal()} · ${formatSongCount(widget.audioFolder.audios.length)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.48),
                              fontSize: 11,
                            ),
                          ),
                        ],
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
  }
}

class _CompactAudioFolderTile extends StatefulWidget {
  const _CompactAudioFolderTile({
    required this.audioFolder,
  });

  final AudioFolder audioFolder;

  @override
  State<_CompactAudioFolderTile> createState() =>
      _CompactAudioFolderTileState();
}

class _CompactAudioFolderTileState extends State<_CompactAudioFolderTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final surfaces = context.surfaces;
    final display = parseFolderDisplay(widget.audioFolder.path);
    final isDark = scheme.brightness == Brightness.dark;
    final rowRadius = BorderRadius.circular(surfaces.radiusMd);

    final targetBgColor = _isHovered
        ? surfaces.tileHoverBackground
        : surfaces.tileBackground;
    final targetBorderColor = _isHovered
        ? surfaces.tileHoverBorderColor
        : surfaces.tileBorderColor;

    final decoration = BoxDecoration(
      color: targetBgColor,
      borderRadius: rowRadius,
      border: targetBorderColor == Colors.transparent
          ? null
          : Border.all(color: targetBorderColor, width: 0.5),
      boxShadow: surfaces.tileShadow,
    );

    return Semantics(
      label: widget.audioFolder.path,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: AnimatedContainer(
          duration: motion.controlTransitionDuration,
          curve: motion.emphasized,
          decoration: decoration,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              enableFeedback: false,
              borderRadius: rowRadius,
              onHover: (hovered) => setState(() => _isHovered = hovered),
              onTap: () => context.push(
                app_paths.FOLDER_DETAIL_PAGE,
                extra: widget.audioFolder,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            display.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.64),
                              fontSize: 12,
                              height: 1.1,
                            ),
                          ),
                        ],
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
  }
}
