import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_edit_service.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lyric_file_helper.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/utils.dart';

/// 栖声播放器现代双栏音乐编辑与在线匹配对话框。
/// 规范对齐 ModernDialogFrame 与亚克力毛玻璃视觉体系，彻底摒弃输入框前置复选框。
class AudioEditDialog extends StatefulWidget {
  const AudioEditDialog({required this.audio, this.searcher, super.key});
  final Audio audio;
  final Future<List<SongSearchResult>> Function(Audio audio)? searcher;

  @override
  State<AudioEditDialog> createState() => _AudioEditDialogState();
}

class _AudioEditDialogState extends State<AudioEditDialog> {
  final _service = const AudioEditService();
  late AudioEditDraft _draft;
  late final TextEditingController titleController,
      artistController,
      albumController,
      albumArtistController,
      trackController,
      discController,
      lyricController,
      searchController;

  late Future<List<SongSearchResult>> _searchFuture;
  String? _error, _result;
  bool _busy = false,
      _loading = true,
      _dirty = false,
      _settingFields = false,
      _allowClose = false,
      _showLyricEditor = false;
  int _lyricRequest = 0;
  ResultSource? _selectedSourceFilter;

  @override
  void initState() {
    super.initState();
    final audio = widget.audio;
    _draft = AudioEditDraft(audio);
    titleController = TextEditingController(text: audio.title);
    artistController = TextEditingController(text: audio.artist);
    albumController = TextEditingController(text: audio.album);
    albumArtistController = TextEditingController(text: audio.albumArtist);
    trackController = TextEditingController(text: audio.track.toString());
    discController = TextEditingController(text: audio.disc.toString());
    lyricController = TextEditingController();
    searchController =
        TextEditingController(text: buildMusicSearchQuery(audio));

    titleController.addListener(() => _edited(() => _draft.writeTitle = true));
    artistController
        .addListener(() => _edited(() => _draft.writeArtist = true));
    albumController.addListener(() => _edited(() => _draft.writeAlbum = true));
    albumArtistController
        .addListener(() => _edited(() => _draft.writeAlbumArtist = true));
    trackController.addListener(() => _edited(() => _draft.writeTrack = true));
    discController.addListener(() => _edited(() => _draft.writeDisc = true));

    _searchFuture = (widget.searcher ?? uniSearch)(audio);
    _readOriginal();
  }

  List<TextEditingController> get _fields => [
        titleController,
        artistController,
        albumController,
        albumArtistController,
        trackController,
        discController
      ];

  void _edited(VoidCallback selectField) {
    if (_settingFields) return;
    selectField();
    if (mounted) setState(() => _dirty = true);
  }

  Future<void> _readOriginal() async {
    try {
      if (!widget.audio.isCueTrack) {
        final original = await _service.read(widget.audio);
        if (!mounted) return;
        _draft.original = original;
        if (!_dirty) {
          _settingFields = true;
          albumArtistController.text = original.albumArtist;
          trackController.text = original.track.toString();
          discController.text = original.disc.toString();
          _settingFields = false;
          _dirty = false;
        }
      }
    } catch (e) {
      if (mounted) _error = '无法读取文件标签：$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _lyricRequest++;
    for (final c in [..._fields, lyricController, searchController]) {
      c.dispose();
    }
    super.dispose();
  }

  void _search() {
    final query = searchController.text.trim();
    if (query.isEmpty) return;
    final witness =
        Audio.fromMap({...widget.audio.toMap(), 'title': query, 'artist': ''});
    setState(() {
      _searchFuture = (widget.searcher ?? uniSearch)(witness);
    });
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('有未保存的修改'),
                  content: const Text('关闭会放弃本次标签、歌词与封面修改。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('继续编辑')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('放弃修改'))
                  ]));
      if (discard != true || !mounted) return;
    }
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _adopt(SongSearchResult result) {
    setState(() {
      _settingFields = true;
      titleController.text = result.title;
      artistController.text = result.artists;
      albumController.text = result.album;
      _draft.writeTitle = true;
      _draft.writeArtist = true;
      _draft.writeAlbum = true;
      if (result.albumArtist != null && result.albumArtist!.isNotEmpty) {
        albumArtistController.text = result.albumArtist!;
        _draft.writeAlbumArtist = true;
      }
      _settingFields = false;
      _draft.association = result;
      if (result.coverUrl?.isNotEmpty == true && !widget.audio.isCueTrack) {
        _draft.coverResult = result;
        _draft.cover = null;
      }
      _dirty = true;
    });
    _chooseLyric(result);
  }

  Future<void> _chooseLyric(SongSearchResult result) async {
    final request = ++_lyricRequest;
    setState(() {
      _draft.lyricResult = result;
      _draft.lyrics = null;
      _dirty = true;
      _showLyricEditor = true;
      _error = null;
    });
    try {
      final lyric = await LyricFileHelper.fetchOnlineLrcText(result);
      if (!mounted || request != _lyricRequest) return;
      setState(() {
        _draft.lyrics = lyric;
        lyricController.text = lyric ?? '';
        if (lyric == null || lyric.trim().isEmpty) {
          _error = '歌词获取失败，可重试或手动编辑';
        }
      });
    } catch (e) {
      if (mounted && request == _lyricRequest) {
        setState(() => _error = '歌词获取失败：$e');
      }
    }
  }

  Future<void> _pickCover() async {
    final picker = OpenFilePicker()
      ..title = '选择歌曲封面图片'
      ..filterSpecification = {'图片文件': '*.jpg;*.jpeg;*.png;*.webp'};
    final file = picker.getFile();
    if (file == null) return;
    try {
      if (await file.length() > 12 * 1024 * 1024) {
        throw const FormatException('图片文件超过 12 MB 限制');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _draft.cover = bytes;
          _draft.coverResult = null;
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    final track = int.tryParse(trackController.text),
        disc = int.tryParse(discController.text);
    if (track == null || disc == null || track < 0 || disc < 0) {
      setState(() => _error = '音轨号和碟号必须为非负整数');
      return;
    }
    _draft
      ..title = titleController.text
      ..artist = artistController.text
      ..album = albumController.text
      ..albumArtist = albumArtistController.text
      ..track = track
      ..disc = disc;

    // 自动标记被修改的字段以写入物理文件
    final old = _draft.original;
    if (old != null) {
      if (_draft.title.trim() != old.title) _draft.writeTitle = true;
      if (_draft.artist.trim() != old.artist) _draft.writeArtist = true;
      if (_draft.album.trim() != old.album) _draft.writeAlbum = true;
      if (_draft.albumArtist.trim() != old.albumArtist) {
        _draft.writeAlbumArtist = true;
      }
      if (_draft.track != old.track) _draft.writeTrack = true;
      if (_draft.disc != old.disc) _draft.writeDisc = true;
    } else {
      _draft.writeTitle = true;
      _draft.writeArtist = true;
      _draft.writeAlbum = true;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    final result = await _service.save(_draft);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result.message;
    });

    if (result.committed) {
      setState(() => _dirty = false);
      if (result.status == AudioEditStatus.saved) {
        showTextOnSnackBar(result.message);
        await _close();
      } else {
        _draft = AudioEditDraft(widget.audio);
        _loading = true;
        await _readOriginal();
      }
    }
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !_busy,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
          ),
          suffixIcon: IconButton(
            tooltip: '清空',
            iconSize: 16,
            onPressed: _busy ? null : () => controller.text = isNumber ? '0' : '',
            icon: const Icon(Icons.clear),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPreview(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverBytes = _draft.cover;
    final coverUrl = _draft.coverResult?.coverUrl;

    Widget imageChild;
    if (coverBytes != null && coverBytes.isNotEmpty) {
      imageChild = Image.memory(coverBytes, fit: BoxFit.cover);
    } else if (coverUrl != null && coverUrl.isNotEmpty) {
      imageChild = Image.network(
        coverUrl,
        fit: BoxFit.cover,
        headers: const {'User-Agent': 'QishengPlayer/1.4.0'},
        errorBuilder: (_, __, ___) => _buildCoverPlaceholder(scheme),
      );
    } else {
      imageChild = FutureBuilder<ImageProvider?>(
        future: widget.audio.cover,
        builder: (context, snapshot) {
          final provider = snapshot.data;
          if (provider != null) {
            return Image(image: provider, fit: BoxFit.cover);
          }
          return _buildCoverPlaceholder(scheme);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: imageChild,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!widget.audio.isCueTrack)
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickCover,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('选择本地封面', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
              ),
            if (_draft.cover != null || _draft.coverResult != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _draft.cover = null;
                          _draft.coverResult = null;
                          _dirty = true;
                        }),
                child: const Text('恢复原封面', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Center(
        child: Icon(
          Symbols.album_rounded,
          size: 48,
          color: scheme.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogHeight = math.min(740.0, MediaQuery.sizeOf(context).height - 80.0);

    return PopScope(
      canPop: _allowClose || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: ModernDialogFrame(
        maxWidth: 960,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: SizedBox(
          height: dialogHeight,
          child: Column(
            children: [
              // 对话框头部
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Symbols.edit_note_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '音乐编辑',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.audio.isCueTrack) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CUE 分轨',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.audio.isCueTrack
                              ? 'CUE 分轨：保存为播放器覆盖，不修改母带'
                              : '修改本地音频元数据标签；点击保存后写入文件并立即同步播放器',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: _busy ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 经典双栏核心主体
              Expanded(
                child: Focus(
                  onFocusChange: HotkeysHelper.onFocusChanges,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 左栏：封面与基础元数据表单
                      Expanded(
                        flex: 43,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.black.withValues(alpha: 0.015),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCoverPreview(scheme),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  label: '歌名',
                                  controller: titleController,
                                ),
                                _buildFormField(
                                  label: '歌手',
                                  controller: artistController,
                                ),
                                _buildFormField(
                                  label: '专辑',
                                  controller: albumController,
                                ),
                                _buildFormField(
                                  label: '专辑艺术家',
                                  controller: albumArtistController,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildFormField(
                                        label: '音轨号',
                                        controller: trackController,
                                        isNumber: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildFormField(
                                        label: '碟号',
                                        controller: discController,
                                        isNumber: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_loading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: LinearProgressIndicator(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // 右栏：在线搜索、匹配列表与歌词工作台
                      Expanded(
                        flex: 57,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.black.withValues(alpha: 0.015),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 搜索栏
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: searchController,
                                      onSubmitted: (_) => _search(),
                                      enabled: !_busy,
                                      style: const TextStyle(fontSize: 13.5),
                                      decoration: InputDecoration(
                                        hintText: '搜索歌名、歌手进行在线匹配…',
                                        isDense: true,
                                        prefixIcon: const Icon(Icons.search, size: 20),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () => searchController.clear(),
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? Colors.white.withValues(alpha: 0.04)
                                            : Colors.black.withValues(alpha: 0.03),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _busy ? null : _search,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('重新检索'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 平台来源快捷过滤 Chip
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    const Text('来源：',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    const SizedBox(width: 4),
                                    ChoiceChip(
                                      label: const Text('全部',
                                          style: TextStyle(fontSize: 11.5)),
                                      selected: _selectedSourceFilter == null,
                                      onSelected: (_) => setState(
                                          () => _selectedSourceFilter = null),
                                    ),
                                    const SizedBox(width: 6),
                                    ChoiceChip(
                                      label: const Text('网易云',
                                          style: TextStyle(fontSize: 11.5)),
                                      selected: _selectedSourceFilter ==
                                          ResultSource.netease,
                                      onSelected: (_) => setState(() =>
                                          _selectedSourceFilter =
                                              ResultSource.netease),
                                    ),
                                    const SizedBox(width: 6),
                                    ChoiceChip(
                                      label: const Text('QQ音乐',
                                          style: TextStyle(fontSize: 11.5)),
                                      selected:
                                          _selectedSourceFilter == ResultSource.qq,
                                      onSelected: (_) => setState(() =>
                                          _selectedSourceFilter = ResultSource.qq),
                                    ),
                                    const SizedBox(width: 6),
                                    ChoiceChip(
                                      label: const Text('酷狗',
                                          style: TextStyle(fontSize: 11.5)),
                                      selected: _selectedSourceFilter ==
                                          ResultSource.kugou,
                                      onSelected: (_) => setState(() =>
                                          _selectedSourceFilter =
                                              ResultSource.kugou),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // 在线匹配候选列表
                              const Text(
                                '在线匹配结果',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),

                              Expanded(
                                child: FutureBuilder<List<SongSearchResult>>(
                                  future: _searchFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    var items = snapshot.data ?? [];
                                    if (_selectedSourceFilter != null) {
                                      items = items
                                          .where((i) =>
                                              i.source == _selectedSourceFilter)
                                          .toList();
                                    }
                                    if (items.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            '未检索到匹配结果，可修改搜索词后重试',
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return ListView.separated(
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        return SearchResultCard(
                                          item: item,
                                          isDark: isDark,
                                          scheme: scheme,
                                          busy: _busy,
                                          onFillForm: () => _adopt(item),
                                          onApplyLyric: () => _chooseLyric(item),
                                          onApplyCover: () => setState(() {
                                            if (!widget.audio.isCueTrack) {
                                              _draft.coverResult = item;
                                              _draft.cover = null;
                                              _dirty = true;
                                            }
                                          }),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              // 歌词微调与预览扩展面板
                              if (_showLyricEditor ||
                                  _draft.lyricResult != null ||
                                  _draft.lyrics != null) ...[
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.lyrics_outlined, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _draft.lyricResult != null
                                            ? '已关联歌词：${_draft.lyricResult!.title} (${_draft.lyricResult!.artists})'
                                            : '歌词预览与编辑',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() {
                                                _lyricRequest++;
                                                _draft.lyricResult = null;
                                                _draft.lyrics = null;
                                                lyricController.clear();
                                                _showLyricEditor = false;
                                              }),
                                      child: const Text('清除',
                                          style: TextStyle(fontSize: 11.5)),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: lyricController,
                                  enabled: !_busy,
                                  minLines: 3,
                                  maxLines: 5,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                  ),
                                  onChanged: (value) {
                                    _draft.lyrics = value;
                                    _draft.lyricResult = null;
                                    _dirty = true;
                                  },
                                  decoration: InputDecoration(
                                    hintText: '可在此粘贴或微调 LRC 歌词内容…',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      FilterChip(
                                        label: Text(
                                          widget.audio.isCueTrack
                                              ? 'CUE 不写母带'
                                              : '写入内嵌歌词',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        selected: !widget.audio.isCueTrack &&
                                            _draft.writeLyrics,
                                        onSelected: widget.audio.isCueTrack ||
                                                _busy
                                            ? null
                                            : (v) => setState(() =>
                                                _draft.writeLyrics = v),
                                      ),
                                      const SizedBox(width: 6),
                                      FilterChip(
                                        label: const Text('导出同级 .lrc',
                                            style: TextStyle(fontSize: 11)),
                                        selected: _draft.exportLyrics,
                                        onSelected: _busy
                                            ? null
                                            : (v) => setState(() =>
                                                _draft.exportLyrics = v),
                                      ),
                                      const SizedBox(width: 6),
                                      FilterChip(
                                        label: const Text('应用到播放器',
                                            style: TextStyle(fontSize: 11)),
                                        selected: _draft.applyLyrics,
                                        onSelected: _busy
                                            ? null
                                            : (v) => setState(() =>
                                                _draft.applyLyrics = v),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                            _showLyricEditor = true;
                                            _draft.lyrics ??= '';
                                          }),
                                  icon: const Icon(Icons.lyrics_outlined, size: 16),
                                  label: const Text('编辑或粘贴歌词',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 错误/成功提示条
              if (_error != null || _result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error ?? _result!,
                    style: TextStyle(
                      color: _error != null ? scheme.error : scheme.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const Divider(height: 18),

              // 底部动作栏
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: widget.audio.mediaPath,
                      child: Text(
                        widget.audio.mediaPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _close,
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ||
                            _loading ||
                            !_dirty ||
                            (!widget.audio.isCueTrack &&
                                _draft.original == null)
                        ? null
                        : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_busy ? '正在保存…' : '保存所选修改'),
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

  (String name, Color brandColor) get _platformInfo =>
      switch (widget.item.source) {
        ResultSource.qq => ("QQ音乐", const Color(0xFF10B981)),
        ResultSource.kugou => ("酷狗", const Color(0xFF0C82FF)),
        ResultSource.netease => ("网易云", const Color(0xFFEF4444)),
      };

  Widget _buildCoverThumbnail() {
    final hasCover =
        widget.item.coverUrl != null && widget.item.coverUrl!.trim().isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.isDark ? 0.35 : 0.12,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
        borderRadius: BorderRadius.circular(9),
        child: hasCover
            ? Image.network(
                widget.item.coverUrl!,
                fit: BoxFit.cover,
                width: 52,
                height: 52,
                headers: const {'User-Agent': 'QishengPlayer/1.4.0'},
                errorBuilder: (context, error, stackTrace) =>
                    _buildCoverPlaceholder(),
              )
            : _buildCoverPlaceholder(),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      width: 52,
      height: 52,
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
          size: 24,
          color: widget.scheme.primary.withValues(
            alpha: widget.isDark ? 0.75 : 0.65,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (sourceName, brandColor) = _platformInfo;
    final matchPercent = (widget.item.score * 100).clamp(0, 100).toInt();

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
                  ? widget.scheme.surfaceContainerHighest.withValues(alpha: 0.20)
                  : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.38)),
          borderRadius: BorderRadius.circular(12),
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
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildCoverThumbnail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.4),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: widget.scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$matchPercent% 匹配',
                          style: TextStyle(
                            color: widget.scheme.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.scheme.onSurfaceVariant
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: widget.scheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          widget.item.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.scheme.onSurfaceVariant
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onApplyLyric,
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text(
                    '选择歌词',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onApplyCover,
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text(
                    '选择封面',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: widget.busy ? null : widget.onFillForm,
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text(
                    '采用此结果',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
