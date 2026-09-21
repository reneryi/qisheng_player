import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/navigation_state.dart';

class _TestPopupRoute<T> extends PopupRoute<T> {
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) =>
      const SizedBox();
  @override
  Duration get transitionDuration => Duration.zero;
}

class _TestPageRoute<T> extends PageRoute<T> {
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) =>
      const SizedBox();
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  bool get maintainState => true;
}

GoRouter createTestRouter({
  String initialLocation = app_paths.AUDIOS_PAGE,
  List<NavigatorObserver>? observers,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    observers: observers ?? [AppNavigationState.instance.routeObserver],
    routes: [
      ShellRoute(
        builder: (context, state, page) {
          AppNavigationState.instance.rememberLocation(
            state.uri.toString(),
            extra: state.extra,
          );
          return page;
        },
        routes: [
          GoRoute(
            path: app_paths.AUDIOS_PAGE,
            builder: (context, state) =>
                const Scaffold(body: Text('AudiosPage')),
          ),
          GoRoute(
            path: app_paths.ALBUMS_PAGE,
            builder: (context, state) =>
                const Scaffold(body: Text('AlbumsPage')),
          ),
        ],
      ),
      GoRoute(
        path: app_paths.NOW_PLAYING_PAGE,
        pageBuilder: (context, state) {
          AppNavigationState.instance.rememberLocation(
            state.uri.toString(),
            extra: state.extra,
          );
          return const MaterialPage(
            child: Scaffold(body: Text('NowPlayingPage')),
          );
        },
      ),
    ],
  );
}

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
    final searchLocation = app_paths.buildSearchResultLocation('鹿晈');

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

  group('Milestone 2 (R2): AppNavigationRouteObserver Unit Tests', () {
    test('tracks PopupRoute lifecycle (push, pop, remove, replace)', () {
      final observer = AppNavigationRouteObserver();
      final popup1 = _TestPopupRoute<void>();
      final popup2 = _TestPopupRoute<void>();
      final popup3 = _TestPopupRoute<void>();

      expect(observer.hasActiveModal, isFalse);
      expect(observer.topModalRoute, isNull);

      observer.didPush(popup1, null);
      expect(observer.hasActiveModal, isTrue);
      expect(observer.topModalRoute, equals(popup1));

      observer.didPush(popup2, popup1);
      expect(observer.topModalRoute, equals(popup2));

      // Pop popup2, popup1 remains
      observer.didPop(popup2, popup1);
      expect(observer.hasActiveModal, isTrue);
      expect(observer.topModalRoute, equals(popup1));

      // Replace popup1 with popup3
      observer.didReplace(newRoute: popup3, oldRoute: popup1);
      expect(observer.hasActiveModal, isTrue);
      expect(observer.topModalRoute, equals(popup3));

      // Remove popup3
      observer.didRemove(popup3, null);
      expect(observer.hasActiveModal, isFalse);
      expect(observer.topModalRoute, isNull);
    });

    test('ignores non-PopupRoute routes', () {
      final observer = AppNavigationRouteObserver();
      final pageRoute = _TestPageRoute<void>();

      observer.didPush(pageRoute, null);
      expect(observer.hasActiveModal, isFalse);
      expect(observer.topModalRoute, isNull);

      observer.didPop(pageRoute, null);
      expect(observer.hasActiveModal, isFalse);
    });

    test('resetShellHistoryForTesting clears modals and active states', () {
      final navigation = AppNavigationState.instance;
      final popup = _TestPopupRoute<void>();
      navigation.routeObserver.didPush(popup, null);
      navigation.setNowPlayingPageActive(true);

      expect(navigation.routeObserver.hasActiveModal, isTrue);
      expect(navigation.nowPlayingPageActive, isTrue);

      navigation.resetShellHistoryForTesting();
      expect(navigation.routeObserver.hasActiveModal, isFalse);
      expect(navigation.nowPlayingPageActive, isFalse);
    });
  });

  group('Milestone 2 (R2): Modal & Navigation Anti-deadlock Widget Tests', () {
    testWidgets(
        'navigateBack pops PopupRoute modal without modifying history index or currentEntry',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));
      context.go(app_paths.ALBUMS_PAGE);
      await tester.pumpAndSettle();

      expect(find.text('AlbumsPage'), findsOneWidget);
      expect(navigation.currentEntry.location, app_paths.ALBUMS_PAGE);
      expect(navigation.canGoBack, isTrue);

      // Open modal (QueueDrawer equivalent using showGeneralDialog / PopupRoute)
      final albumContext = tester.element(find.text('AlbumsPage'));
      showGeneralDialog<void>(
        context: albumContext,
        barrierDismissible: true,
        barrierLabel: '播放队列',
        pageBuilder: (ctx, _, __) =>
            const Scaffold(body: Text('QueueDrawerContent')),
      );
      await tester.pumpAndSettle();

      expect(find.text('QueueDrawerContent'), findsOneWidget);
      expect(navigation.routeObserver.hasActiveModal, isTrue);

      // Simulate mouse back key / shortcut calling navigateBack
      final drawerContext = tester.element(find.text('QueueDrawerContent'));
      final handled = navigation.navigateBack(drawerContext);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      // Modal is closed
      expect(find.text('QueueDrawerContent'), findsNothing);
      expect(find.text('AlbumsPage'), findsOneWidget);
      expect(navigation.routeObserver.hasActiveModal, isFalse);

      // History was preserved with ZERO shift
      expect(navigation.currentEntry.location, app_paths.ALBUMS_PAGE);
      expect(navigation.canGoBack, isTrue);
    });

    testWidgets(
        'navigateBack correctly cascades through multiple nested modals before page navigation',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));
      context.go(app_paths.ALBUMS_PAGE);
      await tester.pumpAndSettle();

      final albumContext = tester.element(find.text('AlbumsPage'));

      // 1. Open Modal 1 (e.g. Queue Drawer)
      showGeneralDialog<void>(
        context: albumContext,
        barrierDismissible: true,
        barrierLabel: 'Modal1',
        pageBuilder: (ctx, _, __) =>
            const Scaffold(body: Text('Modal1Content')),
      );
      await tester.pumpAndSettle();

      // 2. Open Modal 2 (e.g. Confirmation Dialog)
      final modal1Context = tester.element(find.text('Modal1Content'));
      showGeneralDialog<void>(
        context: modal1Context,
        barrierDismissible: true,
        barrierLabel: 'Modal2',
        pageBuilder: (ctx, _, __) =>
            const Scaffold(body: Text('Modal2Content')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modal1Content'), findsOneWidget);
      expect(find.text('Modal2Content'), findsOneWidget);
      expect(navigation.routeObserver.hasActiveModal, isTrue);

      // First back: Closes Modal 2 only
      final modal2Context = tester.element(find.text('Modal2Content'));
      expect(navigation.navigateBack(modal2Context), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Modal2Content'), findsNothing);
      expect(find.text('Modal1Content'), findsOneWidget);
      expect(navigation.routeObserver.hasActiveModal, isTrue);
      expect(navigation.currentEntry.location, app_paths.ALBUMS_PAGE);

      // Second back: Closes Modal 1
      final currentModal1Context = tester.element(find.text('Modal1Content'));
      expect(navigation.navigateBack(currentModal1Context), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Modal1Content'), findsNothing);
      expect(find.text('AlbumsPage'), findsOneWidget);
      expect(navigation.routeObserver.hasActiveModal, isFalse);
      expect(navigation.currentEntry.location, app_paths.ALBUMS_PAGE);

      // Third back: Navigates back in history from AlbumsPage to AudiosPage
      final albumsContext = tester.element(find.text('AlbumsPage'));
      expect(navigation.navigateBack(albumsContext), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('AudiosPage'), findsOneWidget);
      expect(navigation.currentEntry.location, app_paths.AUDIOS_PAGE);
      expect(navigation.canGoBack, isFalse);
    });

    testWidgets(
        'openNowPlaying does not deadlock when nowPlayingPageActive is false even if history points to NOW_PLAYING_PAGE',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Simulate the previously fatal condition: history somehow pointed to NOW_PLAYING_PAGE, but page was not active
      navigation.rememberLocation(app_paths.NOW_PLAYING_PAGE);
      navigation.setNowPlayingPageActive(false);

      expect(navigation.currentEntry.location, app_paths.NOW_PLAYING_PAGE);
      expect(navigation.nowPlayingPageActive, isFalse);

      final context = tester.element(find.text('AudiosPage'));
      navigation.openNowPlaying(context);
      await tester.pumpAndSettle();

      expect(navigation.nowPlayingPageActive, isTrue);
      expect(find.text('NowPlayingPage'), findsOneWidget);
    });

    testWidgets(
        'openNowPlaying successfully opens now playing after modal drawer dismissal',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));

      // Open and dismiss queue drawer
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'QueueDrawer',
        pageBuilder: (ctx, _, __) =>
            const Scaffold(body: Text('QueueDrawerContent')),
      );
      await tester.pumpAndSettle();

      final drawerContext = tester.element(find.text('QueueDrawerContent'));
      navigation.navigateBack(drawerContext);
      await tester.pumpAndSettle();

      expect(navigation.routeObserver.hasActiveModal, isFalse);

      // Bottom bar tap expands now playing
      final audiosContext = tester.element(find.text('AudiosPage'));
      navigation.openNowPlaying(audiosContext);
      await tester.pumpAndSettle();

      expect(find.text('NowPlayingPage'), findsOneWidget);
      expect(navigation.nowPlayingPageActive, isTrue);
    });

    testWidgets(
        'openNowPlaying guards against re-entrancy when nowPlayingPageActive is true',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));
      navigation.openNowPlaying(context);
      await tester.pumpAndSettle();

      expect(navigation.nowPlayingPageActive, isTrue);
      expect(find.text('NowPlayingPage'), findsOneWidget);

      // Re-entrant call should be guarded
      final npContext = tester.element(find.text('NowPlayingPage'));
      navigation.openNowPlaying(npContext);
      await tester.pumpAndSettle();

      expect(find.text('NowPlayingPage'), findsOneWidget);
    });

    testWidgets('navigateForward is blocked when active modal exists',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));
      context.go(app_paths.ALBUMS_PAGE);
      await tester.pumpAndSettle();

      final albumsContext = tester.element(find.text('AlbumsPage'));
      navigation.navigateBack(albumsContext);
      await tester.pumpAndSettle();

      expect(find.text('AudiosPage'), findsOneWidget);
      expect(navigation.canGoForward, isTrue);

      // Open a modal
      final audiosContext = tester.element(find.text('AudiosPage'));
      showGeneralDialog<void>(
        context: audiosContext,
        barrierDismissible: true,
        barrierLabel: 'ActiveModal',
        pageBuilder: (ctx, _, __) =>
            const Scaffold(body: Text('ActiveModalContent')),
      );
      await tester.pumpAndSettle();

      expect(navigation.routeObserver.hasActiveModal, isTrue);

      // Forward should be blocked
      final modalContext = tester.element(find.text('ActiveModalContent'));
      final forwardResult = navigation.navigateForward(modalContext);
      expect(forwardResult, isFalse);
      expect(navigation.currentEntry.location, app_paths.AUDIOS_PAGE);
    });

    testWidgets(
        'navigateForward to NOW_PLAYING_PAGE triggers openNowPlaying push instead of context.go',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));
      navigation.openNowPlaying(context);
      await tester.pumpAndSettle();
      expect(find.text('NowPlayingPage'), findsOneWidget);
      expect(navigation.nowPlayingPageActive, isTrue);

      // Close now playing
      final npContext = tester.element(find.text('NowPlayingPage'));
      navigation.closeNowPlaying(npContext);
      await tester.pumpAndSettle();
      expect(find.text('AudiosPage'), findsOneWidget);
      expect(navigation.nowPlayingPageActive, isFalse);
      expect(navigation.canGoForward, isTrue);

      // Forward should push NOW_PLAYING_PAGE via openNowPlaying
      final audiosContext = tester.element(find.text('AudiosPage'));
      final handled = navigation.navigateForward(audiosContext);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('NowPlayingPage'), findsOneWidget);
      expect(navigation.nowPlayingPageActive, isTrue);
      expect(navigation.currentEntry.location, app_paths.NOW_PLAYING_PAGE);
    });

    testWidgets(
        'navigateForward to regular shell page performs normal forward navigation',
        (tester) async {
      final router = createTestRouter();
      final navigation = AppNavigationState.instance;
      navigation.resetShellHistoryForTesting(app_paths.AUDIOS_PAGE);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('AudiosPage'));
      context.go(app_paths.ALBUMS_PAGE);
      await tester.pumpAndSettle();

      final albumsContext = tester.element(find.text('AlbumsPage'));
      navigation.navigateBack(albumsContext);
      await tester.pumpAndSettle();

      expect(find.text('AudiosPage'), findsOneWidget);
      expect(navigation.canGoForward, isTrue);

      final audiosContext = tester.element(find.text('AudiosPage'));
      final handled = navigation.navigateForward(audiosContext);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('AlbumsPage'), findsOneWidget);
      expect(navigation.currentEntry.location, app_paths.ALBUMS_PAGE);
    });
  });
}
