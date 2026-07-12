import 'dart:io';
import 'dart:ui';

import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/component/fluid_gradient_background.dart';
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
  final outgoingContent = CurvedAnimation(
    parent: secondaryAnimation,
    curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.0, 0.78, curve: Curves.easeInCubic),
  );
  final transitionedChild = provideNowPlayingScope
      ? NowPlayingRouteTransitionScope(animation: curvedAnim, child: child)
      : child;

  return FadeTransition(
    opacity: Tween<double>(begin: 0.72, end: 1).animate(backdropReveal),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05), // 极简空间感：增加进入滑行距离到 0.05
        end: Offset.zero,
      ).animate(contentReveal),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1)
            .animate(contentReveal), // 极简空间感：页面从 0.96 微缩放展开，空间感更强
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.8, end: 1).animate(contentReveal),
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
                    // 当播放详情页覆盖在上方时，对底层主界面仅进行变暗蒙版处理。
                    // 绝不进行 Scale 缩放与 Translate 位移，以确保底部控制栏小封面的物理屏幕坐标绝对静止，
                    // 从而使退场时大封面 Hero 弧度飞越能够百分之百精准落入控制栏的原本槽位，彻底消除闪烁与路径偏差 Bug。
                    return Stack(
                      children: [
                        child!,
                        // 黑色半透明遮罩，产生沉浸式蒙版变暗效果
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Colors.black.withValues(
                                alpha: 0.42 * progress,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 普通的二级跳转折叠退场效果：高斯模糊 + 平滑沉降
                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 8.0 * progress, // 适当减小模糊至 8.0，使淡出过程轮廓变化更平柔
                        sigmaY: 8.0 * progress,
                      ),
                      child: Opacity(
                        // 关键修复：将不透明度从 1 - 0.42 改为直接平滑淡出归零 (1.0 - outgoingProgress)，
                        // 确保旧页面在完全被覆盖前已彻底透明，避免因突然被路由剔除渲染而产生生硬闪现。
                        opacity: (1.0 - outgoingProgress).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0,
                              18.0 * outgoingProgress), // 下沉距离调整为更舒缓温和的 18.0 像素
                          child: Transform.scale(
                            scale: 1.0 - 0.012 * outgoingProgress,
                            child: child,
                          ),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

// 专为播放详情页拉起设计的卡片拉起转场构建函数（iOS Modal Card Presentation）
Widget _buildNowPlayingRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // 从底部完全滑入卡片动画
  final slideAnim = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  final slideTween = Tween<Offset>(
    begin: const Offset(0, 1.0),
    end: Offset.zero,
  ).animate(slideAnim);

  // 包裹 NowPlayingRouteTransitionScope，以便让播放详情页中的渐显元素（如歌词、AppBar 等）能获取到入场动画进度并联动
  final transitionedChild = NowPlayingRouteTransitionScope(
    animation: slideAnim,
    child: child,
  );

  return SlideTransition(
    position: slideTween,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: transitionedChild,
    ),
  );
}

Widget _buildDetailRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // 使用二次方渐进缓动曲线
  final curvedAnim = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  return FadeTransition(
    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim),
    child: ScaleTransition(
      // 极轻微的原地中心膨胀缩放，完美配合 Hero 共享元素的飞跃落点
      scale: Tween<double>(begin: 0.985, end: 1.0).animate(curvedAnim),
      child: child,
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
          transitionDuration:
              const Duration(milliseconds: 400), // 给 Hero 飞行留出舒缓平顺的 400ms 时间
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
          transitionDuration: const Duration(
              milliseconds: 520), // 延长至 520ms 以便给共享元素 Hero 动画提供充分舒展的飞行时间
          reverseTransitionDuration:
              const Duration(milliseconds: 380), // 延长至 380ms
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
          transitionDuration: const Duration(
              milliseconds: 520), // 统一设置为 520ms 供共享 Hero 元素充分展开，并通过测试
          reverseTransitionDuration:
              const Duration(milliseconds: 380), // 统一设置为 380ms 并通过测试
          opaque: false, // 极为关键：允许底层被缩小的页面透过来呈现景深层叠效果
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
                    // 挂载全局流体情感交融背景，让其充满在所有窗口最底层
                    child: FluidGradientBackground(child: routedChild),
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
