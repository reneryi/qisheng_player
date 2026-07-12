// ignore_for_file: unused_element

part of 'page.dart';

class ImmersiveNowPlayingView extends StatelessWidget {
  const ImmersiveNowPlayingView({
    super.key,
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
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    _NowPlayingArtwork(
                      size: size,
                      radius: compact ? 14 : 24, // 大屏下圆角适当增大，让界面更加圆润美观
                      large: true,
                      showBackdropGlow: true, // 启用弥散的动态呼吸光晕特效
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
        final rate = audio.sampleRate != null
            ? '${(audio.sampleRate! / 1000).toStringAsFixed(1)}kHz'
            : '';
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
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  audio?.displayTitle ?? '正在播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: compact ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize:
                        compact ? 22 : 30, // 非 compact 模式下歌曲标题字号调大至 30 像素，更显大气
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

class _NowPlayingArtwork extends StatefulWidget {
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
  State<_NowPlayingArtwork> createState() => _NowPlayingArtworkState();
}

class _NowPlayingArtworkState extends State<_NowPlayingArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController; // 4s 超慢专辑封面呼吸发光控制器

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true); // 双向无限循环，实现平滑吸纳膨胀的呼吸感
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;
    final effectsLevel = context.surfaces.effectsLevel;

    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        final useLargeCover =
            widget.large && effectsLevel == UiEffectsLevel.visual;
        final enableBackdropGlow =
            widget.showBackdropGlow && effectsLevel == UiEffectsLevel.visual;
        final future = audio == null
            ? null
            : (useLargeCover ? audio.largeCover : audio.mediumCover);

        return FutureBuilder<ImageProvider<Object>?>(
          future: future,
          builder: (context, snapshot) {
            final provider = snapshot.data;
            final placeholder = DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                provider == null ? Symbols.music_note : Symbols.broken_image,
                color: scheme.onSurface.withValues(alpha: 0.62),
                size: widget.size * 0.24,
              ),
            );

            Widget image(ImageProvider<Object> imageProvider) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(widget.radius),
                child: Image(
                  image: imageProvider,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
              );
            }

            final mainImage = provider == null ? placeholder : image(provider);
            final imageKey = ValueKey(
              '${audio?.path ?? 'empty'}:${provider.hashCode}:${widget.size.round()}',
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
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (enableBackdropGlow && provider != null)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(widget.size * 0.08),
                        child: AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, staticGlowChild) {
                            final scaleVal = 1.05 +
                                _glowController.value *
                                    0.07; // 1.05 到 1.12 的呼吸缩放
                            final opacityVal = 0.38 +
                                _glowController.value *
                                    0.22; // 0.38 到 0.60 的透明度呼吸
                            return Transform.scale(
                              scale: scaleVal,
                              child: Opacity(
                                opacity: opacityVal,
                                child:
                                    staticGlowChild, // 仅在 GPU 侧对已经模糊好的缓存纹理做变换，杜绝主线程阻塞
                              ),
                            );
                          },
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                                sigmaX: 32,
                                sigmaY: 32), // 将高斯模糊提取为静态 child，确保一整首歌期间只渲染一次
                            child: image(provider),
                          ),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
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

  // 缩放交互与状态控制变量
  double _fontScale = 1.0; // 歌词字体缩放因子，默认 1.0 (从 0.5 到 2.5 范围限制)
  double _baseScale = 1.0; // 记录捏合手势起始时的基础缩放比例
  bool _showScaleIndicator = false; // 是否在界面顶部展示“歌词大小: XXX%”的浮层提示
  Timer? _scaleIndicatorTimer; // 定时器，用于延迟淡出提示胶囊

  // 更新缩放比例并触发提示指示器展示的通用方法
  void _updateScale(double newScale) {
    setState(() {
      _fontScale = newScale.clamp(0.5, 2.5);
      _showScaleIndicator = true;
    });
    _scaleIndicatorTimer?.cancel();
    _scaleIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showScaleIndicator = false);
      }
    });
  }

  double get _primaryFontSize =>
      (widget.compact ? 28 : 36) * _fontScale; // 杂志级排版：主歌词字号随缩放系数动态调整
  double get _secondaryFontSize =>
      (widget.compact ? 18 : 22) * _fontScale; // 杂志级排版：副歌词字号随缩放系数动态调整
  double get _translationFontSize =>
      (widget.compact ? 14 : 16) * _fontScale; // 翻译行字号随缩放系数动态调整
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
    final height =
        _showTranslation(line) ? base + (widget.compact ? 28.0 : 32.0) : base;
    return height * _fontScale; // 必须乘以字号缩放比例，以保证歌词滚动定位在缩放时仍能绝对精准居中
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
                      child: Text(word.content,
                          style: style, textAlign: TextAlign.left),
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

    // 采用 Stack 包裹整个面板，使浮动缩放指示胶囊能够完美悬浮在歌词视口中央上方
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          // 捕获双指捏合手势以缩放歌词大小
          onScaleStart: (details) {
            _baseScale = _fontScale;
          },
          onScaleUpdate: (details) {
            _updateScale(_baseScale * details.scale);
          },
          child: Listener(
            // 捕获桌面端特有的 Ctrl + 鼠标滚轮快捷缩放手势
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                // 判断硬件键盘的 Control 键是否被按下
                final isCtrlPressed =
                    HardwareKeyboard.instance.isControlPressed;
                if (isCtrlPressed) {
                  // 滚轮向上滚动增大字号，向下滚动则减小字号
                  final change =
                      pointerSignal.scrollDelta.dy < 0 ? 0.08 : -0.08;
                  _updateScale(_fontScale + change);
                }
              }
            },
            child: RepaintBoundary(
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

                      final isPast = index < _currentLineIndex;
                      final applyDepthBlur = !isCurrent &&
                          AppSettings.instance.lyricDepthBlur &&
                          AppSettings.instance.uiEffectsLevel ==
                              UiEffectsLevel.visual;

                      return AnimatedOpacity(
                        duration: motion.controlTransitionDuration,
                        curve: motion.fast,
                        opacity:
                            _lineOpacity(index: index, isCurrent: isCurrent),
                        child: AnimatedScale(
                          duration: motion.controlTransitionDuration,
                          curve: motion.normal,
                          scale: isCurrent ? 1 : 0.982,
                          child: InkWell(
                            enableFeedback: false,
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              playbackService
                                  .seek(line.start.inMilliseconds / 1000.0);
                            },
                            child: Builder(
                              builder: (context) {
                                final content = AnimatedPadding(
                                  duration: motion.controlTransitionDuration,
                                  curve: motion.normal,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isCurrent ? 16 : 10,
                                    horizontal: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start, // 杂志排版：歌词左对齐
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
                                          duration:
                                              motion.controlTransitionDuration,
                                          curve: motion.fast,
                                          style: TextStyle(
                                            color: isCurrent
                                                ? scheme.onSurface
                                                    .withValues(alpha: 0.74)
                                                : lineColor.withValues(
                                                    alpha: 0.74),
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
                                );
                                if (!applyDepthBlur) return content;
                                final sigma = isPast ? 0.8 : 1.8;
                                return ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: sigma,
                                    sigmaY: sigma,
                                  ),
                                  child: content,
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        // 精致的高斯毛玻璃风格缩放比例提示胶囊组件
        Positioned(
          top: 32,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showScaleIndicator ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.zoom_in,
                          size: 16,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '歌词大小: ${(_fontScale * 100).round()}%',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scaleIndicatorTimer?.cancel(); // 清理缩放指示指示器可能残存的定时器
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
    super.dispose();
  }
}
