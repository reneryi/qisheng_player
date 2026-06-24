// ignore_for_file: unused_element

part of 'page.dart';

class _NowPlayingMetadataBadgeData {
  const _NowPlayingMetadataBadgeData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _DashboardCreditEntry {
  const _DashboardCreditEntry({
    required this.role,
    required this.name,
  });

  final String role;
  final String name;
}

List<_NowPlayingMetadataBadgeData> _buildMetadataBadges(Audio audio) {
  final badges = <_NowPlayingMetadataBadgeData>[
    _NowPlayingMetadataBadgeData(
      icon: Symbols.music_note,
      label: audio.fileExtension,
    ),
  ];

  if (audio.sampleRate != null && audio.sampleRate! > 0) {
    final sampleRate = audio.sampleRate!;
    final khz = sampleRate / 1000.0;
    badges.add(
      _NowPlayingMetadataBadgeData(
        icon: Symbols.graph_1,
        label: sampleRate % 1000 == 0
            ? '${khz.toStringAsFixed(0)}kHz'
            : '${khz.toStringAsFixed(1)}kHz',
      ),
    );
  }

  if (audio.bitrate != null && audio.bitrate! > 0) {
    badges.add(
      _NowPlayingMetadataBadgeData(
        icon: Symbols.tune,
        label: '${audio.bitrate}kbps',
      ),
    );
  }

  if (audio.replayGainDb != null) {
    badges.add(
      _NowPlayingMetadataBadgeData(
        icon: Symbols.equalizer,
        label: 'RG ${audio.replayGainDb!.toStringAsFixed(1)}dB',
      ),
    );
  }

  if (audio.by != null && audio.by!.trim().isNotEmpty) {
    badges.add(
      _NowPlayingMetadataBadgeData(
        icon: Symbols.sell,
        label: audio.by!,
      ),
    );
  }

  return badges;
}

List<String> _splitCreditNames(String? raw) {
  if (raw == null) return const [];
  return raw
      .split(RegExp(AppSettings.instance.artistSplitPattern))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && item != 'UNKNOWN' && item != '未知艺术家')
      .toList();
}

List<_DashboardCreditEntry> _buildCreditEntries(Audio audio) {
  final entries = <_DashboardCreditEntry>[];

  for (final composer in _splitCreditNames(audio.composer)) {
    entries.add(_DashboardCreditEntry(role: '作曲', name: composer));
  }
  for (final arranger in _splitCreditNames(audio.arranger)) {
    entries.add(_DashboardCreditEntry(role: '编曲', name: arranger));
  }

  return entries;
}

String _buildArtistAlbumLine(Audio audio) {
  final artist = audio.displayArtist;
  final album = audio.displayAlbum;
  if (!audio.hasKnownAlbum || album == artist || album == audio.displayTitle) {
    return artist;
  }
  return '$artist · $album';
}

class _ImmersiveModeView extends StatelessWidget {
  const _ImmersiveModeView({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 恢复极致沉浸体验：移去在背景与内容之间的半透明卡片遮罩，直接让底层的流光动态渐变透出来
        const Positioned.fill(
          child: AbsorbPointer(
            child: SizedBox.expand(),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.fromLTRB(compact ? 16 : 28, 12, compact ? 16 : 28, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = compact ||
                  constraints.maxWidth < 1160 ||
                  MediaQuery.sizeOf(context).height < 760;
              final gap = compact ? 24.0 : 32.0;

              if (stacked) {
                // 垂直堆叠下：封面精致收小在上，大歌词在下
                return Column(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: _ImmersiveArtworkStage(compact: true),
                    ),
                    SizedBox(height: gap),
                    const Expanded(
                      flex: 6,
                      child: _ImmersiveLyricStage(compact: true),
                    ),
                  ],
                );
              }

              // 杂志级排版大歌词流：左侧放置占比 4 的精致小封面与歌曲信息，右侧放置占比 6 的大歌词
              return Row(
                children: [
                  const Expanded(
                    flex: 4,
                    child: _ImmersiveArtworkStage(compact: false),
                  ),
                  SizedBox(width: gap),
                  const Expanded(
                    flex: 6,
                    child: _ImmersiveLyricStage(compact: false),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StudioDashboardView extends StatelessWidget {
  const _StudioDashboardView({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(compact ? 16 : 28, 12, compact ? 16 : 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(compact: compact),
          const SizedBox(height: 24),
          const _StudioMetadataStrip(),
          SizedBox(height: compact ? 24 : 28),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = compact ||
                    constraints.maxWidth < 1220 ||
                    constraints.maxHeight < 720;
                final gap = compact ? 24.0 : 28.0;

                if (stacked) {
                  return Column(
                    children: [
                      const Expanded(
                        flex: 5,
                        child: _StudioInformationPanel(compact: true),
                      ),
                      SizedBox(height: gap),
                      const Expanded(
                        flex: 6,
                        child: _StudioQueuePanel(compact: true),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Expanded(
                      flex: 5,
                      child: _StudioInformationPanel(compact: false),
                    ),
                    SizedBox(width: gap),
                    const Expanded(
                      flex: 7,
                      child: _StudioQueuePanel(compact: false),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '专业面板',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: compact ? 28 : 32,
            fontWeight: FontWeight.w700,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '更清晰的元数据、幕后信息和当前播放队列。',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.6),
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _StudioMetadataStrip extends StatelessWidget {
  const _StudioMetadataStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        if (audio == null) {
          return Text(
            '还没有正在播放的音频。',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          );
        }

        final badges = _buildMetadataBadges(audio);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final badge in badges)
              _MetadataBadge(icon: badge.icon, label: badge.label),
          ],
        );
      },
    );
  }
}

class _MetadataBadge extends StatefulWidget {
  const _MetadataBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  State<_MetadataBadge> createState() => _MetadataBadgeState();
}

class _MetadataBadgeState extends State<_MetadataBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: context.motion.controlTransitionDuration,
        curve: context.motion.normal,
        opacity: _hovered ? 1 : 0.52,
        child: AnimatedContainer(
          duration: context.motion.controlTransitionDuration,
          curve: context.motion.normal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: _hovered ? 0.11 : 0.055),
                scheme.primary.withValues(alpha: _hovered ? 0.08 : 0.035),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovered ? 0.16 : 0.07),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.74),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.76),
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioInformationPanel extends StatelessWidget {
  const _StudioInformationPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      variant: AppSurfaceVariant.glass,
      glassDensity: AppSurfaceGlassDensity.low,
      radius: 24,
      padding: EdgeInsets.all(compact ? 18 : 22),
      child: Selector<PlaybackController, Audio?>(
        selector: (_, playback) => playback.nowPlaying,
        builder: (context, audio, _) {
          if (audio == null) {
            return const _EmptyPanelState(
              title: '暂无歌曲信息',
              subtitle: '开始播放一首歌后，这里会展示封面和幕后人员。',
            );
          }

          final credits = _buildCreditEntries(audio);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeader(
                title: '歌曲信息',
                subtitle: '封面、演唱信息与幕后人员',
              ),
              const SizedBox(height: 22),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scrollable = compact || constraints.maxHeight < 420;
                    final artworkMin = scrollable ? 96.0 : 132.0;
                    final artworkMax = scrollable ? 132.0 : 164.0;
                    final artworkSize =
                        (constraints.biggest.shortestSide * 0.42)
                            .clamp(
                              compact ? artworkMin : 164.0,
                              compact ? artworkMax : 220.0,
                            )
                            .toDouble();
                    final creditsPanel = AppSurface(
                      variant: AppSurfaceVariant.inset,
                      radius: 22,
                      padding: const EdgeInsets.all(14),
                      child: credits.isEmpty
                          ? const _EmptyPanelState(
                              title: '暂无幕后信息',
                              subtitle: '当前音频没有录入作曲或编曲信息。',
                            )
                          : scrollable
                              ? Column(
                                  children: [
                                    for (int index = 0;
                                        index < credits.length;
                                        index++) ...[
                                      _CreditEntryRow(entry: credits[index]),
                                      if (index != credits.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                  ],
                                )
                              : Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        for (int index = 0;
                                            index < credits.length;
                                            index++) ...[
                                          _CreditEntryRow(
                                            entry: credits[index],
                                          ),
                                          if (index != credits.length - 1)
                                            const SizedBox(height: 12),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                    );

                    final mainContent = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          scrollable ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: artworkSize + (scrollable ? 36 : 56),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: _ArtworkStageHitAbsorber(),
                              ),
                              Center(
                                child: _NowPlayingArtwork(
                                  size: artworkSize,
                                  radius: 28,
                                  large: true,
                                  showBackdropGlow: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: scrollable ? 14 : 20),
                        _MarqueeText(
                          text: audio.displayTitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w700,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _buildArtistAlbumLine(audio),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppSurface(
                          variant: AppSurfaceVariant.inset,
                          radius: 20,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Text(
                            audio.qualitySummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54),
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        SizedBox(height: scrollable ? 16 : 22),
                        Text(
                          '幕后人员',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (scrollable)
                          creditsPanel
                        else
                          Expanded(child: creditsPanel),
                      ],
                    );

                    if (scrollable) {
                      return SingleChildScrollView(child: mainContent);
                    }

                    return mainContent;
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreditEntryRow extends StatelessWidget {
  const _CreditEntryRow({required this.entry});

  final _DashboardCreditEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            entry.role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            entry.name,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioQueuePanel extends StatelessWidget {
  const _StudioQueuePanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return AppSurface(
      variant: AppSurfaceVariant.glass,
      glassDensity: AppSurfaceGlassDensity.low,
      radius: 24,
      padding: EdgeInsets.all(compact ? 18 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<List<Audio>>(
            valueListenable: playback.playlist,
            builder: (context, playlist, _) {
              return _PanelHeader(
                title: '播放队列',
                subtitle: '${playlist.length} 首歌曲，当前队列可拖拽重排',
              );
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CurrentPlaylistView(
              showHeader: false,
              dense: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ImmersiveArtworkStage extends StatelessWidget {
  const _ImmersiveArtworkStage({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 极简主义设计：非小屏下由原本的 200 放大至 320 像素以呈现海报感，小屏 120 像素
        final size = compact ? 120.0 : 320.0;

        return SizedBox.expand(
          child: Stack(
            children: [
              const Positioned.fill(child: _ArtworkStageHitAbsorber()),
              Align(
                // 大屏下整体居中对齐以展现海报式视觉美感，小屏则靠左对齐
                alignment: compact ? Alignment.centerLeft : Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    _NowPlayingArtwork(
                      size: size,
                      radius: compact ? 14 : 24, // 大屏下圆角适当增大，让界面更加圆润美观
                      large: true,
                      showBackdropGlow: false, // 去除臃肿的背景毛玻璃光晕，恢复极简纯净
                    ),
                    SizedBox(height: compact ? 12 : 24), // 微调纵向间距为 24 像素，增加呼吸感
                    _NowPlayingStagedReveal(
                      begin: 0.24,
                      end: 0.68,
                      beginOffset: const Offset(0, 0.06),
                      child: _NowPlayingTrackIdentity(compact: compact),
                    ),
                    const SizedBox(height: 8), // 微调纵向间距，增加高度缓冲
                    // 引入极简高质感的音频参数元数据行
                    const _NowPlayingStagedReveal(
                      begin: 0.3,
                      end: 0.75,
                      child: _ImmersiveMetadataStrip(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 极简主义画册排版：以超细细体文字左对齐显示音频格式、采样率与比特率参数
class _ImmersiveMetadataStrip extends StatelessWidget {
  const _ImmersiveMetadataStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        if (audio == null) return const SizedBox.shrink();
        final rate = audio.sampleRate != null ? '${(audio.sampleRate! / 1000).toStringAsFixed(1)}kHz' : '';
        final bit = audio.bitrate != null ? '${audio.bitrate}kbps' : '';
        final ext = audio.fileExtension.toUpperCase();
        return Text(
          '$ext · $rate · $bit',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.46),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.8,
          ),
        );
      },
    );
  }
}

class _NowPlayingTrackIdentity extends StatelessWidget {
  const _NowPlayingTrackIdentity({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Align(
            // 大屏下整体居中对齐以和封面居中保持对称，小屏则左对齐
            alignment: compact ? Alignment.centerLeft : Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Text(
                  audio?.displayTitle ?? '正在播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: compact ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: compact ? 22 : 30, // 非 compact 模式下歌曲标题字号调大至 30 像素，更显大气
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                    decorationThickness: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  audio?.displayArtist ?? '暂无播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: compact ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.64),
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w400,
                    height: 1.18,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                    decorationThickness: 0,
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

class _ArtworkStageHitAbsorber extends StatelessWidget {
  const _ArtworkStageHitAbsorber();

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(child: SizedBox.expand());
  }
}

class _NowPlayingArtwork extends StatelessWidget {
  const _NowPlayingArtwork({
    required this.size,
    required this.radius,
    required this.large,
    required this.showBackdropGlow,
  });

  final double size;
  final double radius;
  final bool large;
  final bool showBackdropGlow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    final effectsLevel = context.surfaces.effectsLevel;

    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        final useLargeCover = large && effectsLevel == UiEffectsLevel.visual;
        final enableBackdropGlow =
            showBackdropGlow && effectsLevel == UiEffectsLevel.visual;
        final future = audio == null
            ? null
            : (useLargeCover ? audio.largeCover : audio.mediumCover);

        return FutureBuilder<ImageProvider<Object>?>(
          future: future,
          builder: (context, snapshot) {
            final provider = snapshot.data;
            final placeholder = DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                provider == null ? Symbols.music_note : Symbols.broken_image,
                color: scheme.onSurface.withValues(alpha: 0.62),
                size: size * 0.24,
              ),
            );

            Widget image(ImageProvider<Object> imageProvider) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Image(
                  image: imageProvider,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
              );
            }

            final mainImage = provider == null ? placeholder : image(provider);
            final imageKey = ValueKey(
              '${audio?.path ?? 'empty'}:${provider.hashCode}:${size.round()}',
            );
            final heroArtwork = NowPlayingArtworkHeroFrame(
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: motion.controlTransitionDuration,
                  switchInCurve: motion.normal,
                  switchOutCurve: motion.fast,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: motion.normal,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale:
                            Tween<double>(begin: 0.975, end: 1).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(key: imageKey, child: mainImage),
                ),
              ),
            );

            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (enableBackdropGlow && provider != null)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(size * 0.08),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Transform.scale(
                            scale: 1.08,
                            child: Opacity(
                              opacity: 0.58,
                              child: image(provider),
                            ),
                          ),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: accents.accentGlow.withValues(alpha: 0.34),
                          blurRadius: enableBackdropGlow ? 32 : 18,
                          spreadRadius: enableBackdropGlow ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Hero(
                      tag: nowPlayingArtworkHeroTag,
                      // 使用自定义的高抛弧线 Tween，让飞跃轨迹极其显著
                      createRectTween: (begin, end) =>
                          CustomIntenseArcTween(begin: begin, end: end),
                      flightShuttleBuilder:
                          nowPlayingArtworkFlightShuttleBuilder,
                      child: heroArtwork,
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

class _ImmersiveLyricStage extends StatelessWidget {
  const _ImmersiveLyricStage({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final useLegacyLyricView =
        context.read<PlaybackController>() is PlaybackService &&
            context.read<LyricController>() is LyricService;
    if (useLegacyLyricView) {
      return const _NowPlayingStagedReveal(
        begin: 0.34,
        end: 0.9,
        beginOffset: Offset(0, 0.05),
        child: VerticalLyricView(),
      );
    }
    final lyricController = context.read<LyricController>();
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: lyricController,
      builder: (context, _) {
        return FutureBuilder<Lyric?>(
          future: lyricController.currLyricFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _NowPlayingStagedReveal(
                begin: 0.34,
                end: 0.9,
                beginOffset: Offset(0, 0.05),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final lyric = snapshot.data;
            if (lyric == null || lyric.lines.isEmpty) {
              return _NowPlayingStagedReveal(
                begin: 0.34,
                end: 0.9,
                beginOffset: const Offset(0, 0.05),
                child: Center(
                  child: Text(
                    '暂无歌词',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: compact ? 22 : 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            return _NowPlayingStagedReveal(
              begin: 0.34,
              end: 0.9,
              beginOffset: const Offset(0, 0.05),
              child: _CenteredLyricView(lyric: lyric, compact: compact),
            );
          },
        );
      },
    );
  }
}

class _CenteredLyricView extends StatefulWidget {
  const _CenteredLyricView({
    required this.lyric,
    required this.compact,
  });

  final Lyric lyric;
  final bool compact;

  @override
  State<_CenteredLyricView> createState() => _CenteredLyricViewState();
}

class _CenteredLyricViewState extends State<_CenteredLyricView> {
  late final PlaybackController playbackService;
  late final LyricController lyricService;
  final ScrollController scrollController = ScrollController();
  late StreamSubscription<int> lyricLineStreamSubscription;

  int _currentLineIndex = 0;

  double get _primaryFontSize => widget.compact ? 28 : 36; // 杂志级排版：主歌词字号调大至 36
  double get _secondaryFontSize => widget.compact ? 18 : 22; // 杂志级排版：副歌词字号调大至 22
  double get _translationFontSize => widget.compact ? 14 : 16;
  double get _verticalPadding => widget.compact ? 140 : 200;

  @override
  void initState() {
    super.initState();
    playbackService = context.read<PlaybackController>();
    lyricService = context.read<LyricController>();
    _currentLineIndex = lyricService.currentLyricLineIndex;
    lyricLineStreamSubscription =
        lyricService.lyricLineStream.listen(_handleLyricLineChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToLine(_currentLineIndex, animated: false);
    });
  }

  void _handleLyricLineChange(int index) {
    if (!mounted || widget.lyric.lines.isEmpty) return;
    final safeIndex = index.clamp(0, widget.lyric.lines.length - 1).toInt();
    if (_currentLineIndex == safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToLine(safeIndex);
      });
      return;
    }
    setState(() {
      _currentLineIndex = safeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToLine(safeIndex);
    });
  }

  @override
  void didUpdateWidget(covariant _CenteredLyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyric == widget.lyric) return;
    _currentLineIndex = widget.lyric.lines.isEmpty
        ? 0
        : lyricService.currentLyricLineIndex
            .clamp(0, widget.lyric.lines.length - 1)
            .toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToLine(_currentLineIndex, animated: false);
    });
  }

  String _primaryText(LyricLine line) {
    if (line is SyncLyricLine) {
      return line.content;
    }
    if (line is LrcLine) {
      return line.content.split('┃').first;
    }
    return '';
  }

  bool _showTranslation(LyricLine line) {
    if (!AppPreference.instance.nowPlayingPagePref.showTranslation) {
      return false;
    }
    return _translationText(line).trim().isNotEmpty;
  }

  String _translationText(LyricLine line) {
    if (line is SyncLyricLine) {
      return line.translation ?? '';
    }
    if (line is LrcLine) {
      final parts = line.content.split('┃');
      return parts.length > 1 ? parts.skip(1).join(' ') : '';
    }
    return '';
  }

  double _estimatedLineHeight(LyricLine line, {required bool isCurrent}) {
    final base = isCurrent
        ? (widget.compact ? 88.0 : 104.0)
        : (widget.compact ? 56.0 : 68.0);
    return _showTranslation(line)
        ? base + (widget.compact ? 28.0 : 32.0)
        : base;
  }

  double _estimatedOffsetBefore(int index) {
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _estimatedLineHeight(
        widget.lyric.lines[i],
        isCurrent: i == _currentLineIndex,
      );
    }
    return offset;
  }

  void _scrollToLine(int index, {bool animated = true, int attempt = 0}) {
    if (widget.lyric.lines.isEmpty) return;
    if (index < 0 || index >= widget.lyric.lines.length) return;
    if (!scrollController.hasClients) {
      _retryScrollToLine(index, animated: animated, attempt: attempt);
      return;
    }

    final estimatedCurrentHeight = _estimatedLineHeight(
      widget.lyric.lines[index],
      isCurrent: true,
    );
    final target = _estimatedOffsetBefore(index) +
        estimatedCurrentHeight / 2 -
        scrollController.position.viewportDimension / 2 +
        _verticalPadding;
    final max = scrollController.position.maxScrollExtent;
    final resolved = target.clamp(0.0, max).toDouble();
    if (animated) {
      scrollController.animateTo(
        resolved,
        duration: context.motion.lyricScrollDuration,
        curve: context.motion.emphasized,
      );
      return;
    }
    scrollController.jumpTo(resolved);
  }

  void _retryScrollToLine(
    int index, {
    required bool animated,
    required int attempt,
  }) {
    if (attempt >= 3) return;
    Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)), () {
      if (!mounted) return;
      _scrollToLine(index, animated: animated, attempt: attempt + 1);
    });
  }

  double _lineOpacity({required int index, required bool isCurrent}) {
    if (isCurrent) return 1.0;
    // 极简奢华对比：已播放过的歌词显示 0.32 不透明度，未播放的使用较淡的 0.22，清晰区隔当前行
    return index < _currentLineIndex ? 0.32 : 0.22;
  }

  Color _lineColor(
    ColorScheme scheme, {
    required int index,
    required bool isCurrent,
  }) {
    if (isCurrent) return scheme.onSurface;
    return scheme.onSurface.withValues(
      alpha: index < _currentLineIndex ? 0.78 : 0.62,
    );
  }

  Widget _primaryLineWidget({
    required LyricLine line,
    required bool isCurrent,
    required Color lineColor,
    required ColorScheme scheme,
  }) {
    final motion = context.motion;
    final style = TextStyle(
      color: lineColor,
      fontSize: isCurrent ? _primaryFontSize : _secondaryFontSize,
      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600, // 高对比字重
      height: 1.15,
      shadows: isCurrent
          ? [
              Shadow(
                color: scheme.primary.withValues(alpha: 0.18), // 减淡阴影光晕
                blurRadius: 12,
              ),
            ]
          : null,
    );

    if (isCurrent && line is SyncLyricLine && line.words.isNotEmpty) {
      return StreamBuilder<double>(
        stream: playbackService.positionStream,
        initialData: playbackService.position,
        builder: (context, snapshot) {
          final positionMs =
              ((snapshot.data ?? playbackService.position) * 1000)
                  .roundToDouble();
          return RichText(
            textAlign: TextAlign.left, // 杂志排版：居左对齐
            text: TextSpan(
              children: [
                for (final word in line.words)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        final lengthMs = word.length.inMilliseconds;
                        final progress = lengthMs <= 0
                            ? (positionMs >= word.start.inMilliseconds
                                ? 1.0
                                : 0.0)
                            : ((positionMs - word.start.inMilliseconds) /
                                    lengthMs)
                                .clamp(0.0, 1.0)
                                .toDouble();
                        return LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary,
                            lineColor.withValues(alpha: 0.42),
                            lineColor.withValues(alpha: 0.42),
                          ],
                          stops: [0, progress, progress, 1],
                        ).createShader(bounds);
                      },
                      child: Text(word.content, style: style, textAlign: TextAlign.left),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return AnimatedDefaultTextStyle(
      duration: motion.controlTransitionDuration,
      curve: motion.normal,
      style: style,
      textAlign: TextAlign.left, // 杂志排版：居左对齐
      child: Text(
        _primaryText(line),
        textAlign: TextAlign.left,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              vertical: _verticalPadding,
              horizontal: widget.compact ? 20 : 48, // 增加左侧缩进呼吸空间
            ),
            itemCount: widget.lyric.lines.length,
            itemBuilder: (context, index) {
              final line = widget.lyric.lines[index];
              final isCurrent = index == _currentLineIndex;
              final translation = _translationText(line);
              final lineColor = _lineColor(
                scheme,
                index: index,
                isCurrent: isCurrent,
              );

              return AnimatedOpacity(
                duration: motion.controlTransitionDuration,
                curve: motion.fast,
                opacity: _lineOpacity(index: index, isCurrent: isCurrent),
                child: AnimatedScale(
                  duration: motion.controlTransitionDuration,
                  curve: motion.normal,
                  scale: isCurrent ? 1 : 0.982,
                  child: InkWell(
                    enableFeedback: false,
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      playbackService.seek(line.start.inMilliseconds / 1000.0);
                    },
                    child: AnimatedPadding(
                      duration: motion.controlTransitionDuration,
                      curve: motion.normal,
                      padding: EdgeInsets.symmetric(
                        vertical: isCurrent ? 16 : 10,
                        horizontal: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // 杂志排版：歌词左对齐
                        children: [
                          _primaryLineWidget(
                            line: line,
                            isCurrent: isCurrent,
                            lineColor: lineColor,
                            scheme: scheme,
                          ),
                          if (_showTranslation(line)) ...[
                            const SizedBox(height: 8),
                            AnimatedDefaultTextStyle(
                              duration: motion.controlTransitionDuration,
                              curve: motion.fast,
                              style: TextStyle(
                                color: isCurrent
                                    ? scheme.onSurface.withValues(alpha: 0.74)
                                    : lineColor.withValues(alpha: 0.74),
                                fontSize: _translationFontSize,
                                fontWeight: FontWeight.w400,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.left, // 翻译行左对齐
                              child: Text(
                                translation,
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
    super.dispose();
  }
}

class _EmptyPanelState extends StatelessWidget {
  const _EmptyPanelState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.music_note,
            size: 28,
            color: scheme.onSurface.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.58),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
