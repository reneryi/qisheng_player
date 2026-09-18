import 'package:qisheng_player/library/artwork_store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/album_artwork_hero.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/album_context_menu.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

class AlbumGridTile extends StatefulWidget {
  const AlbumGridTile({
    super.key,
    required this.album,
    this.onTap,
    this.enableHero = true,
  });

  final Album album;
  final VoidCallback? onTap;
  final bool enableHero;

  @override
  State<AlbumGridTile> createState() => _AlbumGridTileState();
}

class _AlbumGridTileState extends State<AlbumGridTile> {
  final Object _heroSourceKey = Object();
  late Future<ImageProvider?> _coverFuture;

  @override
  void initState() {
    super.initState();
    _initCoverFuture();
  }

  void _initCoverFuture() {
    if (widget.album.cachedCover != null) {
      _coverFuture = Future.value(widget.album.cachedCover);
    } else {
      _coverFuture = widget.album.cover;
    }
  }

  @override
  void didUpdateWidget(covariant AlbumGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.id != widget.album.id) {
      _initCoverFuture();
    }
  }

  Future<void> _handleTap() async {
    final tag = widget.enableHero ? albumArtworkHeroTag(widget.album) : null;
    final navigation = AppNavigationState.instance;
    if (tag != null) {
      navigation.beginArtworkHeroNavigation(
        tag: tag,
        sourceKey: _heroSourceKey,
      );
    }

    try {
      if (!mounted) return;
      if (widget.onTap != null) {
        widget.onTap!();
      } else {
        await context.push(app_paths.ALBUM_DETAIL_PAGE, extra: widget.album);
      }
    } finally {
      navigation.endArtworkHeroNavigation(_heroSourceKey);
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: ListenableBuilder(
          listenable: ArtworkStore.instance,
          builder: (context, _) => _buildArtwork(context),
        ),
      );

  Widget _buildArtwork(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final surfaces = context.surfaces;

    final normalDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: surfaces.tileBackground != Colors.transparent
          ? surfaces.tileBackground
          : (isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02)),
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.25),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
          spreadRadius: -3,
        ),
      ],
    );

    final hoverDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white,
      border: Border.all(
        color: scheme.primary.withValues(alpha: isDark ? 0.50 : 0.40),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.09),
          blurRadius: 14,
          spreadRadius: -4,
        ),
      ],
    );

    return AlbumContextMenu(
      album: widget.album,
      builder: (context, controller, _) => CpMotionPressable(
        onTap: _handleTap,
        hoverScale: 1.018,
        hoverTranslateY: -4.0,
        pressScale: 0.98,
        hoverShadow: true,
        animationDuration: const Duration(milliseconds: 240),
        animationCurve: Curves.easeOutCubic,
        decoration: normalDecoration,
        hoverDecoration: hoverDecoration,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(8.0),
        onSecondaryTapDown: (details) =>
            controller.open(position: details.localPosition),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: _AlbumCover(
                album: widget.album,
                coverFuture: _coverFuture,
                enableHero: widget.enableHero,
                heroSourceKey: _heroSourceKey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.album.artistsMap.keys.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(
                              alpha: isDark ? 0.75 : 0.85,
                            ),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    type: MaterialType.transparency,
                    child: Tooltip(
                      message: '播放专辑',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          final works = orderedAlbumWorks(widget.album);
                          if (works.isNotEmpty) {
                            PlayService.instance.playbackService.play(0, works);
                          }
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(
                              alpha: isDark ? 0.16 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.primary.withValues(
                                alpha: isDark ? 0.35 : 0.25,
                              ),
                              width: 0.8,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Symbols.play_arrow_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({
    required this.album,
    required this.coverFuture,
    required this.enableHero,
    required this.heroSourceKey,
  });

  final Album album;
  final Future<ImageProvider?> coverFuture;
  final bool enableHero;
  final Object heroSourceKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final motion = context.motion;

    // 优先同步命中已有的内存缓存，零等待无闪烁
    final cached = album.cachedCover;
    if (cached != null) {
      return _buildCoverContent(context, cached, scheme, accents, motion);
    }

    return FutureBuilder<ImageProvider?>(
      future: coverFuture,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        return _buildCoverContent(context, provider, scheme, accents, motion);
      },
    );
  }

  Widget _buildCoverContent(
    BuildContext context,
    ImageProvider? provider,
    ColorScheme scheme,
    AppAccentTokens accents,
    AppMotionTokens motion,
  ) {
    final placeholder = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            accents.accent.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Symbols.album,
          size: 64,
          color: scheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );

    Widget imageWidget;
    if (provider == null) {
      imageWidget = placeholder;
    } else {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    final tag = albumArtworkHeroTag(album);
    final heroArtwork = (!enableHero || tag == null || provider == null)
        ? RepaintBoundary(child: imageWidget)
        : ValueListenableBuilder<ArtworkHeroTransition?>(
            valueListenable: AppNavigationState.instance.artworkHeroTransition,
            child: RepaintBoundary(child: imageWidget),
            builder: (context, _, child) {
              final navigation = AppNavigationState.instance;
              if (!navigation.canBuildArtworkHero(
                tag: tag,
                sourceKey: heroSourceKey,
              )) {
                return child!;
              }

              return Hero(
                tag: tag,
                transitionOnUserGestures: true,
                flightShuttleBuilder: (
                  flightContext,
                  animation,
                  flightDirection,
                  fromHeroContext,
                  toHeroContext,
                ) {
                  final toHero = toHeroContext.widget as Hero;
                  return Material(
                    type: MaterialType.transparency,
                    child: toHero.child,
                  );
                },
                child: child!,
              );
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: heroArtwork,
    );
  }
}
