import 'package:qisheng_player/component/artist_artwork_hero.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;

class ArtistTile extends StatefulWidget {
  const ArtistTile({
    super.key,
    required this.artist,
    this.enableHero = false,
  });

  final Artist artist;
  final bool enableHero;

  @override
  State<ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<ArtistTile> {
  final Object _heroSourceKey = Object();

  Future<void> _openArtistDetail() async {
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
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Symbols.broken_image,
      color: scheme.onSurface,
      size: 48,
    );
    return Tooltip(
      message: widget.artist.name,
      child: CpMotionPressable(
        onTap: _openArtistDetail,
        borderRadius: BorderRadius.circular(14.0),
        padding: const EdgeInsets.all(8.0),
        hoverScale: 1.025,
        pressScale: 0.96,
        hoverShadow: true,
        child: Row(
          children: [
            FutureBuilder(
              future: widget.artist.works.first.cover,
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
                  child: ClipOval(
                    child: Image(
                      image: snapshot.data!,
                      width: 48.0,
                      height: 48.0,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder,
                    ),
                  ),
                );
                final tag = artistArtworkHeroTag(widget.artist);
                if (!widget.enableHero || tag == null) return artwork;

                return ValueListenableBuilder<ArtworkHeroTransition?>(
                  valueListenable:
                      AppNavigationState.instance.artworkHeroTransition,
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
              },
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
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
      ),
    );
  }
}
