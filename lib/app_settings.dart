import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:qisheng_player/app_brand.dart';
import 'package:qisheng_player/src/rust/api/system_theme.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

enum WindowBackdropMode {
  /// 原生默认对角渐变背景（日间 135° 柔和温润纸白，夜间 135° 深邃苍青流光）
  defaultGradient,

  /// Windows 11 原生增强型云母材质 (Mica Alt / Tabbed Window)
  micaAlt,

  /// Windows 11 原生实时背景亚克力材质 (Real-time Background Acrylic)
  acrylic,

  /// 仿 Apple Music 沉浸式弥散流彩光斑 (Mesh Flow / Fluid Chroma)
  meshFlow,

  /// 交互水波纹背景（鼠标轨迹波澜 + 点击激荡 + 低音节拍共振涟漪）
  waterRipple,

  /// 极光漫染背景（多点调和的静态高斯漫射光晕）
  prismaticGlass;

  static WindowBackdropMode? fromName(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase();
    if (normalized == 'auto' || normalized == 'none' || normalized == 'defaultgradient') {
      return WindowBackdropMode.defaultGradient;
    }
    if (normalized == 'mica' || normalized == 'micaalt' || normalized == 'tabbed') {
      return WindowBackdropMode.micaAlt;
    }
    if (normalized == 'acrylic') {
      return WindowBackdropMode.acrylic;
    }
    if (normalized == 'fluid' || normalized == 'meshflow' || normalized == 'mesh_flow') {
      return WindowBackdropMode.meshFlow;
    }
    if (normalized == 'waterripple' || normalized == 'water_ripple' || normalized == 'ripple') {
      return WindowBackdropMode.waterRipple;
    }
    if (normalized == 'prismaticglass' ||
        normalized == 'prismatic_glass' ||
        normalized == 'glass' ||
        normalized == 'auroraglow' ||
        normalized == 'aurora_glow') {
      return WindowBackdropMode.prismaticGlass;
    }
    for (final item in values) {
      if (item.name.toLowerCase() == normalized) return item;
    }
    return null;
  }
}

enum WindowLayoutMode { normal, maximized, fullscreen }

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
  /// 纯净实体卡片风格（现代扁平精致色阶、0.5px 精细边界、低冗余、高可读性）
  solidCard,

  /// 无界极简悬浮风格（去底色与硬边框、呼吸微光胶囊、+1.5px 悬浮提升、文字智能微阴影）
  borderless,

  /// 液态玻璃空间风格（连续曲率 Squircle、内边缘 1.2px 高光描边、次表面微光跟随）
  liquidGlass;

  static UiVisualStyleMode? fromName(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase();
    if (normalized == 'contrast' || normalized == 'sharpcard' || normalized == 'solidcard') {
      return UiVisualStyleMode.solidCard;
    }
    if (normalized == 'borderless' || normalized == 'floating') {
      return UiVisualStyleMode.borderless;
    }
    if (normalized == 'glass' || normalized == 'liquidglass' || normalized == 'liquid_glass') {
      return UiVisualStyleMode.liquidGlass;
    }
    for (final item in values) {
      if (item.name.toLowerCase() == normalized) return item;
    }
    return null;
  }
}

enum ProgressBarType {
  /// 全宽流体微光交互轨 (Fluid Ambient Glow Slider)
  fluidGlow,

  /// 自适应动态果冻声波轨 (Adaptive Jelly Waveform Slider)
  adaptiveWaveform,

  /// 双层灵动呼吸光轨 (Dual-Layer Ambient Rhythm Slider)
  dualLayerRhythm;

  static ProgressBarType? fromName(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
    if (normalized == 'fluidglow' || normalized == 'fluid' || normalized == 'glow') {
      return ProgressBarType.fluidGlow;
    }
    if (normalized == 'adaptivewaveform' ||
        normalized == 'waveform' ||
        normalized == 'jelly') {
      return ProgressBarType.adaptiveWaveform;
    }
    if (normalized == 'duallayerrhythm' ||
        normalized == 'rhythm' ||
        normalized == 'ambientrhythm') {
      return ProgressBarType.dualLayerRhythm;
    }
    for (final item in values) {
      if (item.name.toLowerCase() == normalized) return item;
    }
    return null;
  }

  String get label {
    switch (this) {
      case ProgressBarType.fluidGlow:
        return '流体微光';
      case ProgressBarType.adaptiveWaveform:
        return '动态声波';
      case ProgressBarType.dualLayerRhythm:
        return '灵动呼吸';
    }
  }

  String get description {
    switch (this) {
      case ProgressBarType.fluidGlow:
        return '全宽弹性撑满，三态微交互（悬停展开高亮滑块与时间气泡），支持滚轮微调。';
      case ProgressBarType.adaptiveWaveform:
        return '全宽动态排布声波柱，两端无缝贴合，具备果冻弹簧回弹、引力吸附与曲目特征波形。';
      case ProgressBarType.dualLayerRhythm:
        return '顶层高精度时间轴拖拽寻道，底层音频频谱流动律动光雾呼吸动效。';
    }
  }
}

/// 鎶婃棫 app data 鐩綍锛堝鏋滃瓨鍦級绉诲埌鏂扮殑鐩綍銆?
/// 只在 app data 鐩綍娌℃湁鏁版嵁鏃惰繘琛屻€?
/// 什C:\\Users\\$username\\AppData\\Roaming\\com.example\\coriander_player 移到 C:\\Users\\$username\\Documents\\coriander_player
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
  final newDir = Directory(path.join(dir.path, AppBrand.packageName));
  final legacyDir = Directory(path.join(dir.path, AppBrand.legacyPackageName));

  if (!newDir.existsSync() && legacyDir.existsSync()) {
    try {
      legacyDir.renameSync(newDir.path);
    } on FileSystemException catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  return newDir.create(recursive: true);
}

class AppSettings {
  static final github = GitHub();
  // 当前播放器的全局静态版本号，保留四项桌面与列表体验改进。
  static const String version = "1.4.0";
  static const String releaseRepoOwner = "reneryi";
  static const String releaseRepoName = "qisheng_player";
  static const Size defaultWindowSize = Size(1461, 898);
  static const Size minimumWindowSize = Size(507, 507);

  Timer? _saveDebounce;

  /// 主题模式：亮 / 暗 / 跟随系统
  ThemeMode themeMode = ThemeMode.system;

  /// 手动选择的自定义主题色（独立保存，与系统主题色互不覆盖）
  int customTheme = const Color(0xFF4F8DFF).toARGB32();

  /// 启动时或封面主题色不适合当主题时的主色
  int defaultTheme = getWindowsTheme();

  /// 跟随歌曲封面的动态主题
  bool dynamicTheme = true;

  /// 是否让主题色（手动选择或动态取色）微弱浸润默认渐变背景
  /// true = 背景渐变带有极淡的主题色调倾向
  /// false = 背景为纯净中性渐变（夜间午夜蓝 / 日间哑光纸白）
  bool themeColorTintBackground = false;

  /// 跟随系统主题色
  bool useSystemTheme = true;

  /// 跟随系统主题模式
  bool useSystemThemeMode = true;

  List artistSeparator = ["/", "\u3001"];

  /// 歌词来源：true，本地优先；false，在线优先
  bool localLyricFirst = true;

  /// 歌词保存选项偏好：写入音频内嵌标签（ID3v2/FLAC/MP4等）
  bool lyricSaveWriteTag = true;

  /// 歌词保存选项偏好：保存同级 .lrc 文件
  bool lyricSaveExportLrc = true;

  /// 歌词保存选项偏好：应用到播放器
  bool lyricSaveApplyPlayer = true;
  Size windowSize = defaultWindowSize;
  bool isWindowMaximized = false;

  String? fontFamily;
  String? fontPath;
  String? backgroundImagePath;
  double backgroundImageOpacity = 0.8;
  WindowBackdropMode windowBackdropMode = WindowBackdropMode.defaultGradient;
  UiEffectsLevel uiEffectsLevel = UiEffectsLevel.visual;
  final ValueNotifier<bool> lyricDepthBlurNotifier = ValueNotifier(false);
  bool get lyricDepthBlur => lyricDepthBlurNotifier.value;
  set lyricDepthBlur(bool value) {
    if (lyricDepthBlurNotifier.value == value) return;
    lyricDepthBlurNotifier.value = value;
  }
  final ValueNotifier<ProgressBarType> progressBarTypeNotifier =
      ValueNotifier(ProgressBarType.fluidGlow);
  ProgressBarType get progressBarType => progressBarTypeNotifier.value;
  set progressBarType(ProgressBarType value) {
    if (progressBarTypeNotifier.value == value) return;
    progressBarTypeNotifier.value = value;
    scheduleSaveSettings();
  }
  UiVisualStyleMode uiVisualStyleMode = UiVisualStyleMode.borderless;

  /// 全局界面缩放倍率 (1.0 = 100%, 1.1 = 110%, 1.25 = 125% 等)
  double uiScale = 1.0;

  /// 播放页沉浸模块化设置

  /// 是否显示实时音频频谱动效
  bool showSpectrumVisualizer = true;

  /// 是否显示逐字平滑卡拉OK动效
  bool showKaraokeAnimation = true;

  /// 是否开启封面节拍呼吸律动
  bool coverBreathEffect = true;

  /// 全屏/沉浸播放时鼠标静止是否自动隐藏播控栏
  bool autoHideControls = false;

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
      try {
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
      } catch (_) {
        return ThemeMode.dark;
      }
    }
  }

  static int getWindowsTheme() {
    try {
      final systemTheme = SystemTheme.getSystemTheme();
      final a = systemTheme.accent.$1;
      final r = systemTheme.accent.$2;
      final g = systemTheme.accent.$3;
      final b = systemTheme.accent.$4;
      if (a == 0 && r == 0 && g == 0 && b == 0) {
        return const Color(0xFF4F8DFF).toARGB32();
      }
      return Color.fromARGB(
        a == 0 ? 255 : a,
        r,
        g,
        b,
      ).toARGB32();
    } catch (_) {
      return const Color(0xFF4F8DFF).toARGB32();
    }
  }

  AppSettings._();

  static UiVisualStyleMode parseUiVisualStyleMode(Object? value) {
    if (value is String) {
      return UiVisualStyleMode.fromName(value) ?? UiVisualStyleMode.borderless;
    }
    return UiVisualStyleMode.borderless;
  }

  static WindowBackdropMode parseWindowBackdropMode(Object? value) {
    if (value is String) {
      return WindowBackdropMode.fromName(value) ?? WindowBackdropMode.defaultGradient;
    }
    return WindowBackdropMode.defaultGradient;
  }

  static Size parseWindowSize(Object? value) {
    if (value is! String) return defaultWindowSize;

    final parts = value.split(',');
    if (parts.length != 2) return defaultWindowSize;

    final width = double.tryParse(parts[0].trim());
    final height = double.tryParse(parts[1].trim());
    if (width == null ||
        height == null ||
        !width.isFinite ||
        !height.isFinite ||
        width < minimumWindowSize.width ||
        height < minimumWindowSize.height) {
      return defaultWindowSize;
    }

    return Size(width, height);
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

    final ct = settingsMap["CustomTheme"];
    if (ct != null) {
      _instance.customTheme = ct;
    } else if (settingsMap["DefaultTheme"] != null && !_instance.useSystemTheme) {
      _instance.customTheme = settingsMap["DefaultTheme"];
    }

    if (!_instance.useSystemTheme) {
      _instance.defaultTheme = _instance.customTheme;
    } else {
      _instance.defaultTheme = getWindowsTheme();
    }
    if (!_instance.useSystemThemeMode) {
      _instance.themeMode =
          settingsMap["ThemeMode"] == 0 ? ThemeMode.light : ThemeMode.dark;
    } else {
      _instance.themeMode = ThemeMode.system;
    }

    _instance.dynamicTheme = settingsMap["DynamicTheme"] == 1 ? true : false;
    _instance.artistSeparator = settingsMap["ArtistSeparator"];
    _instance.artistSplitPattern = _instance.artistSeparator.join("|");

    final llf = settingsMap["LocalLyricFirst"];
    if (llf != null) {
      _instance.localLyricFirst = llf == 1 ? true : false;
    }

    _instance.windowSize = parseWindowSize(settingsMap["WindowSize"]);

    final isMaximized = settingsMap["IsWindowMaximized"];
    if (isMaximized != null) {
      _instance.isWindowMaximized = isMaximized == 1;
    }

    final us = settingsMap["UiScale"];
    if (us is num) {
      _instance.uiScale = us.toDouble().clamp(0.8, 2.0);
    }
  }

  static Future<void> readFromJson() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final settingsPath = "$supportPath\\settings.json";

      final settingsStr = File(settingsPath).readAsStringSync();
      if (settingsStr.trim().isEmpty) return;
      Map settingsMap = json.decode(settingsStr);
      await parseSettingsMap(settingsMap);
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  static Future<void> parseSettingsMap(Map settingsMap) async {
    try {
      if (settingsMap["Version"] == null) {
        await _readFromJson_old(settingsMap);
        return;
      }

      final ust = settingsMap["UseSystemTheme"];
      if (ust != null) {
        _instance.useSystemTheme = ust;
      }

      final ustm = settingsMap["UseSystemThemeMode"];
      if (ustm != null) {
        _instance.useSystemThemeMode = ustm;
      }

      final ct = settingsMap["CustomTheme"];
      if (ct != null) {
        _instance.customTheme = ct;
      } else if (settingsMap["DefaultTheme"] != null && !_instance.useSystemTheme) {
        _instance.customTheme = settingsMap["DefaultTheme"];
      }

      if (!_instance.useSystemTheme) {
        _instance.defaultTheme = _instance.customTheme;
      } else {
        _instance.defaultTheme = getWindowsTheme();
      }
      if (!_instance.useSystemThemeMode) {
        _instance.themeMode = (settingsMap["ThemeMode"] ?? false)
            ? ThemeMode.dark
            : ThemeMode.light;
      } else {
        _instance.themeMode = ThemeMode.system;
      }

      final dt = settingsMap["DynamicTheme"];
      if (dt != null) {
        _instance.dynamicTheme = dt;
      }

      final tctb = settingsMap["ThemeColorTintBackground"];
      if (tctb != null) {
        _instance.themeColorTintBackground = tctb;
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

      final lswt = settingsMap["LyricSaveWriteTag"];
      if (lswt != null) {
        _instance.lyricSaveWriteTag = lswt;
      }
      final lsel = settingsMap["LyricSaveExportLrc"];
      if (lsel != null) {
        _instance.lyricSaveExportLrc = lsel;
      }
      final lsap = settingsMap["LyricSaveApplyPlayer"];
      if (lsap != null) {
        _instance.lyricSaveApplyPlayer = lsap;
      }

      _instance.windowSize = parseWindowSize(settingsMap["WindowSize"]);

      final isMaximized = settingsMap["IsWindowMaximized"];
      if (isMaximized != null) {
        _instance.isWindowMaximized = isMaximized;
      }

      final ff = settingsMap["FontFamily"];
      final fp = settingsMap["FontPath"];
      _instance.fontFamily = ff;
      _instance.fontPath = fp;

      final bgImage = settingsMap["BackgroundImagePath"];
      if (bgImage is String && bgImage.isNotEmpty) {
        _instance.backgroundImagePath = bgImage;
      }
      final bgOpacity = settingsMap["BackgroundImageOpacity"];
      if (bgOpacity is num) {
        _instance.backgroundImageOpacity = bgOpacity.toDouble().clamp(0.3, 1.0);
      }
      final windowBackdropMode = settingsMap["WindowBackdropMode"];
      if (windowBackdropMode is String) {
        _instance.windowBackdropMode =
            WindowBackdropMode.fromName(windowBackdropMode) ??
                WindowBackdropMode.defaultGradient;
      }
      if (_instance.windowBackdropMode == WindowBackdropMode.meshFlow) {
        _instance.dynamicTheme = true;
      } else if (_instance.windowBackdropMode == WindowBackdropMode.prismaticGlass &&
          _instance.useSystemTheme) {
        _instance.dynamicTheme = false;
      }
      _instance.uiEffectsLevel = UiEffectsLevel.visual;
      _instance.lyricDepthBlur = settingsMap["LyricDepthBlur"] == true;
      final uiVisualStyleModeName = settingsMap["UiVisualStyleMode"];
      if (uiVisualStyleModeName is String) {
        _instance.uiVisualStyleMode =
            UiVisualStyleMode.fromName(uiVisualStyleModeName) ??
                UiVisualStyleMode.borderless;
      } else {
        _instance.uiVisualStyleMode = UiVisualStyleMode.borderless;
      }
      _instance.showSpectrumVisualizer =
          settingsMap["ShowSpectrumVisualizer"] ?? true;
      _instance.showKaraokeAnimation =
          settingsMap["ShowKaraokeAnimation"] ?? true;
      _instance.coverBreathEffect = settingsMap["CoverBreathEffect"] ?? true;
      _instance.autoHideControls = settingsMap["AutoHideControls"] ?? false;
      final progressBarTypeName = settingsMap["ProgressBarType"];
      if (progressBarTypeName is String) {
        _instance.progressBarTypeNotifier.value =
            ProgressBarType.fromName(progressBarTypeName) ??
                ProgressBarType.fluidGlow;
      }
      final us = settingsMap["UiScale"];
      if (us is num) {
        _instance.uiScale = us.toDouble().clamp(0.8, 2.0);
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  Future<void> saveSettings() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      bool isMaximized = false;
      bool isFullScreen = false;
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          isMaximized = await windowManager
              .isMaximized()
              .timeout(const Duration(milliseconds: 300), onTimeout: () => false);
          isFullScreen = await windowManager
              .isFullScreen()
              .timeout(const Duration(milliseconds: 300), onTimeout: () => false);
        } catch (_) {}
      }
      final settingsMap = {
        "Version": version,
        "ThemeMode": themeMode == ThemeMode.dark,
        "DynamicTheme": dynamicTheme,
        "ThemeColorTintBackground": themeColorTintBackground,
        "UseSystemTheme": useSystemTheme,
        "UseSystemThemeMode": useSystemThemeMode,
        "DefaultTheme": defaultTheme,
        "CustomTheme": customTheme,
        "ArtistSeparator": artistSeparator,
        "LocalLyricFirst": localLyricFirst,
        "LyricSaveWriteTag": lyricSaveWriteTag,
        "LyricSaveExportLrc": lyricSaveExportLrc,
        "LyricSaveApplyPlayer": lyricSaveApplyPlayer,
        "IsWindowMaximized": isMaximized,
        "FontFamily": fontFamily,
        "FontPath": fontPath,
        "BackgroundImagePath": backgroundImagePath,
        "BackgroundImageOpacity": backgroundImageOpacity,
        "WindowBackdropMode": windowBackdropMode.name,
        "UiEffectsLevel": uiEffectsLevel.name,
        "LyricDepthBlur": lyricDepthBlur,
        "UiVisualStyleMode": uiVisualStyleMode.name,
        "ShowSpectrumVisualizer": showSpectrumVisualizer,
        "ShowKaraokeAnimation": showKaraokeAnimation,
        "CoverBreathEffect": coverBreathEffect,
        "AutoHideControls": autoHideControls,
        "ProgressBarType": progressBarType.name,
        "UiScale": uiScale,
      };

      // 只有在窗口不是最大化且不是全屏时才保存窗口尺寸。
      // 这样 windowSize 始终保存的是窗口化时的尺寸。
      Size sizeToSave = windowSize;
      if (!isMaximized && !isFullScreen && !Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          sizeToSave = await windowManager
              .getSize()
              .timeout(const Duration(milliseconds: 300), onTimeout: () => sizeToSave);
          windowSize = sizeToSave;
        } catch (_) {}
      }
      settingsMap["WindowSize"] =
          "${sizeToSave.width.toStringAsFixed(1)},${sizeToSave.height.toStringAsFixed(1)}";

      final settingsStr = json.encode(settingsMap);
      final supportPath = (await getAppDataDir()).path;
      final settingsPath = "$supportPath\\settings.json";
      await atomicWriteString(settingsPath, settingsStr);
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  void scheduleSaveSettings() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(saveSettings()),
    );
  }
}
