import 'package:coriander_player/component/album_artwork_hero.dart';
import 'package:coriander_player/component/cp/cp_components.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/navigation_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;

class AlbumTile extends StatefulWidget {
  const AlbumTile({
    super.key,
    required this.album,
    this.enableHero = false,
  });

  final Album album;
  final bool enableHero;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
  final Object _heroSourceKey = Object();

  Future<void> _openAlbumDetail() async {
    final tag = widget.enableHero ? albumArtworkHeroTag(widget.album) : null;
    final navigation = AppNavigationState.instance;
    if (!navigation.beginAlbumArtworkHeroNavigation(
      tag: tag,
      sourceKey: _heroSourceKey,
    )) {
      return;
    }

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await context.push(app_paths.ALBUM_DETAIL_PAGE, extra: widget.album);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 380));
      navigation.endAlbumArtworkHeroNavigation(_heroSourceKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Symbols.broken_image,
      size: 48,
      color: scheme.onSurface,
    );
    return Tooltip(
      message: widget.album.name,
      child: CpMotionPressable(
        onTap: _openAlbumDetail,
        borderRadius: BorderRadius.circular(14.0),
        padding: const EdgeInsets.all(8.0),
        hoverScale: 1.018,
        pressScale: 0.99,
        hoverShadow: true,
        child: Row(
          children: [
            FutureBuilder(
              future: widget.album.works.isEmpty
                  ? Future<ImageProvider?>.value()
                  : widget.album.works.first.cover,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
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
                      image: snapshot.data!,
                      width: 48.0,
                      height: 48.0,
                      fit: BoxFit.cover,
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
                      child: child!,
                    );
                  },
                );
              },
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
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
