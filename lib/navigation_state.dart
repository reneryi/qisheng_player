import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class ArtworkHeroTransition {
  const ArtworkHeroTransition({
    required this.tag,
    required this.sourceKey,
  });

  final String? tag;
  final Object sourceKey;
}

typedef AlbumArtworkHeroTransition = ArtworkHeroTransition;

class AppNavigationEntry {
  const AppNavigationEntry(this.location, {this.extra});

  final String location;
  final Object? extra;
}

class AppNavigationState extends ChangeNotifier {
  AppNavigationState._();

  static final AppNavigationState instance = AppNavigationState._();

  // 侧边栏及 Shell 页面对应的路由次序列表，用于判断侧边栏切换时的滑动方向
  static const List<String> _shellPagesOrder = [
    app_paths.AUDIOS_PAGE,
    app_paths.ARTISTS_PAGE,
    app_paths.ALBUMS_PAGE,
    app_paths.FOLDERS_PAGE,
    app_paths.PLAYLISTS_PAGE,
    app_paths.SETTINGS_PAGE,
    app_paths.SEARCH_PAGE,
  ];

  // 记录转场的横向滑动方向：1 表示自右向左（前进），-1 表示自左向右（后退）
  int _slideDirection = 1;
  int get slideDirection => _slideDirection;

  String _lastShellLocation = app_paths.AUDIOS_PAGE;
  final List<AppNavigationEntry> _history = [
    const AppNavigationEntry(app_paths.AUDIOS_PAGE),
  ];
  int _historyIndex = 0;
  String? _pendingHistoryLocation;
  bool _artworkNavigationInFlight = false;

  final ValueNotifier<ArtworkHeroTransition?> albumArtworkHeroTransition =
      ValueNotifier(null);

  ValueNotifier<ArtworkHeroTransition?> get artworkHeroTransition =>
      albumArtworkHeroTransition;

  String get lastShellLocation => _lastShellLocation;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _history.length - 1;
  AppNavigationEntry get currentEntry => _history[_historyIndex];

  void rememberShellLocation(String location) {
    rememberLocation(location);
  }

  void rememberLocation(String location, {Object? extra}) {
    if (location != app_paths.ALBUM_DETAIL_PAGE &&
        location != app_paths.ARTIST_DETAIL_PAGE &&
        _artworkNavigationInFlight) {
      // Detail pages may be dismissed via go()/shell navigation instead of pop().
      // Release the hero guard so the source tile can be tapped again.
      albumArtworkHeroTransition.value = null;
      _artworkNavigationInFlight = false;
    }

    if (!_shouldTrackLocation(location)) {
      return;
    }

    // 检查当前页面与上一页面路径，判定横向滑动过渡方向
    final newIndex = _shellPagesOrder.indexWhere((p) => location.startsWith(p));
    final oldIndex =
        _shellPagesOrder.indexWhere((p) => _lastShellLocation.startsWith(p));

    final isNewDetail = location.contains('/detail') ||
        location.contains('/result') ||
        location.contains('/issue');
    final isOldDetail = _lastShellLocation.contains('/detail') ||
        _lastShellLocation.contains('/result') ||
        _lastShellLocation.contains('/issue');

    if (isNewDetail && !isOldDetail) {
      // 从主列表进入详情子页面：向左滑入
      _slideDirection = 1;
    } else if (!isNewDetail && isOldDetail) {
      // 从详情子页面退回主列表：向右滑出退回
      _slideDirection = -1;
    } else if (newIndex != -1 && oldIndex != -1 && newIndex != oldIndex) {
      // 侧边栏同级主页面切换：右侧页面则向左滑入，左侧页面向右滑入
      _slideDirection = newIndex > oldIndex ? 1 : -1;
    }

    if (_isShellLocation(location)) {
      _lastShellLocation = location;
    }

    final current = _history[_historyIndex];
    if (_sameEntry(current, location, extra)) {
      _pendingHistoryLocation = null;
      return;
    }

    if (_pendingHistoryLocation == location) {
      _pendingHistoryLocation = null;
      return;
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(AppNavigationEntry(location, extra: extra));
    _historyIndex = _history.length - 1;

    // 避免在 widget 树 build 期间同步触发 notifyListeners 导致 markNeedsBuild 异常或卡死
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  AppNavigationEntry? moveHistoryBackEntry() {
    if (!canGoBack) return null;
    _historyIndex -= 1;
    final target = _history[_historyIndex];
    _pendingHistoryLocation = target.location;
    if (_isShellLocation(target.location)) {
      _lastShellLocation = target.location;
    }
    notifyListeners();
    return target;
  }

  AppNavigationEntry? moveHistoryForwardEntry() {
    if (!canGoForward) return null;
    _historyIndex += 1;
    final target = _history[_historyIndex];
    _pendingHistoryLocation = target.location;
    if (_isShellLocation(target.location)) {
      _lastShellLocation = target.location;
    }
    notifyListeners();
    return target;
  }

  String? moveShellHistoryBack() {
    return moveHistoryBackEntry()?.location;
  }

  String? moveShellHistoryForward() {
    return moveHistoryForwardEntry()?.location;
  }

  void openNowPlaying(BuildContext context) {
    if (currentEntry.location == app_paths.NOW_PLAYING_PAGE) return;
    // 在跳转前主动将状态置为 true，使底层首帧就能感知并准备缩放
    setNowPlayingPageActive(true);
    context.push(app_paths.NOW_PLAYING_PAGE);
  }

  AppNavigationEntry? prepareNowPlayingClose() {
    if (currentEntry.location != app_paths.NOW_PLAYING_PAGE || !canGoBack) {
      return null;
    }
    return moveHistoryBackEntry();
  }

  bool closeNowPlaying(BuildContext context, {String? fallback}) {
    // 先启动 Shell 的延迟恢复；包装层仍保留原布局和 Hero 目标矩形，
    // 只在反向转场后半段恢复绘制与命中。
    final previous = prepareNowPlayingClose();
    setNowPlayingPageActive(false);
    if (context.canPop()) {
      context.pop();
      return true;
    }
    if (previous != null) {
      context.go(previous.location, extra: previous.extra);
      return true;
    }
    final fallbackLocation = fallback ?? lastShellLocation;
    if (fallbackLocation.isNotEmpty) {
      context.go(fallbackLocation);
      return true;
    }
    return false;
  }

  bool navigateBack(BuildContext context, {String? fallback}) {
    if (currentEntry.location == app_paths.NOW_PLAYING_PAGE) {
      return closeNowPlaying(context, fallback: fallback);
    }
    final target = canGoBack ? moveHistoryBackEntry() : null;
    if (context.canPop()) {
      context.pop();
      return true;
    }
    if (target != null) {
      context.go(target.location, extra: target.extra);
      return true;
    }
    final fallbackLocation = fallback ?? app_paths.AUDIOS_PAGE;
    if (fallbackLocation.isNotEmpty) {
      context.go(fallbackLocation);
      return true;
    }
    return false;
  }

  bool navigateForward(BuildContext context) {
    final target = moveHistoryForwardEntry();
    if (target == null) return false;
    context.go(target.location, extra: target.extra);
    return true;
  }

  @visibleForTesting
  void resetShellHistoryForTesting([String initial = app_paths.AUDIOS_PAGE]) {
    _lastShellLocation = initial;
    _history
      ..clear()
      ..add(AppNavigationEntry(initial));
    _historyIndex = 0;
    _pendingHistoryLocation = null;
    notifyListeners();
  }

  bool _shouldTrackLocation(String location) {
    return location.isNotEmpty &&
        location != app_paths.WELCOMING_PAGE &&
        location != app_paths.UPDATING_DIALOG;
  }

  bool _isShellLocation(String location) {
    return _shouldTrackLocation(location) &&
        location != app_paths.NOW_PLAYING_PAGE;
  }

  bool _sameEntry(AppNavigationEntry entry, String location, Object? extra) {
    return entry.location == location && identical(entry.extra, extra);
  }

  bool beginAlbumArtworkHeroNavigation({
    required String? tag,
    required Object sourceKey,
  }) =>
      beginArtworkHeroNavigation(tag: tag, sourceKey: sourceKey);

  bool beginArtworkHeroNavigation({
    required String? tag,
    required Object sourceKey,
  }) {
    if (_artworkNavigationInFlight) return false;
    _artworkNavigationInFlight = true;
    albumArtworkHeroTransition.value = ArtworkHeroTransition(
      tag: tag,
      sourceKey: sourceKey,
    );
    return true;
  }

  void endAlbumArtworkHeroNavigation(Object sourceKey) {
    endArtworkHeroNavigation(sourceKey);
  }

  void endArtworkHeroNavigation(Object sourceKey) {
    final active = albumArtworkHeroTransition.value;
    if (active == null || identical(active.sourceKey, sourceKey)) {
      albumArtworkHeroTransition.value = null;
      _artworkNavigationInFlight = false;
    }
  }

  bool canBuildAlbumArtworkHero({
    required String tag,
    Object? sourceKey,
  }) =>
      canBuildArtworkHero(tag: tag, sourceKey: sourceKey);

  bool canBuildArtworkHero({
    required String tag,
    Object? sourceKey,
  }) {
    final active = albumArtworkHeroTransition.value;
    if (active == null) return true;
    if (active.tag != tag) return false;
    if (sourceKey == null) return true;
    return identical(active.sourceKey, sourceKey);
  }

  // 记录当前播放详情页是否正处于显示生命周期（包含转场期间）
  bool _nowPlayingPageActive = false;

  // 获取当前播放详情页的活跃状态
  bool get nowPlayingPageActive => _nowPlayingPageActive;

  // 更新播放详情页的活跃状态，并通知所有关联的路由监听器进行重绘
  void setNowPlayingPageActive(bool active) {
    if (_nowPlayingPageActive == active) return;
    _nowPlayingPageActive = active;
    notifyListeners();
  }
}
