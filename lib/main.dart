import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/library_reload_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';
import 'package:qisheng_player/src/rust/api/logger.dart';
import 'package:qisheng_player/src/rust/frb_generated.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initWindow() async {
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    minimumSize: AppSettings.minimumWindowSize,
    size: AppSettings.instance.windowSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (AppSettings.instance.isWindowMaximized) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> loadPrefFont() async {
  final settings = AppSettings.instance;
  if (settings.fontFamily != null) {
    try {
      final fontLoader = FontLoader(settings.fontFamily!);

      fontLoader.addFont(
        File(settings.fontPath!).readAsBytes().then((value) {
          return ByteData.sublistView(value);
        }),
      );
      await fontLoader.load();
      ThemeProvider.instance.changeFontFamily(settings.fontFamily!);
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }
}

Future<AudioLibraryLoadStatus> _loadLibraryState({
  bool reconcilePlayback = false,
}) {
  return libraryReloadCoordinator.reload(
    afterReload: reconcilePlayback
        ? PlayService.instance.playbackService.reconcileLibraryReferences
        : null,
  );
}

Future<void> _runStartupIndexUpdateSilently(String supportPath) async {
  try {
    await for (final action in updateIndex(indexPath: supportPath)) {
      LOGGER.i("[update index silent] ${action.progress}: ${action.message}");
    }
    final status = await _loadLibraryState(reconcilePlayback: true);
    if (status != AudioLibraryLoadStatus.loaded) {
      LOGGER.e("[update index silent] reload failed: ${status.name}");
    }
  } catch (err, trace) {
    LOGGER.e("[update index silent] $err", stackTrace: trace);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RustLib.init();

  initRustLogger().listen((msg) {
    LOGGER.i("[rs]: $msg");
  });

  await migrateAppData();

  final supportPath = (await getAppDataDir()).path;
  if (File("$supportPath\\settings.json").existsSync()) {
    await AppSettings.readFromJson();
    await loadPrefFont();
  }
  if (File("$supportPath\\app_preference.json").existsSync()) {
    await AppPreference.read();
  }
  var welcome = !File("$supportPath\\index.json").existsSync();
  if (!welcome) {
    final status = await _loadLibraryState();
    welcome = status != AudioLibraryLoadStatus.loaded;
    if (!welcome) {
      await PlayService.instance.playbackService.restoreLastSession();
    }
  }

  // Must initialize after loading preferences to avoid default-volume capture.
  final initialBackdropResult = await WindowControls.init();
  ThemeProvider.instance.acceptInitialWindowBackdropResult(
    initialBackdropResult,
  );
  await initWindow();
  await HotkeysHelper.init();

  runApp(Entry(welcome: welcome));
  if (!welcome) {
    unawaited(_runStartupIndexUpdateSilently(supportPath));
  }
}
