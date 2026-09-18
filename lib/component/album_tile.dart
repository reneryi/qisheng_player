import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/component/album_artwork_hero.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/album_context_menu.dart';

class AlbumTile extends StatefulWidget {
  const AlbumTile({
    super.key,
    required this.album,
    this.enableHero = false,
    this.selected = false,
    this.multiSelectController,
  });

  final Album album;
  final bool enableHero;
  final bool selected;
  final MultiSelectController<Album>? multiSelectController;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
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
  void didUpdateWidget(covariant AlbumTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.id != widget.album.id) {
      _initCoverFuture();
    }
  }

  Future<void> _openAlbumDetail() async {
    if (widget.multiSelectController?.enableMultiSelectView == true) {
      if (widget.multiSelectController!.selected.contains(widget.album)) {
        widget.multiSelectController!.unselect(widget.album);
      } else {
        widget.multiSelectController!.select(widget.album);
      }
      return;
    }

    final tag = widget.enableHero ? albumArtworkHeroTag(widget.album) : null;
    final navigation = AppNavigationState.instance;
    if (tag != null) {
      navigation.beginAlbumArtworkHeroNavigation(
        tag: tag,
        sourceKey: _heroSourceKey,
      );
    }

    try {
      if (!mounted) return;
      await context.push(app_paths.ALBUM_DETAIL_PAGE, extra: widget.album);
    } finally {
      navigation.endAlbumArtworkHeroNavigation(_heroSourceKey);
    }
  }

  Widget _buildArtworkImage(ImageProvider? provider, Widget placeholder) {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
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
    final tag = albumArtworkHeroTag(widget.album);
    if (!widget.enableHero || tag == null) return artwork;

    return ValueListenableBuilder<AlbumArtworkHeroTransition?>(
      valueListenable:
          AppNavigationState.instance.albumArtworkHeroTransition,
      child: artwork,
      builder: (context, _, child) {
        final navigation = AppNavigationState.instance;
        if (!navigation.canBuildAlbumArtworkHero(
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
        ? widget.multiSelectController!.selected.contains(widget.album)
        : widget.selected;

    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Symbols.album_rounded,
          size: 26,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
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

    final cachedImage = widget.album.cachedCover;

    return AlbumContextMenu(
      album: widget.album,
      builder: (context, controller, _) => CpMotionPressable(
        onTap: _openAlbumDetail,
        onSecondaryTapDown: (details) {
          if (widget.multiSelectController?.enableMultiSelectView == true) {
            return;
          }
          controller.open(position: details.localPosition);
        },
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
              _buildArtworkImage(cachedImage, placeholder)
            else
              FutureBuilder<ImageProvider?>(
                future: _coverFuture,
                builder: (context, snapshot) =>
                    _buildArtworkImage(snapshot.data, placeholder),
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Text(
                  widget.album.name,
                  softWrap: false,
                  maxLines: 2,
                  style: TextStyle(color: scheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
