import 'dart:io';
import 'dart:ui';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/component/app_shell.dart';
import 'package:qisheng_player/page/album_detail_page.dart';
import 'package:qisheng_player/page/albums_page.dart';
import 'package:qisheng_player/page/artist_detail_page.dart';
import 'package:qisheng_player/page/artists_page.dart';
import 'package:qisheng_player/component/window_resize_frame.dart';
import 'package:qisheng_player/page/audio_detail_page.dart';
import 'package:qisheng_player/page/audios_page.dart';
import 'package:qisheng_player/page/folder_detail_page.dart';
import 'package:qisheng_player/page/folders_page.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/page/playlist_detail_page.dart';
import 'package:qisheng_player/page/playlists_page.dart';
import 'package:qisheng_player/page/search_page/search_page.dart';
import 'package:qisheng_player/page/search_page/search_result_page.dart';
import 'package:qisheng_player/page/settings_page/create_issue.dart';
import 'package:qisheng_player/page/settings_page/check_update.dart';
import 'package:qisheng_player/page/settings_page/page.dart';
import 'package:qisheng_player/page/updating_page.dart';
import 'package:qisheng_player/page/welcoming_page.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme/app_shadcn_theme.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

Widget _buildAppRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  bool provideNowPlayingScope = false,
}) {
  final motion = context.motion;
  final curvedAnim = CurvedAnimation(
    parent: animation,
    curve: motion.emphasized,
    reverseCurve: motion.fast,
  );
  final backdropReveal = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.0, 0.26, curve: Curves.easeInCubic),
  );
  final contentReveal = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.08, 0.92, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.0, 0.74, curve: Curves.easeInCubic),
  );
  final secondaryCurvedAnim = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final transitionedChild = provideNowPlayingScope
      ? NowPlayingRouteTransitionScope(animation: curvedAnim, child: child)
      : child;

  return FadeTransition(
    opacity: Tween<double>(begin: 0.72, end: 1).animate(backdropReveal),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(contentReveal),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.988, end: 1).animate(contentReveal),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.8, end: 1).animate(contentReveal),
          child: AnimatedBuilder(
            animation: secondaryCurvedAnim,
            child: transitionedChild,
            builder: (context, child) {
              final progress = secondaryCurvedAnim.value;
              return ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 8 * progress,
                  sigmaY: 8 * progress,
                ),
                child: Opacity(
                  opacity: 1 - 0.3 * progress,
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class SlideTransitionPage<T> extends CustomTransitionPage<T> {
  const SlideTransitionPage({
    required super.child,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
  }) : super(
          transitionsBuilder: _transitionsBuilder,
          transitionDuration: const Duration(milliseconds: 430),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );

  static Widget _transitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildAppRouteTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class NowPlayingTransitionPage<T> extends CustomTransitionPage<T> {
  const NowPlayingTransitionPage({
    required super.child,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
  }) : super(
          transitionsBuilder: _transitionsBuilder,
          transitionDuration: const Duration(milliseconds: 430),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );

  static Widget _transitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildAppRouteTransition(
      context,
      animation,
      secondaryAnimation,
      child,
      provideNowPlayingScope: true,
    );
  }
}

class Entry extends StatelessWidget {
  Entry({super.key, required this.welcome});
  final bool welcome;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ThemeProvider.instance),
        ChangeNotifierProvider.value(
          value: PlayService.instance.playbackService,
        ),
        ChangeNotifierProvider<PlaybackController>.value(
          value: PlayService.instance.playbackService,
        ),
        ChangeNotifierProvider.value(value: PlayService.instance.lyricService),
        ChangeNotifierProvider<LyricController>.value(
          value: PlayService.instance.lyricService,
        ),
        ChangeNotifierProvider.value(
          value: PlayService.instance.desktopLyricService,
        ),
        ChangeNotifierProvider<DesktopLyricController>.value(
          value: PlayService.instance.desktopLyricService,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final lightTheme = AppTheme.build(
            fontFamily: theme.fontFamily,
            colorScheme: theme.lightScheme,
            effectsLevel: theme.uiEffectsLevel,
            visualStyleMode: theme.visualStyleMode,
            windowBackdropMode: theme.windowBackdropMode,
          );
          final darkTheme = AppTheme.build(
            fontFamily: theme.fontFamily,
            colorScheme: theme.darkScheme,
            effectsLevel: theme.uiEffectsLevel,
            visualStyleMode: theme.visualStyleMode,
            windowBackdropMode: theme.windowBackdropMode,
          );
          return MaterialApp.router(
            scaffoldMessengerKey: SCAFFOLD_MESSAGER,
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: theme.themeMode,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: supportedLocales,
            routerConfig: config,
            builder: (context, child) {
              final materialTheme = Theme.of(context);
              final shadcnTheme = AppShadcnTheme.build(
                colorScheme: materialTheme.colorScheme,
                fontFamily: theme.fontFamily,
              );
              final routedChild = Platform.isWindows
                  ? child ?? const SizedBox.shrink()
                  : WindowResizeFrame(
                      child: child ?? const SizedBox.shrink(),
                    );
              return shadcn.Theme(
                data: shadcnTheme,
                child: StartupUpdatePrompt(
                  child: Listener(
                    onPointerDown: HotkeysHelper.handlePointerDown,
                    child: routedChild,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  late final GoRouter config = GoRouter(
    navigatorKey: ROUTER_KEY,
    initialLocation: welcome ? app_paths.WELCOMING_PAGE : _startLocation(),
    routes: [
      ShellRoute(
        builder: (context, state, page) {
          AppNavigationState.instance.rememberLocation(
            state.uri.toString(),
            extra: state.extra,
          );
          return AppShell(
            page: page,
            pageIdentity: state.uri.toString(),
          );
        },
        routes: [
          /// audios page
          GoRoute(
            path: app_paths.AUDIOS_PAGE,
            pageBuilder: (context, state) {
              if (state.extra != null) {
                return SlideTransitionPage(
                    child: AudiosPage(locateTo: state.extra as Audio));
              }
              return const SlideTransitionPage(child: AudiosPage());
            },
            routes: [
              GoRoute(
                path: "detail",
                pageBuilder: (context, state) => SlideTransitionPage(
                  child: AudioDetailPage(audio: state.extra as Audio),
                ),
              ),
            ],
          ),

          /// artists page
          GoRoute(
            path: app_paths.ARTISTS_PAGE,
            pageBuilder: (context, state) => const SlideTransitionPage(
              child: ArtistsPage(),
            ),
            routes: [
              GoRoute(
                path: "detail",
                pageBuilder: (context, state) => SlideTransitionPage(
                  child: ArtistDetailPage(artist: state.extra as Artist),
                ),
              ),
            ],
          ),

          /// albums page
          GoRoute(
            path: app_paths.ALBUMS_PAGE,
            pageBuilder: (context, state) => const SlideTransitionPage(
              child: AlbumsPage(),
            ),
            routes: [
              GoRoute(
                path: "detail",
                pageBuilder: (context, state) => SlideTransitionPage(
                  child: AlbumDetailPage(album: state.extra as Album),
                ),
              ),
            ],
          ),

          /// folders page
          GoRoute(
            path: app_paths.FOLDERS_PAGE,
            pageBuilder: (context, state) => const SlideTransitionPage(
              child: FoldersPage(),
            ),
            routes: [
              /// folder detail page
              GoRoute(
                path: "detail",
                pageBuilder: (context, state) {
                  final folder = state.extra as AudioFolder;
                  return SlideTransitionPage(
                    child: FolderDetailPage(folder: folder),
                  );
                },
              ),
            ],
          ),

          /// playlists page
          GoRoute(
            path: app_paths.PLAYLISTS_PAGE,
            pageBuilder: (context, state) => const SlideTransitionPage(
              child: PlaylistsPage(),
            ),
            routes: [
              GoRoute(
                path: "detail",
                pageBuilder: (context, state) {
                  final playlist = state.extra as Playlist;
                  return SlideTransitionPage(
                    child: PlaylistDetailPage(playlist: playlist),
                  );
                },
              ),
            ],
          ),

          /// search page
          GoRoute(
            path: app_paths.SEARCH_PAGE,
            pageBuilder: (context, state) => const SlideTransitionPage(
              child: SearchPage(),
            ),
            routes: [
              GoRoute(
                path: "result",
                redirect: (context, state) {
                  final query = state.uri.queryParameters["q"]?.trim() ?? "";
                  return query.isEmpty ? app_paths.SEARCH_PAGE : null;
                },
                pageBuilder: (context, state) {
                  final query = state.uri.queryParameters["q"]!.trim();
                  final extraResult = state.extra;
                  final result = extraResult is UnionSearchResult &&
                          extraResult.query == query
                      ? extraResult
                      : UnionSearchResult.search(query);
                  return SlideTransitionPage(
                    child: SearchResultPage(
                      initialQuery: query,
                      initialResult: result,
                    ),
                  );
                },
              ),
            ],
          ),

          /// settings page
          GoRoute(
              path: app_paths.SETTINGS_PAGE,
              pageBuilder: (context, state) => const SlideTransitionPage(
                    child: SettingsPage(),
                  ),
              routes: [
                GoRoute(
                  path: "issue",
                  pageBuilder: (context, state) => const SlideTransitionPage(
                    child: SettingsIssuePage(),
                  ),
                )
              ]),
        ],
      ),

      /// now playing page
      GoRoute(
        path: app_paths.NOW_PLAYING_PAGE,
        pageBuilder: (context, state) {
          AppNavigationState.instance.rememberLocation(
            state.uri.toString(),
            extra: state.extra,
          );
          return const NowPlayingTransitionPage(
            child: NowPlayingPage(),
          );
        },
      ),

      /// welcoming page
      GoRoute(
        path: app_paths.WELCOMING_PAGE,
        pageBuilder: (context, state) => const SlideTransitionPage(
          child: WelcomingPage(),
        ),
      ),

      /// updating dialog
      GoRoute(
        path: app_paths.UPDATING_DIALOG,
        pageBuilder: (context, state) => const SlideTransitionPage(
          child: UpdatingPage(),
        ),
      ),
    ],
  );

  final supportedLocales = const [
    Locale.fromSubtags(languageCode: 'zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
    Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
    Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'),
    Locale("en", "US"),
  ];

  String _startLocation() {
    final startPage = AppPreference.instance.startPage;
    return startPage >= 0 && startPage < app_paths.START_PAGES.length
        ? app_paths.START_PAGES[startPage]
        : app_paths.AUDIOS_PAGE;
  }
}
