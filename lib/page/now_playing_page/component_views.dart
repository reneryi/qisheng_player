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
        final availableHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;

        // 响应式自适应封面尺寸：根据宽高动态计算，保证大屏震撼、小屏精致
        final size = compact
            ? (availableHeight * 0.44).clamp(80.0, 150.0).toDouble()
            : math
                .min(availableWidth * 0.74, availableHeight * 0.54)
                .clamp(180.0, 380.0)
                .toDouble();

        return SizedBox.expand(
          child: Stack(
            children: [
              const Positioned.fill(child: _ArtworkStageHitAbsorber()),
              Align(
                alignment: compact ? Alignment.centerLeft : Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: compact ? Alignment.centerLeft : Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      _NowPlayingArtwork(
                        size: size,
                        radius: compact ? 14 : 24,
                        large: true,
                        showBackdropGlow: true,
                      ),
                      SizedBox(height: compact ? 10 : 20),
                      _NowPlayingStagedReveal(
                        begin: 0.24,
                        end: 0.68,
                        beginOffset: const Offset(0, 0.06),
                        child: _NowPlayingTrackIdentity(compact: compact),
                      ),
                      const SizedBox(height: 10),
                      // 极简音频参数胶囊标牌
                      const _NowPlayingStagedReveal(
                        begin: 0.3,
                        end: 0.75,
                        child: _ImmersiveMetadataStrip(),
                      ),
                      // 模块化实时音频频谱律动条
                      if (AppSettings.instance.showSpectrumVisualizer) ...[
                        const SizedBox(height: 12),
                        const _NowPlayingStagedReveal(
                          begin: 0.35,
                          end: 0.8,
                          child: _ImmersiveSpectrumBar(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 沉浸式频谱律动条组件
class _ImmersiveSpectrumBar extends StatelessWidget {
  const _ImmersiveSpectrumBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = context.watch<PlaybackController>();

    return ValueListenableBuilder<List<double>>(
      valueListenable: playbackService.audioSpectrum,
      builder: (context, spectrum, _) {
        if (spectrum.isEmpty) {
          return const SizedBox(height: 24, width: 220);
        }
        return RepaintBoundary(
          child: Container(
            height: 28,
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.3),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: CustomPaint(
              painter: _SpectrumBarPainter(
                spectrum: spectrum,
                color: scheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpectrumBarPainter extends CustomPainter {
  const _SpectrumBarPainter({
    required this.spectrum,
    required this.color,
  });

  final List<double> spectrum;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final barCount = math.min(spectrum.length, 24);
    final barWidth = (size.width - (barCount - 1) * 2.5) / barCount;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final val = spectrum[i].clamp(0.08, 1.0);
      final barHeight = size.height * val;
      final x = i * (barWidth + 2.5);
      final y = size.height - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumBarPainter oldDelegate) => true;
}

// 现代 Hi-Fi 音频参数胶囊栏：展示格式、Hi-Res 标牌、采样率与比特率
class _ImmersiveMetadataStrip extends StatelessWidget {
  const _ImmersiveMetadataStrip();

  @override
  Widget build(BuildContext context) {
    return Selector<PlaybackController, Audio?>(
      selector: (_, playback) => playback.nowPlaying,
      builder: (context, audio, _) {
        if (audio == null) return const SizedBox.shrink();
        return AudioFormatBadge(
          audio: audio,
          compact: false,
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
                MarqueeText(
                  text: audio?.displayTitle ?? '正在播放',
                  textAlign: compact ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize:
                        compact ? 22 : 30, // 非 compact 模式下歌曲标题字号调大至 30 像素，更显大气
                    fontWeight: FontWeight.w800,
                    height: 1.2,
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
    with TickerProviderStateMixin {
  static const double _maxDragDistance = 10;
  static const double _maxRotation = 0.08;
  static const double _perspective = 0.0012;
  static const SpringDescription _returnSpring = SpringDescription(
    mass: 0.8,
    stiffness: 190,
    damping: 18,
  );

  late final AnimationController _returnController;
  Animation<double>? _routeAnimation;
  Offset _dragOffset = Offset.zero;
  Offset _returnStart = Offset.zero;
  String? _audioPath;
  late final AnimationController _glowController; // 4s 超慢专辑封面呼吸发光控制器

  @override
  void initState() {
    super.initState();
    _returnController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final progress = _returnController.value;
        final nextOffset = _clampDragOffset(_returnStart * (1 - progress));
        if (nextOffset == _dragOffset || !mounted) return;
        setState(() => _dragOffset = nextOffset);
      })
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        if (_dragOffset != Offset.zero) {
          setState(() => _dragOffset = Offset.zero);
        }
      });
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true); // 双向无限循环，实现平滑吸纳膨胀的呼吸感
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteAnimation = ModalRoute.of(context)?.animation;
    if (!identical(nextRouteAnimation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = nextRouteAnimation;
      _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    }

    final glowEnabled =
        context.surfaces.effectsLevel == UiEffectsLevel.visual &&
            !MediaQuery.disableAnimationsOf(context) &&
            TickerMode.valuesOf(context).enabled;
    if (glowEnabled && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!glowEnabled && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _glowController.dispose();
    _returnController.dispose();
    super.dispose();
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      _resetDragState();
    }
  }

  void _syncAudio(String? path) {
    if (_audioPath == path) return;
    _audioPath = path;
    _returnController.stop();
    _dragOffset = Offset.zero;
    _returnStart = Offset.zero;
  }

  Offset _clampDragOffset(Offset value) {
    final distance = value.distance;
    if (distance <= _maxDragDistance || distance == 0) return value;
    return value / distance * _maxDragDistance;
  }

  void _resetDragState() {
    _returnController.stop();
    _returnStart = Offset.zero;
    if (!mounted || _dragOffset == Offset.zero) return;
    setState(() => _dragOffset = Offset.zero);
  }

  void _handlePanStart(DragStartDetails details) {
    _returnController.stop();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final nextOffset = _clampDragOffset(_dragOffset + details.delta);
    if (nextOffset == _dragOffset) return;
    setState(() => _dragOffset = nextOffset);
  }

  void _handlePanEnd() {
    if (_dragOffset == Offset.zero) return;
    _returnStart = _dragOffset;
    _returnController
      ..stop()
      ..value = 0;
    _returnController.animateWith(
      SpringSimulation(_returnSpring, 0, 1, 0),
    );
  }

  Matrix4 _artworkTransform() {
    final normalizedX = _dragOffset.dx / _maxDragDistance;
    final normalizedY = _dragOffset.dy / _maxDragDistance;
    final scale = 1 - (_dragOffset.distance / _maxDragDistance) * 0.012;
    return Matrix4.identity()
      ..setEntry(3, 2, _perspective)
      ..translateByDouble(_dragOffset.dx, _dragOffset.dy, 0, 1)
      ..rotateX(-normalizedY * _maxRotation)
      ..rotateY(normalizedX * _maxRotation)
      ..scaleByDouble(scale, scale, 1, 1);
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
        _syncAudio(audio?.path);
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
            final motionEnabled = effectsLevel != UiEffectsLevel.performance &&
                !MediaQuery.disableAnimationsOf(context);
            final shadowOffset = Offset(
              _dragOffset.dx * 0.45,
              7 + _dragOffset.dy * 0.45,
            );

            final showVinyl = AppSettings.instance.showVinylRecord && widget.large;
            final enableBreath = AppSettings.instance.coverBreathEffect &&
                enableBackdropGlow &&
                provider != null;

            if (showVinyl) {
              return SizedBox(
                width: widget.size * 1.15,
                height: widget.size,
                child: Hero(
                  tag: nowPlayingArtworkHeroTag,
                  createRectTween: (begin, end) =>
                      NowPlayingArtworkRectTween(begin: begin, end: end),
                  flightShuttleBuilder:
                      nowPlayingArtworkFlightShuttleBuilder,
                  child: GestureDetector(
                    key: const ValueKey('now-playing-artwork-drag'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: motionEnabled ? _handlePanStart : null,
                    onPanUpdate: motionEnabled ? _handlePanUpdate : null,
                    onPanEnd: motionEnabled ? (_) => _handlePanEnd() : null,
                    child: Center(
                      child: VinylRecordPlayerView(
                        size: widget.size * 0.92,
                        coverProvider: provider,
                        showTonearm: true,
                      ),
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (enableBreath)
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
                                child: staticGlowChild,
                              ),
                            );
                          },
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 32,
                              sigmaY: 32,
                            ),
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
                          offset: shadowOffset,
                        ),
                      ],
                    ),
                    child: Hero(
                      tag: nowPlayingArtworkHeroTag,
                      createRectTween: (begin, end) =>
                          NowPlayingArtworkRectTween(begin: begin, end: end),
                      flightShuttleBuilder:
                          nowPlayingArtworkFlightShuttleBuilder,
                      child: GestureDetector(
                        key: const ValueKey('now-playing-artwork-drag'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: motionEnabled ? _handlePanStart : null,
                        onPanUpdate: motionEnabled ? _handlePanUpdate : null,
                        onPanEnd: motionEnabled ? (_) => _handlePanEnd() : null,
                        onPanCancel: motionEnabled ? _handlePanEnd : null,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: motionEnabled
                              ? _artworkTransform()
                              : Matrix4.identity(),
                          child: heroArtwork,
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
      return _NowPlayingStagedReveal(
        begin: 0.34,
        end: 0.9,
        beginOffset: const Offset(0, 0.05),
        child: VerticalLyricView(compact: compact),
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
  final List<GlobalKey> _lineKeys = <GlobalKey>[];
  int _scrollRequestId = 0;

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
  double get _baseVerticalPadding => widget.compact ? 140 : 200;
  double _verticalPaddingFor(LyricLine line) {
    if (_viewportHeight <= 0) return _baseVerticalPadding;
    final centered =
        _viewportHeight / 2 - _estimatedLineHeight(line, isCurrent: true) / 2;
    return math.max(_baseVerticalPadding, centered);
  }

  double _viewportHeight = 0;

  void _syncLineKeys() {
    while (_lineKeys.length < widget.lyric.lines.length) {
      _lineKeys.add(GlobalKey(debugLabel: 'lyric-line-${_lineKeys.length}'));
    }
    if (_lineKeys.length > widget.lyric.lines.length) {
      _lineKeys.removeRange(widget.lyric.lines.length, _lineKeys.length);
    }
  }

  void _requestScrollToLine(int index, {required bool animated}) {
    final requestId = ++_scrollRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestId != _scrollRequestId) return;
      _scrollToLine(index, animated: animated, requestId: requestId);
    });
  }

  @override
  void initState() {
    super.initState();
    playbackService = context.read<PlaybackController>();
    lyricService = context.read<LyricController>();
    _syncLineKeys();
    _currentLineIndex = lyricService.currentLyricLineIndex;
    lyricLineStreamSubscription =
        lyricService.lyricLineStream.listen(_handleLyricLineChange);
    _requestScrollToLine(_currentLineIndex, animated: false);
  }

  void _handleLyricLineChange(int index) {
    if (!mounted || widget.lyric.lines.isEmpty) return;
    final safeIndex = index.clamp(0, widget.lyric.lines.length - 1).toInt();
    if (_currentLineIndex == safeIndex) {
      _requestScrollToLine(safeIndex, animated: true);
      return;
    }
    setState(() {
      _currentLineIndex = safeIndex;
    });
    _requestScrollToLine(safeIndex, animated: true);
  }

  @override
  void didUpdateWidget(covariant _CenteredLyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyric == widget.lyric) return;
    _syncLineKeys();
    _currentLineIndex = widget.lyric.lines.isEmpty
        ? 0
        : lyricService.currentLyricLineIndex
            .clamp(0, widget.lyric.lines.length - 1)
            .toInt();
    _requestScrollToLine(_currentLineIndex, animated: false);
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

  void _scrollToLine(
    int index, {
    required bool animated,
    required int requestId,
    int attempt = 0,
  }) {
    if (widget.lyric.lines.isEmpty) return;
    if (index < 0 || index >= widget.lyric.lines.length) return;
    if (requestId != _scrollRequestId) return;
    if (!scrollController.hasClients) {
      _retryScrollToLine(
        index,
        animated: animated,
        requestId: requestId,
        attempt: attempt,
      );
      return;
    }

    final lineContext = _lineKeys[index].currentContext;
    if (lineContext == null) {
      _retryScrollToLine(
        index,
        animated: animated,
        requestId: requestId,
        attempt: attempt,
      );
      return;
    }

    final duration =
        animated ? context.motion.lyricScrollDuration : Duration.zero;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.5,
      duration: duration,
      curve: context.motion.emphasized,
    );
  }

  void _retryScrollToLine(
    int index, {
    required bool animated,
    required int requestId,
    required int attempt,
  }) {
    if (attempt >= 3) return;
    Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)), () {
      if (!mounted || requestId != _scrollRequestId) return;
      _scrollToLine(
        index,
        animated: animated,
        requestId: requestId,
        attempt: attempt + 1,
      );
    });
  }

  double _lineOpacity({required int index, required bool isCurrent}) {
    return resolveLyricLineOpacity(
      distanceFromCurrent: (index - _currentLineIndex).abs(),
      isPastLine: index < _currentLineIndex,
    );
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewportHeight = constraints.maxHeight;
                    final currentLine = widget.lyric.lines[_currentLineIndex
                        .clamp(0, widget.lyric.lines.length - 1)];
                    final verticalPadding = _verticalPaddingFor(currentLine);
                    return Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(
                          vertical: verticalPadding,
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

                          final distanceFromCurrent =
                              (index - _currentLineIndex).abs();
                          final depthBlurSigma = resolveLyricDepthBlurSigma(
                            distanceFromCurrent: distanceFromCurrent,
                            enabled: AppSettings.instance.lyricDepthBlur,
                            effectsLevel: AppSettings.instance.uiEffectsLevel,
                          );

                          return KeyedSubtree(
                            key: _lineKeys[index],
                            child: AnimatedOpacity(
                              duration: motion.controlTransitionDuration,
                              curve: motion.fast,
                              opacity: _lineOpacity(
                                  index: index, isCurrent: isCurrent),
                              child: LyricLineMotion(
                                isCurrent: isCurrent,
                                distanceFromCurrent: distanceFromCurrent,
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  enableFeedback: false,
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () {
                                    playbackService.seek(
                                        line.start.inMilliseconds / 1000.0);
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      final content = AnimatedPadding(
                                        duration:
                                            motion.controlTransitionDuration,
                                        curve: motion.normal,
                                        padding: EdgeInsets.symmetric(
                                          vertical: isCurrent ? 16 : 10,
                                          horizontal: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start, // 杂志排版：歌词左对齐
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
                                                duration: motion
                                                    .controlTransitionDuration,
                                                curve: motion.fast,
                                                style: TextStyle(
                                                  color: isCurrent
                                                      ? scheme.onSurface
                                                          .withValues(
                                                              alpha: 0.74)
                                                      : lineColor.withValues(
                                                          alpha: 0.74),
                                                  fontSize:
                                                      _translationFontSize,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.25,
                                                ),
                                                textAlign:
                                                    TextAlign.left, // 翻译行左对齐
                                                child: Text(
                                                  translation,
                                                  textAlign: TextAlign.left,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                      if (depthBlurSigma <= 0) return content;
                                      return ImageFiltered(
                                        imageFilter: createLyricDepthBlurFilter(
                                          depthBlurSigma,
                                        ),
                                        child: content,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
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
