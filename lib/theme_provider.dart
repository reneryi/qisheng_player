import 'dart:async';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/album_palette.dart' as rust_palette;
import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:flutter/material.dart';

Color resolveThemeDominantColor({
  required Color fallbackColor,
  Color? dynamicDominantColor,
}) {
  return dynamicDominantColor ?? fallbackColor;
}

bool isNeutralColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  final channels = [
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  ];
  final channelRange = channels.reduce((a, b) => a > b ? a : b) -
      channels.reduce((a, b) => a < b ? a : b);
  return hsl.saturation < 0.08 || channelRange < 18;
}

/// 依据主导颜色和明暗模式动态生成 135° 对角背景渐变
/// 日间模式为哑光柔和纸白，夜间模式为午夜深蓝黑
List<Color> buildDynamicBackgroundGradient(
    Color dominantColor, Brightness brightness) {
  final hsl = HSLColor.fromColor(dominantColor);
  if (isNeutralColor(dominantColor)) {
    if (brightness == Brightness.dark) {
      return const [
        Color(0xFF0A1324), // 深邃午夜蓝
        Color(0xFF0F1D32), // 微亮静谧蓝灰
        Color(0xFF070D18), // 纯净玄黑
      ];
    } else {
      return const [
        Color(0xFFF6F8FA), // 珍珠冷白
        Color(0xFFF0F2F5), // 柔和哑光纸白
        Color(0xFFE8EBF0), // 温润浅米灰
      ];
    }
  }

  if (brightness == Brightness.dark) {
    // 暗色模式：午夜深蓝黑微浸润专辑主色调（极低明度，柔和沉静）
    final baseSat = hsl.saturation.clamp(0.06, 0.28);
    final top = hsl
        .withHue((hsl.hue - 10 + 360) % 360)
        .withSaturation(baseSat)
        .withLightness(0.09)
        .toColor();
    final middle = hsl
        .withSaturation(baseSat * 0.9)
        .withLightness(0.12)
        .toColor();
    final bottom = hsl
        .withHue((hsl.hue + 12) % 360)
        .withSaturation(baseSat * 0.75)
        .withLightness(0.06)
        .toColor();

    return [top, middle, bottom];
  } else {
    // 明亮模式：主体为 135° 哑光柔和纸白，微量浸润专辑主色调（极低饱和度，极高明度）
    final baseSat = hsl.saturation.clamp(0.03, 0.12);
    final top = hsl
        .withHue((hsl.hue - 8 + 360) % 360)
        .withSaturation(baseSat)
        .withLightness(0.97)
        .toColor();
    final middle = hsl
        .withSaturation(baseSat)
        .withLightness(0.95)
        .toColor();
    final bottom = hsl
        .withHue((hsl.hue + 8) % 360)
        .withSaturation(baseSat * 0.8)
        .withLightness(0.92)
        .toColor();

    return [top, middle, bottom];
  }
}

/// 返回文档规范中定义的纯净中性渐变（不受任何主题色影响）
/// 夜间：深邃午夜蓝 → 微亮静谧蓝灰 → 纯净玄黑
/// 日间：珍珠冷白 → 柔和哑光纸白 → 温润浅米灰
List<Color> pureNeutralGradient(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const [
      Color(0xFF0A1324), // 深邃午夜蓝
      Color(0xFF0F1D32), // 微亮静谧蓝灰
      Color(0xFF070D18), // 纯净玄黑
    ];
  } else {
    return const [
      Color(0xFFF6F8FA), // 珍珠冷白
      Color(0xFFF0F2F5), // 柔和哑光纸白
      Color(0xFFE8EBF0), // 温润浅米灰
    ];
  }
}

/// 在纯净中性渐变的基础上，以极微弱强度混入主题色调
/// [tintStrength] 控制浸润程度：0.0 = 完全纯净，1.0 = 完全由主题色生成
List<Color> buildTintedNeutralGradient(
    Color tintColor, Brightness brightness, {double tintStrength = 0.08}) {
  final neutralColors = pureNeutralGradient(brightness);
  final tintedColors = buildDynamicBackgroundGradient(tintColor, brightness);
  return [
    for (int i = 0; i < neutralColors.length; i++)
      Color.lerp(neutralColors[i], tintedColors[i], tintStrength.clamp(0.0, 0.3))!,
  ];
}

Color buildGlassTint(Color dominantColor, Brightness brightness) {
  final hsl = HSLColor.fromColor(dominantColor);
  if (isNeutralColor(dominantColor)) {
    final lightness = brightness == Brightness.dark
        ? hsl.lightness.clamp(0.48, 0.68)
        : hsl.lightness.clamp(0.38, 0.56);
    return hsl.withSaturation(0).withLightness(lightness).toColor();
  }
  // 极浅淡微染色管道：暗色模式提亮晶体透光，日间模式雅致微染色，杜绝发脏发灰
  final isDark = brightness == Brightness.dark;
  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
  final darkMaxL = (0.76 - excess * 0.18).clamp(0.52, 0.76);
  final darkMinL = (0.62 - excess * 0.14).clamp(0.44, darkMaxL);
  final lightMaxL = (0.50 - excess * 0.12).clamp(0.36, 0.50);
  final lightMinL = (0.38 - excess * 0.08).clamp(0.28, lightMaxL);

  return hsl
      .withSaturation(
        isDark
            ? (hsl.saturation * (1.0 - excess * 0.20)).clamp(0.10, 0.44).toDouble()
            : hsl.saturation.clamp(0.08, 0.36).toDouble(),
      )
      .withLightness(
        isDark
            ? hsl.lightness.clamp(darkMinL, darkMaxL).toDouble()
            : hsl.lightness.clamp(lightMinL, lightMaxL).toDouble(),
      )
      .toColor();
}

/// Generates the primary-color variants used by the AppShell's main surface.
/// The surface chooses the alpha when blending these colors over its material.
List<Color> buildDynamicSurfaceGradient(
  Color primaryColor,
  Brightness brightness,
) {
  final hsl = HSLColor.fromColor(primaryColor);
  final isNeutral = isNeutralColor(primaryColor);
  final lum = isNeutral ? 0.0 : AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);

  final maxSat = isNeutral ? 0.0 : (0.70 - excess * 0.22).clamp(0.35, 0.70);
  final saturation = isNeutral
      ? 0.0
      : hsl.saturation.clamp(0.04, maxSat).toDouble();

  if (brightness == Brightness.dark) {
    // 暗色模式：避免高感知亮度色彩（黄、橙、嫩绿、青等）在微透渐变中产生白炽暴晒感
    final maxBaseL = (0.58 - excess * 0.26).clamp(0.32, 0.58);
    final baseLightness = hsl.lightness.clamp(0.30, maxBaseL).toDouble();
    final startLightness =
        (baseLightness * (1.24 - excess * 0.35)).clamp(0.18, 0.68);
    final endLightness =
        (baseLightness * (0.88 - excess * 0.10)).clamp(0.12, 0.60);

    return [
      hsl.withSaturation(saturation).withLightness(startLightness).toColor(),
      hsl.withSaturation(saturation).withLightness(endLightness).toColor(),
    ];
  } else {
    // 亮色模式：温润水彩白底衬，保留既有明度算法确保测试与既有视觉一致性
    final maxBaseL = (0.68 - excess * 0.14).clamp(0.48, 0.68);
    final baseLightness = hsl.lightness.clamp(0.28, maxBaseL).toDouble();
    final startLightness = (baseLightness * 1.08).clamp(0.0, 0.88);
    final endLightness = (baseLightness * 0.92).clamp(0.0, 0.82);

    return [
      hsl.withSaturation(saturation).withLightness(startLightness).toColor(),
      hsl.withSaturation(saturation).withLightness(endLightness).toColor(),
    ];
  }
}

List<Color> buildAuroraGlowGradient(
  AlbumPalette palette,
  Brightness brightness,
) {
  if (brightness == Brightness.dark) {
    final darkPalette = palette.forDarkMode();
    return [
      Color.lerp(const Color(0xFF060A13), darkPalette.primary, 0.16)!,
      Color.lerp(const Color(0xFF080D18), darkPalette.muted, 0.10)!,
      Color.lerp(const Color(0xFF060A13), darkPalette.secondary, 0.16)!,
    ];
  }
  final lightPalette = palette.forLightMode();
  return [
    Color.lerp(const Color(0xFFF7F9FD), lightPalette.primary, 0.14)!,
    Color.lerp(const Color(0xFFF1F5FA), lightPalette.muted, 0.08)!,
    Color.lerp(const Color(0xFFF6F8FD), lightPalette.secondary, 0.14)!,
  ];
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();

  static ThemeProvider? _instance;

  static ThemeProvider get instance {
    _instance ??= ThemeProvider._();
    return _instance!;
  }

  ColorScheme _lightBaseScheme = ColorScheme.fromSeed(
    seedColor: Color(AppSettings.instance.defaultTheme),
    brightness: Brightness.light,
  );

  ColorScheme _darkBaseScheme = ColorScheme.fromSeed(
    seedColor: Color(AppSettings.instance.defaultTheme),
    brightness: Brightness.dark,
  );

  static const int _maxPaletteCacheEntries = 128;
  static const String _paletteRoleVersion = 'roles-v2';

  final Map<String, AlbumPalette> _paletteCache = {};
  int _dynamicThemeRequestId = 0;
  int _windowBackdropRequestId = 0;

  Color? _lightAccentColor;
  Color? _darkAccentColor;
  Color? _dynamicDominantColor;
  AlbumPalette? _dynamicAlbumPalette;

  UiEffectsLevel uiEffectsLevel = AppSettings.instance.uiEffectsLevel;
  UiVisualStyleMode visualStyleMode = AppSettings.instance.uiVisualStyleMode;
  WindowBackdropMode windowBackdropMode =
      AppSettings.instance.windowBackdropMode;
  WindowBackdropModeResult? windowBackdropResult =
      WindowControls.lastBackdropResult;
  ThemeMode themeMode = AppSettings.instance.themeMode;
  String? fontFamily = AppSettings.instance.fontFamily;

  ColorScheme get lightScheme =>
      _mergeAccent(_lightBaseScheme, _lightAccentColor, visualStyleMode);

  ColorScheme get darkScheme =>
      _mergeAccent(_darkBaseScheme, _darkAccentColor, visualStyleMode);

  Brightness get effectiveBrightness {
    return switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  ColorScheme get currScheme =>
      effectiveBrightness == Brightness.dark ? darkScheme : lightScheme;

  WindowBackdropMode get effectiveWindowBackdropMode {
    if (windowBackdropMode == WindowBackdropMode.meshFlow ||
        windowBackdropMode == WindowBackdropMode.waterRipple ||
        windowBackdropMode == WindowBackdropMode.prismaticGlass ||
        windowBackdropMode == WindowBackdropMode.defaultGradient) {
      return windowBackdropMode;
    }
    final result = windowBackdropResult;
    if (result == null || result.requestedMode != windowBackdropMode) {
      return WindowBackdropMode.defaultGradient;
    }
    return result.effectiveRenderMode;
  }

  Color get dominantColor {
    return resolveThemeDominantColor(
      fallbackColor: currScheme.primary,
      dynamicDominantColor: _dynamicDominantColor,
    );
  }

  AlbumPalette get albumPalette =>
      _dynamicAlbumPalette ?? AlbumPalette.fallback(dominantColor);

  /// 根据当前窗口背景材质模式和色彩浸润设置，返回适合的背景渐变色列表。
  /// - defaultGradient：严格以文档纯净渐变为基调，仅在开关开启时极微弱浸润
  /// - meshFlow：完全依赖动态取色/主题色生成流体光斑底色
  /// - 其他原生/着色器模式：返回中性渐变（实际渲染由着色器或系统负责）
  List<Color> get backgroundGradient {
    final mode = effectiveWindowBackdropMode;
    final brightness = effectiveBrightness;
    final settings = AppSettings.instance;

    // 弥散流彩模式：需要带色彩的渐变作为着色器底色（保持原逻辑）
    if (mode == WindowBackdropMode.meshFlow) {
      return buildDynamicBackgroundGradient(
        albumPalette.secondary,
        brightness,
      );
    }

    // 默认渐变模式：根据浸润开关控制色彩
    if (mode == WindowBackdropMode.defaultGradient) {
      // 浸润开关关闭 → 纯净中性渐变（文档原版：午夜蓝/哑光纸白）
      if (!settings.themeColorTintBackground) {
        return pureNeutralGradient(brightness);
      }

      // 浸润开关开启 + 动态取色 ON → 适度封面色浸润（暗色约 18%，亮色约 14%）
      if (settings.dynamicTheme && _dynamicAlbumPalette != null) {
        return buildTintedNeutralGradient(
          _dynamicAlbumPalette!.secondary,
          brightness,
          tintStrength: brightness == Brightness.dark ? 0.18 : 0.14,
        );
      }

      // 浸润开关开启 + 动态取色 OFF → 适度手动主题色浸润（暗色约 15%，亮色约 12%）
      return buildTintedNeutralGradient(
        _fallbackDominantColor(),
        brightness,
        tintStrength: brightness == Brightness.dark ? 0.15 : 0.12,
      );
    }

    // 其他模式（Mica/Acrylic/WaterRipple/PrismaticGlass）：
    // 实际渲染由原生系统或着色器负责，这里返回中性渐变作为 fallback
    return pureNeutralGradient(brightness);
  }

  Color get glassTint => buildGlassTint(
        albumPalette.secondary,
        effectiveBrightness,
      );

  List<Color> get surfaceGradient => buildDynamicSurfaceGradient(
        albumPalette.primary,
        effectiveBrightness,
      );

  ColorScheme _mergeAccent(
    ColorScheme baseScheme,
    Color? accentColor,
    UiVisualStyleMode styleMode,
  ) {
    if (accentColor == null) {
      return AppTheme.applyChromeSurfaces(
        baseScheme,
        visualStyleMode: styleMode,
      );
    }

    final accentScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: baseScheme.brightness,
    );

    return AppTheme.applyChromeSurfaces(
      baseScheme.copyWith(
        primary: accentScheme.primary,
        onPrimary: accentScheme.onPrimary,
        primaryContainer: accentScheme.primaryContainer,
        onPrimaryContainer: accentScheme.onPrimaryContainer,
        secondary: accentScheme.secondary,
        onSecondary: accentScheme.onSecondary,
        tertiary: accentScheme.tertiary,
        onTertiary: accentScheme.onTertiary,
        inversePrimary: accentScheme.inversePrimary,
      ),
      visualStyleMode: styleMode,
    );
  }

  /// 通知主题系统重新计算所有派生值（如背景渐变、色调等）并刷新 UI。
  /// 供外部在修改设置项（如 themeColorTintBackground）后调用。
  void refreshTheme() {
    notifyListeners();
  }

  void applyTheme({required Color seedColor}) {
    _dynamicThemeRequestId++;
    _lightBaseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    _darkBaseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    _resetDynamicTheme(notify: false);
    notifyListeners();
    unawaited(_syncDesktopLyricTheme());
  }

  void applyThemeMode(ThemeMode themeMode) {
    this.themeMode = themeMode;
    notifyListeners();
    unawaited(_syncDesktopLyricTheme(sendThemeMode: true));
  }

  void applyThemeFromAudio(Audio audio) {
    if (!AppSettings.instance.dynamicTheme) {
      _dynamicThemeRequestId++;
      _resetDynamicTheme();
      return;
    }
    final requestId = ++_dynamicThemeRequestId;
    unawaited(_applyDynamicTheme(audio, requestId));
  }

  void changeFontFamily(String? fontFamily) {
    this.fontFamily = fontFamily;
    notifyListeners();
  }

  void applyUiEffectsLevel(UiEffectsLevel level) {
    if (uiEffectsLevel == level) return;
    uiEffectsLevel = level;
    notifyListeners();
  }

  Future<void> applyVisualStyleMode(UiVisualStyleMode mode) async {
    if (visualStyleMode == mode) return;
    visualStyleMode = mode;
    AppSettings.instance.uiVisualStyleMode = mode;
    notifyListeners();
    await AppSettings.instance.saveSettings();
    await _syncDesktopLyricTheme();
  }

  Future<WindowBackdropModeResult> applyWindowBackdropMode(
    WindowBackdropMode mode,
  ) async {
    final requestId = ++_windowBackdropRequestId;
    if (mode == WindowBackdropMode.meshFlow &&
        !AppSettings.instance.dynamicTheme) {
      AppSettings.instance.dynamicTheme = true;
      final audio = PlayService.instance.playbackService.nowPlaying;
      if (audio != null) {
        applyThemeFromAudio(audio);
      }
    }
    windowBackdropMode = mode;
    windowBackdropResult = null;
    notifyListeners();

    final result = await WindowControls.setWindowBackdropMode(mode);
    if (requestId != _windowBackdropRequestId) return result;

    windowBackdropResult = result;
    AppSettings.instance.windowBackdropMode = mode;
    notifyListeners();
    await AppSettings.instance.saveSettings();
    return result;
  }

  void acceptInitialWindowBackdropResult(WindowBackdropModeResult result) {
    if (result.requestedMode != windowBackdropMode) return;
    windowBackdropResult = result;
    notifyListeners();
  }

  Future<void> _applyDynamicTheme(Audio audio, int requestId) async {
    try {
      final cacheKey = _paletteCacheKey(audio);
      final cached = _paletteCache[cacheKey];
      final extracted = cached ?? await _extractAlbumPalette(audio);
      if (requestId != _dynamicThemeRequestId) return;

      if (extracted != null && cached == null) {
        _cachePalette(cacheKey, extracted);
      }

      _applyAlbumPalette(
        extracted ?? AlbumPalette.fallback(_fallbackDominantColor()),
      );
      notifyListeners();
      await _syncDesktopLyricTheme();
    } catch (_) {
      if (requestId != _dynamicThemeRequestId) return;
      _applyAlbumPalette(AlbumPalette.fallback(_fallbackDominantColor()));
      notifyListeners();
      await _syncDesktopLyricTheme();
    }
  }

  Future<AlbumPalette?> _extractAlbumPalette(Audio audio) async {
    final coverBytes = await audio.coverBytes;
    if (coverBytes == null || coverBytes.isEmpty) return null;

    final rgbColors = await rust_palette.extractDominantColors(
      imageBytes: coverBytes,
      maxColors: 6,
    );
    if (rgbColors.isEmpty) return null;

    final selected = AlbumPalette.fromColors(
      rgbColors.map(_colorFromRgbInt).toList(growable: false),
      fallback: _fallbackDominantColor(),
    );
    return AlbumPalette.fromColors(
      selected.colors.map(_normalizeColor).toList(growable: false),
      fallback: _normalizeColor(_fallbackDominantColor()),
    );
  }

  void _applyAlbumPalette(AlbumPalette palette) {
    _dynamicAlbumPalette = palette;
    _dynamicDominantColor = palette.primary;
    _lightAccentColor = _resolveAccentColor(palette.accent, Brightness.light);
    _darkAccentColor = _resolveAccentColor(palette.accent, Brightness.dark);
  }

  @visibleForTesting
  void setDynamicAlbumPaletteForTesting(AlbumPalette? palette) {
    if (palette == null) {
      _resetDynamicTheme();
    } else {
      _applyAlbumPalette(palette);
      notifyListeners();
    }
  }

  void _cachePalette(String key, AlbumPalette palette) {
    if (!_paletteCache.containsKey(key) &&
        _paletteCache.length >= _maxPaletteCacheEntries) {
      _paletteCache.remove(_paletteCache.keys.first);
    }
    _paletteCache[key] = palette;
  }

  String _paletteCacheKey(Audio audio) {
    return '$_paletteRoleVersion\u0001${audio.path}\u0001${audio.modified}'
        '\u0001${audio.mediaPath}';
  }

  Color _colorFromRgbInt(int rgb) {
    return Color(0xFF000000 | (rgb & 0x00FFFFFF));
  }

  Color _resolveAccentColor(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    final lum = AlbumPalette.pureHueLuminance(hsl.hue);
    final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
    if (brightness == Brightness.dark) {
      final darkMaxL = (0.58 - excess * 0.22).clamp(0.36, 0.58);
      final darkMinL = (0.44 - excess * 0.16).clamp(0.28, darkMaxL);
      final maxSat = (0.80 - excess * 0.26).clamp(0.48, 0.80);
      final saturation = hsl.saturation.clamp(0.30, maxSat).toDouble();
      final lightness = hsl.lightness.clamp(darkMinL, darkMaxL).toDouble();
      return hsl.withSaturation(saturation).withLightness(lightness).toColor();
    } else {
      final lightMaxL = (0.54 - excess * 0.18).clamp(0.34, 0.54);
      final lightMinL = (0.36 - excess * 0.12).clamp(0.24, lightMaxL);
      final maxSat = (0.86 - excess * 0.18).clamp(0.52, 0.86);
      final saturation = hsl.saturation.clamp(0.35, maxSat).toDouble();
      final lightness = hsl.lightness.clamp(lightMinL, lightMaxL).toDouble();
      return hsl.withSaturation(saturation).withLightness(lightness).toColor();
    }
  }

  Color _normalizeColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.0, 0.82).toDouble())
        .withLightness(hsl.lightness.clamp(0.32, 0.62).toDouble())
        .toColor();
  }

  Color _fallbackDominantColor() {
    final scheme = effectiveBrightness == Brightness.dark
        ? _darkBaseScheme
        : _lightBaseScheme;
    return _normalizeColor(
      Color.lerp(scheme.primary, scheme.tertiary, 0.28) ?? scheme.primary,
    );
  }

  void _resetDynamicTheme({bool notify = true}) {
    _dynamicDominantColor = null;
    _dynamicAlbumPalette = null;
    _lightAccentColor = null;
    _darkAccentColor = null;
    if (!notify) return;
    notifyListeners();
    unawaited(_syncDesktopLyricTheme());
  }

  Future<void> _syncDesktopLyricTheme({bool sendThemeMode = false}) async {
    try {
      final canSend =
          await PlayService.instance.desktopLyricService.canSendMessage;
      if (!canSend) return;

      PlayService.instance.desktopLyricService.sendThemeMessage(currScheme);
      if (sendThemeMode) {
        PlayService.instance.desktopLyricService.sendThemeModeMessage(
          effectiveBrightness == Brightness.dark,
        );
      }
    } catch (_) {}
  }
}
