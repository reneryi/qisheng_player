import 'dart:async';

import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/build_index_state_view.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart';

class WelcomingPage extends StatelessWidget {
  const WelcomingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(64.0),
            child: _TitleBar(),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AppSurface(
                  variant: AppSurfaceVariant.glass,
                  glassDensity: AppSurfaceGlassDensity.low,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "你的音乐放在哪些文件夹里？",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "软件会扫描这些目录（包含子目录）并建立索引。",
                        style: TextStyle(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 16),
                      const FolderSelectorView(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FolderSelectorView extends StatefulWidget {
  const FolderSelectorView({super.key});

  @override
  State<FolderSelectorView> createState() => _FolderSelectorViewState();
}

class _FolderSelectorViewState extends State<FolderSelectorView> {
  bool selecting = true;
  final List<String> folders = [];
  final applicationSupportDirectory = getAppDataDir();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 460,
      height: 420,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: selecting
            ? folderSelector(scheme)
            : FutureBuilder(
                future: applicationSupportDirectory,
                builder: (context, snapshot) {
                  if (snapshot.data == null) {
                    return const Center(
                      child: Text("Fail to get app data dir."),
                    );
                  }

                  return BuildIndexStateView(
                    indexPath: snapshot.data!,
                    folders: folders,
                    whenIndexBuilt: () async {
                      await Future.wait([
                        AppSettings.instance.saveSettings(),
                        AudioLibrary.initFromIndex(),
                      ]);
                      if (context.mounted) {
                        context.go(app_paths.AUDIOS_PAGE);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget folderSelector(ColorScheme scheme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FilledButton(
              onPressed: () async {
                final dirPicker = DirectoryPicker();
                dirPicker.title = "选择文件夹";

                final dir = dirPicker.getDirectory();
                if (dir == null) return;

                setState(() {
                  folders.add(dir.path);
                });
              },
              child: const Text("添加文件夹"),
            ),
            FilledButton(
              onPressed: folders.isEmpty
                  ? null
                  : () {
                      setState(() {
                        selecting = false;
                      });
                    },
              child: const Text("开始扫描"),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Expanded(
          child: ListView.builder(
            itemCount: folders.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(folders[i]),
              trailing: IconButton(
                tooltip: "移除",
                onPressed: () {
                  setState(() {
                    folders.removeAt(i);
                  });
                },
                color: scheme.error,
                icon: const Icon(Symbols.delete),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: AppSurface(
        variant: AppSurfaceVariant.glass,
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: DragToMoveArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Image.asset("app_icon.ico", width: 24, height: 24),
                    ),
                    Text(
                      "Coriander Player",
                      style: TextStyle(color: scheme.onSurface, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              const _WindowControlls(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowControlls extends StatefulWidget {
  const _WindowControlls();

  @override
  State<_WindowControlls> createState() => __WindowControllsState();
}

class __WindowControllsState extends State<_WindowControlls>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    setState(() {});
  }

  @override
  void onWindowRestore() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      children: [
        IconButton(
          tooltip: "最小化",
          onPressed: windowManager.minimize,
          icon: const Icon(Symbols.remove),
        ),
        FutureBuilder(
          future: windowManager.isMaximized(),
          builder: (context, snapshot) {
            final isMaximized = snapshot.data ?? false;
            return IconButton(
              tooltip: isMaximized ? "还原" : "最大化",
              onPressed: isMaximized
                  ? windowManager.unmaximize
                  : windowManager.maximize,
              icon: Icon(
                isMaximized ? Symbols.fullscreen_exit : Symbols.fullscreen,
              ),
            );
          },
        ),
        IconButton(
          tooltip: "退出",
          onPressed: windowManager.close,
          icon: const Icon(Symbols.close),
        ),
      ],
    );
  }
}
