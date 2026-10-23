import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/lens_glass_surface.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

/// 音频信号链品质等级（致敬 Roon Signal Path 色彩语义）
enum SignalPathQuality {
  /// 紫光/星芒紫：无损音源 + WASAPI 独占硬件直通 (Bit-Perfect Lossless)
  bitPerfect,

  /// 青碧光：无损音源 + 高精度浮点感知 DSP / 共享混音 (High-Quality DSP)
  highQualityDsp,

  /// 琥珀金：有损压缩音源标准回放 (Standard Compressed)
  standard,
}

@immutable
class SignalPathSnapshot {
  const SignalPathSnapshot({
    required this.quality,
    required this.formatExtension,
    required this.isLossless,
    required this.isHiRes,
    required this.isCueTrack,
    required this.sampleRateHz,
    required this.bitrateKbps,
    required this.wasapiExclusive,
    required this.perceptualVolume,
    required this.physicalAmplitude,
    required this.attenuationDb,
    required this.replayGainEnabled,
    required this.replayGainDb,
    required this.preampDb,
  });

  final SignalPathQuality quality;
  final String formatExtension;
  final bool isLossless;
  final bool isHiRes;
  final bool isCueTrack;
  final int? sampleRateHz;
  final int? bitrateKbps;
  final bool wasapiExclusive;
  final double perceptualVolume;
  final double physicalAmplitude;
  final double attenuationDb;
  final bool replayGainEnabled;
  final double? replayGainDb;
  final double preampDb;

  static const Set<String> _losslessExtensions = {
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

  factory SignalPathSnapshot.fromState({
    required Audio? audio,
    required bool wasapiExclusive,
    required double perceptualVolume,
    bool replayGainEnabled = false,
    double preampDb = 0.0,
  }) {
    final ext = (audio != null && audio.path.contains('.'))
        ? audio.path.split('.').last.toUpperCase()
        : 'PCM';
    final isLossless = _losslessExtensions.contains(ext);
    final sampleRate = audio?.sampleRate;
    final bitrate = audio?.bitrate;
    final isHiRes =
        (sampleRate ?? 0) >= 48000 || (bitrate != null && bitrate > 1411);
    final isCue = audio?.isCueTrack ?? false;

    final clampedPerceptual =
        perceptualVolume.isFinite ? perceptualVolume.clamp(0.0, 1.0) : 0.0;
    final amplitude = perceptualVolumeToAmplitude(clampedPerceptual);
    final attenuationDb = amplitude <= 0.00001
        ? -96.0
        : (20.0 * math.log(amplitude) / math.ln10).clamp(-96.0, 0.0);

    final SignalPathQuality quality;
    if (isLossless && wasapiExclusive) {
      quality = SignalPathQuality.bitPerfect;
    } else if (isLossless) {
      quality = SignalPathQuality.highQualityDsp;
    } else {
      quality = SignalPathQuality.standard;
    }

    return SignalPathSnapshot(
      quality: quality,
      formatExtension: ext,
      isLossless: isLossless,
      isHiRes: isHiRes,
      isCueTrack: isCue,
      sampleRateHz: sampleRate,
      bitrateKbps: bitrate,
      wasapiExclusive: wasapiExclusive,
      perceptualVolume: clampedPerceptual,
      physicalAmplitude: amplitude,
      attenuationDb: attenuationDb,
      replayGainEnabled: replayGainEnabled,
      replayGainDb: audio?.replayGainDb,
      preampDb: preampDb,
    );
  }

  Color resolveIndicatorColor(ColorScheme scheme) {
    return switch (quality) {
      SignalPathQuality.bitPerfect => const Color(0xFFA855F7), // 星芒紫
      SignalPathQuality.highQualityDsp => const Color(0xFF10B981), // 翡翠青
      SignalPathQuality.standard => const Color(0xFFF59E0B), // 琥珀金
    };
  }

  String get qualityLabel {
    return switch (quality) {
      SignalPathQuality.bitPerfect => 'Bit-Perfect 无损独占直通',
      SignalPathQuality.highQualityDsp => '高保真 64-bit 浮点声学管线',
      SignalPathQuality.standard => '标准数字音频解码管线',
    };
  }
}

Future<void> showSignalPathInspector(BuildContext context) {
  return showModernDialog<void>(
    context: context,
    builder: (context) => const SignalPathInspectorDialog(),
  );
}

/// 全透明声学信号链检视器弹窗 (Signal Path Inspector Dialog)
class SignalPathInspectorDialog extends StatelessWidget {
  const SignalPathInspectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: playback.wasapiExclusive,
      builder: (context, exclusive, _) {
        return ValueListenableBuilder<double>(
          valueListenable: playback.volumeDspNotifier,
          builder: (context, volume, _) {
            final snapshot = SignalPathSnapshot.fromState(
              audio: playback.nowPlaying,
              wasapiExclusive: exclusive,
              perceptualVolume: volume,
              replayGainEnabled: AppSettings.instance.enableReplayGain,
              preampDb: AppSettings.instance.replayGainPreampDb,
            );
            final orbColor = snapshot.resolveIndicatorColor(scheme);

            return ModernDialogFrame(
              key: const ValueKey('signal-path-inspector-dialog'),
              width: 560,
              maxHeight: 640,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _SignalGlowOrb(color: orbColor, size: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '声学信号链检视器 · Signal Path',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              snapshot.qualityLabel,
                              style: TextStyle(
                                color: orbColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('signal-path-close-button'),
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Symbols.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 节点 1：本地音源与物理介质层
                          _SignalNodeCard(
                            index: '01',
                            title: '本地源媒体解码层 · Source Stream',
                            subtitle: playback.nowPlaying?.displayTitle ??
                                '未加载曲目（待机状态）',
                            icon: Symbols.album_rounded,
                            accentColor: orbColor,
                            badges: [
                              snapshot.formatExtension,
                              if (snapshot.sampleRateHz != null &&
                                  snapshot.sampleRateHz! > 0)
                                '${(snapshot.sampleRateHz! / 1000.0).toStringAsFixed(1)} kHz',
                              if (snapshot.bitrateKbps != null &&
                                  snapshot.bitrateKbps! > 0)
                                '${snapshot.bitrateKbps} kbps',
                              snapshot.isLossless ? '无损源码验证' : '有损心理声学编码',
                              if (snapshot.isHiRes) 'Hi-Res 高解析度',
                              if (snapshot.isCueTrack) 'CUE 镜像精准分轨',
                            ],
                          ),
                          _SignalConnectorLine(color: orbColor),
                          // 节点 2：声学响度与感知曲线 DSP 层
                          _SignalNodeCard(
                            index: '02',
                            title: '人耳听觉感知 DSP · Perceptual Engine',
                            subtitle:
                                'Stevens 幂律三次曲线 (a = p³) 与 ReplayGain 响度均衡',
                            icon: Symbols.graphic_eq_rounded,
                            accentColor: scheme.primary,
                            badges: [
                              '感知音量 ${(snapshot.perceptualVolume * 100).round()}%',
                              '物理振幅 ${(snapshot.physicalAmplitude * 100).toStringAsFixed(1)}%',
                              '衰减 ${snapshot.attenuationDb.toStringAsFixed(1)} dB',
                              if (snapshot.replayGainEnabled)
                                'ReplayGain ${snapshot.replayGainDb != null ? "${snapshot.replayGainDb!.toStringAsFixed(1)} dB" : "待机"}'
                              else
                                'ReplayGain 直通关闭',
                            ],
                          ),
                          _SignalConnectorLine(color: orbColor),
                          // 节点 3：WASAPI 硬件终端层
                          LensGlassSurface(
                            borderRadius: 18,
                            enableBackdropBlur: false,
                            tintColor: orbColor,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: orbColor.withValues(
                                      alpha: isDark ? 0.20 : 0.14,
                                    ),
                                  ),
                                  child: Icon(
                                    exclusive
                                        ? Symbols.lock_rounded
                                        : Symbols.speaker_rounded,
                                    color: orbColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exclusive
                                            ? '03 · WASAPI 独占硬件时钟直通'
                                            : '03 · WASAPI 系统共享混音终端',
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        exclusive
                                            ? '绕过 Windows 系统内核混音器重采样，直接锁定声卡原生硬件采样率'
                                            : '经由系统音频引擎混合输出，兼容桌面多应用同时发声',
                                        style: TextStyle(
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.72),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.tonalIcon(
                                  key: const ValueKey(
                                    'signal-path-toggle-exclusive-btn',
                                  ),
                                  onPressed: () =>
                                      playback.useExclusiveMode(!exclusive),
                                  icon: Icon(
                                    exclusive
                                        ? Symbols.lock_open_rounded
                                        : Symbols.lock_rounded,
                                    size: 16,
                                  ),
                                  label: Text(exclusive ? '切回共享' : '开启独占'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SignalGlowOrb extends StatelessWidget {
  const _SignalGlowOrb({required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.65),
            blurRadius: 10,
            spreadRadius: 1.5,
          ),
        ],
      ),
    );
  }
}

class _SignalConnectorLine extends StatelessWidget {
  const _SignalConnectorLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 34),
        child: Container(
          width: 2,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.65),
                color.withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalNodeCard extends StatelessWidget {
  const _SignalNodeCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badges,
  });

  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.26 : 0.20),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                ),
                child: Icon(icon, color: accentColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index · $title',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final badge in badges)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: accentColor.withValues(alpha: isDark ? 0.14 : 0.09),
                      border: Border.all(
                        color:
                            accentColor.withValues(alpha: isDark ? 0.30 : 0.22),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.90),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
