import 'dart:async';
import 'dart:io';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/online_cover_store.dart';
import 'package:coriander_player/library/play_count_store.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/lyric/lyric_source.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/rust/api/tag_reader.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;

class UpdatingPage extends StatelessWidget {
  const UpdatingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [chrome.windowBgTop, chrome.windowBgBottom],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: AppSurface(
              variant: AppSurfaceVariant.glass,
              glassDensity: AppSurfaceGlassDensity.low,
              padding: const EdgeInsets.all(22),
              child: FutureBuilder(
                future: getAppDataDir(),
                builder: (context, snapshot) {
                  if (snapshot.data == null) {
                    return const Center(
                      child: Text("Fail to get app data dir."),
                    );
                  }

                  return UpdatingStateView(indexPath: snapshot.data!);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class UpdatingStateView extends StatefulWidget {
  const UpdatingStateView({super.key, required this.indexPath});

  final Directory indexPath;

  @override
  State<UpdatingStateView> createState() => _UpdatingStateViewState();
}

class _UpdatingStateViewState extends State<UpdatingStateView> {
  late final Stream<IndexActionState> updateIndexStream;
  StreamSubscription? _subscription;

  void whenIndexUpdated() async {
    await Future.wait([
      AudioLibrary.initFromIndex(),
      readPlaylists(),
      readLyricSources(),
      PlayCountStore.instance.read(),
      OnlineCoverStore.instance.read(),
    ]);
    await PlayService.instance.playbackService.restoreLastSession();
    _subscription?.cancel();
    final ctx = context;
    if (ctx.mounted) {
      final startPage = AppPreference.instance.startPage;
      final startLocation =
          startPage >= 0 && startPage < app_paths.START_PAGES.length
              ? app_paths.START_PAGES[startPage]
              : app_paths.AUDIOS_PAGE;
      ctx.go(startLocation);
    }
  }

  @override
  void initState() {
    super.initState();
    updateIndexStream = updateIndex(
      indexPath: widget.indexPath.path,
    ).asBroadcastStream();

    _subscription = updateIndexStream.listen(
      (action) {
        LOGGER.i("[update index] ${action.progress}: ${action.message}");
      },
      onDone: whenIndexUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 420.0,
      child: StreamBuilder(
        stream: updateIndexStream,
        builder: (context, snapshot) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LinearProgressIndicator(
                value: snapshot.data?.progress,
                borderRadius: BorderRadius.circular(2.0),
              ),
              const SizedBox(height: 8.0),
              Text(
                "${snapshot.data?.message}",
                style: TextStyle(color: scheme.onSurface),
              ),
            ],
          );
        },
      ),
    );
  }
}
