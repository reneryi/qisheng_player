import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/app_surface.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/library_reload_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;

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
                      child: Text("无法获取应用数据目录。"),
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
  const UpdatingStateView({
    super.key,
    required this.indexPath,
    @visibleForTesting this.streamOverride,
  });

  final Directory indexPath;
  final Stream<IndexActionState>? streamOverride;

  @override
  State<UpdatingStateView> createState() => _UpdatingStateViewState();
}

class _UpdatingStateViewState extends State<UpdatingStateView> {
  late final Stream<IndexActionState> updateIndexStream;
  StreamSubscription? _subscription;

  void whenIndexUpdated() async {
    if (!mounted) return;
    final playback = PlayService.instance.playbackService;
    final status = await libraryReloadCoordinator.reload(
      afterReload: playback.reconcileLibraryReferences,
    );
    if (!mounted) return;
    if (status != AudioLibraryLoadStatus.loaded) {
      showTextOnSnackBar("曲库索引加载失败，请重新扫描音乐文件夹");
      return;
    }
    if (playback.nowPlaying == null) {
      await playback.restoreLastSession();
    }
    if (!mounted) return;
    _subscription?.cancel();
    _subscription = null;
    final ctx = context;
    if (ctx.mounted) {
      ctx.go(app_paths.AUDIOS_PAGE);
    }
  }

  @override
  void initState() {
    super.initState();
    updateIndexStream = widget.streamOverride ??
        updateIndex(
          indexPath: widget.indexPath.path,
        ).asBroadcastStream();

    _subscription = updateIndexStream.listen(
      (action) {
        LOGGER.i("[update index] ${action.progress}: ${action.message}");
      },
      onError: (err, stack) {
        LOGGER.e("[update index] error: $err", stackTrace: stack);
        if (!mounted) return;
        showTextOnSnackBar("更新曲库索引时发生错误: $err");
      },
      onDone: whenIndexUpdated,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
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
