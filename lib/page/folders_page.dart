import 'dart:io';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/build_index_state_view.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/lyric/lyric_source.dart';
import 'package:coriander_player/page/uni_page.dart';
import 'package:coriander_player/utils.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:coriander_player/app_paths.dart' as app_paths;

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  Future<void> _openFolderManager({required bool allowFolderEdit}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FolderLibraryManagerDialog(
        allowFolderEdit: allowFolderEdit,
        initialFolders: AudioLibrary.instance.folders.map((e) => e.path).toList(),
        onIndexBuilt: () async {
          await Future.wait([
            AudioLibrary.initFromIndex(),
            readPlaylists(),
            readLyricSources(),
          ]);
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
      subtitle: "${contentList.length} 个文件夹",
      contentList: contentList,
      contentBuilder: (context, item, i, multiSelectController) =>
          AudioFolderTile(audioFolder: item),
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
              case SortOrder.decending:
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
              case SortOrder.decending:
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
              case SortOrder.decending:
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

class _FolderLibraryManagerDialogState extends State<_FolderLibraryManagerDialog> {
  late final List<String> folders = List<String>.from(widget.initialFolders);
  final applicationSupportDirectory = getAppDataDir();
  bool editing = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        height: 450.0,
        width: 500.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  widget.allowFolderEdit ? "管理文件夹" : "扫描音乐库",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: editing
                      ? ListView.builder(
                          itemCount: folders.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(folders[i], maxLines: 1),
                            trailing: widget.allowFolderEdit
                                ? IconButton(
                                    tooltip: "移除",
                                    color: scheme.error,
                                    onPressed: () {
                                      setState(() {
                                        folders.removeAt(i);
                                      });
                                    },
                                    icon: const Icon(Symbols.delete),
                                  )
                                : null,
                          ),
                        )
                      : FutureBuilder<Directory>(
                          future: applicationSupportDirectory,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: Text("Fail to get app data dir."),
                              );
                            }

                            return Center(
                              child: BuildIndexStateView(
                                indexPath: snapshot.data!,
                                folders: folders,
                                whenIndexBuilt: () async {
                                  await widget.onIndexBuilt();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.allowFolderEdit)
                    TextButton(
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
                      child: const Text("添加"),
                    ),
                  const SizedBox(width: 8.0),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("取消"),
                  ),
                  const SizedBox(width: 8.0),
                  TextButton(
                    onPressed: folders.isEmpty
                        ? null
                        : () {
                            setState(() {
                              editing = false;
                            });
                          },
                    child: Text(widget.allowFolderEdit ? "保存并扫描" : "开始扫描"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class AudioFolderTile extends StatelessWidget {
  final AudioFolder audioFolder;
  const AudioFolderTile({
    super.key,
    required this.audioFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: audioFolder.path,
      child: ListTile(
        title: Text(
          audioFolder.path,
          softWrap: false,
          maxLines: 1,
        ),
        subtitle: Text(
          "修改日期：${DateTime.fromMillisecondsSinceEpoch(audioFolder.modified * 1000).toString()}",
          softWrap: false,
          maxLines: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        onTap: () => context.push(
          app_paths.FOLDER_DETAIL_PAGE,
          extra: audioFolder,
        ),
      ),
    );
  }
}
