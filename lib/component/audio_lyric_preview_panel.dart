import 'dart:async';

import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
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
              icon: Symbols.music_note,
              title: '暂无正在播放的歌曲',
              message: '开始播放后，这里会显示封面、歌曲信息和歌词预览。',
              color: scheme.onSurface,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox(
                    width: 214,
                    height: 214,
                    child: _LyricPreviewArtwork(audio: audio),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  audio.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
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
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: FutureBuilder<Lyric?>(
                    future: lyricController.currLyricFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final lyric = snapshot.data;
                      if (lyric == null || lyric.lines.isEmpty) {
                        return _LyricPreviewEmptyState(
                          icon: Symbols.lyrics,
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
            ),
    );
  }
}

class _LyricPreviewArtwork extends StatelessWidget {
  const _LyricPreviewArtwork({required this.audio});

  final Audio audio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Center(
        child: Icon(
          Symbols.music_note,
          size: 34,
          color: scheme.onSurface.withValues(alpha: 0.56),
        ),
      ),
    );

    return FutureBuilder<ImageProvider?>(
      future: audio.mediumCover,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: placeholder,
          );
        }

        final cover = snapshot.data;
        if (cover == null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: placeholder,
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image(
            image: cover,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      },
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
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<int>? _lineSubscription;
  late List<GlobalKey> _lineKeys;
  int _activeLine = 0;

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
      _jumpToActiveLine();
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
    if (attempt >= 3) return;
    Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)), () {
      if (!mounted) return;
      _jumpToActiveLine(animated: animated, attempt: attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * 0.42).clamp(24.0, 160.0).toDouble()
            : 24.0;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: verticalPadding,
            bottom: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(widget.lyric.lines.length, (index) {
              final entry = _LyricLineEntry.from(widget.lyric.lines[index]);
              final active = index == _activeLine;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == widget.lyric.lines.length - 1 ? 0 : 10,
                ),
                child: KeyedSubtree(
                  key: _lineKeys[index],
                  child: AnimatedDefaultTextStyle(
                    duration: context.motion.controlTransitionDuration,
                    curve: context.motion.normal,
                    style: TextStyle(
                      color: active
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.58),
                      fontSize: active ? 15 : 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      height: 1.4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.primary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.secondary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.secondary!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? scheme.onSurface.withValues(alpha: 0.62)
                                  : scheme.onSurface.withValues(alpha: 0.42),
                              fontSize: active ? 11.5 : 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
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
        );
      },
    );
  }

  @override
  void dispose() {
    _lineSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

class _LyricLineEntry {
  const _LyricLineEntry({
    required this.primary,
    this.secondary,
  });

  final String primary;
  final String? secondary;

  factory _LyricLineEntry.from(LyricLine line) {
    if (line is LrcLine) {
      final parts = line.content.split('─');
      final primary = parts.first.trim();
      final secondary =
          parts.length > 1 ? parts.sublist(1).join('─').trim() : null;
      return _LyricLineEntry(
        primary: primary.isEmpty ? '...' : primary,
        secondary: secondary?.isEmpty ?? true ? null : secondary,
      );
    }

    if (line is SyncLyricLine) {
      return _LyricLineEntry(
        primary: line.content.trim().isEmpty ? '...' : line.content.trim(),
        secondary: line.translation?.trim().isEmpty ?? true
            ? null
            : line.translation!.trim(),
      );
    }

    return const _LyricLineEntry(primary: '...');
  }
}

class _LyricPreviewEmptyState extends StatelessWidget {
  const _LyricPreviewEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 16,
          vertical: compact ? 10 : 16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color.withValues(alpha: 0.48),
              size: compact ? 20 : 26,
            ),
            SizedBox(height: compact ? 10 : 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.62),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
