import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/album_context_menu.dart';
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
    final isDark = scheme.brightness == Brightness.dark;

    return AlbumContextMenu(
      album: widget.album,
      builder: (context, controller, _) => MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: CpMotionPressable(
          onTap: widget.onTap,
          onSecondaryTapDown: (details) =>
              controller.open(position: details.localPosition),
          child: AnimatedScale(
            scale: _hovering ? 1.035 : 1.0,
            duration: motion.microInteractionDuration,
            curve: motion.fast,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  // 悬停时多层弥散软阴影
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovering
                          ? (isDark ? 0.42 : 0.16)
                          : (isDark ? 0.18 : 0.06),
                    ),
                    blurRadius: _hovering ? 24 : 12,
                    offset: Offset(0, _hovering ? 8 : 4),
                    spreadRadius: _hovering ? -2 : -4,
                  ),
                  if (_hovering)
                    BoxShadow(
                      color: context.accents.accentGlow.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: _AlbumCover(
                      album: widget.album,
                      hovering: _hovering,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 2),
                    child: Text(
                      widget.album.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    child: Text(
                      widget.album.artistsMap.keys.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
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
    final accents = context.accents;
    final motion = context.motion;

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
              // 悬浮时的顶部到暗底渐变遮罩
              AnimatedOpacity(
                opacity: hovering ? 1.0 : 0.0,
                duration: motion.microInteractionDuration,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              // 悬浮时浮现的右下角半透明毛玻璃播放徽章
              AnimatedPositioned(
                duration: motion.microInteractionDuration,
                curve: motion.fast,
                right: 12,
                bottom: hovering ? 12 : -40,
                child: AnimatedOpacity(
                  opacity: hovering ? 1.0 : 0.0,
                  duration: motion.microInteractionDuration,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accents.accent,
                      boxShadow: [
                        BoxShadow(
                          color: accents.accentGlow.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Symbols.play_arrow,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
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
