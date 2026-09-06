import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter; // 引入 ImageFilter 用于毛玻璃背景渲染

import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_controls_visibility.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_depth_effect.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/gestures.dart'; // 引入 gestures 包用于拦截鼠标滚轮信号
import 'package:flutter/services.dart'; // 引入 services 包用于检测 Ctrl 键盘状态
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _compactLyricFocusAlignment = 0.25;
const _largeLyricFocusAlignment = 0.5;

@visibleForTesting
double resolveVerticalLyricFocusAlignment({required bool compact}) {
  return compact ? _compactLyricFocusAlignment : _largeLyricFocusAlignment;
}

class VerticalLyricView extends StatefulWidget {
  const VerticalLyricView({super.key, this.compact = false});

  final bool compact;

  @override
  State<VerticalLyricView> createState() => _VerticalLyricViewState();
}

class _VerticalLyricViewState extends State<VerticalLyricView> {
  final lyricViewController = LyricViewController();
  late final LyricControlsVisibilityController visibilityController =
      LyricControlsVisibilityController();

  // 缩放状态管理与交互参数
  double _lastFontSize = 22.0; // 缓存旧字号用于检测变化
  double _baseFontSize = 22.0; // 记录 Pinch 手势启动时的初始字号
  bool _showScaleIndicator = false; // 是否显示顶部歌词缩放比例的提示浮层
  Timer? _scaleIndicatorTimer; // 定时器，用于操作结束后淡出指示胶囊

  // 双指捏合手势被动测距状态管理
  final Map<int, Offset> _pointers = {}; // 缓存活跃的指针 ID 与位置坐标
  double _initialDistance = 0.0; // 记录捏合手势初始时的双指间距

  @override
  void initState() {
    super.initState();
    _lastFontSize = lyricViewController.lyricFontSize;
    lyricViewController
        .addListener(_onFontSizeChanged); // 添加监听，统一捕获手势缩放或右下角按钮的字号变化
  }

  // 监听字号修改，控制缩放卡片的动画显示与淡出逻辑
  void _onFontSizeChanged() {
    if (!mounted) return;
    if (lyricViewController.lyricFontSize != _lastFontSize) {
      _lastFontSize = lyricViewController.lyricFontSize;
      setState(() {
        _showScaleIndicator = true;
      });
      _scaleIndicatorTimer?.cancel();
      _scaleIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _showScaleIndicator = false);
        }
      });
    }
  }

  // 被动多指指针按下事件：记录并初始化捏合双指间距
  void _handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final keys = _pointers.keys.toList();
      final p1 = _pointers[keys[0]]!;
      final p2 = _pointers[keys[1]]!;
      _initialDistance = (p1 - p2).distance;
      _baseFontSize = lyricViewController.lyricFontSize;
    }
  }

  // 被动多指指针移动事件：动态更新距离并驱动字号缩放
  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final keys = _pointers.keys.toList();
      final p1 = _pointers[keys[0]]!;
      final p2 = _pointers[keys[1]]!;
      final currentDistance = (p1 - p2).distance;
      if (_initialDistance > 10.0) {
        final scale = currentDistance / _initialDistance;
        lyricViewController.setFontSize(_baseFontSize * scale);
      }
    }
  }

  // 指针抬起时，移除缓存
  void _handlePointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
  }

  // 指针被系统取消时，移除缓存
  void _handlePointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
  }

  @override
  void dispose() {
    lyricViewController.removeListener(_onFontSizeChanged);
    _scaleIndicatorTimer?.cancel(); // 清理残留计时器
    lyricViewController.dispose();
    visibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        visibilityController.setRegionHovered(true);
      },
      onExit: (_) {
        visibilityController.setRegionHovered(false);
      },
      child: Material(
        type: MaterialType.transparency,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: lyricViewController),
              ChangeNotifierProvider.value(value: visibilityController),
            ],
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              // 监听 Ctrl + 鼠标滚轮/触控板双指滚动的字号修改
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  final isCtrlPressed =
                      HardwareKeyboard.instance.isControlPressed;
                  if (isCtrlPressed) {
                    // 滚轮往上滚（dy < 0）增大字号，往下滚减小字号
                    final change =
                        pointerSignal.scrollDelta.dy < 0 ? 1.0 : -1.0;
                    lyricViewController.setFontSize(
                        lyricViewController.lyricFontSize + change);
                  }
                }
              },
              child: ListenableBuilder(
                listenable: PlayService.instance.lyricService,
                builder: (context, _) => ListenableBuilder(
                  listenable: visibilityController,
                  builder: (context, __) {
                    final showControls = visibilityController.visible;
                    return FutureBuilder(
                      future: PlayService.instance.lyricService.currLyricFuture,
                      builder: (context, snapshot) {
                        final lyricNullable = snapshot.data;
                        final noLyricWidget = Center(
                          child: Text(
                            "暂无歌词",
                            style: TextStyle(
                              fontSize: 22,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        );

                        return Stack(
                          children: [
                            const Positioned.fill(
                              child: AbsorbPointer(
                                child: SizedBox.expand(),
                              ),
                            ),
                            switch (snapshot.connectionState) {
                              ConnectionState.none => loadingWidget,
                              ConnectionState.waiting => loadingWidget,
                              ConnectionState.active => loadingWidget,
                              ConnectionState.done => lyricNullable == null
                                  ? noLyricWidget
                                  : _VerticalLyricScrollView(
                                      lyric: lyricNullable,
                                      currentLineAlignment:
                                          resolveVerticalLyricFocusAlignment(
                                        compact: widget.compact,
                                      ),
                                    ),
                            },
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IgnorePointer(
                                ignoring: !showControls,
                                child: AnimatedSlide(
                                  duration: motion.controlTransitionDuration,
                                  curve: motion.normal,
                                  offset: showControls
                                      ? Offset.zero
                                      : const Offset(0.04, 0.08),
                                  child: AnimatedOpacity(
                                    duration: motion.controlTransitionDuration,
                                    curve: motion.fast,
                                    opacity: showControls ? 1 : 0,
                                    child: const LyricViewControls(),
                                  ),
                                ),
                              ),
                            ),
                            // 顶部的歌词大小百分比毛玻璃指示卡片
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 32.0),
                                child: AnimatedOpacity(
                                  opacity: _showScaleIndicator ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  child: GestureDetector(
                                    onTap: () {
                                      // 点击或双击胶囊立即重置为 100% 默认字号
                                      lyricViewController.resetFontSize();
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 12, sigmaY: 12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainer
                                                .withValues(alpha: 0.68),
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.12),
                                                blurRadius: 16,
                                                spreadRadius: -4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.zoom_in,
                                                size: 16,
                                                color: scheme.onSurface
                                                    .withValues(alpha: 0.8),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '歌词大小: ${(lyricViewController.lyricFontSize / 22.0 * 100).round()}% (点击重置)',
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
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final LYRIC_VIEW_KEY = GlobalKey();

class _VerticalLyricScrollView extends StatefulWidget {
  const _VerticalLyricScrollView({
    required this.lyric,
    required this.currentLineAlignment,
  });

  final Lyric lyric;
  final double currentLineAlignment;

  @override
  State<_VerticalLyricScrollView> createState() =>
      _VerticalLyricScrollViewState();
}

class _VerticalLyricScrollViewState extends State<_VerticalLyricScrollView> {
  final playbackService = PlayService.instance.playbackService;
  final lyricService = PlayService.instance.lyricService;
  late StreamSubscription lyricLineStreamSubscription;
  final scrollController = ScrollController();

  List<LyricViewTile> lyricTiles = [
    LyricViewTile(line: LrcLine.defaultLine, opacity: 1.0)
  ];

  final currentLyricTileKey = GlobalKey();
  int? _lastSafeIndex;
  DateTime _lastLyricUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    _initLyricView();
    lyricLineStreamSubscription =
        lyricService.lyricLineStream.listen(_updateNextLyricLine);
  }

  void _initLyricView() {
    final next = widget.lyric.lines.indexWhere(
      (element) =>
          element.start.inMilliseconds / 1000 > playbackService.position,
    );
    final nextLyricLine = next == -1 ? widget.lyric.lines.length : next;
    lyricTiles = _generateLyricTiles(max(nextLyricLine - 1, 0));

    _scrollCurrentLyricIntoView(animated: false);
  }

  @override
  void didUpdateWidget(covariant _VerticalLyricScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyric == widget.lyric) {
      if (oldWidget.currentLineAlignment != widget.currentLineAlignment) {
        _scrollCurrentLyricIntoView(animated: false);
      }
      return;
    }
    _lastSafeIndex = null;
    _lastLyricUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    _initLyricView();
  }

  void _seekToLyricLine(int i) {
    playbackService.seek(widget.lyric.lines[i].start.inMilliseconds / 1000);
    setState(() {
      lyricTiles = _generateLyricTiles(i);
    });
  }

  List<LyricViewTile> _generateLyricTiles(int mainLine) {
    return List.generate(
      widget.lyric.lines.length,
      (i) {
        final isCurrent = i == mainLine;
        final isPast = i < mainLine;
        final distanceFromCurrent = (i - mainLine).abs();
        final opacity = resolveLyricLineOpacity(
          distanceFromCurrent: distanceFromCurrent,
          isPastLine: isPast,
        );
        return LyricViewTile(
          key: i == mainLine ? currentLyricTileKey : null,
          line: widget.lyric.lines[i],
          opacity: opacity,
          isCurrentLine: isCurrent,
          isPastLine: isPast,
          distanceFromCurrent: distanceFromCurrent,
          onTap: () => _seekToLyricLine(i),
        );
      },
    );
  }

  void _updateNextLyricLine(int lyricLine) {
    if (widget.lyric.lines.isEmpty) return;
    final safeIndex = lyricLine.clamp(0, widget.lyric.lines.length - 1).toInt();
    final now = DateTime.now();
    if (_lastSafeIndex == safeIndex &&
        now.difference(_lastLyricUpdateAt) <
            const Duration(milliseconds: 120)) {
      return;
    }
    final isLargeJump = _lastSafeIndex != null &&
        (safeIndex - _lastSafeIndex!).abs() > 5;
    _lastSafeIndex = safeIndex;
    _lastLyricUpdateAt = now;
    lyricTiles = _generateLyricTiles(safeIndex);
    setState(() {});

    _scrollCurrentLyricIntoView(animated: !isLargeJump, jumpFast: isLargeJump);
  }

  void _scrollCurrentLyricIntoView({
    bool animated = true,
    bool jumpFast = false,
    int attempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      if (!scrollController.hasClients) {
        _retryScrollCurrentLyricIntoView(
          animated: animated,
          jumpFast: jumpFast,
          attempt: attempt,
        );
        return;
      }

      final targetContext = currentLyricTileKey.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        _retryScrollCurrentLyricIntoView(
          animated: animated,
          jumpFast: jumpFast,
          attempt: attempt,
        );
        return;
      }

      final duration = jumpFast
          ? const Duration(milliseconds: 120)
          : animated
              ? context.motion.lyricScrollDuration
              : Duration.zero;
      final curve = jumpFast ? Curves.easeOutCubic : context.motion.emphasized;

      Scrollable.ensureVisible(
        targetContext,
        alignment: widget.currentLineAlignment,
        duration: duration,
        curve: curve,
      );
    });
  }

  void _retryScrollCurrentLyricIntoView({
    required bool animated,
    bool jumpFast = false,
    required int attempt,
  }) {
    if (attempt >= 3) return;
    Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)), () {
      if (!mounted) return;
      _scrollCurrentLyricIntoView(
        animated: animated,
        jumpFast: jumpFast,
        attempt: attempt + 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomScrollView(
        key: LYRIC_VIEW_KEY,
        controller: scrollController,
        slivers: [
          const SliverFillRemaining(),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lyricTiles,
              ),
            ),
          ),
          const SliverFillRemaining(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
  }
}
