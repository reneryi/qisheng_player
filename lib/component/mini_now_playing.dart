import 'package:coriander_player/component/rectangle_progress_indicator.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class MiniNowPlaying extends StatelessWidget {
  const MiniNowPlaying({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final bottomOffset = screenType == ScreenType.small
            ? chrome.shellGap
            : chrome.shellGap + 6;
        final width = switch (screenType) {
          ScreenType.small => MediaQuery.sizeOf(context).width - 16,
          ScreenType.medium => 620.0,
          ScreenType.large => 760.0,
        };

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomOffset),
            child: SizedBox(
              height: chrome.dockHeight,
              width: width,
              child: AppSurface(
                variant: AppSurfaceVariant.floating,
                radius: context.surfaces.radiusXxl,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(context.surfaces.radiusXxl),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return RectangleProgressIndicator(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        progressColor: context.accents.progressActive,
                        trackColor: context.accents.progressInactive,
                        child: const _NowPlayingForeground(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NowPlayingForeground extends StatelessWidget {
  const _NowPlayingForeground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          final location = GoRouterState.of(context).uri.toString();
          if (location == app_paths.NOW_PLAYING_PAGE) return;
          context.go(app_paths.NOW_PLAYING_PAGE);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListenableBuilder(
            listenable: PlayService.instance.playbackService,
            builder: (context, _) {
              final playbackService = PlayService.instance.playbackService;
              final nowPlaying = playbackService.nowPlaying;
              final placeholder = DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Symbols.music_note,
                  size: 26,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              );

              return Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: nowPlaying != null
                        ? FutureBuilder(
                            future: nowPlaying.cover,
                            builder: (context, snapshot) =>
                                switch (snapshot.connectionState) {
                              ConnectionState.done => snapshot.data == null
                                  ? placeholder
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image(
                                        image: snapshot.data!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            placeholder,
                                      ),
                                    ),
                              _ => const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            },
                          )
                        : placeholder,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          nowPlaying?.title ?? 'Coriander Player',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nowPlaying != null
                              ? '${nowPlaying.artist} - ${nowPlaying.album}'
                              : 'Enjoy music',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppSurface(
                    variant: AppSurfaceVariant.inset,
                    radius: 26,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '上一首',
                          onPressed: playbackService.lastAudio,
                          icon: const Icon(Symbols.skip_previous),
                        ),
                        StreamBuilder(
                          stream: playbackService.playerStateStream,
                          initialData: playbackService.playerState,
                          builder: (context, snapshot) {
                            late void Function() onPressed;
                            if (snapshot.data! == PlayerState.playing) {
                              onPressed = playbackService.pause;
                            } else if (snapshot.data! ==
                                PlayerState.completed) {
                              onPressed = playbackService.playAgain;
                            } else {
                              onPressed = playbackService.start;
                            }

                            return FilledButton(
                              onPressed: onPressed,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.all(0),
                                shape: const CircleBorder(),
                              ),
                              child: Icon(
                                snapshot.data! == PlayerState.playing
                                    ? Symbols.pause
                                    : Symbols.play_arrow,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: '下一首',
                          onPressed: playbackService.nextAudio,
                          icon: const Icon(Symbols.skip_next),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
