import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/metadata_provider.dart';
import 'package:qisheng_player/utils.dart';

class EntityArtworkActions extends StatelessWidget {
  const EntityArtworkActions({
    super.key,
    required this.id,
    required this.name,
    required this.kind,
    required this.works,
    this.albumArtist = '',
    this.album,
  });

  final String id, name, kind, albumArtist;
  final List<Audio> works;
  final Album? album;

  Future<void> _run(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        showTextOnSnackBar('图片操作失败：$e');
      }
    }
  }

  Future<void> _openSearchDialog(BuildContext context) async {
    await showModernDialog<void>(
      context: context,
      builder: (_) => _ArtworkSearch(
        id: id,
        name: name,
        kind: kind,
        works: works,
        albumArtist: albumArtist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: kind == 'artist' ? '歌手头像设置' : '专辑封面设置',
        icon: const Icon(Icons.add_photo_alternate_outlined),
        onSelected: (value) => _run(context, () async {
          if (value == 'search') {
            await _openSearchDialog(context);
          } else if (value == 'local') {
            final picker = OpenFilePicker()
              ..title = '选择图片'
              ..filterSpecification = {'JPEG／PNG 图片': '*.jpg;*.jpeg;*.png'};
            final file = picker.getFile();
            if (file == null) return;
            if (await file.length() > ArtworkStore.maxArtworkBytes) {
              throw const FormatException('图片大小超过 32 MB 限制');
            }
            await ArtworkStore.instance.local(id, await file.readAsBytes());
            if (context.mounted) {
              showTextOnSnackBar(
                  '已成功设置本地${kind == 'artist' ? '歌手头像' : '专辑封面'}');
            }
          } else if (value == 'reset') {
            await ArtworkStore.instance.reset(id);
            if (context.mounted) {
              showTextOnSnackBar('已恢复使用歌曲封面');
            }
          } else if (value == 'merge' && album != null) {
            final others = AudioLibrary.instance.albumCollection.values
                .where((a) => a.id != id && a.name == name)
                .toList();
            final target = await showDialog<Album>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('将这些歌曲关联到同一专辑'),
                children: [
                  if (others.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('没有其他同名专辑'),
                    ),
                  for (final a in others)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, a),
                      child: Text(
                        '${a.name} · ${a.albumArtist.isEmpty ? a.artistsMap.keys.join(" / ") : a.albumArtist}\n${a.works.firstOrNull?.mediaPath ?? ""}',
                      ),
                    ),
                ],
              ),
            );
            if (target != null) {
              await ArtworkStore.instance.mergeAlbum(album!, target);
            }
          }
        }),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'search',
            child: Row(
              children: [
                Icon(Symbols.search, size: 20),
                SizedBox(width: 8),
                Text('查找在线图片…'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'local',
            child: Row(
              children: [
                Icon(Symbols.upload_file, size: 20),
                SizedBox(width: 8),
                Text('选择本地图片'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reset',
            child: Row(
              children: [
                Icon(Symbols.image, size: 20),
                SizedBox(width: 8),
                Text('恢复歌曲封面'),
              ],
            ),
          ),
          if (album != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'merge',
              child: Row(
                children: [
                  Icon(Symbols.merge, size: 20),
                  SizedBox(width: 8),
                  Text('关联到同名专辑…'),
                ],
              ),
            ),
          ],
        ],
      );
}

class _ArtworkSearch extends StatefulWidget {
  const _ArtworkSearch({
    required this.id,
    required this.name,
    required this.kind,
    required this.works,
    required this.albumArtist,
  });

  final String id, name, kind, albumArtist;
  final List<Audio> works;

  @override
  State<_ArtworkSearch> createState() => _ArtworkSearchState();
}

class _ArtworkSearchState extends State<_ArtworkSearch> {
  late final TextEditingController _query =
      TextEditingController(text: widget.name);
  late Future<List<MetadataCandidate>> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _search();
  }

  Future<List<MetadataCandidate>> _search() => ArtworkStore.instance
      .candidates(_query.text.trim(), widget.kind, widget.works,
          widget.albumArtist);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    if (_busy) return;
    setState(() {
      _error = null;
      _future = _search();
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isArtist = widget.kind == 'artist';

    return ModernDialogFrame(
      maxWidth: 720,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标题与关闭
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isArtist ? Symbols.person : Symbols.album,
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
                      isArtist ? '查找歌手官方头像' : '查找专辑官方封面',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Symbols.close),
                tooltip: '关闭',
                onPressed: _busy ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 搜索与智能匹配工具栏
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  decoration: InputDecoration(
                    hintText: isArtist ? '输入歌手名搜索…' : '输入专辑名搜索…',
                    prefixIcon: const Icon(Symbols.search, size: 20),
                    suffixIcon: _query.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Symbols.clear, size: 18),
                            onPressed: () {
                              _query.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _triggerSearch(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _triggerSearch,
                icon: const Icon(Symbols.search, size: 18),
                label: const Text('搜索'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 提示说明
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Symbols.info,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '此操作将在线图片关联至本地资料库，绝不修改物理音频文件本身。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ),

          // 候选列表区域
          SizedBox(
            height: 360,
            child: FutureBuilder<List<MetadataCandidate>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在检索在线实体候选…'),
                      ],
                    ),
                  );
                }

                final candidates = snapshot.data ?? [];
                if (candidates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.image_not_supported,
                            size: 44, color: scheme.outline),
                        const SizedBox(height: 8),
                        const Text('未检索到候选结果'),
                        const SizedBox(height: 4),
                        Text(
                          '可尝试微调搜索关键词，或在菜单中选择本地图片',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = candidates[i];
                    return _CandidateCard(
                      candidate: c,
                      kind: widget.kind,
                      busy: _busy,
                      onApply: () => _applyCandidate(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCandidate(MetadataCandidate c) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await PlatformMetadataProvider(c.source).detail(c);
      if (detail.imageUrl == null || detail.imageUrl!.isEmpty) {
        throw const FormatException('该候选图片地址无效');
      }
      final bytes = await ArtworkStore.download(detail.imageUrl!);
      if (!mounted) return;

      final selected = await showModernDialog<bool>(
        context: context,
        builder: (ctx) {
          final isArtist = widget.kind == 'artist';
          final scheme = Theme.of(ctx).colorScheme;
          return ModernDialogFrame(
            maxWidth: 420,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        detail.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close, size: 20),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(isArtist ? 140 : 16),
                  child: Image.memory(
                    bytes,
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '来源：${detail.source.name} · ${detail.artist}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('返回'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认使用此图片'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

      if (selected == true) {
        await ArtworkStore.instance.select(widget.id, detail);
        if (!mounted) return;
        showTextOnSnackBar(
            '已成功更新${widget.kind == "artist" ? "歌手头像" : "专辑封面"}');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '获取并应用图片失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.kind,
    required this.busy,
    required this.onApply,
  });

  final MetadataCandidate candidate;
  final String kind;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isArtist = kind == 'artist';
    final hasImage =
        candidate.imageUrl != null && candidate.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onApply,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(isArtist ? 24 : 8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: hasImage
                      ? Image.network(
                          candidate.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackIcon(isArtist, scheme),
                        )
                      : _fallbackIcon(isArtist, scheme),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            candidate.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (candidate.evidence == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '高置信度',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            candidate.source.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        if (candidate.artist.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              candidate.artist,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: busy ? null : onApply,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('选择'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(bool isArtist, ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Icon(
        isArtist ? Symbols.person : Symbols.album,
        size: 26,
        color: scheme.outline,
      ),
    );
  }
}
