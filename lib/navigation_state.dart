import 'package:coriander_player/app_paths.dart' as app_paths;

class AppNavigationState {
  AppNavigationState._();

  static final AppNavigationState instance = AppNavigationState._();

  String _lastShellLocation = app_paths.AUDIOS_PAGE;

  String get lastShellLocation => _lastShellLocation;

  void rememberShellLocation(String location) {
    if (location.isEmpty || location == app_paths.NOW_PLAYING_PAGE) {
      return;
    }
    _lastShellLocation = location;
  }
}
