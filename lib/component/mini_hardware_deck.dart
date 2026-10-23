import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/marquee_text.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/component/signal_path_inspector.dart';
import 'package:qisheng_player/component/ui/lens_glass_surface.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/utils.dart';

/// 桌面微缩唱机态全局开关控制器 (Mini Hardware Deck Mode Controller)
class MiniHardwareDeckController extends ValueNotifier<bool> {
  MiniHardwareDeckController._() : super(false);

  static final MiniHardwareDeckController instance =
      MiniHardwareDeckController._();

  void toggle() => value = !value;
}

/// 工业拟物桌面微缩唱机挂件 (Tactile Mini Hardware Deck Overlay)
/// 融合博朗 (Braun) 极简工业仪表、黑胶唱臂物理摆角、16 段 LED 实时频谱电平表与等宽时间码读数。
class MiniHardwareDeckOverlay extends StatefulWidget {
  const MiniHardwareDeckOverlay({super.key});

  @override
  State<MiniHardwareDeckOverlay> createState() =>
      _MiniHardwareDeckOverlayState();
}

class _MiniHardwareDeckOverlayState extends State<MiniHardwareDeckOverlay>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = const Offset(24, 72);
  late final AnimationController _platterController;

  @override
  void initState() {
    super.initState();
    _platterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _platterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MiniHardwareDeckController.instance,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();

        final viewport = MediaQuery.sizeOf(context);
        final clampedX = _dragOffset.dx
            .clamp(12.0, math.max(12.0, viewport.width - 392.0))
            .toDouble();
        final clampedY = _dragOffset.dy
            .clamp(56.0, math.max(56.0, viewport.height - 208.0))
            .toDouble();

        return Positioned(
          left: clampedX,
          top: clampedY,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _dragOffset = Offset(
                  clampedX + details.delta.dx,
                  clampedY + details.delta.dy,
                );
              });
            },
            child: _MiniHardwareDeckCard(
              platterAnimation: _platterController,
              onClose: () => MiniHardwareDeckController.instance.value = false,
            ),
          ),
        );
      },
    );
  }
}

class _MiniHardwareDeckCard extends StatelessWidget {
  const _MiniHardwareDeckCard({
    required this.platterAnimation,
    required this.onClose,
  });

  final Animation<double> platterAnimation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final isDark = scheme.brightness == Brightness.dark;
    final audio = playback.nowPlaying;

    return StreamBuilder<PlayerState>(
      stream: playback.playerStateStream,
      initialData: playback.playerState,
      builder: (context, stateSnap) {
        final isPlaying = stateSnap.data == PlayerState.playing;

        return SizedBox(
          key: const ValueKey('mini-hardware-deck-card'),
          width: 376,
          height: 172,
          child: LensGlassSurface(
            borderRadius: 24,
            refractionStrength: 1.35,
            blurSigma: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                // 左侧：黑胶转盘 + 拟物唱臂 (Vinyl Platter & Tonearm)
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 铝合金唱盘底座外环
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF1A1E26),
                              const Color(0xFF0D1016),
                              accents.accent.withValues(alpha: 0.25),
                            ],
                            stops: const [0.0, 0.86, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                      // 旋转黑胶唱片纹理与中心画芯
                      AnimatedBuilder(
                        animation: platterAnimation,
                        builder: (context, child) {
                          final angle = isPlaying
                              ? platterAnimation.value * math.pi * 2
                              : 0.0;
                          return Transform.rotate(
                            angle: angle,
                            child: child,
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(98, 98),
                              painter: _VinylGroovePainter(
                                accentColor: accents.accent,
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: ClipOval(
                                child: NowPlayingArtworkCard(
                                  audio: audio,
                                  coverProvider:
                                      NowPlayingArtworkCard.getSyncCover(audio),
                                  radius: 24,
                                  showShadow: false,
                                ),
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE5E7EB),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 机械唱臂 (播放时平滑切入音轨槽，暂停时归位)
                      Positioned(
                        top: 2,
                        right: -2,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            end: isPlaying ? 0.36 : 0.04,
                          ),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          builder: (context, angle, _) {
                            return Transform.rotate(
                              angle: angle,
                              alignment: const Alignment(0.6, -0.75),
                              child: CustomPaint(
                                size: const Size(36, 76),
                                painter: _TonearmPainter(
                                  accentColor: accents.accent,
                                  isDark: isDark,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // 右侧：工业仪表读数、实时 VU 频谱柱与微动量机械按键
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 顶部状态栏：HARDWARE DECK 铭牌 + 信号链指示灯 + 关闭按钮
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => unawaited(
                              showSignalPathInspector(context),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: accents.accent.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: accents.accent.withValues(alpha: 0.32),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.5,
                                    height: 5.5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accents.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DECK · 01',
                                    style: TextStyle(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.88),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          StreamBuilder<double>(
                            stream: playback.positionStream,
                            initialData: playback.position,
                            builder: (context, posSnap) {
                              final posSec = (posSnap.data ?? 0).round();
                              return Text(
                                Duration(seconds: posSec).toStringHMMSS(),
                                style: TextStyle(
                                  color: accents.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            key: const ValueKey('mini-deck-close-btn'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onClose,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Symbols.close_fullscreen_rounded,
                                  size: 15,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.68),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 曲目与歌手铭牌
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarqueeText(
                            text: audio?.displayTitle ?? '栖声唱机待机中',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            audio?.displayArtist ?? '拖拽面板任意位置可自由摆放',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.68),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // 16 段实时 LED 电平频谱表 (Live VU Meter)
                      SizedBox(
                        height: 18,
                        child: ValueListenableBuilder<List<double>>(
                          valueListenable: playback.audioSpectrum,
                          builder: (context, spectrum, _) {
                            return CustomPaint(
                              size: const Size(double.infinity, 18),
                              painter: _MiniVuMeterPainter(
                                spectrum: spectrum,
                                activeColor: accents.accent,
                                inactiveColor:
                                    scheme.onSurface.withValues(alpha: 0.12),
                              ),
                            );
                          },
                        ),
                      ),
                      // 底部拟物机械播控簇
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CpIconButton(
                            variant: CpButtonVariant.immersive,
                            size: const Size(32, 32),
                            onPressed: playback.lastAudio,
                            icon: const Icon(
                              Symbols.skip_previous_rounded,
                              size: 18,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            key: const ValueKey('mini-deck-play-btn'),
                            onPressed: isPlaying
                                ? playback.pause
                                : playback.start,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              minimumSize: const Size(84, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              isPlaying
                                  ? Symbols.pause_rounded
                                  : Symbols.play_arrow_rounded,
                              size: 17,
                            ),
                            label: Text(
                              isPlaying ? 'PAUSE' : 'PLAY',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          CpIconButton(
                            variant: CpButtonVariant.immersive,
                            size: const Size(32, 32),
                            onPressed: playback.nextAudio,
                            icon: const Icon(
                              Symbols.skip_next_rounded,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VinylGroovePainter extends CustomPainter {
  const _VinylGroovePainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;

    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.09);

    for (var r = maxR * 0.56; r < maxR * 0.96; r += 3.2) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // 唱片表面各向异性斜向光泽反光扇区
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          accentColor.withValues(alpha: 0.18),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.48, 0.74, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, maxR * 0.96, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

class _TonearmPainter extends CustomPainter {
  const _TonearmPainter({
    required this.accentColor,
    required this.isDark,
  });

  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.76, size.height * 0.12);
    final elbow = Offset(size.width * 0.64, size.height * 0.68);
    final head = Offset(size.width * 0.36, size.height * 0.90);

    // 唱臂转轴底座
    canvas.drawCircle(
      pivot,
      7.5,
      Paint()
        ..color = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
    );
    canvas.drawCircle(
      pivot,
      4.0,
      Paint()..color = accentColor,
    );

    // 金属唱臂杆
    final armPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(head.dx, head.dy);
    canvas.drawPath(
      armPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563),
    );

    // 唱头
    canvas.drawCircle(
      head,
      3.4,
      Paint()..color = accentColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor || oldDelegate.isDark != isDark;
}

class _MiniVuMeterPainter extends CustomPainter {
  const _MiniVuMeterPainter({
    required this.spectrum,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> spectrum;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 20;
    const gap = 3.0;
    final barWidth =
        ((size.width - gap * (barCount - 1)) / barCount).clamp(2.0, 12.0);

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap);
      var level = 0.12;
      if (spectrum.isNotEmpty) {
        final idx = (i * spectrum.length / barCount)
            .floor()
            .clamp(0, spectrum.length - 1);
        final v = spectrum[idx];
        if (v.isFinite) {
          level = (0.14 + v * 0.86).clamp(0.14, 1.0);
        }
      }
      final barHeight = size.height * level;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barWidth, size.height),
          const Radius.circular(2),
        ),
        Paint()..color = inactiveColor,
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = level > 0.78
              ? Color.lerp(activeColor, const Color(0xFFF59E0B), 0.45)!
              : activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniVuMeterPainter oldDelegate) =>
      oldDelegate.spectrum != spectrum ||
      oldDelegate.activeColor != activeColor;
}
