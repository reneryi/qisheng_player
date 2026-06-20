import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

class AlbumGridTile extends StatefulWidget {
  const AlbumGridTile({
    super.key,
    required this.album,
    required this.onTap,
  });

  final Album album;
  final VoidCallback onTap;

  @override
  State<AlbumGridTile> createState() => _AlbumGridTileState();
}

class _AlbumGridTileState extends State<AlbumGridTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: CpMotionPressable(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? 1.03 : 1.0,
          duration: motion.microInteractionDuration,
          curve: motion.fast,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: _hovering ? 0.12 : 0.06),
                  blurRadius: _hovering ? 20 : 12,
                  offset: Offset(0, _hovering ? 4 : 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AlbumCover(
                    album: widget.album,
                    hovering: _hovering,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Text(
                    widget.album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(
                    widget.album.artistsMap.keys.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({
    required this.album,
    required this.hovering,
  });

  final Album album;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<ImageProvider?>(
      future: album.cover,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        final placeholder = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                context.accents.accent.withValues(alpha: 0.06),
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

        if (provider == null) return placeholder;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
              if (hovering)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
