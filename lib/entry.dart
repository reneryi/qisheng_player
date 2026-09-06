import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/component/fluid_gradient_background.dart';
import 'package:qisheng_player/component/app_shell.dart';
import 'package:qisheng_player/component/now_playing_shell_underlay.dart';
export 'package:qisheng_player/component/now_playing_shell_underlay.dart';
import 'package:qisheng_player/page/album_detail_page.dart';
import 'package:qisheng_player/page/albums_page.dart';
import 'package:qisheng_player/page/artist_detail_page.dart';
import 'package:qisheng_player/page/artists_page.dart';
import 'package:qisheng_player/component/window_resize_frame.dart';
import 'package:qisheng_player/component/windows_accessibility_tooltip_guard.dart';
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
  final contentReveal = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeInCubic),
  );
  final secondaryCurvedAnim = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final outgoingContent = CurvedAnimation(
    parent: secondaryAnimation,
    // 旧页面在新页面覆盖到中段前完成退场，避免半透明详情面板中
    // 继续看到旧列表的头像、文字和卡片轮廓。
    curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.0, 0.72, curve: Curves.easeInCubic),
  );
  final transitionedChild = provideNowPlayingScope
      ? NowPlayingRouteTransitionScope(animation: curvedAnim, child: child)
      : child;

  return FadeTransition(
    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(contentReveal),
    child: ListenableBuilder(
      listenable: AppNavigationState.instance,
      builder: (context, _) {
        final isNowPlayingAbove =
            AppNavigationState.instance.nowPlayingPageActive;
        return AnimatedBuilder(
          animation: secondaryCurvedAnim,
          child: transitionedChild,
          builder: (context, child) {
            final progress = secondaryCurvedAnim.value;
            final outgoingProgress = outgoingContent.value;

            if (isNowPlayingAbove) {
              final underlayFactor = const Interval(
                0.0,
                0.48,
                curve: Curves.easeOutCubic,
              ).transform(secondaryAnimation.value);
              final underlayScale = 1.0 - 0.04 * underlayFactor;
              final underlayOpacity = 1.0 - underlayFactor;
              return IgnorePointer(
                key: const ValueKey('now-playing-underlay-pointer'),
                ignoring: progress > 0.001,
                child: Transform.scale(
                  key: const ValueKey('now-playing-underlay-scale'),
                  scale: underlayScale.clamp(0.96, 1.0),
                  child: TickerMode(
                    enabled: underlayOpacity > 0.001,
                    child: Opacity(
                      key: const ValueKey('now-playing-underlay-opacity'),
                      opacity: underlayOpacity.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                ),
              );
            } else {
              // 侧栏页面与详情子路由的层级过渡：旧页面完整淡出，
              // 让半透明的新详情面板不会把旧内容叠在上面。
              return Transform.translate(
                offset: Offset(-12.0 * outgoingProgress, 0),
                child: Opacity(
                  opacity: (1.0 - outgoingProgress).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            }
          },
        );
      },
    ),
  );
}

// 专为播放详情页设计的全屏沉浸抽屉转场：
// 页面自下而上丝滑升起进入，退出时整页平滑向下滑出（对齐 v1.3.2 饱受好评的实体质感），
// 核心封面通过 Hero 在 Overlay 保持独立平滑飞行，实现极其柔和自然的空间动效。
Widget _buildNowPlayingRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // 采用现代三次贝塞尔曲线，入场柔和减速，退场顺畅滑走
  final slideAnim = CurvedAnimation(
    parent: animation,
    curve: const Cubic(0.2, 0.9, 0.2, 1.0),
    reverseCurve: const Cubic(0.2, 0.0, 0.3, 1.0),
  );

  // 包裹 NowPlayingRouteTransitionScope，以便详情页子组件获取动画状态
  final transitionedChild = NowPlayingRouteTransitionScope(
    animation: slideAnim,
    child: child,
  );

  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(slideAnim),
    child: transitionedChild,
  );
}

// 内容详情页（艺术家/专辑/歌曲信息/文件夹/歌单）覆盖式淡入转场。
// 详情页自身只承担一套轻量位移与淡入，旧页面的退场由其 secondaryAnimation
// 完整驱动，避免 AppShell 和嵌套路由同时移动同一棵页面树。
Widget _buildDetailRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curvedAnim = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final secondaryCurvedAnim = CurvedAnimation(
    parent: secondaryAnimation,
    curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.0, 0.72, curve: Curves.easeInCubic),
  );

  final outgoingChild = FadeTransition(
    key: const ValueKey('detail-route-outgoing-opacity'),
    opacity: Tween<double>(begin: 1.0, end: 0.0).animate(secondaryCurvedAnim),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.018, 0.0),
      ).animate(secondaryCurvedAnim),
      child: child,
    ),
  );

  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0.035, 0.0),
      end: Offset.zero,
    ).animate(curvedAnim),
    child: FadeTransition(
      key: const ValueKey('detail-route-incoming-opacity'),
      // 先以少量可见度覆盖旧页面，再平滑完成显现，避免首帧空洞或
      // 半透明 surface 把旧列表直接“印”到新页面上。
      opacity: Tween<double>(begin: 0.12, end: 1.0).animate(curvedAnim),
      child: outgoingChild,
    ),
  );
}

class DetailTransitionPage<T> extends CustomTransitionPage<T> {
  const DetailTransitionPage({
    required super.child,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
  }) : super(
          transitionsBuilder: _transitionsBuilder,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 320),
        );

  static Widget _transitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildDetailRouteTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
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
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
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
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 450),
          opaque: false, // 允许底层呈现平滑淡出与 Hero 连续飞跃
          barrierColor: Colors.transparent, // 杜绝模态层级黑色遮罩，确保背景纯净通透
        );

  static Widget _transitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildNowPlayingRouteTransition(
      context,
      animation,
      secondaryAnimation,
      child,
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
            windowBackdropMode: theme.effectiveWindowBackdropMode,
          );
          final darkTheme = AppTheme.build(
            fontFamily: theme.fontFamily,
            colorScheme: theme.darkScheme,
            effectsLevel: theme.uiEffectsLevel,
            visualStyleMode: theme.visualStyleMode,
            windowBackdropMode: theme.effectiveWindowBackdropMode,
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
              final routedChild = WindowResizeFrame(
                child: child ?? const SizedBox.shrink(),
              );
              return AnimatedTheme(
                data: materialTheme,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                child: shadcn.Theme(
                  data: shadcnTheme,
                  child: StartupUpdatePrompt(
                    child: Listener(
                      onPointerDown: HotkeysHelper.handlePointerDown,
                      // 挂载全局流体情感交融背景与全局辅助功能保护
                      child: WindowsAccessibilityTooltipGuard(
                        child: FluidGradientBackground(child: routedChild),
                      ),
                    ),
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
          return NowPlayingShellUnderlay(
            child: AppShell(
              page: page,
              pageIdentity: state.uri.toString(),
            ),
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
                pageBuilder: (context, state) => DetailTransitionPage(
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
                pageBuilder: (context, state) => DetailTransitionPage(
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
                pageBuilder: (context, state) => DetailTransitionPage(
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
                  return DetailTransitionPage(
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
                  return DetailTransitionPage(
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
                  return DetailTransitionPage(
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
    return app_paths.AUDIOS_PAGE;
  }
}
