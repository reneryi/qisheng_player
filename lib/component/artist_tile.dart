import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/component/artist_artwork_hero.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;

class ArtistTile extends StatefulWidget {
  const ArtistTile({
    super.key,
    required this.artist,
    this.enableHero = false,
    this.selected = false,
    this.multiSelectController,
  });

  final Artist artist;
  final bool enableHero;
  final bool selected;
  final MultiSelectController<Artist>? multiSelectController;

  @override
  State<ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<ArtistTile> {
  final Object _heroSourceKey = Object();
  late Future<ImageProvider?> _pictureFuture;

  @override
  void initState() {
    super.initState();
    _initPictureFuture();
    ArtworkStore.instance.addListener(_handleArtworkStoreChange);
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
  void didUpdateWidget(covariant ArtistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.id != widget.artist.id) {
      _initPictureFuture();
    }
  }

  Future<void> _openArtistDetail() async {
    if (widget.multiSelectController?.enableMultiSelectView == true) {
      if (widget.multiSelectController!.selected.contains(widget.artist)) {
        widget.multiSelectController!.unselect(widget.artist);
      } else {
        widget.multiSelectController!.select(widget.artist);
      }
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

  Widget _buildAvatarWidget(ImageProvider? provider, Widget placeholder) {
    if (provider == null) {
      return RepaintBoundary(
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: placeholder),
        ),
      );
    }
    final artwork = RepaintBoundary(
      child: ClipOval(
        child: Image(
          image: provider,
          width: 48.0,
          height: 48.0,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
    final tag = artistArtworkHeroTag(widget.artist);
    if (!widget.enableHero || tag == null) return artwork;

    return ValueListenableBuilder<ArtworkHeroTransition?>(
      valueListenable: AppNavigationState.instance.artworkHeroTransition,
      child: artwork,
      builder: (context, _, child) {
        final navigation = AppNavigationState.instance;
        if (!navigation.canBuildArtworkHero(
          tag: tag,
          sourceKey: _heroSourceKey,
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
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.multiSelectController != null
        ? Listenable.merge([ArtworkStore.instance, widget.multiSelectController!])
        : ArtworkStore.instance;

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => _buildArtwork(context),
    );
  }

  Widget _buildArtwork(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final surfaces = context.surfaces;
    final contentView =
        PageContentViewScope.maybeOf(context) ?? ContentView.list;
    final isTable = contentView == ContentView.table;
    final isSelected = widget.multiSelectController != null
        ? widget.multiSelectController!.selected.contains(widget.artist)
        : widget.selected;

    final placeholder = Container(
      width: 48,
      height: 48,
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
          color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
          size: 26,
        ),
      ),
    );

    final rowRadius = BorderRadius.circular(14.0);

    final BoxDecoration normalDecoration;
    final BoxDecoration hoverDecoration;

    if (isTable) {
      // 沉浸式表格视图卡片：
      // 默认（未选中/未悬停）完全沉浸透明融入背景，不显式展示深色底板和边框
      // 选中（selected）状态显式呈现主题高亮外框与强调底色
      normalDecoration = BoxDecoration(
        color: isSelected
            ? (isDark
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.primary.withValues(alpha: 0.10))
            : Colors.transparent,
        borderRadius: rowRadius,
        border: Border.all(
          color: isSelected
              ? scheme.primary.withValues(alpha: isDark ? 0.55 : 0.45)
              : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      );
      hoverDecoration = BoxDecoration(
        color: isSelected
            ? (isDark
                ? scheme.primary.withValues(alpha: 0.22)
                : scheme.primary.withValues(alpha: 0.15))
            : (surfaces.tileHoverBackground != Colors.transparent
                ? surfaces.tileHoverBackground
                : (isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.30)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.55))),
        borderRadius: rowRadius,
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.55 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: surfaces.shadowColor.withValues(
              alpha: (isDark ? 0.25 : 0.10) * surfaces.shadowDepthScale,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else {
      normalDecoration = BoxDecoration(
        color: isSelected
            ? (isDark
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.primary.withValues(alpha: 0.10))
            : surfaces.tileBackground,
        borderRadius: rowRadius,
        border: (isSelected
                ? scheme.primary.withValues(alpha: isDark ? 0.45 : 0.35)
                : surfaces.tileBorderColor) ==
            Colors.transparent
            ? null
            : Border.all(
                color: isSelected
                    ? scheme.primary.withValues(alpha: isDark ? 0.45 : 0.35)
                    : surfaces.tileBorderColor,
                width: isSelected ? 1.0 : 0.5,
              ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : surfaces.tileShadow,
      );
      hoverDecoration = BoxDecoration(
        color: isSelected
            ? (isDark
                ? scheme.primary.withValues(alpha: 0.22)
                : scheme.primary.withValues(alpha: 0.15))
            : (surfaces.tileHoverBackground != Colors.transparent
                ? surfaces.tileHoverBackground
                : scheme.primary.withValues(alpha: isDark ? 0.08 : 0.05)),
        borderRadius: rowRadius,
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: surfaces.shadowColor.withValues(
              alpha: (isDark ? 0.20 : 0.08) * surfaces.shadowDepthScale,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }

    final cachedImage = widget.artist.cachedPicture ??
        ArtworkStore.instance.cached(widget.artist.id);

    return CpMotionPressable(
      onTap: _openArtistDetail,
      borderRadius: rowRadius,
      decoration: normalDecoration,
      hoverDecoration: hoverDecoration,
      selected: isSelected,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      hoverScale: isTable ? 1.015 : 1.0,
      hoverTranslateY: isTable ? -3.0 : -2.0,
      pressScale: 0.985,
      hoverShadow: true,
      animationDuration: Duration(milliseconds: isTable ? 260 : 200),
      animationCurve: Curves.easeOutCubic,
      child: Row(
        children: [
          if (cachedImage != null)
            _buildAvatarWidget(cachedImage, placeholder)
          else
            FutureBuilder<ImageProvider?>(
              future: _pictureFuture,
              builder: (context, snapshot) =>
                  _buildAvatarWidget(snapshot.data, placeholder),
            ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                widget.artist.name,
                softWrap: false,
                maxLines: 2,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
