import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:flutter/foundation.dart';

class AlbumArtworkHeroTransition {
  const AlbumArtworkHeroTransition({
    required this.tag,
    required this.sourceKey,
  });

  final String? tag;
  final Object sourceKey;
}

class AppNavigationState {
  AppNavigationState._();

  static final AppNavigationState instance = AppNavigationState._();

  String _lastShellLocation = app_paths.AUDIOS_PAGE;
  bool _albumArtworkNavigationInFlight = false;

  final ValueNotifier<AlbumArtworkHeroTransition?> albumArtworkHeroTransition =
      ValueNotifier(null);

  String get lastShellLocation => _lastShellLocation;

  void rememberShellLocation(String location) {
    if (location.isEmpty || location == app_paths.NOW_PLAYING_PAGE) {
      return;
    }
    _lastShellLocation = location;
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
