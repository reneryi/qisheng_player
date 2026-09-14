import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/src/rust/api/tag_reader.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';

class BuildIndexStateView extends StatefulWidget {
  const BuildIndexStateView({
    super.key,
    required this.indexPath,
    required this.folders,
    required this.whenIndexBuilt,
    @visibleForTesting this.streamOverride,
  });

  final Directory indexPath;
  final List<String> folders;
  final void Function() whenIndexBuilt;
  final Stream<IndexActionState>? streamOverride;

  @override
  State<BuildIndexStateView> createState() => _BuildIndexStateViewState();
}

class _BuildIndexStateViewState extends State<BuildIndexStateView> {
  late final Stream<IndexActionState> buildIndexStream;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    buildIndexStream = widget.streamOverride ??
        buildIndexFromFoldersRecursively(
          folders: widget.folders,
          indexPath: widget.indexPath.path,
        ).asBroadcastStream();

    _subscription = buildIndexStream.listen(
      (action) {
        LOGGER.i("[build index] ${action.progress}: ${action.message}");
      },
      onError: (err, stack) {
        LOGGER.e("[build index] error: $err", stackTrace: stack);
        if (!mounted) return;
        showTextOnSnackBar("扫描曲库时发生错误: $err");
      },
      onDone: () {
        _subscription?.cancel();
        _subscription = null;
        if (!mounted) return;
        widget.whenIndexBuilt();
      },
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

    return StreamBuilder(
      stream: buildIndexStream,
      builder: (context, snapshot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}
