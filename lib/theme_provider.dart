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

/// 依据主导颜色和明暗模式动态生成 3 色流体渐变背景
List<Color> buildDynamicBackgroundGradient(
    Color dominantColor, Brightness brightness) {
  final hsl = HSLColor.fromColor(dominantColor);
  if (isNeutralColor(dominantColor)) {
    final baseLight = brightness == Brightness.dark
        ? (hsl.lightness * 0.34).clamp(0.04, 0.18)
        : (0.78 + hsl.lightness * 0.16).clamp(0.78, 0.96);
    return [
      hsl
          .withSaturation(0)
          .withLightness((baseLight * 1.12).clamp(0.0, 1.0))
          .toColor(),
      hsl.withSaturation(0).withLightness(baseLight).toColor(),
      hsl
          .withSaturation(0)
          .withLightness((baseLight * 0.88).clamp(0.0, 1.0))
          .toColor(),
    ];
  }

  if (brightness == Brightness.dark) {
    // 暗色模式：生成低饱和度、低亮度的同色系暗色流光背景
    final baseSat = hsl.saturation.clamp(0.04, 0.32); // 控制饱和度，避免过于鲜艳影响文字可读性
    final baseLight = hsl.lightness.clamp(0.08,
        0.16); // Keep the dark backdrop visible without flattening it to black.

    // top 颜色：色相微调 -12 度，稍微亮一丁点
    final top = hsl
        .withHue((hsl.hue - 12) % 360)
        .withSaturation(baseSat)
        .withLightness((baseLight * 1.18).clamp(0.0, 1.0))
        .toColor();

    // middle 颜色：保持原色相
    final middle =
        hsl.withSaturation(baseSat).withLightness(baseLight).toColor();

    // bottom 颜色：色相微调 +12 度，稍暗，形成过渡
    final bottom = hsl
        .withHue((hsl.hue + 12) % 360)
        .withSaturation((baseSat * 0.85).clamp(0.0, 1.0))
        .withLightness((baseLight * 0.88).clamp(0.0, 1.0))
        .toColor();

    return [top, middle, bottom];
  } else {
    // 明亮模式：生成淡雅、高亮度的白昼同色系清爽背景
    final baseSat = hsl.saturation.clamp(0.06, 0.18); // 极低饱和度，温和不刺眼
    final baseLight = hsl.lightness.clamp(0.92, 0.96); // 极高亮度，保持类似宣纸的洁净感

    // top 颜色：色相微调 -10 度
    final top = hsl
        .withHue((hsl.hue - 10) % 360)
        .withSaturation(baseSat)
        .withLightness(baseLight)
        .toColor();

    // middle 颜色
    final middle = hsl
        .withSaturation((baseSat * 1.15).clamp(0.0, 1.0))
        .withLightness((baseLight * 0.97).clamp(0.0, 1.0))
        .toColor();

    // bottom 颜色：色相微调 +10 度
    final bottom = hsl
        .withHue((hsl.hue + 10) % 360)
        .withSaturation((baseSat * 0.95).clamp(0.0, 1.0))
        .withLightness((baseLight * 1.01).clamp(0.0, 1.0))
        .toColor();

    return [top, middle, bottom];
  }
}

Color buildGlassTint(Color dominantColor, Brightness brightness) {
  final hsl = HSLColor.fromColor(dominantColor);
  if (isNeutralColor(dominantColor)) {
    final lightness = brightness == Brightness.dark
        ? hsl.lightness.clamp(0.42, 0.68)
        : hsl.lightness.clamp(0.38, 0.62);
    return hsl.withSaturation(0).withLightness(lightness).toColor();
  }
  // 移除硬编码的青蓝锚点插值，100% 忠实表达专辑封面与主题提取色的原生色彩
  return hsl
      .withSaturation(hsl.saturation.clamp(0.0, 0.55).toDouble())
      .withLightness(
        brightness == Brightness.dark
            ? hsl.lightness.clamp(0.60, 0.78).toDouble()
            : hsl.lightness.clamp(0.32, 0.48).toDouble(),
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
  final saturation = isNeutralColor(primaryColor)
      ? 0.0
      : hsl.saturation.clamp(0.04, 0.72).toDouble();
  final baseLightness = brightness == Brightness.dark
      ? hsl.lightness.clamp(0.34, 0.72).toDouble()
      : hsl.lightness.clamp(0.28, 0.68).toDouble();
  final startLightness = brightness == Brightness.dark
      ? (baseLightness * 1.24).clamp(0.0, 1.0)
      : (baseLightness * 1.08).clamp(0.0, 1.0);
  final endLightness = brightness == Brightness.dark
      ? (baseLightness * 0.88).clamp(0.0, 1.0)
      : (baseLightness * 0.92).clamp(0.0, 1.0);

  return [
    hsl.withSaturation(saturation).withLightness(startLightness).toColor(),
    hsl.withSaturation(saturation).withLightness(endLightness).toColor(),
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

  Color get dominantColor {
    return resolveThemeDominantColor(
      fallbackColor: currScheme.primary,
      dynamicDominantColor: _dynamicDominantColor,
    );
  }

  AlbumPalette get albumPalette =>
      _dynamicAlbumPalette ?? AlbumPalette.fallback(dominantColor);

  List<Color> get backgroundGradient => buildDynamicBackgroundGradient(
        albumPalette.secondary,
        effectiveBrightness,
      );

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
    if (mode == WindowBackdropMode.fluid &&
        !AppSettings.instance.dynamicTheme) {
      AppSettings.instance.dynamicTheme = true;
      final audio = PlayService.instance.playbackService.nowPlaying;
      if (audio != null) {
        applyThemeFromAudio(audio);
      }
    }
    final result = await WindowControls.setWindowBackdropMode(mode);
    windowBackdropMode = mode;
    windowBackdropResult = result;
    AppSettings.instance.windowBackdropMode = mode;
    notifyListeners();
    await AppSettings.instance.saveSettings();
    return result;
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
    final saturation = hsl.saturation.clamp(0.35, 0.9).toDouble();
    final lightness = brightness == Brightness.dark
        ? hsl.lightness.clamp(0.52, 0.68).toDouble()
        : hsl.lightness.clamp(0.38, 0.56).toDouble();
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
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
