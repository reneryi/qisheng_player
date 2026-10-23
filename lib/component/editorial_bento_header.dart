import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/ui/lens_glass_surface.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/play_count_store.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

/// 多维曲库正交焦点过滤维度（致敬 Roon Focus 漏斗理念）
enum LibraryFocusDimension {
  all('全部藏品', Symbols.library_music_rounded),
  hiRes('Hi-Res 母带', Symbols.high_quality_rounded),
  lossless('无损音源', Symbols.album_rounded),
  cueSplit('CUE 分轨', Symbols.segment_rounded),
  mostPlayed('高频常听', Symbols.local_fire_department_rounded);

  const LibraryFocusDimension(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 判定音频是否匹配指定焦点维度
bool matchesLibraryFocus(Audio audio, LibraryFocusDimension focus) {
  switch (focus) {
    case LibraryFocusDimension.all:
      return true;
    case LibraryFocusDimension.hiRes:
      return (audio.sampleRate ?? 0) >= 48000 || (audio.bitrate ?? 0) > 1411;
    case LibraryFocusDimension.lossless:
      final ext = audio.path.contains('.')
          ? audio.path.split('.').last.toUpperCase()
          : '';
      const lossless = {
        'FLAC',
        'WAV',
        'WAVE',
        'APE',
        'DSD',
        'DSF',
        'DFF',
        'AIFF',
        'AIF',
        'WV',
      };
      return lossless.contains(ext);
    case LibraryFocusDimension.cueSplit:
      return audio.isCueTrack;
    case LibraryFocusDimension.mostPlayed:
      return PlayCountStore.instance.get(audio) > 0;
  }
}

/// 曲库宏观声学遥测统计快照
@immutable
class LibraryTelemetrySummary {
  const LibraryTelemetrySummary({
    required this.totalTracks,
    required this.losslessCount,
    required this.hiResCount,
    required this.cueCount,
    required this.totalHours,
  });

  final int totalTracks;
  final int losslessCount;
  final int hiResCount;
  final int cueCount;
  final double totalHours;

  double get losslessRatio =>
      totalTracks > 0 ? (losslessCount / totalTracks).clamp(0.0, 1.0) : 0.0;

  factory LibraryTelemetrySummary.fromAudios(Iterable<Audio> audios) {
    var total = 0;
    var lossless = 0;
    var hiRes = 0;
    var cue = 0;
    var seconds = 0;

    for (final a in audios) {
      total++;
      seconds += math.max(0, a.duration);
      if (matchesLibraryFocus(a, LibraryFocusDimension.lossless)) {
        lossless++;
      }
      if (matchesLibraryFocus(a, LibraryFocusDimension.hiRes)) {
        hiRes++;
      }
      if (a.isCueTrack) {
        cue++;
      }
    }

    return LibraryTelemetrySummary(
      totalTracks: total,
      losslessCount: lossless,
      hiResCount: hiRes,
      cueCount: cue,
      totalHours: seconds / 3600.0,
    );
  }
}

/// 多维曲库焦点漏斗与杂志策展入口栏 (Roon Focus Filter & Editorial Telemetry Bar)
class LibraryFocusFilterBar extends StatelessWidget {
  const LibraryFocusFilterBar({
    super.key,
    required this.allAudios,
    required this.activeFocus,
    required this.onFocusChanged,
  });

  final List<Audio> allAudios;
  final LibraryFocusDimension activeFocus;
  final ValueChanged<LibraryFocusDimension> onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final isDark = scheme.brightness == Brightness.dark;
    final telemetry = LibraryTelemetrySummary.fromAudios(allAudios);

    return Container(
      key: const ValueKey('library-focus-filter-bar'),
      margin: const EdgeInsets.fromLTRB(6, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.black.withValues(alpha: 0.025),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.07 : 0.05),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // 左侧：多维正交焦点胶囊 (Focus Chips)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'FOCUS · 焦点漏斗',
                    style: TextStyle(
                      color: accents.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(width: 10),
                  for (final dim in LibraryFocusDimension.values) ...[
                    _FocusDimensionPill(
                      dimension: dim,
                      selected: activeFocus == dim,
                      onTap: () => onFocusChanged(dim),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 右侧：无损占比遥测读数 + 杂志 Bento 画廊弹窗入口
          if (MediaQuery.sizeOf(context).width >= 880) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: scheme.onSurface.withValues(alpha: 0.05),
              ),
              child: Text(
                '无损 ${(telemetry.losslessRatio * 100).round()}% · Hi-Res ${telemetry.hiResCount}',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            key: const ValueKey('open-editorial-bento-showcase-btn'),
            borderRadius: BorderRadius.circular(999),
            onTap: () => unawaited(showEditorialBentoShowcaseDialog(context)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: accents.accent.withValues(alpha: isDark ? 0.16 : 0.10),
                border: Border.all(
                  color: accents.accent.withValues(alpha: 0.34),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.dashboard_customize_rounded,
                    size: 14,
                    color: accents.accent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '画廊策展',
                    style: TextStyle(
                      color: accents.accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusDimensionPill extends StatelessWidget {
  const _FocusDimensionPill({
    required this.dimension,
    required this.selected,
    required this.onTap,
  });

  final LibraryFocusDimension dimension;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final isDark = scheme.brightness == Brightness.dark;

    return InkWell(
      key: ValueKey('focus-pill-${dimension.name}'),
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? accents.accent.withValues(alpha: isDark ? 0.22 : 0.14)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? accents.accent.withValues(alpha: isDark ? 0.48 : 0.35)
                : scheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.08),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dimension.icon,
              size: 13.5,
              color: selected
                  ? accents.accent
                  : scheme.onSurface.withValues(alpha: 0.68),
            ),
            const SizedBox(width: 5),
            Text(
              dimension.label,
              style: TextStyle(
                color: selected
                    ? accents.accent
                    : scheme.onSurface.withValues(alpha: 0.82),
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 杂志级非对称 Bento 画廊策展视窗 (Editorial Asymmetric Bento Showcase Modal)
/// 融合 Zune HD / Rune 大字号杂志排版与 Roon 曲库遥测卡片，消除传统列表的单调感。
Future<void> showEditorialBentoShowcaseDialog(BuildContext context) {
  return showModernDialog<void>(
    context: context,
    builder: (context) => const EditorialBentoShowcaseDialog(),
  );
}

class EditorialBentoShowcaseDialog extends StatelessWidget {
  const EditorialBentoShowcaseDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final isDark = scheme.brightness == Brightness.dark;
    final audios = AudioLibrary.instance.audioCollection;
    final albums = AudioLibrary.instance.albumCollection.values.toList();
    final artists = AudioLibrary.instance.artistCollection.values.toList();
    final telemetry = LibraryTelemetrySummary.fromAudios(audios);

    // 挑選最具代表性的焦点专辑（曲目最多或第一张专辑）
    Album? featuredAlbum;
    if (albums.isNotEmpty) {
      featuredAlbum = albums.reduce(
        (a, b) => a.works.length >= b.works.length ? a : b,
      );
    }

    return ModernDialogFrame(
      key: const ValueKey('editorial-bento-showcase-dialog'),
      width: 840,
      maxHeight: 580,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 杂志刊头 (Editorial Masthead)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QISHENG AUDIO ARCHIVE · ISSUE 01',
                      style: TextStyle(
                        color: accents.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '栖声画廊策展 · Editorial Bento Showcase',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '关闭画廊',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Symbols.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 非对称 Bento Grid 主体 (左 60% 巨幅典藏唱片海报 + 右 40% 双层声学遥测与高频巡礼)
          SizedBox(
            height: 360,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左翼 2x2 巨幅焦点唱片卡片
                Expanded(
                  flex: 6,
                  child: LensGlassSurface(
                    borderRadius: 22,
                    enableBackdropBlur: false,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: accents.accent.withValues(alpha: 0.18),
                              ),
                              child: Text(
                                'FEATURED RECORD · 镇馆典藏',
                                style: TextStyle(
                                  color: accents.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (featuredAlbum != null)
                              Text(
                                '${featuredAlbum.works.length} TRACKS',
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.55),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              featuredAlbum?.name ?? '本地无损音乐典藏库',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              featuredAlbum != null
                                  ? featuredAlbum.artistsMap.keys.join(' / ')
                                  : '支持 FLAC / WAV / DSD / APE / CUE 高解析度回放',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.75),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (featuredAlbum != null) ...[
                              FilledButton.icon(
                                onPressed: () {
                                  final tracks = featuredAlbum!.works;
                                  if (tracks.isNotEmpty) {
                                    PlayService.instance.playbackService
                                        .play(0, tracks);
                                  }
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(
                                  Symbols.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: const Text('立即聆听整张专辑'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  context.push(
                                    app_paths.ALBUM_DETAIL_PAGE,
                                    extra: featuredAlbum,
                                  );
                                },
                                child: const Text('翻阅内页'),
                              ),
                            ] else
                              FilledButton.tonalIcon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Symbols.library_music_rounded),
                                label: const Text('浏览本地曲库'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 右翼上下双层 Bento 卡片
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 右上：声学馆藏规格矩阵
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03),
                            border: Border.all(
                              color: scheme.onSurface.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SONIC TELEMETRY · 馆藏声学规格',
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.58),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _BentoStatMetric(
                                    value: '${telemetry.totalTracks}',
                                    label: '总曲目',
                                    accent: accents.accent,
                                  ),
                                  _BentoStatMetric(
                                    value:
                                        '${(telemetry.losslessRatio * 100).round()}%',
                                    label: '无损占比',
                                    accent: const Color(0xFF10B981),
                                  ),
                                  _BentoStatMetric(
                                    value: '${telemetry.hiResCount}',
                                    label: 'Hi-Res',
                                    accent: const Color(0xFFEAB308),
                                  ),
                                ],
                              ),
                              Text(
                                '累计典藏 ${albums.length} 张专辑 · ${artists.length} 位艺术家 · 共 ${telemetry.totalHours.toStringAsFixed(1)} 小时',
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 右下：情绪漫游快速电台 (Instant Sonic Mix)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accents.accent
                                    .withValues(alpha: isDark ? 0.18 : 0.12),
                                scheme.secondaryContainer
                                    .withValues(alpha: isDark ? 0.22 : 0.32),
                              ],
                            ),
                            border: Border.all(
                              color: accents.accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Symbols.auto_awesome_rounded,
                                    size: 16,
                                    color: accents.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SONIC ROAM · 无损漫游电台',
                                    style: TextStyle(
                                      color: accents.accent,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '从馆藏无损曲目中智能编排不间断随机漫游序列',
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: audios.isEmpty
                                      ? null
                                      : () {
                                          PlayService.instance.playbackService
                                              .shuffleAndPlay(audios);
                                          Navigator.of(context).pop();
                                        },
                                  icon: const Icon(
                                    Symbols.shuffle_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('开启漫游'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoStatMetric extends StatelessWidget {
  const _BentoStatMetric({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.68),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
