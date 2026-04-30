import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class AlbumArtworkHeroTransition {
  const AlbumArtworkHeroTransition({
    required this.tag,
    required this.sourceKey,
  });

  final String? tag;
  final Object sourceKey;
}

class AppNavigationEntry {
  const AppNavigationEntry(this.location, {this.extra});

  final String location;
  final Object? extra;
}

class AppNavigationState extends ChangeNotifier {
  AppNavigationState._();

  static final AppNavigationState instance = AppNavigationState._();

  String _lastShellLocation = app_paths.AUDIOS_PAGE;
  final List<AppNavigationEntry> _history = [
    const AppNavigationEntry(app_paths.AUDIOS_PAGE),
  ];
  int _historyIndex = 0;
  String? _pendingHistoryLocation;
  bool _albumArtworkNavigationInFlight = false;

  final ValueNotifier<AlbumArtworkHeroTransition?> albumArtworkHeroTransition =
      ValueNotifier(null);

  String get lastShellLocation => _lastShellLocation;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _history.length - 1;
  AppNavigationEntry get currentEntry => _history[_historyIndex];

  void rememberShellLocation(String location) {
    rememberLocation(location);
  }

  void rememberLocation(String location, {Object? extra}) {
    if (location != app_paths.ALBUM_DETAIL_PAGE &&
        _albumArtworkNavigationInFlight) {
      // Album detail may be dismissed via go()/shell navigation instead of pop().
      // Release the hero guard so the source tile can be tapped again.
      albumArtworkHeroTransition.value = null;
      _albumArtworkNavigationInFlight = false;
    }

    if (!_shouldTrackLocation(location)) {
      return;
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
    notifyListeners();
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
    context.push(app_paths.NOW_PLAYING_PAGE);
  }

  AppNavigationEntry? prepareNowPlayingClose() {
    if (currentEntry.location != app_paths.NOW_PLAYING_PAGE || !canGoBack) {
      return null;
    }
    return moveHistoryBackEntry();
  }

  bool closeNowPlaying(BuildContext context, {String? fallback}) {
    final previous = prepareNowPlayingClose();
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
  }) {
    if (_albumArtworkNavigationInFlight) return false;
    _albumArtworkNavigationInFlight = true;
    albumArtworkHeroTransition.value = AlbumArtworkHeroTransition(
      tag: tag,
      sourceKey: sourceKey,
    );
    return true;
  }

  void endAlbumArtworkHeroNavigation(Object sourceKey) {
    final active = albumArtworkHeroTransition.value;
    if (active == null || identical(active.sourceKey, sourceKey)) {
      albumArtworkHeroTransition.value = null;
      _albumArtworkNavigationInFlight = false;
    }
  }

  bool canBuildAlbumArtworkHero({
    required String tag,
    Object? sourceKey,
  }) {
    final active = albumArtworkHeroTransition.value;
    if (active == null) return true;
    if (active.tag != tag) return false;
    if (sourceKey == null) return true;
    return identical(active.sourceKey, sourceKey);
  }
}
