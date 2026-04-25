import 'dart:convert';
import 'dart:io';
import 'package:coriander_player/src/rust/api/system_theme.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

enum WindowBackdropMode {
  auto,
  mica,
  acrylic,
  none;

  static WindowBackdropMode? fromName(String? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

enum UiEffectsLevel {
  balanced,
  visual,
  performance;

  static UiEffectsLevel? fromName(String? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

enum UiVisualStyleMode {
  glass,
  contrast;

  static UiVisualStyleMode? fromName(String? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

/// 把旧 app data 目录（如果存在）移到新的目录。
/// 只在 app data 目录没有数据时进行。
/// 从 C:\\Users\\$username\\AppData\\Roaming\\com.example\\coriander_player 移到 C:\\Users\\$username\\Documents\\coriander_player。
Future<void> migrateAppData() async {
  try {
    final newAppDataDir = await getAppDataDir();
    if (newAppDataDir.listSync().isNotEmpty) return;

    final oldAppDataDir = await getApplicationSupportDirectory();

    if (oldAppDataDir.existsSync()) {
      final datas = oldAppDataDir.listSync();
      for (var item in datas) {
        final oldDataFile = File(item.path);
        oldDataFile.copySync(
          path.join(newAppDataDir.path, path.basename(item.path)),
        );
      }
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }
}

Future<Directory> getAppDataDir() async {
  final dir = await getApplicationDocumentsDirectory();
  return Directory(path.join(dir.path, "coriander_player"))
      .create(recursive: true);
}

class AppSettings {
  static final github = GitHub();
  static const String version = "1.7.0";
  static const String releaseRepoOwner = "reneryi";
  static const String releaseRepoName = "coriander_player";

  /// 主题模式：亮 / 暗 / 跟随系统
  ThemeMode themeMode = getWindowsThemeMode();

  /// 启动时或封面主题色不适合当主题时的主色
  int defaultTheme = getWindowsTheme();

  /// 跟随歌曲封面的动态主题
  bool dynamicTheme = true;

  /// 跟随系统主题色
  bool useSystemTheme = true;

  /// 跟随系统主题模式
  bool useSystemThemeMode = true;

  List artistSeparator = ["/", "\u3001"];

  /// 歌词来源：true，本地优先；false，在线优先
  bool localLyricFirst = true;
  Size windowSize = const Size(1280, 756);
  bool isWindowMaximized = false;

  String? fontFamily;
  String? fontPath;
  String? backgroundImagePath;
  double backgroundImageOpacity = 0.18;
  WindowBackdropMode windowBackdropMode = WindowBackdropMode.auto;
  UiEffectsLevel uiEffectsLevel = UiEffectsLevel.balanced;
  UiVisualStyleMode uiVisualStyleMode = UiVisualStyleMode.glass;
  final ValueNotifier<int> backgroundVersion = ValueNotifier(0);

  late String artistSplitPattern = artistSeparator.join("|");

  static final AppSettings _instance = AppSettings._();

  static AppSettings get instance => _instance;

  static ThemeMode getWindowsThemeMode() {
    try {
      final systemTheme = SystemTheme.getSystemTheme();

      final isDarkMode = (((5 * systemTheme.fore.$3) +
              (2 * systemTheme.fore.$2) +
              systemTheme.fore.$4) >
          (8 * 128));
      return isDarkMode ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  static int getWindowsTheme() {
    try {
      final systemTheme = SystemTheme.getSystemTheme();
      return Color.fromARGB(
        systemTheme.accent.$1,
        systemTheme.accent.$2,
        systemTheme.accent.$3,
        systemTheme.accent.$4,
      ).toARGB32();
    } catch (_) {
      return const Color(0xFF4F8DFF).toARGB32();
    }
  }

  AppSettings._();

  static UiVisualStyleMode parseUiVisualStyleMode(Object? value) {
    if (value is String) {
      return UiVisualStyleMode.fromName(value) ?? UiVisualStyleMode.glass;
    }
    return UiVisualStyleMode.glass;
  }

  void notifyBackgroundChanged() {
    backgroundVersion.value++;
  }

  static Future<void> _readFromJson_old(Map settingsMap) async {
    final ust = settingsMap["UseSystemTheme"];
    if (ust != null) {
      _instance.useSystemTheme = ust == 1 ? true : false;
    }

    final ustm = settingsMap["UseSystemThemeMode"];
    if (ustm != null) {
      _instance.useSystemThemeMode = ustm == 1 ? true : false;
    }

    if (!_instance.useSystemTheme) {
      _instance.defaultTheme = settingsMap["DefaultTheme"];
    }
    if (!_instance.useSystemThemeMode) {
      _instance.themeMode =
          settingsMap["ThemeMode"] == 0 ? ThemeMode.light : ThemeMode.dark;
    }

    _instance.dynamicTheme = settingsMap["DynamicTheme"] == 1 ? true : false;
    _instance.artistSeparator = settingsMap["ArtistSeparator"];
    _instance.artistSplitPattern = _instance.artistSeparator.join("|");

    final llf = settingsMap["LocalLyricFirst"];
    if (llf != null) {
      _instance.localLyricFirst = llf == 1 ? true : false;
    }

    final sizeStr = settingsMap["WindowSize"];
    if (sizeStr != null) {
      final sizeStrs = (sizeStr as String).split(",");
      _instance.windowSize = Size(double.tryParse(sizeStrs[0]) ?? 1280,
          double.tryParse(sizeStrs[1]) ?? 756);
    }

    final isMaximized = settingsMap["IsWindowMaximized"];
    if (isMaximized != null) {
      _instance.isWindowMaximized = isMaximized == 1;
    }
  }

  static Future<void> readFromJson() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final settingsPath = "$supportPath\\settings.json";

      final settingsStr = File(settingsPath).readAsStringSync();
      if (settingsStr.trim().isEmpty) return;
      Map settingsMap = json.decode(settingsStr);

      if (settingsMap["Version"] == null) {
        return _readFromJson_old(settingsMap);
      }

      final ust = settingsMap["UseSystemTheme"];
      if (ust != null) {
        _instance.useSystemTheme = ust;
      }

      final ustm = settingsMap["UseSystemThemeMode"];
      if (ustm != null) {
        _instance.useSystemThemeMode = ustm;
      }

      if (!_instance.useSystemTheme) {
        _instance.defaultTheme = settingsMap["DefaultTheme"];
      }
      if (!_instance.useSystemThemeMode) {
        _instance.themeMode = (settingsMap["ThemeMode"] ?? false)
            ? ThemeMode.dark
            : ThemeMode.light;
      }

      final dt = settingsMap["DynamicTheme"];
      if (dt != null) {
        _instance.dynamicTheme = dt;
      }

      final as = settingsMap["ArtistSeparator"];
      if (as != null) {
        _instance.artistSeparator = as;
        _instance.artistSplitPattern = _instance.artistSeparator.join("|");
      }

      final llf = settingsMap["LocalLyricFirst"];
      if (llf != null) {
        _instance.localLyricFirst = llf;
      }

      final sizeStr = settingsMap["WindowSize"];
      if (sizeStr != null) {
        final sizeStrs = (sizeStr as String).split(",");
        _instance.windowSize = Size(double.tryParse(sizeStrs[0]) ?? 1280,
            double.tryParse(sizeStrs[1]) ?? 756);
      }

      final isMaximized = settingsMap["IsWindowMaximized"];
      if (isMaximized != null) {
        _instance.isWindowMaximized = isMaximized;
      }

      final ff = settingsMap["FontFamily"];
      final fp = settingsMap["FontPath"];
      if (ff != null) {
        _instance.fontFamily = ff;
        _instance.fontPath = fp;
      }

      final bgImage = settingsMap["BackgroundImagePath"];
      if (bgImage is String && bgImage.isNotEmpty) {
        _instance.backgroundImagePath = bgImage;
      }
      final bgOpacity = settingsMap["BackgroundImageOpacity"];
      if (bgOpacity is num) {
        _instance.backgroundImageOpacity = bgOpacity.toDouble().clamp(0.0, 0.6);
      }
      final windowBackdropMode = settingsMap["WindowBackdropMode"];
      if (windowBackdropMode is String) {
        _instance.windowBackdropMode =
            WindowBackdropMode.fromName(windowBackdropMode) ??
                WindowBackdropMode.auto;
      }
      final uiEffectsLevel = settingsMap["UiEffectsLevel"];
      if (uiEffectsLevel is String) {
        _instance.uiEffectsLevel =
            UiEffectsLevel.fromName(uiEffectsLevel) ?? UiEffectsLevel.balanced;
      }
      _instance.uiVisualStyleMode = parseUiVisualStyleMode(
        settingsMap["UiVisualStyleMode"],
      );
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> saveSettings() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      final isFullScreen = await windowManager.isFullScreen();
      final settingsMap = {
        "Version": version,
        "ThemeMode": themeMode == ThemeMode.dark,
        "DynamicTheme": dynamicTheme,
        "UseSystemTheme": useSystemTheme,
        "UseSystemThemeMode": useSystemThemeMode,
        "DefaultTheme": defaultTheme,
        "ArtistSeparator": artistSeparator,
        "LocalLyricFirst": localLyricFirst,
        "IsWindowMaximized": isMaximized,
        "FontFamily": fontFamily,
        "FontPath": fontPath,
        "BackgroundImagePath": backgroundImagePath,
        "BackgroundImageOpacity": backgroundImageOpacity,
        "WindowBackdropMode": windowBackdropMode.name,
        "UiEffectsLevel": uiEffectsLevel.name,
        "UiVisualStyleMode": uiVisualStyleMode.name,
      };

      // 只有在窗口不是最大化且不是全屏时才保存窗口尺寸。
      // 这样 windowSize 始终保存的是窗口化时的尺寸。
      Size sizeToSave = windowSize;
      if (!isMaximized && !isFullScreen) {
        sizeToSave = await windowManager.getSize();
      }
      settingsMap["WindowSize"] =
          "${sizeToSave.width.toStringAsFixed(1)},${sizeToSave.height.toStringAsFixed(1)}";

      final settingsStr = json.encode(settingsMap);
      final supportPath = (await getAppDataDir()).path;
      final settingsPath = "$supportPath\\settings.json";
      final output = await File(settingsPath).create(recursive: true);
      output.writeAsStringSync(settingsStr);
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }
}
