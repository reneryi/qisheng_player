import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/navigation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppNavigationState ignores now playing and remembers shell route', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();

    navigation.rememberShellLocation(app_paths.PLAYLISTS_PAGE);
    expect(navigation.lastShellLocation, app_paths.PLAYLISTS_PAGE);

    navigation.rememberShellLocation(app_paths.NOW_PLAYING_PAGE);
    expect(navigation.lastShellLocation, app_paths.PLAYLISTS_PAGE);
  });

  test('AppNavigationState supports shell back and forward history', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();

    navigation.rememberShellLocation(app_paths.ALBUMS_PAGE);
    navigation.rememberShellLocation(app_paths.SETTINGS_PAGE);

    expect(navigation.canGoBack, isTrue);
    expect(navigation.moveShellHistoryBack(), app_paths.ALBUMS_PAGE);
    expect(navigation.canGoForward, isTrue);
    expect(navigation.moveShellHistoryForward(), app_paths.SETTINGS_PAGE);
  });

  test('AppNavigationState notifies listeners when shell history changes', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();
    var notifyCount = 0;

    void listener() {
      notifyCount += 1;
    }

    navigation.addListener(listener);
    addTearDown(() => navigation.removeListener(listener));

    navigation.rememberShellLocation(app_paths.ALBUMS_PAGE);
    navigation.moveShellHistoryBack();
    navigation.moveShellHistoryForward();
    expect(notifyCount, greaterThanOrEqualTo(2));
  });

  test('AppNavigationState preserves query parameters in shell history', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();
    final searchLocation = app_paths.buildSearchResultLocation('楣挎櫁');

    navigation.rememberShellLocation(searchLocation);
    navigation.rememberShellLocation(app_paths.SETTINGS_PAGE);

    expect(navigation.moveShellHistoryBack(), searchLocation);
    expect(navigation.lastShellLocation, searchLocation);
  });

  test('AppNavigationState preserves route extras in history entries', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();
    final extra = Object();

    navigation.rememberLocation(app_paths.ALBUM_DETAIL_PAGE, extra: extra);
    navigation.rememberLocation(app_paths.NOW_PLAYING_PAGE);

    final target = navigation.moveHistoryBackEntry();
    expect(target?.location, app_paths.ALBUM_DETAIL_PAGE);
    expect(identical(target?.extra, extra), isTrue);
  });

  test('AppNavigationState tracks same route with different extras', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();
    final first = Object();
    final second = Object();

    navigation.rememberLocation(app_paths.ALBUM_DETAIL_PAGE, extra: first);
    navigation.rememberLocation(app_paths.ALBUM_DETAIL_PAGE, extra: second);

    final target = navigation.moveHistoryBackEntry();
    expect(target?.location, app_paths.ALBUM_DETAIL_PAGE);
    expect(identical(target?.extra, first), isTrue);
  });

  test('AppNavigationState rolls history back before closing now playing', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();

    navigation.rememberShellLocation(app_paths.ALBUMS_PAGE);
    navigation.rememberLocation(app_paths.NOW_PLAYING_PAGE);

    final previous = navigation.prepareNowPlayingClose();
    expect(previous?.location, app_paths.ALBUMS_PAGE);
    expect(navigation.currentEntry.location, app_paths.ALBUMS_PAGE);
    expect(navigation.canGoForward, isTrue);
  });

  test('AppNavigationState restores detail entry when closing now playing', () {
    final navigation = AppNavigationState.instance;
    navigation.resetShellHistoryForTesting();
    final extra = Object();

    navigation.rememberLocation(app_paths.ALBUM_DETAIL_PAGE, extra: extra);
    navigation.rememberLocation(app_paths.NOW_PLAYING_PAGE);

    final previous = navigation.prepareNowPlayingClose();
    expect(previous?.location, app_paths.ALBUM_DETAIL_PAGE);
    expect(identical(previous?.extra, extra), isTrue);
    expect(identical(navigation.currentEntry.extra, extra), isTrue);
  });
}
