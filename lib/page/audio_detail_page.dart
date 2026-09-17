import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/artist_tile.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/src/rust/api/utils.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class AudioDetailPage extends StatelessWidget {
  const AudioDetailPage({super.key, required this.audio});

  final Audio audio;

  Future<void> _openInExplorer(BuildContext context) async {
    final result = await showInExplorer(path: audio.mediaPath);
    if (!result && context.mounted) {
      showTextOnSnackBar('打开失败');
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: AudioLibrary.revision,
    builder:(context,_,__) => _buildCurrent(context));

  Widget _buildCurrent(BuildContext context) {
    final audio = AudioLibrary.instance.audioCollection.where((a)=>a.path==this.audio.path).firstOrNull ?? this.audio;
    final artists = List.generate(audio.splitedArtists.length, (i) {
      final name = audio.splitedArtists[i];
      return AudioLibrary.instance.artistCollection[name] ??
          (Artist(name: name)..works.add(audio));
    });
    final album = AudioLibrary.instance.albumCollection[audio.albumKey] ??
        (Album(name: audio.album)..works.add(audio));

    return PageScaffold(
      title: audio.displayTitle,
      subtitle: audio.displayArtistAlbumLine,
      primaryAction: FilledButton.icon(
        onPressed: () {
          context.pushReplacement(
            app_paths.AUDIOS_PAGE,
            extra: audio,
          );
        },
        icon: const Icon(Symbols.my_location),
        label: const Text('定位到音乐列表'),
      ),
      secondaryActions: [
        OutlinedButton.icon(
          onPressed: () => _openInExplorer(context),
          icon: const Icon(Symbols.folder_open),
          label: const Text('在资源管理器中显示'),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AudioDetailHero(audio: audio),
            const SizedBox(height: 16),
            CpSurface(
              key: const ValueKey('audio-detail-content-surface'),
              tone: CpSurfaceTone.panel,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSection(
                    title: '艺术家',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(
                        artists.length,
                        (i) => SizedBox(
                          width: 280,
                          child: ArtistTile(artist: artists[i]),
                        ),
                      ),
                    ),
                  ),
                  _DetailSection(
                    title: '专辑',
                    child: SizedBox(
                      width: 320,
                      child: AlbumTile(
                        album: album,
                        enableHero: true,
                      ),
                    ),
                  ),
                  if (audio.hasCredits)
                    _DetailSection(
                      title: '制作信息',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (audio.composer?.trim().isNotEmpty ?? false)
                            _DetailInfoCard(
                              title: '作曲',
                              content: audio.composer!.trim(),
                            ),
                          if (audio.arranger?.trim().isNotEmpty ?? false)
                            _DetailInfoCard(
                              title: '编曲',
                              content: audio.arranger!.trim(),
                            ),
                        ],
                      ),
                    ),
                  _DetailSection(
                    title: '音频参数',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _DetailInfoCard(
                          title: '音轨',
                          content: audio.track.toString(),
                        ),
                        _DetailInfoCard(
                          title: '时长',
                          content: Duration(
                            milliseconds: (audio.duration * 1000).toInt(),
                          ).toStringHMMSS(),
                        ),
                        _DetailInfoCard(
                          title: '码率',
                          content: audio.bitrate == null
                              ? '未知'
                              : '${audio.bitrate} kbps',
                        ),
                        _DetailInfoCard(
                          title: '采样率',
                          content: audio.sampleRate == null
                              ? '未知'
                              : '${audio.sampleRate} hz',
                        ),
                        _DetailInfoCard(
                          title: '播放次数',
                          content: '${PlayCountStore.instance.get(audio)}',
                        ),
                        _DetailInfoCard(
                          title: '格式',
                          content: audio.fileExtension,
                        ),
                      ],
                    ),
                  ),
                  _DetailSection(
                    title: '文件路径',
                    child: SelectableText(
                      audio.mediaPath,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  if (audio.isCueTrack)
                    _DetailSection(
                      title: 'CUE 轨道',
                      child: SelectableText(
                        audio.path,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                  _DetailSection(
                    title: '时间信息',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _DetailInfoCard(
                          title: '修改时间',
                          content: DateTime.fromMillisecondsSinceEpoch(
                            audio.modified * 1000,
                          ).toString(),
                          width: 260,
                        ),
                        _DetailInfoCard(
                          title: '创建时间',
                          content: DateTime.fromMillisecondsSinceEpoch(
                            audio.created * 1000,
                          ).toString(),
                          width: 260,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioDetailHero extends StatelessWidget {
  const _AudioDetailHero({required this.audio});

  final Audio audio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Icon(
        Symbols.broken_image,
        size: 48,
        color: scheme.onSurface.withValues(alpha: 0.64),
      ),
    );

    return CpSurface(
      key: const ValueKey('audio-detail-hero-surface'),
      tone: CpSurfaceTone.floating,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final artwork = FutureBuilder<ImageProvider?>(
            future: audio.mediumCover,
            builder: (context, snapshot) {
              final image = snapshot.data;
              if (image == null) {
                return SizedBox(
                  width: compact ? 180 : 208,
                  height: compact ? 180 : 208,
                  child: placeholder,
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image(
                  image: image,
                  width: compact ? 180 : 208,
                  height: compact ? 180 : 208,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
              );
            },
          );

          final summary = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                audio.displayTitle,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: compact ? 28 : 34,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                audio.displayArtistAlbumLine,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: compact ? WrapAlignment.center : WrapAlignment.start,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AudioMetadataChip(
                    icon: Symbols.audio_file,
                    label: audio.qualitySummary,
                  ),
                  _AudioMetadataChip(
                    icon: Symbols.schedule,
                    label: Duration(
                      milliseconds: (audio.duration * 1000).toInt(),
                    ).toStringHMMSS(),
                  ),
                  _AudioMetadataChip(
                    icon: Symbols.bar_chart,
                    label: '播放 ${PlayCountStore.instance.get(audio)} 次',
                  ),
                ],
              ),
            ],
          );

          return compact
              ? Column(
                  children: [
                    artwork,
                    const SizedBox(height: 18),
                    summary,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    artwork,
                    const SizedBox(width: 22),
                    Expanded(child: summary),
                  ],
                );
        },
      ),
    );
  }
}

class _AudioMetadataChip extends StatelessWidget {
  const _AudioMetadataChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({
    required this.title,
    required this.content,
    this.width = 180,
  });

  final String title;
  final String content;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CpSurface(
      tone: CpSurfaceTone.subtle,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.58),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
