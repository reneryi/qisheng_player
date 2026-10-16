import 'package:flutter/material.dart';
import 'package:qisheng_player/library/audio_library.dart';

/// 音频无损/高清规格胶囊徽章组件
/// 用于在底部播放条、歌曲详情与正在播放视图中优雅展示音频无损标识与采样率
class AudioFormatBadge extends StatelessWidget {
  const AudioFormatBadge({
    super.key,
    required this.audio,
    this.compact = false,
    this.subtle = false,
  });

  /// 音频元数据对象
  final Audio audio;

  /// 是否紧凑模式（紧凑模式下只显示关键无损/Hi-Res标签）
  final bool compact;

  /// 是否采用列表态低饱和磨砂质感（降低多行重复出现时的视觉喧宾夺主感）
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 解析文件后缀扩展名
    final extension = audio.path.contains('.')
        ? audio.path.split('.').last.toUpperCase()
        : 'AUDIO';

    final isLossless = _isLosslessFormat(extension);
    final isHiRes = (audio.sampleRate ?? 0) >= 48000 ||
        (audio.bitrate != null && audio.bitrate! > 1411);

    // 格式文案处理
    String badgeText = extension;
    if (extension == 'FLAC' ||
        extension == 'APE' ||
        extension == 'WAV' ||
        extension == 'DSD') {
      badgeText = isHiRes ? 'Hi-Res • $extension' : extension;
    } else if (audio.bitrate != null && audio.bitrate! > 0) {
      badgeText = '$extension ${audio.bitrate}kbps';
    }

    // 采样率文案（非紧凑模式可选展示）
    final sampleRateText = _formatSampleRate(audio.sampleRate);

    // 高解析度/无损强调配色
    final Color badgeTint = isHiRes
        ? const Color(0xFFEAB308) // 金色 Hi-Res
        : (isLossless ? scheme.primary : scheme.outline);

    final double bgAlpha = subtle
        ? (isDark ? 0.07 : 0.05)
        : (isDark ? 0.12 : 0.08);
    final double borderAlpha = subtle
        ? (isDark ? 0.22 : 0.16)
        : (isDark ? 0.35 : 0.25);

    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: badgeTint.withValues(alpha: bgAlpha),
          border: Border.all(
            color: badgeTint.withValues(alpha: borderAlpha),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isHiRes) ...[
              Icon(
                Icons.stars_rounded,
                size: 11,
                color: subtle
                    ? badgeTint.withValues(alpha: 0.85)
                    : badgeTint,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              badgeText,
              style: TextStyle(
                color: isDark
                    ? Color.lerp(
                        badgeTint,
                        Colors.white,
                        subtle ? 0.62 : 0.5,
                      )
                    : Color.lerp(
                        badgeTint,
                        Colors.black,
                        subtle ? 0.52 : 0.4,
                      ),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.1,
              ),
            ),
            if (!compact && sampleRateText.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                width: 2.5,
                height: 2.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeTint.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                sampleRateText,
                style: TextStyle(
                  color: scheme.onSurface.withValues(
                    alpha: isDark ? 0.78 : 0.88,
                  ),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 判断是否属于主流无损音频格式
  bool _isLosslessFormat(String ext) {
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
  }

  /// 格式化采样率（例如 44100 -> 44.1kHz, 96000 -> 96kHz）
  String _formatSampleRate(int? sampleRate) {
    if (sampleRate == null || sampleRate <= 0) return '';
    if (sampleRate >= 1000) {
      final khz = sampleRate / 1000.0;
      return '${khz.toStringAsFixed(khz.truncateToDouble() == khz ? 0 : 1)}kHz';
    }
    return '${sampleRate}Hz';
  }
}
