import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/cp/cp_components.dart';
import 'package:coriander_player/component/scroll_aware_future_builder.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/audio_metadata_override_store.dart';
import 'package:coriander_player/library/online_cover_store.dart';
import 'package:coriander_player/library/play_count_store.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/lyric/lyric_source.dart';
import 'package:coriander_player/music_matcher.dart';
import 'package:coriander_player/page/uni_page.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/rust/api/tag_reader.dart' as tag_writer;
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 展示 `playlist[audioIndex]` 对应的歌曲条目。
/// 可通过 [leading]/[action] 注入额外前后缀组件。
class AudioTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final audio = playlist[audioIndex];
    final playbackService = PlayService.instance.playbackService;

    return ListenableBuilder(
      listenable: playbackService,
      builder: (context, _) {
        final isNowPlaying = playbackService.nowPlaying?.path == audio.path;
        final effectiveFocus = focus || isNowPlaying;
        return MenuAnchor(
          consumeOutsideTap: true,
          menuChildren: [
            SubmenuButton(
              menuChildren: List.generate(
                audio.splitedArtists.length,
                (i) => MenuItemButton(
                  onPressed: () {
                    final artist = AudioLibrary
                        .instance.artistCollection[audio.splitedArtists[i]]!;
                    context.push(
                      app_paths.ARTIST_DETAIL_PAGE,
                      extra: artist,
                    );
                  },
                  leadingIcon: const Icon(Symbols.artist),
                  child: Text(audio.splitedArtists[i]),
                ),
              ),
              child: const Text("艺术家"),
            ),
            MenuItemButton(
              onPressed: () {
                final album =
                    AudioLibrary.instance.albumCollection[audio.album]!;
                context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album);
              },
              leadingIcon: const Icon(Symbols.album),
              child: Text(audio.album),
            ),
            MenuItemButton(
              onPressed: () {
                PlayService.instance.playbackService.addToNext(audio);
              },
              leadingIcon: const Icon(Symbols.plus_one),
              child: const Text("下一首播放"),
            ),
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  onPressed: () async {
                    final controller = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("新建歌单"),
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
              child: const Text("添加到歌单"),
            ),
            MenuItemButton(
              onPressed: () {
                context.push(app_paths.AUDIO_DETAIL_PAGE, extra: audio);
              },
              leadingIcon: const Icon(Symbols.info),
              child: const Text("详细信息"),
            ),
            MenuItemButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _AudioEditDialog(audio: audio),
                );
              },
              leadingIcon: const Icon(Symbols.edit_note),
              child: const Text("音乐编辑"),
            ),
          ],
          builder: (context, controller, _) {
            final textColor =
                effectiveFocus ? scheme.primary : scheme.onSurface;
            final placeholder = Icon(
              Symbols.broken_image,
              size: 48.0,
              color: scheme.onSurface,
            );

            final selected =
                multiSelectController?.selected.contains(audio) == true;

            return SizedBox(
              height: 64.0,
              child: CpMotionPressable(
                borderRadius: BorderRadius.circular(12.0),
                selected: effectiveFocus || selected,
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                    return;
                  }

                  if (multiSelectController == null ||
                      !multiSelectController!.enableMultiSelectView) {
                    PlayService.instance.playbackService
                        .play(audioIndex, playlist);
                  } else {
                    multiSelectController!.toggleSelectionWithIndex(
                      index: audioIndex,
                      item: audio,
                      items: playlist,
                      shiftPressed: MultiSelectController.isShiftPressed(),
                    );
                  }
                },
                onSecondaryTapDown: (details) {
                  if (multiSelectController?.enableMultiSelectView == true) {
                    return;
                  }
                  controller.open(
                    position: details.localPosition.translate(0, -240),
                  );
                },
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    if (leading != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: leading!,
                      ),
                    ScrollAwareFutureBuilder(
                      futureKey: audio.path,
                      future: () => audio.cover,
                      builder: (context, snapshot) {
                        if (snapshot.data == null) {
                          return placeholder;
                        }

                        return RepaintBoundary(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Image(
                              image: snapshot.data!,
                              width: 48.0,
                              height: 48.0,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => placeholder,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audio.title,
                            style: TextStyle(color: textColor, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            showPlayCount
                                ? "${audio.artist} - ${audio.album} | ${audio.qualitySummary} | 播放 ${PlayCountStore.instance.get(audio)} 次"
                                : "${audio.artist} - ${audio.album} | ${audio.qualitySummary}",
                            style: TextStyle(color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      Duration(seconds: audio.duration).toStringHMMSS(),
                      style: TextStyle(
                        color:
                            effectiveFocus ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    if (multiSelectController?.enableMultiSelectView == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Checkbox(
                          value:
                              multiSelectController!.selected.contains(audio),
                          onChanged: (_) {
                            multiSelectController!.toggleSelectionWithIndex(
                              index: audioIndex,
                              item: audio,
                              items: playlist,
                              shiftPressed:
                                  MultiSelectController.isShiftPressed(),
                            );
                          },
                        ),
                      ),
                    if (action != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: action!,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AudioEditDialog extends StatefulWidget {
  const _AudioEditDialog({required this.audio});

  final Audio audio;

  @override
  State<_AudioEditDialog> createState() => _AudioEditDialogState();
}

class _AudioEditDialogState extends State<_AudioEditDialog> {
  late final titleController = TextEditingController(text: widget.audio.title);
  late final artistController =
      TextEditingController(text: widget.audio.artist);
  late final albumController = TextEditingController(text: widget.audio.album);
  late final Future<List<SongSearchResult>> _searchFuture =
      uniSearch(widget.audio);
  bool _busy = false;

  /// 保存标签覆盖到 JSON 文件，并同步更新 index.json 使修改持久化
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

      // 直接写入音乐文件的元数据标签（非 CUE 轨道）
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

      // 同步更新 index.json，使修改在重启/重建索引后依然保留
      await _updateIndexJson(widget.audio, title, artist, album);

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

  /// 更新 index.json 中对应音频的元数据
  Future<void> _updateIndexJson(
    Audio audio,
    String title,
    String artist,
    String album,
  ) async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final indexFile = File("$supportPath\\index.json");
      if (!indexFile.existsSync()) return;

      final indexStr = await indexFile.readAsString();
      final Map indexJson = json.decode(indexStr);
      final List folders = indexJson["folders"] ?? [];

      // 在 index.json 中查找并更新匹配的音频条目
      bool found = false;
      for (final folder in folders) {
        final List audios = folder["audios"] ?? [];
        for (int i = 0; i < audios.length; i++) {
          if (audios[i]["path"] == audio.path) {
            audios[i]["title"] = title;
            audios[i]["artist"] = artist;
            audios[i]["album"] = album;
            found = true;
            break;
          }
        }
        if (found) break;
      }

      if (found) {
        await indexFile.writeAsString(json.encode(indexJson));
      }
    } catch (err, trace) {
      LOGGER.e("更新 index.json 失败", error: err, stackTrace: trace);
    }
  }

  /// 设置在线歌词来源，保存后刷新正在播放的歌词
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
    // 清除封面缓存并通知播放服务刷新 UI
    widget.audio.clearCoverCache();

    // 将封面写入音乐文件的元数据标签（非 CUE 轨道）
    if (!widget.audio.isCueTrack) {
      try {
        // 从 setCoverFromUrl 返回的缓存路径读取封面数据
        final supportPath = (await getAppDataDir()).path;
        final coverDir = "$supportPath\\cover_cache";
        // 使用与 OnlineCoverStore 相同的命名规则找到缓存文件
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
