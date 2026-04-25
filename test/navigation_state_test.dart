import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/navigation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppNavigationState ignores now playing and remembers shell route', () {
    final navigation = AppNavigationState.instance;

    navigation.rememberShellLocation(app_paths.PLAYLISTS_PAGE);
    expect(navigation.lastShellLocation, app_paths.PLAYLISTS_PAGE);

    navigation.rememberShellLocation(app_paths.NOW_PLAYING_PAGE);
    expect(navigation.lastShellLocation, app_paths.PLAYLISTS_PAGE);
  });
}
