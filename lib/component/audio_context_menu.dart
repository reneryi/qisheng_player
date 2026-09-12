import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/animated_menu_content.dart';
import 'package:qisheng_player/component/audio_edit_dialog.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/page/playlists_page.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/utils.dart' as rust_utils;
import 'package:qisheng_player/utils.dart';

/// 全局单曲上下文菜单状态管理器。
///
/// 确保应用内任何时刻只保留最新一次操作触发的菜单（例如右键点击或点击“更多”按钮），
/// 新菜单弹出时自动关闭前一状态的菜单，避免重叠或同时出现多个菜单。
class AudioContextMenuManager {
  static MenuController? _activeController;

  /// 当前展开的菜单控制器
  static MenuController? get activeController => _activeController;

  /// 当前是否有菜单处于展开状态
  static bool get hasActive =>
      _activeController != null && _activeController!.isOpen;

  /// 注册新打开的菜单控制器。若先前已有其他菜单展开，立即将其关闭
  static void registerOpened(MenuController controller) {
    if (_activeController != null && _activeController != controller) {
      if (_activeController!.isOpen) {
        _activeController!.close();
      }
    }
    _activeController = controller;
  }

  /// 主动关闭当前处于展开状态的菜单
  static void closeActive({MenuController? except}) {
    if (_activeController != null && _activeController != except) {
      if (_activeController!.isOpen) {
        _activeController!.close();
      }
      _activeController = null;
    }
  }

  /// 注销已关闭的菜单控制器
  static void clear(MenuController controller) {
    if (_activeController == controller) {
      _activeController = null;
    }
  }
}

/// 单曲右键上下文菜单（1.4 统一组件）。
///
/// 菜单项：
/// - 播放 / 下一首播放 / 追加到队列
/// - 添加到歌单（新建 / 现有）
/// - 跳转歌手 / 专辑
/// - 定位到本地文件（Explorer 选中）
/// - 匹配歌词 / 音乐编辑（在线匹配）
/// - 详细信息
class AudioContextMenu extends StatefulWidget {
  const AudioContextMenu({
    super.key,
    required this.audio,
    required this.builder,
    this.controller,
    this.playlist,
    this.audioIndex,
    this.onEdit,
  });

  final Audio audio;

  /// 触发区域构建器（与 [MenuAnchor.builder] 同构，可通过 controller 主动打开菜单）。
  final MenuAnchorChildBuilder builder;

  /// 可选的外部 MenuController，为空时内部自动维护。
  final MenuController? controller;

  /// 播放上下文：提供后可「按列表索引播放」；为空时播放单曲。
  final List<Audio>? playlist;
  final int? audioIndex;
  final VoidCallback? onEdit;

  @override
  State<AudioContextMenu> createState() => _AudioContextMenuState();
}

class _AudioContextMenuState extends State<AudioContextMenu> {
  late final MenuController _internalController = MenuController();

  MenuController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void dispose() {
    AudioContextMenuManager.clear(_effectiveController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _effectiveController,
      consumeOutsideTap: true,
      onOpen: () {
        AudioContextMenuManager.registerOpened(_effectiveController);
      },
      onClose: () {
        AudioContextMenuManager.clear(_effectiveController);
      },
      menuChildren: animatedMenuChildren(
        context,
        buildAudioContextMenuChildren(
          context,
          audio: widget.audio,
          playlist: widget.playlist,
          audioIndex: widget.audioIndex,
          onEdit: widget.onEdit,
        ),
      ),
      builder: widget.builder,
    );
  }
}

/// 构建统一的单曲右键菜单项列表，供 [AudioContextMenu] 及其他自定义 MenuAnchor 复用。
/// 注意：播放服务在回调内惰性获取，避免构建期实例化（测试环境无 BASS 运行时）。
List<Widget> buildAudioContextMenuChildren(
  BuildContext context, {
  required Audio audio,
  List<Audio>? playlist,
  int? audioIndex,
  VoidCallback? onEdit,
}) {
  return [
    MenuItemButton(
      onPressed: () {
        final playback = PlayService.instance.playbackService;
        final list = playlist ?? [audio];
        final index = playlist != null &&
                audioIndex != null &&
                audioIndex >= 0 &&
                audioIndex < list.length
            ? audioIndex
            : list.indexOf(audio);
        playback.play(index < 0 ? 0 : index, list);
      },
      leadingIcon: const Icon(Symbols.play_arrow),
      child: const Text("播放"),
    ),
    MenuItemButton(
      onPressed: () {
        PlayService.instance.playbackService.addToNext(audio);
      },
      leadingIcon: const Icon(Symbols.plus_one),
      child: const Text("下一首播放"),
    ),
    MenuItemButton(
      onPressed: () {
        PlayService.instance.playbackService.addToQueue(audio);
        showTextOnSnackBar("已追加「${audio.title}」到队列末尾");
      },
      leadingIcon: const Icon(Symbols.playlist_add),
      child: const Text("追加到队列"),
    ),
    SubmenuButton(
      menuChildren: animatedMenuChildren(
        context,
        [
          MenuItemButton(
            onPressed: () async {
              final existingNames = PLAYLISTS.map((e) => e.name).toList();
              final name = await showModernDialog<String>(
                context: context,
                builder: (context) =>
                    NewPlaylistDialog(existingNames: existingNames),
              );

              final trimmed = name?.trim();
              if (trimmed == null || trimmed.isEmpty) return;
              if (PLAYLISTS.any((item) => item.name == trimmed)) {
                showTextOnSnackBar("歌单“$trimmed”已存在");
                return;
              }

              final targetPlaylist = Playlist(trimmed, {});
              targetPlaylist.addAudio(audio);
              PLAYLISTS.add(targetPlaylist);
              scheduleSavePlaylists();
              showTextOnSnackBar("已创建歌单“$trimmed”并添加当前歌曲");
            },
            leadingIcon: const Icon(Symbols.add),
            child: const Text("新建歌单并添加"),
          ),
          if (PLAYLISTS.isEmpty)
            const MenuItemButton(
              onPressed: null,
              child: Text("暂无歌单"),
            )
          else
            ...List.generate(
              PLAYLISTS.length,
              (i) => MenuItemButton(
                onPressed: () {
                  final added = PLAYLISTS[i].addAudio(audio);
                  if (!added) {
                    showTextOnSnackBar("歌曲“${audio.title}”已在歌单中");
                    return;
                  }

                  showTextOnSnackBar(
                    "成功将“${audio.title}”添加到歌单“${PLAYLISTS[i].name}”",
                  );
                },
                leadingIcon: const Icon(Symbols.queue_music),
                child: Text(PLAYLISTS[i].name),
              ),
            ),
        ],
      ),
      child: const Text("添加到歌单"),
    ),
    if (audio.splitedArtists.isNotEmpty)
      SubmenuButton(
        menuChildren: animatedMenuChildren(
          context,
          List.generate(
            audio.splitedArtists.length,
            (i) {
              final artistName = audio.splitedArtists[i];
              return MenuItemButton(
                onPressed: () {
                  final artist =
                      AudioLibrary.instance.artistCollection[artistName];
                  if (artist == null) return;
                  context.push(app_paths.ARTIST_DETAIL_PAGE, extra: artist);
                },
                leadingIcon: const Icon(Symbols.artist),
                child: Text(artistName),
              );
            },
          ),
        ),
        child: const Text("艺术家"),
      ),
    MenuItemButton(
      onPressed: () {
        final album = AudioLibrary.instance.albumCollection[audio.album];
        if (album == null) return;
        context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album);
      },
      leadingIcon: const Icon(Symbols.album),
      child: Text(audio.album),
    ),
    MenuItemButton(
      onPressed: () async {
        final opened = await rust_utils.showInExplorer(path: audio.mediaPath);
        if (!opened) {
          showTextOnSnackBar("无法在资源管理器中定位：${audio.mediaPath}");
        }
      },
      leadingIcon: const Icon(Symbols.folder_open),
      child: const Text("定位到本地文件"),
    ),
    MenuItemButton(
      onPressed: onEdit ??
          () => showModernDialog(
                context: context,
                builder: (context) => AudioEditDialog(audio: audio),
              ),
      leadingIcon: const Icon(Symbols.lyrics),
      child: const Text("匹配歌词 / 音乐编辑"),
    ),
    MenuItemButton(
      onPressed: () {
        context.push(app_paths.AUDIO_DETAIL_PAGE, extra: audio);
      },
      leadingIcon: const Icon(Symbols.info),
      child: const Text("详细信息"),
    ),
  ];
}
