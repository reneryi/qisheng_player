import 'dart:io';

import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/ui/app_surface.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ShufflePlay<T> extends StatelessWidget {
  final List<T> contentList;
  const ShufflePlay({super.key, required this.contentList});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => PlayService.instance.playbackService.shuffleAndPlay(
        contentList as List<Audio>,
      ),
      icon: const Icon(Symbols.shuffle),
      label: const Text("随机播放"),
      style: const ButtonStyle(
        enableFeedback: false,
        fixedSize: WidgetStatePropertyAll(Size.fromHeight(48)),
      ),
    );
  }
}

class SortMethodComboBox<T> extends StatelessWidget {
  final List<T> contentList;
  final List<SortMethodDesc<T>> sortMethods;
  final SortMethodDesc<T> currSortMethod;
  final void Function(SortMethodDesc<T> sortMethod) setSortMethod;
  const SortMethodComboBox({
    super.key,
    required this.sortMethods,
    required this.contentList,
    required this.currSortMethod,
    required this.setSortMethod,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      menuChildren: List.generate(
        sortMethods.length,
        (i) => MenuItemButton(
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
          ),
          leadingIcon: Icon(sortMethods[i].icon),
          child: Text(sortMethods[i].name),
          onPressed: () => setSortMethod(sortMethods[i]),
        ),
      ),
      builder: (context, menuController, _) {
        return SizedBox(
          height: 48.0,
          child: AppSurface(
            variant: AppSurfaceVariant.inset,
            radius: 24,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                enableFeedback: false,
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  if (menuController.isOpen) {
                    menuController.close();
                  } else {
                    menuController.open();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.sort,
                        size: 24,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        currSortMethod.name,
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 4.0),
                      Icon(
                        Symbols.arrow_drop_down,
                        size: 24,
                        color: scheme.onSecondaryContainer,
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
  }
}

class SortOrderSwitch<T> extends StatelessWidget {
  final SortOrder sortOrder;
  final void Function(SortOrder order) setSortOrder;
  const SortOrderSwitch(
      {super.key, required this.sortOrder, required this.setSortOrder});

  @override
  Widget build(BuildContext context) {
    var isAscending = sortOrder == SortOrder.ascending;
    return CpIconButton(
      variant: CpButtonVariant.immersive,
      tooltip: "切换排序顺序：当前为${isAscending ? "升序" : "降序"}",
      onPressed: () => setSortOrder(
        isAscending ? SortOrder.descending : SortOrder.ascending,
      ),
      icon: Icon(isAscending ? Symbols.arrow_upward : Symbols.arrow_downward),
    );
  }
}

class ContentViewSwitch<T> extends StatelessWidget {
  final ContentView contentView;
  final void Function(ContentView contentView) setContentView;
  const ContentViewSwitch(
      {super.key, required this.contentView, required this.setContentView});

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip, nextView) = switch (contentView) {
      ContentView.list => (Symbols.list, "列表视图", ContentView.table),
      ContentView.table => (Symbols.table, "表格视图", ContentView.grid),
      ContentView.grid => (Symbols.grid_view, "网格视图", ContentView.list),
    };

    return CpIconButton(
      variant: CpButtonVariant.immersive,
      tooltip: "切换页面视图：当前为$tooltip",
      onPressed: () => setContentView(nextView),
      icon: Icon(icon),
    );
  }
}

class AddAllToPlaylist extends StatelessWidget {
  const AddAllToPlaylist({super.key, required this.multiSelectController});

  final MultiSelectController<Audio> multiSelectController;

  Future<String?> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("创建歌单"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "歌单名称",
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: const Text("创建"),
          ),
        ],
      ),
    );
  }

  Future<Playlist?> _pickTargetPlaylist(BuildContext context) async {
    if (PLAYLISTS.isEmpty) {
      final createdName = await _showCreatePlaylistDialog(context);
      final trimmed = createdName?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      if (PLAYLISTS.any((item) => item.name == trimmed)) {
        showTextOnSnackBar('歌单“$trimmed”已存在');
        return null;
      }
      final playlist = Playlist(trimmed, {});
      PLAYLISTS.add(playlist);
      scheduleSavePlaylists();
      return playlist;
    }

    return showDialog<Playlist>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("选择歌单"),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: PLAYLISTS.length,
            itemBuilder: (context, index) {
              final playlist = PLAYLISTS[index];
              return ListTile(
                leading: const Icon(Symbols.queue_music),
                title: Text(playlist.name),
                onTap: () => Navigator.pop(context, playlist),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton.tonalIcon(
            onPressed: () async {
              final createdName = await _showCreatePlaylistDialog(context);
              final trimmed = createdName?.trim();
              if (trimmed == null || trimmed.isEmpty) return;
              if (PLAYLISTS.any((item) => item.name == trimmed)) {
                showTextOnSnackBar('歌单“$trimmed”已存在');
                return;
              }
              final playlist = Playlist(trimmed, {});
              PLAYLISTS.add(playlist);
              scheduleSavePlaylists();
              if (context.mounted) {
                Navigator.pop(context, playlist);
              }
            },
            icon: const Icon(Symbols.add),
            label: const Text("创建歌单"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddToPlaylist(BuildContext context) async {
    if (multiSelectController.selected.isEmpty) {
      showTextOnSnackBar("请先选择歌曲");
      return;
    }

    final targetPlaylist = await _pickTargetPlaylist(context);
    if (targetPlaylist == null) return;

    int addedCount = 0;
    int existedCount = 0;
    for (final audio in multiSelectController.selected) {
      if (targetPlaylist.addAudio(audio)) {
        addedCount++;
      } else {
        existedCount++;
      }
    }

    if (addedCount == 0 && existedCount > 0) {
      showTextOnSnackBar("所选歌曲已存在于歌单“${targetPlaylist.name}”");
      return;
    }
    if (existedCount > 0) {
      showTextOnSnackBar(
        "已添加 $addedCount 首到“${targetPlaylist.name}”，$existedCount 首已存在",
      );
      return;
    }
    showTextOnSnackBar("成功将 $addedCount 首添加到歌单“${targetPlaylist.name}”");
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _handleAddToPlaylist(context),
      icon: const Icon(Symbols.add),
      label: const Text("添加到歌单"),
      style: const ButtonStyle(
        fixedSize: WidgetStatePropertyAll(Size.fromHeight(40)),
      ),
    );
  }
}

enum _DeleteSelectedMode {
  removeOnly,
  removeAndDeleteSource,
}

class DeleteSelectedAudios extends StatelessWidget {
  const DeleteSelectedAudios({
    super.key,
    required this.multiSelectController,
    required this.contentList,
  });

  final MultiSelectController<Audio> multiSelectController;
  final List<Audio> contentList;

  Future<_DeleteSelectedMode?> _confirmDelete(
    BuildContext context,
    int count,
  ) {
    return showDialog<_DeleteSelectedMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("删除选中歌曲"),
        content: Text(
          "已选择 $count 首歌曲。\n"
          "删除源文件：会删除磁盘上的音乐文件。\n"
          "仅从播放器移除：不会删除磁盘文件。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton.tonal(
            onPressed: () =>
                Navigator.pop(context, _DeleteSelectedMode.removeOnly),
            child: const Text("仅从播放器移除"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _DeleteSelectedMode.removeAndDeleteSource,
            ),
            child: const Text("删除源文件"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final selected = List<Audio>.from(multiSelectController.selected);
    if (selected.isEmpty) {
      showTextOnSnackBar("请先选择歌曲");
      return;
    }

    final mode = await _confirmDelete(context, selected.length);
    if (mode == null) return;

    final pathsToRemove = <String>{};
    final failedMediaPaths = <String>{};

    if (mode == _DeleteSelectedMode.removeAndDeleteSource) {
      final mediaPaths = selected.map((audio) => audio.mediaPath).toSet();
      final deletedMediaPaths = <String>{};
      for (final mediaPath in mediaPaths) {
        try {
          final file = File(mediaPath);
          if (file.existsSync()) {
            await file.delete();
          }
          deletedMediaPaths.add(mediaPath);
        } catch (_) {
          failedMediaPaths.add(mediaPath);
        }
      }

      if (deletedMediaPaths.isNotEmpty) {
        for (final audio in AudioLibrary.instance.audioCollection) {
          if (deletedMediaPaths.contains(audio.mediaPath)) {
            pathsToRemove.add(audio.path);
          }
        }
      }
    } else {
      pathsToRemove.addAll(selected.map((audio) => audio.path));
    }

    if (pathsToRemove.isEmpty) {
      if (failedMediaPaths.isNotEmpty) {
        showTextOnSnackBar("删除失败，${failedMediaPaths.length} 个源文件无法删除");
      }
      return;
    }

    AudioLibrary.instance.removeAudiosByPaths(pathsToRemove);
    for (final path in pathsToRemove) {
      OnlineCoverStore.instance.removeByPath(path);
      removeAudioFromAllPlaylistsByPath(path);
      PlayService.instance.playbackService.removeAudioFromPlaylistByPath(path);
    }
    contentList.removeWhere((audio) => pathsToRemove.contains(audio.path));

    multiSelectController.clear();
    multiSelectController.useMultiSelectView(false);

    final modeText = mode == _DeleteSelectedMode.removeAndDeleteSource
        ? "已删除源文件并移除"
        : "已从播放器移除";
    if (failedMediaPaths.isNotEmpty) {
      showTextOnSnackBar(
        "$modeText ${pathsToRemove.length} 首，${failedMediaPaths.length} 个源文件删除失败",
      );
      return;
    }
    showTextOnSnackBar("$modeText ${pathsToRemove.length} 首歌曲");
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      enableFeedback: false,
      tooltip: "删除选中歌曲",
      onPressed: () => _deleteSelected(context),
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.error),
        foregroundColor: WidgetStatePropertyAll(scheme.onError),
      ),
      icon: const Icon(Symbols.delete),
    );
  }
}

class MultiSelectSelectOrClearAll<T> extends StatelessWidget {
  final MultiSelectController<T> multiSelectController;
  final List<T> contentList;

  const MultiSelectSelectOrClearAll(
      {super.key,
      required this.multiSelectController,
      required this.contentList});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: multiSelectController,
      builder: (context, _) => IconButton.filledTonal(
        enableFeedback: false,
        tooltip: multiSelectController.selected.isEmpty ? "全选" : "取消全选",
        onPressed: () {
          if (multiSelectController.selected.isEmpty) {
            multiSelectController.selectAll(contentList);
          } else {
            multiSelectController.clear();
          }
        },
        icon: Icon(
          multiSelectController.selected.isEmpty
              ? Symbols.select_all
              : Symbols.clear_all,
        ),
      ),
    );
  }
}

class MultiSelectExit<T> extends StatelessWidget {
  final MultiSelectController<T> multiSelectController;

  const MultiSelectExit({super.key, required this.multiSelectController});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      enableFeedback: false,
      tooltip: "退出多选视图",
      onPressed: () {
        multiSelectController.useMultiSelectView(false);
        multiSelectController.clear();
      },
      icon: const Icon(Symbols.cancel),
    );
  }
}

/// 极简锐利卡片风格下的主页 Header 大 Banner 组件（类似 Steam 个人主页/游戏库头部）
class SharpCardDashboardHeader extends StatelessWidget {
  final int totalAudiosCount;
  final String title;

  const SharpCardDashboardHeader({
    super.key,
    required this.totalAudiosCount,
    this.title = "QiSheng Music",
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191C) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部栏：Logo 图标、应用/媒体库名称、状态点
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  Symbols.graphic_eq,
                  color: scheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // 绿色在线/活跃指示点
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "音乐库就绪",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Symbols.graphic_eq,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          // 中间特粗体大字号数值展示（模仿 Steam 游戏时长与库存）
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$totalAudiosCount",
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "音频曲目",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "FLAC / HR",
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "无损音质引擎",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 极简锐利卡片风格下的彩色 Pill 胶囊徽章（用于列表项右侧高亮显示格式/时长）
class SharpCardPillChip extends StatelessWidget {
  final String label;
  final String? subLabel;
  final Color? color;
  final IconData? icon;

  const SharpCardPillChip({
    super.key,
    required this.label,
    this.subLabel,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pillColor = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: pillColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: pillColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pillColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(width: 4),
            Text(
              subLabel!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
