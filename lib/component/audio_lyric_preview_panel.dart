import 'dart:async';
import 'dart:math' as math;

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_line_parser.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

class AudioLyricPreviewPanel extends StatelessWidget {
  const AudioLyricPreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playback = context.watch<PlaybackController>();
    final lyricController = context.watch<LyricController>();
    final audio = playback.nowPlaying;

    return Container(
      key: const ValueKey('audio-lyric-preview-panel'),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      child: audio == null
          ? _LyricPreviewEmptyState(
              icon: Symbols.music_note_rounded,
              title: '暂无正在播放的歌曲',
              message: '开始播放后，这里会显示封面、歌曲信息和歌词预览。',
              color: scheme.onSurface,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxH = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 600.0;
                final maxW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 260.0;
                final ultraCompact = maxH < 340.0;
                final coverSize = ultraCompact
                    ? 56.0
                    : math.min(maxW - 16.0, maxH * 0.35).clamp(84.0, 214.0);
                final spacing = maxH < 480.0 ? 10.0 : 18.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ultraCompact)
                      Row(
                        children: [
                          SizedBox(
                            width: coverSize,
                            height: coverSize,
                            child: _LyricPreviewArtwork(audio: audio),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  audio.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  audio.displayArtist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Center(
                        child: SizedBox(
                          width: coverSize,
                          height: coverSize,
                          child: _LyricPreviewArtwork(audio: audio),
                        ),
                      ),
                      SizedBox(height: spacing),
                      Text(
                        audio.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        audio.displayArtist,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                    SizedBox(height: spacing),
                    Expanded(
                      child: FutureBuilder<Lyric?>(
                        future: lyricController.currLyricFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }

                          final lyric = snapshot.data;
                          if (lyric == null || lyric.lines.isEmpty) {
                            return _LyricPreviewEmptyState(
                              icon: Symbols.lyrics_rounded,
                              title: '暂无歌词',
                              message: '当前歌曲还没有可用歌词。',
                              compact: true,
                              color: scheme.onSurface,
                            );
                          }

                          return _LyricPreviewLines(
                            lyric: lyric,
                            lyricController: lyricController,
                          );
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

class _LyricPreviewArtwork extends StatefulWidget {
  const _LyricPreviewArtwork({required this.audio});

  final Audio audio;

  @override
  State<_LyricPreviewArtwork> createState() => _LyricPreviewArtworkState();
}

class _LyricPreviewArtworkState extends State<_LyricPreviewArtwork> {
  ImageProvider? _displayedCover;
  String? _displayedPath;
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  @override
  void didUpdateWidget(covariant _LyricPreviewArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio.path != widget.audio.path) {
      _resolveCover();
    }
  }

  void _resolveCover() {
    final audio = widget.audio;
    final cached = NowPlayingArtworkCard.getSyncCover(audio);
    if (cached != null) {
      _loadSequence++;
      _displayedCover = cached;
      _displayedPath = audio.path;
      return;
    }

    final currentSeq = ++_loadSequence;
    audio.largeCover.then((provider) {
      if (!mounted || _loadSequence != currentSeq) return;
      if (provider != null) {
        NowPlayingArtworkCard.cacheSyncCover(audio, provider);
      }
      setState(() {
        _displayedCover = provider;
        _displayedPath = audio.path;
      });
    }).catchError((_) {
      if (!mounted || _loadSequence != currentSeq) return;
      setState(() {
        _displayedCover = null;
        _displayedPath = audio.path;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = DecoratedBox(
      key: const ValueKey('lyric-preview-placeholder'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Center(
        child: Icon(
          Symbols.music_note_rounded,
          size: 34,
          color: scheme.onSurface.withValues(alpha: 0.56),
        ),
      ),
    );

    final Widget activeChild;
    if (_displayedCover != null) {
      activeChild = Image(
        key: ValueKey(_displayedPath ?? 'lyric-preview-cover'),
        image: _displayedCover!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      activeChild = placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: SizedBox.expand(child: activeChild),
      ),
    );
  }
}

class _LyricPreviewLines extends StatefulWidget {
  const _LyricPreviewLines({
    required this.lyric,
    required this.lyricController,
  });

  final Lyric lyric;
  final LyricController lyricController;

  @override
  State<_LyricPreviewLines> createState() => _LyricPreviewLinesState();
}

class _LyricPreviewLinesState extends State<_LyricPreviewLines> {
  static const _manualScrollCooldown = Duration(milliseconds: 1800);

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<int>? _lineSubscription;
  late List<GlobalKey> _lineKeys;
  int _activeLine = 0;

  // 仅当用户手动使用鼠标滚轮或拖拽浏览歌词时才显示滚动条，自动滚词时隐藏滚动条
  bool _manualScrolling = false;
  Timer? _manualScrollTimer;

  void _triggerManualScroll() {
    _manualScrollTimer?.cancel();
    if (!_manualScrolling && mounted) {
      setState(() => _manualScrolling = true);
    }
    _manualScrollTimer = Timer(_manualScrollCooldown, () {
      if (!mounted) return;
      setState(() => _manualScrolling = false);
      _jumpToActiveLine(animated: true);
    });
  }

  @override
  void initState() {
    super.initState();
    _lineKeys = _generateLineKeys();
    _bindController();
  }

  @override
  void didUpdateWidget(covariant _LyricPreviewLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyricController != widget.lyricController) {
      _lineSubscription?.cancel();
      if (oldWidget.lyric != widget.lyric) {
        _lineKeys = _generateLineKeys();
      }
      _bindController();
      return;
    }
    if (oldWidget.lyric != widget.lyric) {
      _manualScrollTimer?.cancel();
      _manualScrolling = false;
      _lineKeys = _generateLineKeys();
      _activeLine = widget.lyricController.currentLyricLineIndex
          .clamp(0, widget.lyric.lines.length - 1)
          .toInt();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToActiveLine(animated: false);
      });
    }
  }

  List<GlobalKey> _generateLineKeys() {
    return List.generate(widget.lyric.lines.length, (_) => GlobalKey());
  }

  void _bindController() {
    final safeMax =
        widget.lyric.lines.isEmpty ? 0 : widget.lyric.lines.length - 1;
    _activeLine =
        widget.lyricController.currentLyricLineIndex.clamp(0, safeMax).toInt();
    _lineSubscription = widget.lyricController.lyricLineStream.listen((line) {
      if (!mounted || widget.lyric.lines.isEmpty) return;
      setState(() {
        _activeLine = line.clamp(0, widget.lyric.lines.length - 1).toInt();
      });
      if (!_manualScrolling) {
        _jumpToActiveLine();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToActiveLine(animated: false);
    });
  }

  void _jumpToActiveLine({bool animated = true, int attempt = 0}) {
    if (_activeLine < 0 || _activeLine >= _lineKeys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        _retryJumpToActiveLine(animated: animated, attempt: attempt);
        return;
      }

      final targetContext = _lineKeys[_activeLine].currentContext;
      if (targetContext == null || !targetContext.mounted) {
        _retryJumpToActiveLine(animated: animated, attempt: attempt);
        return;
      }

      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.45,
        duration: animated ? context.motion.lyricScrollDuration : Duration.zero,
        curve: context.motion.normal,
      );
    });
  }

  void _retryJumpToActiveLine({required bool animated, required int attempt}) {
    if (attempt >= 4) return;
    Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)), () {
      if (!mounted) return;
      _jumpToActiveLine(animated: animated, attempt: attempt + 1);
    });
  }

  String _lineText(LyricLine line) {
    if (line is SyncLyricLine) {
      return line.content.trim();
    }
    if (line is LrcLine) {
      return LyricLineParser.parse(line.content).primary;
    }
    return '';
  }

  String _lineTranslation(LyricLine line) {
    if (line is SyncLyricLine) {
      return (line.translation ?? '').trim();
    }
    if (line is LrcLine) {
      final parsed = LyricLineParser.parse(line.content);
      if (parsed.isCredit) return '';
      return (parsed.translation ?? '').trim();
    }
    return '';
  }

  bool _isCreditLine(LyricLine line) {
    if (line is LrcLine) {
      return LyricLineParser.parse(line.content).isCredit;
    }
    return false;
  }

  @override
  void dispose() {
    _manualScrollTimer?.cancel();
    _lineSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final scrollView = Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          _triggerManualScroll();
        }
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction != ScrollDirection.idle) {
            _triggerManualScroll();
          }
          return false;
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: _manualScrolling,
            trackVisibility: false,
            interactive: _manualScrolling,
            thickness: _manualScrolling ? 4.0 : 0.0,
            radius: const Radius.circular(999),
            fadeDuration: const Duration(milliseconds: 220),
            timeToFade: const Duration(milliseconds: 400),
            thumbColor: _manualScrolling
                ? scheme.onSurface.withValues(alpha: 0.28)
                : Colors.transparent,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(widget.lyric.lines.length, (i) {
                  final line = widget.lyric.lines[i];
                  final content = _lineText(line);
                  if (content.isEmpty) {
                    return SizedBox(key: _lineKeys[i], height: 10);
                  }

                  final active = i == _activeLine;
                  final isCredit = _isCreditLine(line);
                  final translation = _lineTranslation(line);
                  final showTranslation = translation.isNotEmpty;

                  return Padding(
                    key: _lineKeys[i],
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: AnimatedContainer(
                      duration: motion.controlTransitionDuration,
                      curve: motion.normal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: active
                            ? scheme.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: motion.controlTransitionDuration,
                        curve: motion.normal,
                        style: TextStyle(
                          color: isCredit
                              ? scheme.onSurface.withValues(alpha: 0.48)
                              : (active
                                  ? scheme.onSurface
                                  : scheme.onSurface
                                      .withValues(alpha: 0.62)),
                          fontSize: isCredit ? 13 : (active ? 15 : 13),
                          fontWeight: isCredit
                              ? FontWeight.w400
                              : (active
                                  ? FontWeight.w700
                                  : FontWeight.w400),
                          height: 1.35,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(content),
                            if (showTranslation) ...[
                              const SizedBox(height: 4),
                              Text(
                                translation,
                                style: TextStyle(
                                  color: active
                                      ? scheme.onSurface.withValues(alpha: 0.72)
                                      : scheme.onSurface.withValues(alpha: 0.46),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );

    if (AppSettings.instance.uiEffectsLevel == UiEffectsLevel.performance) {
      return scrollView;
    }

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.08, 0.92, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: scrollView,
    );
  }
}

class _LyricPreviewEmptyState extends StatelessWidget {
  const _LyricPreviewEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 42 : 48,
                height: compact ? 42 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: compact ? 20 : 22,
                  color: color.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.withValues(alpha: 0.66),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
