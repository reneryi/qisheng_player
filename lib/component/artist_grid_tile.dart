import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/artist_artwork_hero.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/utils.dart';

class ArtistGridTile extends StatefulWidget {
  const ArtistGridTile({
    super.key,
    required this.artist,
    this.onTap,
    this.enableHero = true,
    this.selected = false,
    this.multiSelectController,
  });

  final Artist artist;
  final VoidCallback? onTap;
  final bool enableHero;
  final bool selected;
  final MultiSelectController<Artist>? multiSelectController;

  @override
  State<ArtistGridTile> createState() => _ArtistGridTileState();
}

class _ArtistGridTileState extends State<ArtistGridTile> {
  final Object _heroSourceKey = Object();
  Future<ImageProvider?>? _pictureFuture;

  @override
  void initState() {
    super.initState();
    _initPictureFuture();
    ArtworkStore.instance.addListener(_handleArtworkStoreChange);
  }

  @override
  void reassemble() {
    super.reassemble();
    _initPictureFuture();
  }

  void _handleArtworkStoreChange() {
    if (mounted) {
      setState(() {
        _initPictureFuture();
      });
    }
  }

  @override
  void dispose() {
    ArtworkStore.instance.removeListener(_handleArtworkStoreChange);
    super.dispose();
  }

  void _initPictureFuture() {
    final cached = widget.artist.cachedPicture ??
        ArtworkStore.instance.cached(widget.artist.id);
    if (cached != null) {
      _pictureFuture = Future.value(cached);
    } else {
      _pictureFuture = widget.artist.picture;
    }
  }

  @override
  void didUpdateWidget(covariant ArtistGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.id != widget.artist.id) {
      _initPictureFuture();
    }
  }

  Future<void> _handleTap() async {
    if (widget.multiSelectController?.enableMultiSelectView == true) {
      if (widget.multiSelectController!.selected.contains(widget.artist)) {
        widget.multiSelectController!.unselect(widget.artist);
      } else {
        widget.multiSelectController!.select(widget.artist);
      }
      return;
    }

    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    final tag = widget.enableHero ? artistArtworkHeroTag(widget.artist) : null;
    final navigation = AppNavigationState.instance;
    if (tag != null) {
      navigation.beginArtworkHeroNavigation(
        tag: tag,
        sourceKey: _heroSourceKey,
      );
    }

    try {
      if (!mounted) return;
      await context.push(app_paths.ARTIST_DETAIL_PAGE, extra: widget.artist);
    } finally {
      navigation.endArtworkHeroNavigation(_heroSourceKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.multiSelectController != null
        ? Listenable.merge([ArtworkStore.instance, widget.multiSelectController!])
        : ArtworkStore.instance;

    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: listenable,
        builder: (context, _) => _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final surfaces = context.surfaces;
    final isSelected = widget.multiSelectController != null
        ? widget.multiSelectController!.selected.contains(widget.artist)
        : widget.selected;

    final normalDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: isSelected
          ? (isDark
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.primary.withValues(alpha: 0.10))
          : (surfaces.tileBackground != Colors.transparent
              ? surfaces.tileBackground
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02))),
      border: Border.all(
        color: isSelected
            ? scheme.primary.withValues(alpha: isDark ? 0.55 : 0.45)
            : scheme.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.25),
        width: isSelected ? 1.2 : 0.8,
      ),
      boxShadow: [
        if (isSelected)
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        else
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
      color: isSelected
          ? (isDark
              ? scheme.primary.withValues(alpha: 0.22)
              : scheme.primary.withValues(alpha: 0.15))
          : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white),
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

    return CpMotionPressable(
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
      selected: isSelected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ArtistAvatar(
                  artist: widget.artist,
                  pictureFuture: _pictureFuture,
                  enableHero: widget.enableHero,
                  heroSourceKey: _heroSourceKey,
                ),
                if (widget.multiSelectController?.enableMultiSelectView == true)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? scheme.primary
                            : (isDark
                                ? Colors.black.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.8)),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outline.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Symbols.check_rounded,
                              size: 16,
                              color: scheme.onPrimary,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.artist.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatWorkCount(widget.artist.works.length),
                  textAlign: TextAlign.center,
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({
    required this.artist,
    required this.pictureFuture,
    required this.enableHero,
    required this.heroSourceKey,
  });

  final Artist artist;
  final Future<ImageProvider?>? pictureFuture;
  final bool enableHero;
  final Object heroSourceKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cached = artist.cachedPicture ?? ArtworkStore.instance.cached(artist.id);
    if (cached != null) {
      return _buildAvatarContent(context, cached, scheme);
    }

    return FutureBuilder<ImageProvider?>(
      future: pictureFuture,
      builder: (context, snapshot) {
        return _buildAvatarContent(context, snapshot.data, scheme);
      },
    );
  }

  Widget _buildAvatarContent(
    BuildContext context,
    ImageProvider? provider,
    ColorScheme scheme,
  ) {
    final placeholder = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.65),
            scheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Symbols.person_rounded,
          size: 56,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
        ),
      ),
    );

    Widget imageWidget;
    if (provider == null) {
      imageWidget = placeholder;
    } else {
      imageWidget = ClipOval(
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    final tag = artistArtworkHeroTag(artist);
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

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ClipOval(
        child: heroArtwork,
      ),
    );
  }
}
