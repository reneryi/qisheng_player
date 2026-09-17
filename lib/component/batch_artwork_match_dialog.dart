import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/audio_library.dart';

Future<void> showBatchArtworkMatchDialog(
  BuildContext context, {
  required String kind,
  List<Artist>? artists,
  List<Album>? albums,
}) {
  return showModernDialog<void>(
    context: context,
    builder: (_) => BatchArtworkMatchDialog(
      kind: kind,
      artists: artists,
      albums: albums,
    ),
  );
}

enum _BatchStatus { idle, running, finished }

class BatchArtworkMatchDialog extends StatefulWidget {
  const BatchArtworkMatchDialog({
    super.key,
    required this.kind,
    this.artists,
    this.albums,
  });

  final String kind;
  final List<Artist>? artists;
  final List<Album>? albums;

  @override
  State<BatchArtworkMatchDialog> createState() =>
      _BatchArtworkMatchDialogState();
}

class _BatchArtworkMatchDialogState extends State<BatchArtworkMatchDialog> {
  _BatchStatus _status = _BatchStatus.idle;
  bool _skipExisting = true;
  bool _isCancelled = false;

  int _currentIndex = 0;
  int _totalCount = 0;
  String _currentName = '';
  int _successCount = 0;
  int _skippedCount = 0;
  int _unmatchedCount = 0;

  bool get _isArtist => widget.kind == 'artist';

  @override
  void initState() {
    super.initState();
    _totalCount = _isArtist
        ? (widget.artists?.length ?? 0)
        : (widget.albums?.length ?? 0);
  }

  Future<void> _startMatching() async {
    setState(() {
      _status = _BatchStatus.running;
      _isCancelled = false;
      _currentIndex = 0;
      _currentName = '';
      _successCount = 0;
      _skippedCount = 0;
      _unmatchedCount = 0;
    });

    final store = ArtworkStore.instance;

    if (_isArtist) {
      final list = widget.artists ?? [];
      for (var i = 0; i < list.length; i++) {
        if (_isCancelled || !mounted) break;
        final artist = list[i];

        setState(() {
          _currentIndex = i + 1;
          _currentName = artist.name;
        });

        if (_skipExisting && store.hasArtwork(artist.id)) {
          setState(() => _skippedCount++);
          await Future.delayed(const Duration(milliseconds: 10));
          continue;
        }

        try {
          final result = await store.autoMatchEntity(
            id: artist.id,
            name: artist.name,
            kind: 'artist',
            works: artist.works,
            albumArtist: '',
          );

          if (!mounted) break;
          if (result.status == AutoMatchStatus.success) {
            setState(() => _successCount++);
          } else {
            setState(() => _unmatchedCount++);
          }
        } catch (_) {
          if (!mounted) break;
          setState(() => _unmatchedCount++);
        }

        await Future.delayed(const Duration(milliseconds: 40));
      }
    } else {
      final list = widget.albums ?? [];
      for (var i = 0; i < list.length; i++) {
        if (_isCancelled || !mounted) break;
        final album = list[i];

        setState(() {
          _currentIndex = i + 1;
          _currentName = album.name;
        });

        if (_skipExisting && store.hasArtwork(album.id)) {
          setState(() => _skippedCount++);
          await Future.delayed(const Duration(milliseconds: 10));
          continue;
        }

        try {
          final result = await store.autoMatchEntity(
            id: album.id,
            name: album.name,
            kind: 'album',
            works: album.works,
            albumArtist: album.effectiveArtist,
          );

          if (!mounted) break;
          if (result.status == AutoMatchStatus.success) {
            setState(() => _successCount++);
          } else {
            setState(() => _unmatchedCount++);
          }
        } catch (_) {
          if (!mounted) break;
          setState(() => _unmatchedCount++);
        }

        await Future.delayed(const Duration(milliseconds: 40));
      }
    }

    if (mounted) {
      setState(() {
        _status = _BatchStatus.finished;
      });
    }
  }

  void _stopMatching() {
    setState(() {
      _isCancelled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = _isArtist ? '一键匹配歌手头像' : '一键匹配专辑封面';
    final entityLabel = _isArtist ? '位艺术家' : '张专辑';

    return ModernDialogFrame(
      maxWidth: 540,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标题栏
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Symbols.auto_awesome,
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
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '共 $_totalCount $entityLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_status != _BatchStatus.running)
                IconButton(
                  icon: const Icon(Symbols.close, size: 20),
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 主体内容切换
          switch (_status) {
            _BatchStatus.idle => _buildIdleView(theme, scheme),
            _BatchStatus.running => _buildRunningView(theme, scheme),
            _BatchStatus.finished => _buildFinishedView(theme, scheme),
          },
          const SizedBox(height: 20),

          // 底部操作区
          _buildActionRow(scheme),
        ],
      ),
    );
  }

  Widget _buildIdleView(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.verified_user, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '严格校验标准',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '匹配引擎将严格对比名称准确度、歌手与专辑一致性及作品证据（置信度 ≥ 80% 方可应用）。未达到严格标准的实体将自动跳过，绝不错误关联。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '注：所有匹配图片保存在播放器本地资料库，绝不改写音频文件本身。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _skipExisting = !_skipExisting),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: _skipExisting,
                  onChanged: (v) => setState(() => _skipExisting = v ?? true),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '跳过已有图片的实体（推荐）',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '已具备自定义或已匹配封面的实体将直接跳过，大幅节约时间与网络开销',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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
      ],
    );
  }

  Widget _buildRunningView(ThemeData theme, ColorScheme scheme) {
    final progress = _totalCount > 0 ? (_currentIndex / _totalCount) : 0.0;
    final percent = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '正在匹配 ($_currentIndex/$_totalCount): $_currentName',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 18),
        _buildStatsBar(scheme),
      ],
    );
  }

  Widget _buildFinishedView(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _isCancelled
                ? scheme.errorContainer.withValues(alpha: 0.25)
                : Colors.green.withValues(alpha: 0.1),
            border: Border.all(
              color: _isCancelled
                  ? scheme.error.withValues(alpha: 0.3)
                  : Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isCancelled ? Symbols.cancel : Symbols.check_circle,
                color: _isCancelled ? scheme.error : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCancelled ? '匹配已提前终止' : '批量匹配完成',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCancelled
                          ? '已停止后续检索，当前已成功匹配并更新 $_successCount 个。'
                          : '所有实体检索完成，已成功匹配并更新 $_successCount 个。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildStatsBar(scheme),
      ],
    );
  }

  Widget _buildStatsBar(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '成功匹配',
            count: _successCount,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '已跳过',
            count: _skippedCount,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '未严格匹配',
            count: _unmatchedCount,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(ColorScheme scheme) {
    switch (_status) {
      case _BatchStatus.idle:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _totalCount > 0 ? _startMatching : null,
              icon: const Icon(Symbols.auto_awesome, size: 18),
              label: const Text('开始一键匹配'),
            ),
          ],
        );
      case _BatchStatus.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _isCancelled ? null : _stopMatching,
              icon: const Icon(Symbols.stop, size: 18),
              label: Text(_isCancelled ? '正在停止…' : '停止匹配'),
            ),
          ],
        );
      case _BatchStatus.finished:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
