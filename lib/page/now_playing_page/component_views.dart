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
      .where((item) => item.isNotEmpty && item != 'UNKNOWN')
      .toList();
}

List<_DashboardCreditEntry> _buildCreditEntries(Audio audio) {
  final entries = <_DashboardCreditEntry>[];

  for (final composer in _splitCreditNames(audio.composer)) {
    entries.add(_DashboardCreditEntry(role: 'Composed by', name: composer));
  }
  for (final arranger in _splitCreditNames(audio.arranger)) {
    entries.add(_DashboardCreditEntry(role: 'Arranged by', name: arranger));
  }

  return entries;
}

class _ImmersiveModeView extends StatelessWidget {
  const _ImmersiveModeView({
    required this.compact,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(compact ? 16 : 28, 12, compact ? 16 : 28, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = compact ||
              constraints.maxWidth < 1160 ||
              MediaQuery.sizeOf(context).height < 760;
          final gap = compact ? 24.0 : 32.0;

          if (stacked) {
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
          'Pro Dashboard',
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

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurface.withValues(alpha: 0.74)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.86),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioInformationPanel extends StatelessWidget {
  const _StudioInformationPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final prefersGlass = context.surfaces.effectsLevel == UiEffectsLevel.visual;
    return AppSurface(
      variant:
          prefersGlass ? AppSurfaceVariant.glass : AppSurfaceVariant.raised,
      glassDensity: prefersGlass
          ? AppSurfaceGlassDensity.low
          : AppSurfaceGlassDensity.medium,
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
                title: 'Information',
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
                              subtitle: '当前音频没有录入 composer 或 arranger。',
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
                        Center(
                          child: _NowPlayingArtwork(
                            size: artworkSize,
                            radius: 28,
                            large: true,
                            showBackdropGlow: false,
                          ),
                        ),
                        SizedBox(height: scrollable ? 14 : 20),
                        _MarqueeText(
                          text: audio.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w700,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${audio.artist} · ${audio.album}',
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
                                  .withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
    final prefersGlass = context.surfaces.effectsLevel == UiEffectsLevel.visual;

    return AppSurface(
      variant:
          prefersGlass ? AppSurfaceVariant.glass : AppSurfaceVariant.raised,
      glassDensity: prefersGlass
          ? AppSurfaceGlassDensity.low
          : AppSurfaceGlassDensity.medium,
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
        final size = (constraints.biggest.shortestSide * 0.82)
            .clamp(compact ? 220.0 : 340.0, compact ? 320.0 : 520.0)
            .toDouble();

        return Center(
          child: _NowPlayingArtwork(
            size: size,
            radius: 34,
            large: true,
            showBackdropGlow: true,
          ),
        );
      },
    );
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
                      tag: 'now-playing-artwork',
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
                                scale: Tween<double>(begin: 0.975, end: 1)
                                    .animate(curved),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(key: imageKey, child: mainImage),
                        ),
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

class _ImmersiveLyricStage extends StatelessWidget {
  const _ImmersiveLyricStage({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final useLegacyLyricView =
        context.read<PlaybackController>() is PlaybackService &&
            context.read<LyricController>() is LyricService;
    if (useLegacyLyricView) {
      return const VerticalLyricView();
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
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final lyric = snapshot.data;
            if (lyric == null || lyric.lines.isEmpty) {
              return Center(
                child: Text(
                  '暂无歌词',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: compact ? 22 : 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            return _CenteredLyricView(lyric: lyric, compact: compact);
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

  double get _primaryFontSize => widget.compact ? 28 : 32;
  double get _secondaryFontSize => widget.compact ? 18 : 20;
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
    if (_currentLineIndex == safeIndex) return;
    setState(() {
      _currentLineIndex = safeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToLine(safeIndex);
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

  void _scrollToLine(int index, {bool animated = true}) {
    if (!scrollController.hasClients || widget.lyric.lines.isEmpty) return;
    if (index < 0 || index >= widget.lyric.lines.length) return;

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
        curve: context.motion.normal,
      );
      return;
    }
    scrollController.jumpTo(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withValues(alpha: 0.58);
    final motion = context.motion;

    return Material(
      type: MaterialType.transparency,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.symmetric(
            vertical: _verticalPadding,
            horizontal: widget.compact ? 12 : 20,
          ),
          itemCount: widget.lyric.lines.length,
          itemBuilder: (context, index) {
            final line = widget.lyric.lines[index];
            final isCurrent = index == _currentLineIndex;
            final translation = _translationText(line);

            return AnimatedOpacity(
              duration: motion.controlTransitionDuration,
              curve: motion.fast,
              opacity: isCurrent ? 1 : 0.9,
              child: AnimatedScale(
                duration: motion.controlTransitionDuration,
                curve: motion.normal,
                scale: isCurrent ? 1 : 0.985,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    playbackService.seek(line.start.inMilliseconds / 1000.0);
                  },
                  child: AnimatedPadding(
                    duration: motion.controlTransitionDuration,
                    curve: motion.normal,
                    padding: EdgeInsets.symmetric(
                      vertical: isCurrent ? 14 : 10,
                      horizontal: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: motion.controlTransitionDuration,
                          curve: motion.normal,
                          style: TextStyle(
                            color: isCurrent ? Colors.white : inactiveColor,
                            fontSize: isCurrent
                                ? _primaryFontSize
                                : _secondaryFontSize,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w400,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          child: Text(
                            _primaryText(line),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_showTranslation(line)) ...[
                          const SizedBox(height: 8),
                          AnimatedDefaultTextStyle(
                            duration: motion.controlTransitionDuration,
                            curve: motion.fast,
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : inactiveColor.withValues(alpha: 0.76),
                              fontSize: _translationFontSize,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                            textAlign: TextAlign.center,
                            child: Text(
                              translation,
                              textAlign: TextAlign.center,
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
