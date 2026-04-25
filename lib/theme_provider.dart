import 'dart:async';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

Color resolveThemeDominantColor({
  required Color fallbackColor,
  Color? dynamicDominantColor,
}) {
  return dynamicDominantColor ?? fallbackColor;
}

List<Color> buildDynamicBackgroundGradient(Color dominantColor) {
  final hsl = HSLColor.fromColor(dominantColor);
  final normalized = hsl
      .withSaturation(hsl.saturation.clamp(0.24, 0.62).toDouble())
      .withLightness(hsl.lightness.clamp(0.26, 0.42).toDouble())
      .toColor();
  // 现代简约：更深邃的背景渐变，降低 dominant 色混合比例
  final top = Color.lerp(const Color(0xFF0C1219), normalized, 0.32)!;
  final middle = Color.lerp(const Color(0xFF040609), normalized, 0.18)!;
  final bottom = Color.lerp(const Color(0xFF010203), normalized, 0.06)!;
  return [top, middle, bottom];
}

// 现代简约：玻璃色调更柔和淡雅
Color buildGlassTint(Color dominantColor, Brightness brightness) {
  final hsl = HSLColor.fromColor(dominantColor);
  final normalized = hsl
      .withSaturation(hsl.saturation.clamp(0.16, 0.44).toDouble())
      .withLightness(
        brightness == Brightness.dark
            ? hsl.lightness.clamp(0.72, 0.82).toDouble()
            : hsl.lightness.clamp(0.24, 0.36).toDouble(),
      )
      .toColor();
  return Color.lerp(
    normalized,
    brightness == Brightness.dark ? Colors.white : Colors.black,
    brightness == Brightness.dark ? 0.12 : 0.06,
  )!;
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

  final Map<String, Color> _dominantColorCache = {};

  Color? _lightAccentColor;
  Color? _darkAccentColor;
  Color? _dynamicDominantColor;

  UiEffectsLevel uiEffectsLevel = AppSettings.instance.uiEffectsLevel;
  UiVisualStyleMode visualStyleMode = AppSettings.instance.uiVisualStyleMode;
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

  Color get dominantColor => resolveThemeDominantColor(
        fallbackColor: currScheme.primary,
        dynamicDominantColor: _dynamicDominantColor,
      );

  List<Color> get backgroundGradient => buildDynamicBackgroundGradient(
        dominantColor,
      );

  Color get glassTint => buildGlassTint(
        dominantColor,
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
      _resetDynamicTheme();
      return;
    }
    unawaited(_applyDynamicTheme(audio));
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

  Future<void> _applyDynamicTheme(Audio audio) async {
    try {
      final cached = _dominantColorCache[audio.path];
      final extracted = cached ?? await _extractDominantColor(audio);
      final dominant = extracted ?? _fallbackDominantColor();

      _dominantColorCache[audio.path] = dominant;
      _dynamicDominantColor = dominant;
      _lightAccentColor = _resolveAccentColor(dominant, Brightness.light);
      _darkAccentColor = _resolveAccentColor(dominant, Brightness.dark);
      notifyListeners();
      await _syncDesktopLyricTheme();
    } catch (_) {
      _resetDynamicTheme();
    }
  }

  Future<Color?> _extractDominantColor(Audio audio) async {
    final cover = await audio.cover;
    if (cover == null) return null;
    final palette = await PaletteGenerator.fromImageProvider(
      cover,
      maximumColorCount: 16,
    );
    final resolved = palette.dominantColor?.color ??
        palette.vibrantColor?.color ??
        palette.lightVibrantColor?.color ??
        palette.mutedColor?.color;
    if (resolved == null) return null;
    return _normalizeColor(resolved);
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
        .withSaturation(hsl.saturation.clamp(0.22, 0.82).toDouble())
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
