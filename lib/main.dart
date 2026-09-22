import 'dart:async';
import 'dart:io';
import 'package:qisheng_player/src/rust/api/metadata_editor.dart';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/font_loader_helper.dart';
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
import 'package:window_manager/window_manager.dart';

Future<void> initWindow() async {
  await windowManager.ensureInitialized();
  final isMax = AppSettings.instance.isWindowMaximized;
  final isFull = AppSettings.instance.isWindowFullScreen;
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setMinimumSize(AppSettings.minimumWindowSize);
  if (!isMax && !isFull) {
    await windowManager.setSize(AppSettings.instance.windowSize);
    await windowManager.setAlignment(Alignment.center);
  }
}

Future<void> loadPrefFont() async {
  final settings = AppSettings.instance;
  final family = settings.fontFamily ?? 'MiSans';
  try {
    await FontLoaderHelper.loadFontFamily(
      familyName: family,
      fontPath: settings.fontPath,
    );
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }
  if (settings.fontFamily != null) {
    ThemeProvider.instance.changeFontFamily(settings.fontFamily!);
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
    var hasChanged = false;
    await for (final action in updateIndex(indexPath: supportPath)) {
      LOGGER.i("[update index silent] ${action.progress}: ${action.message}");
      if (action.message == "changed") {
        hasChanged = true;
      }
    }
    if (!hasChanged) {
      LOGGER.i(
          "[update index silent] index unchanged, skip reloading library state");
      return;
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
  PaintingBinding.instance.imageCache.maximumSize = 3000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;

  await RustLib.init();
  final appDataDir = await getAppDataDir();
  final supportPath = appDataDir.path;

  initRustLogger().listen((msg) {
    LOGGER.i("[rs]: $msg");
  });

  await migrateAppData();

  unawaited(() async {
    try {
      final warnings = await recoverAudioMetadata(supportPath: supportPath);
      for (final warning in warnings) {
        LOGGER.w('标签编辑恢复：$warning');
      }
    } catch (error, stackTrace) {
      LOGGER.e('标签编辑恢复失败', error: error, stackTrace: stackTrace);
    }
  }());

  final settingsFile = File("$supportPath\\settings.json");
  final prefFile = File("$supportPath\\app_preference.json");
  await Future.wait([
    if (settingsFile.existsSync()) AppSettings.readFromJson(),
    if (prefFile.existsSync()) AppPreference.read(),
  ]);

  final startupSettings = AppSettings.instance;
  final startupIsMaximized = startupSettings.isWindowMaximized;
  final startupIsFullScreen = startupSettings.isWindowFullScreen;
  WindowControls.setInitialLayoutMode(
    startupIsMaximized,
    isFullScreen: startupIsFullScreen,
  );

  if (!settingsFile.existsSync()) {
    if (startupSettings.useSystemTheme) {
      startupSettings.defaultTheme = AppSettings.getWindowsTheme();
    } else {
      startupSettings.defaultTheme = startupSettings.customTheme;
    }
    if (startupSettings.useSystemThemeMode) {
      startupSettings.themeMode = ThemeMode.system;
    }
  }

  ThemeProvider.instance.applyTheme(
    seedColor: Color(startupSettings.defaultTheme),
  );
  ThemeProvider.instance.applyThemeMode(startupSettings.themeMode);

  final savedPalette = AppPreference.instance.lastDynamicAlbumPalette;
  if (savedPalette != null &&
      (startupSettings.dynamicTheme ||
          startupSettings.windowBackdropMode == WindowBackdropMode.meshFlow ||
          startupSettings.windowBackdropMode ==
              WindowBackdropMode.prismaticGlass)) {
    ThemeProvider.instance.restorePersistedAlbumPalette(savedPalette);
  }

  if (settingsFile.existsSync()) {
    unawaited(loadPrefFont());
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

  runApp(Entry(welcome: welcome));

  var windowShown = false;
  Future<void> showWindowSafely() async {
    if (windowShown) return;
    windowShown = true;
    await WindowControls.showWindow(
      maximize: startupIsMaximized,
      fullscreen: startupIsFullScreen,
    );
    unawaited(HotkeysHelper.init());
  }

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await showWindowSafely();
  });

  // 超时防御保底：若因调试器接入、首帧管线延迟等原因未及时收到回调，确保 600ms 内强制显示窗口
  Future.delayed(const Duration(milliseconds: 600), () async {
    if (!windowShown) {
      await showWindowSafely();
    }
  });

  if (!welcome) {
    unawaited(_runStartupIndexUpdateSilently(supportPath));
  }
}
