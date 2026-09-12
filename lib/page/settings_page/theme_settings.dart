import 'dart:async';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/settings_tile.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/font_loader_helper.dart';
import 'package:qisheng_player/page/settings_page/theme_picker_dialog.dart';
import 'package:qisheng_player/src/rust/api/installed_font.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:crypto/crypto.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:qisheng_player/page/settings_page/ui_scale_settings.dart';

class _FontPreviewRegistry {
  const _FontPreviewRegistry._();

  static final Set<String> _loadedFamilies = <String>{};
  static final Set<String> _failedFamilies = <String>{};
  static final Map<String, Future<void>> _pendingLoads =
      <String, Future<void>>{};

  static void markLoaded(String? family) {
    final normalized = family?.trim();
    if (normalized == null || normalized.isEmpty) return;
    _loadedFamilies.add(normalized);
  }

  static Future<void> ensureLoaded(InstalledFont font) {
    final family = font.fullName.trim();
    if (family.isEmpty ||
        _loadedFamilies.contains(family) ||
        _failedFamilies.contains(family)) {
      return Future<void>.value();
    }

    return _pendingLoads.putIfAbsent(family, () async {
      try {
        await FontLoaderHelper.loadFontFamily(
          familyName: family,
          fontPath: font.path,
        );
        _loadedFamilies.add(family);
      } catch (err, trace) {
        _failedFamilies.add(family);
        LOGGER.w('[font preview] load failed for $family: $err',
            stackTrace: trace);
      } finally {
        _pendingLoads.remove(family);
      }
    });
  }
}

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isMeshFlow =
        theme.effectiveWindowBackdropMode == WindowBackdropMode.meshFlow;

    final hint = isMeshFlow
        ? "弥散流彩由当前歌曲封面色彩实时驱动，手动选色在此模式下暂不生效。"
        : "手动选择强调色；对默认与水波纹仅影响 UI 按钮，对极光漫染可改变背景渐变。";

    return SettingsTile(
      description: "主题颜色",
      hint: hint,
      action: FilledButton.icon(
        onPressed: () async {
          if (isMeshFlow) {
            showTextOnSnackBar("弥散流彩模式由当前歌曲封面色彩实时驱动");
            return;
          }
          final seedColor = await showModernDialog<Color>(
            context: context,
            builder: (context) => const ThemePickerDialog(),
          );
          if (seedColor == null) return;

          AppSettings.instance.customTheme = seedColor.toARGB32();
          AppSettings.instance.defaultTheme = seedColor.toARGB32();
          AppSettings.instance.useSystemTheme = false;
          await ThemeProvider.instance.applyDynamicTheme(false);
          ThemeProvider.instance.applyTheme(seedColor: seedColor);
          await AppSettings.instance.saveSettings();
        },
        label: const Text("选择颜色"),
        icon: const Icon(Symbols.palette),
      ),
    );
  }
}

class ThemeModeControl extends StatefulWidget {
  const ThemeModeControl({super.key});

  @override
  State<ThemeModeControl> createState() => _ThemeModeControlState();
}

class _ThemeModeControlState extends State<ThemeModeControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final effectiveMode = theme.effectiveBrightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    return SettingsTile(
      description: "明暗模式",
      hint: settings.useSystemThemeMode
          ? "当前正在跟随系统明暗模式。手动切换将关闭跟随系统。"
          : "在明亮和夜间界面之间切换。",
      action: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<ThemeMode>(
            value: ThemeMode.light,
            icon: Icon(Symbols.light_mode),
            label: Text("浅色"),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.dark,
            icon: Icon(Symbols.dark_mode),
            label: Text("深色"),
          ),
        ],
        selected: {effectiveMode},
        onSelectionChanged: (newSelection) async {
          final selected = newSelection.first;
          setState(() {
            settings.useSystemThemeMode = false;
            settings.themeMode = selected;
          });
          ThemeProvider.instance.applyThemeMode(selected);
          await settings.saveSettings();
        },
      ),
    );
  }
}

class DynamicThemeSwitch extends StatelessWidget {
  const DynamicThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final settings = AppSettings.instance;

    return SettingsTile(
      description: "动态主题",
      hint: "使用当前封面色彩影响强调色与支持的背景材质。",
      action: Switch(
        value: settings.dynamicTheme,
        onChanged: (value) async {
          final prevMode = theme.effectiveWindowBackdropMode;
          if (value && settings.useSystemTheme) {
            settings.useSystemTheme = false;
            settings.defaultTheme = settings.customTheme;
            ThemeProvider.instance.applyTheme(
              seedColor: Color(settings.customTheme),
            );
          }
          await ThemeProvider.instance.applyDynamicTheme(value);
          if (!value &&
              prevMode == WindowBackdropMode.meshFlow &&
              context.mounted) {
            showTextOnSnackBar("已关闭动态主题，背景材质已自动切换为默认");
          }
          await settings.saveSettings();
        },
      ),
    );
  }
}

class LyricDepthBlurSwitch extends StatelessWidget {
  const LyricDepthBlurSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.lyricDepthBlurNotifier,
      builder: (context, enabled, _) => SettingsTile(
        description: "歌词景深模糊",
        hint: "模糊非当前歌词行，聚焦当前演唱内容。",
        action: Switch(
          value: enabled,
          onChanged: (value) async {
            settings.lyricDepthBlur = value;
            await settings.saveSettings();
          },
        ),
      ),
    );
  }
}

class WindowBackdropModeControl extends StatefulWidget {
  const WindowBackdropModeControl({super.key});

  @override
  State<WindowBackdropModeControl> createState() =>
      _WindowBackdropModeControlState();
}

class _WindowBackdropModeControlState extends State<WindowBackdropModeControl> {
  final settings = AppSettings.instance;
  WindowBackdropModeResult? _latestResult = WindowControls.lastBackdropResult;

  String _modeLabel(String mode) {
    return switch (WindowBackdropMode.fromName(mode)) {
      WindowBackdropMode.defaultGradient => "默认",
      WindowBackdropMode.micaAlt => "增强云母",
      WindowBackdropMode.acrylic => "亚克力",
      WindowBackdropMode.meshFlow => "弥散流彩",
      WindowBackdropMode.waterRipple => "水波纹",
      WindowBackdropMode.prismaticGlass => "极光漫染",
      null => mode,
    };
  }

  String _fallbackLabel(String? value) {
    return switch (value) {
      null => "",
      "empty_platform_response" => "平台没有返回结果",
      "platform_exception" => "平台通道调用失败",
      "unsupported_platform" => "系统不支持原生背景材质",
      "system_backdrop_requires_windows_11" => "需要 Windows 11",
      "system_backdrop_requires_win11_22h2" => "需要 Windows 11 22H2 及以上版本",
      "mica_alt_not_supported" => "当前系统不支持增强云母",
      "acrylic_not_supported" => "当前系统不支持亚克力",
      "native_backdrop_not_supported" => "系统不支持该原生材质",
      "window_handle_unavailable" => "窗口句柄不可用",
      final other => other,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final result = _latestResult ??
        theme.windowBackdropResult ??
        WindowBackdropModeResult.fallback(
          theme.windowBackdropMode,
          appliedMode: theme.windowBackdropMode,
          nativeBackdropSupported: false,
          fallbackReason: 'unknown',
        );
    final effectiveModeLabel = _modeLabel(result.appliedMode.name);
    final fallbackText = _fallbackLabel(result.fallbackReason);
    final fallbackHint = fallbackText.isEmpty ? '' : '，回退原因：$fallbackText';
    return SettingsTile(
      description: "窗口底座材质",
      hint: "包含默认、弥散流彩、水波纹与极光漫染。当前实际模式：$effectiveModeLabel$fallbackHint",
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildBackdropChip(WindowBackdropMode.defaultGradient, "默认"),
          _buildBackdropChip(WindowBackdropMode.meshFlow, "弥散流彩"),
          _buildBackdropChip(WindowBackdropMode.waterRipple, "水波纹"),
          _buildBackdropChip(WindowBackdropMode.prismaticGlass, "极光漫染"),
        ],
      ),
    );
  }

  Widget _buildBackdropChip(WindowBackdropMode mode, String label) {
    final theme = context.watch<ThemeProvider>();
    final isSelected = theme.windowBackdropMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) async {
        if (!selected || mode == theme.windowBackdropMode) return;
        final result = await ThemeProvider.instance.applyWindowBackdropMode(
          mode,
        );
        setState(() {
          settings.windowBackdropMode = mode;
          _latestResult = result;
        });
        await settings.saveSettings();
        if (result.appliedMode != mode && mounted) {
          showTextOnSnackBar(
            "背景材质已从 ${_modeLabel(mode.name)} 回退为 ${_modeLabel(result.appliedMode.name)}",
          );
        }
      },
    );
  }
}

class UseSystemThemeSwitch extends StatefulWidget {
  const UseSystemThemeSwitch({super.key});

  @override
  State<UseSystemThemeSwitch> createState() => _UseSystemThemeSwitchState();
}

class _UseSystemThemeSwitchState extends State<UseSystemThemeSwitch> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isMeshFlow =
        theme.effectiveWindowBackdropMode == WindowBackdropMode.meshFlow;

    final isPrismaticGlass =
        theme.effectiveWindowBackdropMode == WindowBackdropMode.prismaticGlass;

    final hint = isMeshFlow
        ? "弥散流彩由当前歌曲封面色彩实时驱动，系统主题色在此模式下暂不生效。"
        : "读取系统强调色作为应用主题来源。";

    return SettingsTile(
      description: "启动时使用系统主题色",
      hint: hint,
      action: Switch(
        value: isMeshFlow ? false : settings.useSystemTheme,
        onChanged: (value) async {
          if (isMeshFlow) {
            showTextOnSnackBar("弥散流彩模式由当前歌曲封面色彩实时驱动");
            return;
          }
          setState(() {
            settings.useSystemTheme = value;
          });
          if (value) {
            final sysTheme = AppSettings.getWindowsTheme();
            settings.defaultTheme = sysTheme;
            if (isPrismaticGlass) {
              await ThemeProvider.instance.applyDynamicTheme(false);
            } else {
              ThemeProvider.instance.applyTheme(seedColor: Color(sysTheme));
            }
            showTextOnSnackBar("已应用系统主题色");
          } else {
            settings.defaultTheme = settings.customTheme;
            if (isPrismaticGlass) {
              ThemeProvider.instance.applyTheme(
                seedColor: Color(settings.customTheme),
              );
              await ThemeProvider.instance.applyDynamicTheme(true);
              showTextOnSnackBar("已恢复动态取色");
            } else {
              ThemeProvider.instance.applyTheme(
                seedColor: Color(settings.customTheme),
              );
              showTextOnSnackBar("已恢复自定义主题色");
            }
          }
          await settings.saveSettings();
        },
      ),
    );
  }
}

class UseSystemThemeModeSwitch extends StatefulWidget {
  const UseSystemThemeModeSwitch({super.key});

  @override
  State<UseSystemThemeModeSwitch> createState() =>
      _UseSystemThemeModeSwitchState();
}

class _UseSystemThemeModeSwitchState extends State<UseSystemThemeModeSwitch> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return SettingsTile(
      description: "使用系统明暗模式",
      hint: "跟随系统明暗模式设置。",
      action: Switch(
        value: settings.useSystemThemeMode,
        onChanged: (value) async {
          setState(() {
            settings.useSystemThemeMode = value;
          });
          if (value) {
            settings.themeMode = ThemeMode.system;
            ThemeProvider.instance.applyThemeMode(ThemeMode.system);
            showTextOnSnackBar("已开启跟随系统明暗模式");
          } else {
            final currentMode =
                ThemeProvider.instance.effectiveBrightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light;
            settings.themeMode = currentMode;
            ThemeProvider.instance.applyThemeMode(currentMode);
          }
          await settings.saveSettings();
        },
      ),
    );
  }
}

class _FontSelectorResult {
  const _FontSelectorResult({
    this.font,
    this.isImported = false,
    this.resetToDefault = false,
    this.useFamilyName = false,
    this.familyName,
  });

  final InstalledFont? font;
  final bool isImported;
  final bool resetToDefault;
  final bool useFamilyName;
  final String? familyName;
}

class SelectFontCombobox extends StatelessWidget {
  const SelectFontCombobox({super.key});

  @visibleForTesting
  static List<InstalledFont>? cachedSystemFonts;
  @visibleForTesting
  static List<InstalledFont>? cachedImportedFonts;
  @visibleForTesting
  static bool isSelecting = false;
  @visibleForTesting
  static bool isImporting = false;
  @visibleForTesting
  static bool isResetting = false;

  Future<void> _applyFont(
    BuildContext context,
    InstalledFont font, {
    bool isImported = false,
    String? overrideFamilyName,
  }) async {
    final settings = AppSettings.instance;
    final effectiveFamily = overrideFamilyName ?? font.fullName;
    final isAlreadyActive = ThemeProvider.instance.fontFamily == effectiveFamily &&
        settings.fontFamily == effectiveFamily &&
        settings.fontPath == font.path;
    if (isAlreadyActive) {
      showTextOnSnackBar("当前已使用该字体");
      return;
    }

    try {
      await FontLoaderHelper.loadFontFamily(
        familyName: effectiveFamily,
        fontPath: font.path,
      );
      _FontPreviewRegistry.markLoaded(effectiveFamily);
    } catch (err, trace) {
      LOGGER.w('[font] dynamic font loader failed: $err', stackTrace: trace);
    }
    ThemeProvider.instance.changeFontFamily(effectiveFamily);

    settings.fontFamily = effectiveFamily;
    settings.fontPath = font.path;
    await settings.saveSettings();
    showTextOnSnackBar("已应用字体：$effectiveFamily");
  }

  Future<void> _resetToDefaultFont() async {
    if (isResetting) return;
    isResetting = true;
    try {
      final settings = AppSettings.instance;
      final isAlreadyDefault = ThemeProvider.instance.fontFamily == null &&
          settings.fontFamily == null &&
          settings.fontPath == null;
      if (isAlreadyDefault) {
        showTextOnSnackBar("当前已是默认字体");
        return;
      }
      ThemeProvider.instance.changeFontFamily(null);
      settings.fontFamily = null;
      settings.fontPath = null;
      await settings.saveSettings();
      showTextOnSnackBar("已恢复使用默认字体");
    } finally {
      isResetting = false;
    }
  }

  Future<List<InstalledFont>> _loadImportedFonts() async {
    if (cachedImportedFonts != null) {
      return cachedImportedFonts!;
    }
    final list = <InstalledFont>[];
    try {
      final appDir = await getAppDataDir();
      final fontsDir =
          Directory(path.join(appDir.path, 'fonts'));
      if (await fontsDir.exists()) {
        final entities = fontsDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final ext = path.extension(entity.path).toLowerCase();
            if (ext == '.ttf' || ext == '.otf' || ext == '.ttc') {
              final font = await inspectFontFile(path: entity.path);
              if (font != null) {
                list.add(font);
              }
            }
          }
        }
      }
      cachedImportedFonts = list;
    } catch (err, trace) {
      LOGGER.w('[imported fonts] load error: $err', stackTrace: trace);
    }
    return list;
  }

  Future<void> _selectFont(BuildContext context) async {
    if (isSelecting) {
      return;
    }
    isSelecting = true;
    try {
      final importedFonts = await _loadImportedFonts();
      cachedSystemFonts ??= (await getInstalledFonts()) ?? <InstalledFont>[];
      final systemFonts = cachedSystemFonts!;

      if (!context.mounted) {
        return;
      }
      final result = await showModernDialog<_FontSelectorResult>(
        context: context,
        builder: (context) => _FontSelector(
          importedFonts: importedFonts,
          systemFonts: systemFonts,
        ),
      );
      if (result == null || !context.mounted) return;

      if (result.resetToDefault) {
        await _resetToDefaultFont();
      } else if (result.font != null) {
        await _applyFont(
          context,
          result.font!,
          isImported: result.isImported,
          overrideFamilyName: result.useFamilyName ? result.familyName : null,
        );
      }
    } finally {
      isSelecting = false;
    }
  }

  Future<void> _importFont(BuildContext context) async {
    if (isImporting) return;
    isImporting = true;
    try {
      final picker = OpenFilePicker()
        ..title = "添加字体"
        ..filterSpecification = {
          "字体文件 (*.ttf;*.otf;*.ttc)": "*.ttf;*.otf;*.ttc",
          "所有文件 (*.*)": "*.*",
        };
      final source = picker.getFile();
      if (source == null) return;

      final inspected = await inspectFontFile(path: source.path);
      if (inspected == null) {
        throw const FormatException("无法识别该字体文件，请确保格式为 TTF、OTF 或 TTC");
      }

      final bytes = await source.readAsBytes();
      final fontsDir = Directory(
        path.join((await getAppDataDir()).path, 'fonts'),
      );
      await fontsDir.create(recursive: true);
      final extension = path.extension(source.path).toLowerCase();
      final managedPath = path.join(
        fontsDir.path,
        '${sha256.convert(bytes)}$extension',
      );
      final managedFile = File(managedPath);
      if (!await managedFile.exists()) {
        await managedFile.writeAsBytes(bytes, flush: true);
      }

      final managedFont = await inspectFontFile(path: managedPath);
      if (managedFont == null) {
        if (await managedFile.exists()) {
          await managedFile.delete();
        }
        throw const FormatException("字体文件复制后校验失败");
      }
      if (!context.mounted) return;
      cachedImportedFonts = null;
      await _applyFont(context, managedFont, isImported: true);
      showTextOnSnackBar("已添加并应用字体：${managedFont.fullName}");
    } finally {
      isImporting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final hasCustomFont = theme.fontFamily != null;

    return SettingsTile(
      description: "自定义字体",
      hint: hasCustomFont
          ? "当前字体：${theme.fontFamily}。应用到页面标题、正文和播放控件文本。"
          : "应用到页面标题、正文和播放控件文本。",
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () async {
              try {
                await _selectFont(context);
              } catch (err, trace) {
                // ignore: avoid_print
                print('CAUGHT IN BUTTON: $err\n$trace');
                LOGGER.e("[select font] $err", stackTrace: trace);
                showTextOnSnackBar(err.toString());
              }
            },
            label: const Text("选择字体"),
            icon: const Icon(Symbols.text_fields),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await _importFont(context);
              } catch (err, trace) {
                LOGGER.e("[import font] $err", stackTrace: trace);
                showTextOnSnackBar(err.toString());
              }
            },
            label: const Text("添加字体"),
            icon: const Icon(Symbols.add),
          ),
          if (hasCustomFont)
            TextButton.icon(
              onPressed: () async {
                await _resetToDefaultFont();
              },
              label: const Text("恢复默认"),
              icon: const Icon(Symbols.restart_alt),
            ),
        ],
      ),
    );
  }
}

class FontVariant {
  const FontVariant({
    required this.font,
    required this.styleName,
    required this.weight,
    this.isItalic = false,
    this.isImported = false,
  });

  final InstalledFont font;
  final String styleName;
  final int weight;
  final bool isItalic;
  final bool isImported;

  FontWeight get fontWeight {
    final lower = styleName.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
    if (lower == 'regular' || lower == 'normal' || lower == 'book' || lower == '常规') {
      return FontWeight.w400;
    }
    if (lower == 'thin' || lower == 'hairline' || lower == '极细') {
      return FontWeight.w100;
    }
    if (lower == 'extralight' || lower == 'ultralight' || lower == '特细') {
      return FontWeight.w200;
    }
    if (lower == 'light' || lower == '细体') {
      return FontWeight.w300;
    }
    if (lower == 'medium' || lower == '中黑') {
      return FontWeight.w500;
    }
    if (lower == 'semibold' || lower == 'demibold' || lower == '半粗') {
      return FontWeight.w600;
    }
    if (lower == 'bold' || lower == '粗体') {
      return FontWeight.w700;
    }
    if (lower == 'extrabold' || lower == 'ultrabold' || lower == '特粗') {
      return FontWeight.w800;
    }
    if (lower == 'black' || lower == 'heavy' || lower == '黑体') {
      return FontWeight.w900;
    }

    if (weight <= 150) return FontWeight.w100;
    if (weight <= 250) return FontWeight.w200;
    if (weight <= 350) return FontWeight.w300;
    if (weight <= 450) return FontWeight.w400;
    if (weight <= 550) return FontWeight.w500;
    if (weight <= 650) return FontWeight.w600;
    if (weight <= 750) return FontWeight.w700;
    if (weight <= 850) return FontWeight.w800;
    return FontWeight.w900;
  }

  String get displayStyleName {
    final s = styleName.trim();
    if (s.isEmpty) {
      return _weightToLabel(weight, isItalic);
    }
    final lower = s.toLowerCase();
    if (lower == 'regular') return '常规 Regular';
    if (lower == 'bold') return '粗体 Bold';
    if (lower == 'italic') return '斜体 Italic';
    if (lower == 'bold italic') return '粗斜体 Bold Italic';
    if (lower == 'light') return '细体 Light';
    if (lower == 'extralight' || lower == 'extra light' || lower == 'extra-light') return '特细 ExtraLight';
    if (lower == 'thin') return '极细 Thin';
    if (lower == 'medium') return '中黑 Medium';
    if (lower == 'semibold' || lower == 'semi bold' || lower == 'semi-bold') return '半粗 SemiBold';
    if (lower == 'extrabold' || lower == 'extra bold' || lower == 'extra-bold') return '特粗 ExtraBold';
    if (lower == 'black' || lower == 'heavy') return '黑体 Heavy/Black';
    return s;
  }

  static String _weightToLabel(int weight, bool isItalic) {
    String label;
    if (weight <= 150) {
      label = '极细 Thin';
    } else if (weight <= 250) {
      label = '特细 ExtraLight';
    } else if (weight <= 350) {
      label = '细体 Light';
    } else if (weight <= 450) {
      label = '常规 Regular';
    } else if (weight <= 550) {
      label = '中黑 Medium';
    } else if (weight <= 650) {
      label = '半粗 SemiBold';
    } else if (weight <= 750) {
      label = '粗体 Bold';
    } else if (weight <= 850) {
      label = '特粗 ExtraBold';
    } else {
      label = '黑体 Heavy';
    }
    return isItalic ? '$label 斜体' : label;
  }
}

class FontFamilyGroup {
  const FontFamilyGroup({
    required this.familyName,
    required this.isImported,
    required this.variants,
  });

  final String familyName;
  final bool isImported;
  final List<FontVariant> variants;

  bool get hasMultipleWeights => variants.length > 1;

  FontVariant get primaryVariant {
    for (final v in variants) {
      if (!v.isItalic) {
        final s = v.styleName.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
        if (s == 'regular' || s == 'normal' || s == 'book' || s == '常规') {
          return v;
        }
      }
    }
    for (final v in variants) {
      if (!v.isItalic && (v.fontWeight == FontWeight.w400 || (v.weight >= 350 && v.weight <= 450))) {
        return v;
      }
    }
    for (final v in variants) {
      if (!v.isItalic) return v;
    }
    return variants.first;
  }
}

String _extractFamilyFallback(String fullName) {
  final patterns = [
    RegExp(
      r'\s+(Regular|Bold\s+Italic|Bold|Italic|Light|Medium|Black|Heavy|Thin|SemiBold|ExtraLight|ExtraBold|DemiBold|常规|粗体|细体|粗斜体)$',
      caseSensitive: false,
    ),
  ];
  for (final p in patterns) {
    if (p.hasMatch(fullName)) {
      final stripped = fullName.replaceAll(p, '').trim();
      if (stripped.isNotEmpty) return stripped;
    }
  }
  return fullName;
}

String _extractStyleFallback(String fullName) {
  final lower = fullName.toLowerCase();
  if (lower.contains('bold italic')) return 'Bold Italic';
  if (lower.contains('bold') || lower.contains('粗体')) return 'Bold';
  if (lower.contains('italic') || lower.contains('斜体')) return 'Italic';
  if (lower.contains('light') || lower.contains('细体')) return 'Light';
  if (lower.contains('medium') || lower.contains('中黑')) return 'Medium';
  if (lower.contains('black') || lower.contains('heavy') || lower.contains('黑体')) return 'Black';
  if (lower.contains('thin') || lower.contains('极细')) return 'Thin';
  if (lower.contains('extralight') || lower.contains('特细')) return 'ExtraLight';
  if (lower.contains('semibold') || lower.contains('半粗')) return 'SemiBold';
  return 'Regular';
}

int _extractWeightFallback(String fullName, String style) {
  final combined = '$fullName $style'.toLowerCase();
  if (combined.contains('thin') || combined.contains('极细')) return 100;
  if (combined.contains('extralight') || combined.contains('extra light') || combined.contains('特细')) return 200;
  if (combined.contains('light') || combined.contains('细体')) return 300;
  if (combined.contains('medium') || combined.contains('中黑')) return 500;
  if (combined.contains('semibold') || combined.contains('semi bold') || combined.contains('半粗')) return 600;
  if (combined.contains('extrabold') || combined.contains('extra bold') || combined.contains('特粗')) return 800;
  if (combined.contains('black') || combined.contains('heavy') || combined.contains('黑体')) return 900;
  if (combined.contains('bold') || combined.contains('粗体')) return 700;
  return 400;
}

List<FontFamilyGroup> _groupFonts(List<InstalledFont> fonts, {required bool isImported}) {
  final Map<String, List<FontVariant>> map = {};

  for (final font in fonts) {
    final family = (font.familyName != null && font.familyName!.trim().isNotEmpty)
        ? font.familyName!.trim()
        : _extractFamilyFallback(font.fullName);

    final style = (font.styleName != null && font.styleName!.trim().isNotEmpty)
        ? font.styleName!.trim()
        : _extractStyleFallback(font.fullName);

    final weight = (font.weight != null && font.weight! > 0)
        ? font.weight!
        : _extractWeightFallback(font.fullName, style);

    final isItalic = font.isItalic ?? font.fullName.toLowerCase().contains('italic');

    final variant = FontVariant(
      font: font,
      styleName: style,
      weight: weight,
      isItalic: isItalic,
      isImported: isImported,
    );

    map.putIfAbsent(family, () => []).add(variant);
  }

  final groups = <FontFamilyGroup>[];
  for (final entry in map.entries) {
    final sortedVariants = List<FontVariant>.from(entry.value);
    sortedVariants.sort((a, b) {
      if (a.isItalic != b.isItalic) {
        return a.isItalic ? 1 : -1;
      }
      final w = a.weight.compareTo(b.weight);
      if (w != 0) return w;
      return a.font.fullName.compareTo(b.font.fullName);
    });

    final uniqueVariants = <FontVariant>[];
    final seen = <String>{};
    for (final v in sortedVariants) {
      final key = '${v.font.fullName}_${v.weight}_${v.isItalic}';
      if (seen.add(key)) {
        uniqueVariants.add(v);
      }
    }

    groups.add(FontFamilyGroup(
      familyName: entry.key,
      isImported: isImported,
      variants: uniqueVariants,
    ));
  }

  groups.sort((a, b) => a.familyName.localeCompareTo(b.familyName));
  return groups;
}

bool _matchesGroup(FontFamilyGroup group, String query) {
  if (query.isEmpty) return true;
  if (group.familyName.toLowerCase().contains(query)) return true;
  try {
    if (group.familyName.toLocaleSortKey().contains(query)) return true;
  } catch (_) {}
  for (final v in group.variants) {
    if (v.font.fullName.toLowerCase().contains(query)) return true;
    if (v.displayStyleName.toLowerCase().contains(query)) return true;
    if (v.styleName.toLowerCase().contains(query)) return true;
    if ('${v.weight}'.contains(query)) return true;
  }
  return false;
}

class _FontSelector extends StatefulWidget {
  const _FontSelector({
    required this.importedFonts,
    required this.systemFonts,
  });

  final List<InstalledFont> importedFonts;
  final List<InstalledFont> systemFonts;

  @override
  State<_FontSelector> createState() => _FontSelectorState();
}

class _FontSelectorState extends State<_FontSelector> {
  late final TextEditingController _searchController;
  late List<InstalledFont> _importedFonts;
  String _filter = '';
  bool _isPopping = false;
  FontFamilyGroup? _activeFamily;

  void _popWithResult([_FontSelectorResult? result]) {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    Navigator.of(context).pop(result);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _importedFonts = List.from(widget.importedFonts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TextStyle _previewStyle(
    String? family,
    Color color, {
    String? fallbackFamily,
    double size = 15,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: [
        if (fallbackFamily != null &&
            fallbackFamily.isNotEmpty &&
            fallbackFamily != family)
          fallbackFamily,
        ...AppTheme.fallbackList,
      ],
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle _variantPreviewStyle(
    FontVariant variant,
    String fallbackFamily,
    Color color, {
    String? previewFamily,
    double size = 15,
  }) {
    final primaryFamily = variant.isImported
        ? previewFamily
        : (variant.font.familyName ?? variant.font.fullName);
    return TextStyle(
      fontFamily: primaryFamily,
      fontFamilyFallback: [
        if (variant.font.fullName.isNotEmpty &&
            variant.font.fullName != primaryFamily)
          variant.font.fullName,
        if (variant.font.familyName != null &&
            variant.font.familyName!.isNotEmpty &&
            variant.font.familyName != primaryFamily)
          variant.font.familyName!,
        if (fallbackFamily.isNotEmpty && fallbackFamily != primaryFamily)
          fallbackFamily,
        ...AppTheme.fallbackList,
      ],
      fontWeight: variant.fontWeight,
      fontStyle: variant.isItalic ? FontStyle.italic : FontStyle.normal,
      color: color,
      fontSize: size,
    );
  }

  Future<void> _deleteImportedFont(InstalledFont font) async {
    try {
      final file = File(font.path);
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        _importedFonts.removeWhere((f) => f.path == font.path);
        if (_activeFamily != null) {
          final updatedVariants = _activeFamily!.variants
              .where((v) => v.font.path != font.path)
              .toList();
          if (updatedVariants.isEmpty) {
            _activeFamily = null;
          } else {
            _activeFamily = FontFamilyGroup(
              familyName: _activeFamily!.familyName,
              isImported: _activeFamily!.isImported,
              variants: updatedVariants,
            );
          }
        }
      });
      if (AppSettings.instance.fontFamily == font.fullName) {
        AppSettings.instance.fontFamily = null;
        AppSettings.instance.fontPath = null;
        ThemeProvider.instance.changeFontFamily(null);
        await AppSettings.instance.saveSettings();
      }
      showTextOnSnackBar("已删除字体：${font.fullName}");
    } catch (err) {
      showTextOnSnackBar("删除字体失败: $err");
    }
  }

  Future<void> _deleteImportedFamily(FontFamilyGroup family) async {
    try {
      for (final v in family.variants) {
        final file = File(v.font.path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        final paths = family.variants.map((v) => v.font.path).toSet();
        _importedFonts.removeWhere((f) => paths.contains(f.path));
        if (_activeFamily?.familyName == family.familyName) {
          _activeFamily = null;
        }
      });
      if (family.variants.any((v) => v.font.fullName == AppSettings.instance.fontFamily)) {
        AppSettings.instance.fontFamily = null;
        AppSettings.instance.fontPath = null;
        ThemeProvider.instance.changeFontFamily(null);
        await AppSettings.instance.saveSettings();
      }
      showTextOnSnackBar("已删除字体族：${family.familyName}");
    } catch (err) {
      showTextOnSnackBar("删除字体族失败: $err");
    }
  }

  Widget _buildSecondaryMenu(
    BuildContext context,
    ColorScheme scheme,
    ThemeProvider theme,
    FontFamilyGroup family,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: "返回字体列表",
              icon: Icon(
                Symbols.arrow_back,
                size: 20,
                color: scheme.onSurface,
              ),
              onPressed: () => setState(() => _activeFamily = null),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.familyName,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "选择粗细字重规格（共 ${family.variants.length} 种）",
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: scheme.brightness == Brightness.dark ? 0.82 : 0.92,
                      ),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: "关闭",
              icon: Icon(
                Symbols.close_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () => _popWithResult(null),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              type: MaterialType.transparency,
              child: ListView.separated(
                itemCount: family.variants.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final variant = family.variants[index];
                  final isCurrent = variant.font.fullName == theme.fontFamily;

                  Widget tileContent(String? previewFamily) {
                    return ListTile(
                      enableFeedback: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      leading: Container(
                        width: 46,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? scheme.primary.withValues(alpha: 0.16)
                              : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: isCurrent
                              ? Border.all(color: scheme.primary, width: 1.2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            "${variant.weight}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            variant.displayStyleName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isCurrent ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          if (variant.isItalic) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "斜体",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "AaBbCc 永和九年 岁在癸丑 123",
                          style: _variantPreviewStyle(
                            variant,
                            family.familyName,
                            scheme.onSurface.withValues(alpha: 0.88),
                            previewFamily: previewFamily,
                            size: 15,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: scheme.primary,
                            ),
                          if (variant.isImported)
                            IconButton(
                              tooltip: "删除该规格",
                              icon: Icon(
                                Symbols.delete_outline,
                                size: 18,
                                color: scheme.error,
                              ),
                              onPressed: () => _deleteImportedFont(variant.font),
                            ),
                        ],
                      ),
                      onTap: () => _popWithResult(
                        _FontSelectorResult(
                          font: variant.font,
                          isImported: variant.isImported,
                        ),
                      ),
                    );
                  }

                  if (variant.isImported) {
                    return FutureBuilder<void>(
                      future: _FontPreviewRegistry.ensureLoaded(variant.font),
                      builder: (context, snapshot) {
                        final previewFamily =
                            snapshot.hasError ? null : variant.font.fullName;
                        return tileContent(previewFamily);
                      },
                    );
                  }
                  return tileContent(variant.font.fullName);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        LayoutBuilder(
          builder: (context, constraints) {
            final backButton = TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Symbols.arrow_back, size: 16),
              label: const Text("返回字体列表"),
              onPressed: () => setState(() => _activeFamily = null),
            );

            final actionButtons = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Symbols.auto_awesome, size: 16),
                  label: const Text("应用全字重家族"),
                  onPressed: () => _popWithResult(
                    _FontSelectorResult(
                      font: family.primaryVariant.font,
                      isImported: family.isImported,
                      useFamilyName: true,
                      familyName: family.familyName,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _popWithResult(null),
                  child: const Text("取消"),
                ),
              ],
            );

            if (constraints.maxWidth < 360) {
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  backButton,
                  actionButtons,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                backButton,
                actionButtons,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrimaryMenu(
    BuildContext context,
    ColorScheme scheme,
    ThemeProvider theme,
    String query,
    List<FontFamilyGroup> filteredImported,
    List<FontFamilyGroup> filteredSystem,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Symbols.text_fields,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "选择字体",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '当前字体：${theme.fontFamily ?? "系统默认"}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: scheme.brightness == Brightness.dark ? 0.82 : 0.92,
                      ),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: "关闭",
              icon: Icon(
                Symbols.close_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () => _popWithResult(null),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "搜索字体...",
            prefixIcon: const Icon(Symbols.search, size: 18),
            suffixIcon: _filter.isNotEmpty
                ? IconButton(
                    icon: const Icon(Symbols.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _filter = '');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (val) {
            setState(() => _filter = val);
          },
        ),
        const SizedBox(height: 12.0),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              type: MaterialType.transparency,
              child: CustomScrollView(
                slivers: [
                  if (query.isEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            enableFeedback: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            leading: Icon(
                              Symbols.font_download,
                              color: theme.fontFamily == null
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            title: const Text("系统默认字体"),
                            subtitle: const Text(
                              "恢复使用系统与播放器默认字体（MiSans / 微软雅黑等）",
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: theme.fontFamily == null
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  )
                                : null,
                            onTap: () => _popWithResult(
                              const _FontSelectorResult(resetToDefault: true),
                            ),
                          ),
                          const Divider(height: 16),
                        ],
                      ),
                    ),
                  if (filteredImported.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          "项目字体库（已导入 ${filteredImported.length} 组）",
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: filteredImported.length,
                      itemBuilder: (context, index) {
                        final family = filteredImported[index];
                        return _buildFamilyTile(
                          context,
                          scheme,
                          theme,
                          family,
                          isImported: true,
                        );
                      },
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 16),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        "系统已有字体（${filteredSystem.length} 组）",
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: filteredSystem.length,
                    itemBuilder: (context, index) {
                      final family = filteredSystem[index];
                      return _buildFamilyTile(
                        context,
                        scheme,
                        theme,
                        family,
                        isImported: false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => _popWithResult(null),
              child: const Text("取消"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyTile(
    BuildContext context,
    ColorScheme scheme,
    ThemeProvider theme,
    FontFamilyGroup family, {
    required bool isImported,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final isCurrentFamily = family.variants.any((v) => v.font.fullName == theme.fontFamily);
    final activeVariant = isCurrentFamily
        ? family.variants.firstWhere((v) => v.font.fullName == theme.fontFamily)
        : null;

    Widget renderContent(String? previewFamily) {
      String subtitleText;
      if (family.hasMultipleWeights) {
        if (isCurrentFamily && activeVariant != null) {
          subtitleText = "当前已选：${activeVariant.displayStyleName} · 共 ${family.variants.length} 种粗细规格";
        } else {
          subtitleText = "共 ${family.variants.length} 种粗细规格 · 点击展开选择粗细";
        }
      } else {
        subtitleText = isImported
            ? "已导入字体 · AaBbCc 你好 123"
            : "AaBbCc 你好 123";
      }

      return ListTile(
        enableFeedback: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        title: Text(
          family.familyName,
          style: _previewStyle(
            previewFamily,
            scheme.onSurface,
            fallbackFamily: family.primaryVariant.font.fullName,
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: _previewStyle(
            previewFamily,
            scheme.onSurface.withValues(alpha: isDark ? 0.78 : 0.88),
            fallbackFamily: family.primaryVariant.font.fullName,
            size: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentFamily && !family.hasMultipleWeights)
              Icon(
                Icons.check_rounded,
                size: 18,
                color: scheme.primary,
              ),
            if (family.hasMultipleWeights) ...[
              if (isCurrentFamily) ...[
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${family.variants.length} 种粗细",
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Symbols.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
            if (isImported)
              IconButton(
                tooltip: "删除字体",
                icon: Icon(
                  Symbols.delete_outline,
                  size: 18,
                  color: scheme.error,
                ),
                onPressed: () => _deleteImportedFamily(family),
              ),
          ],
        ),
        onTap: () {
          if (family.hasMultipleWeights) {
            setState(() => _activeFamily = family);
          } else {
            _popWithResult(
              _FontSelectorResult(
                font: family.primaryVariant.font,
                isImported: isImported,
              ),
            );
          }
        },
      );
    }

    if (isImported) {
      return FutureBuilder<void>(
        future: _FontPreviewRegistry.ensureLoaded(family.primaryVariant.font),
        builder: (context, snapshot) {
          final previewFamily =
              snapshot.hasError ? null : family.primaryVariant.font.fullName;
          return renderContent(previewFamily);
        },
      );
    }
    return renderContent(
      family.primaryVariant.font.familyName ??
          family.primaryVariant.font.fullName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.instance;
    final scheme = Theme.of(context).colorScheme;
    _FontPreviewRegistry.markLoaded(theme.fontFamily);

    final query = _filter.trim().toLowerCase();
    final importedGroups = _groupFonts(_importedFonts, isImported: true);
    final systemGroups = _groupFonts(widget.systemFonts, isImported: false);

    final filteredImported = importedGroups.where((g) => _matchesGroup(g, query)).toList();
    final filteredSystem = systemGroups.where((g) => _matchesGroup(g, query)).toList();

    return PopScope(
      canPop: _isPopping || _activeFamily == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_activeFamily != null) {
          setState(() {
            _isPopping = false;
            _activeFamily = null;
          });
        }
      },
      child: ModernDialogFrame(
        maxWidth: 500.0,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: SizedBox(
          height: 520,
          child: _activeFamily != null
              ? _buildSecondaryMenu(context, scheme, theme, _activeFamily!)
              : _buildPrimaryMenu(
                  context,
                  scheme,
                  theme,
                  query,
                  filteredImported,
                  filteredSystem,
                ),
        ),
      ),
    );
  }
}

class BackgroundImageSettings extends StatefulWidget {
  const BackgroundImageSettings({super.key});

  @override
  State<BackgroundImageSettings> createState() =>
      _BackgroundImageSettingsState();
}

class _BackgroundImageSettingsState extends State<BackgroundImageSettings> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    final hasBackground = settings.backgroundImagePath != null &&
        settings.backgroundImagePath!.isNotEmpty;

    return Column(
      children: [
        SettingsTile(
          description: "自定义背景",
          hint: "选择图片作为背景，已开启独立壁纸渲染与文字高对比度保真保护。",
          action: Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final picker = OpenFilePicker()
                    ..title = "选择背景图片"
                    ..filterSpecification = {
                      "图片": "*.png;*.jpg;*.jpeg;*.bmp;*.webp",
                    };
                  final file = picker.getFile();
                  if (file == null) return;

                  setState(() {
                    settings.backgroundImagePath = file.path;
                  });
                  settings.notifyBackgroundChanged();
                  await settings.saveSettings();
                },
                icon: const Icon(Symbols.image),
                label: Text(hasBackground ? "更换背景" : "选择背景"),
              ),
              FilledButton.tonalIcon(
                onPressed: hasBackground
                    ? () async {
                        setState(() {
                          settings.backgroundImagePath = null;
                        });
                        settings.notifyBackgroundChanged();
                        await settings.saveSettings();
                      }
                    : null,
                icon: const Icon(Symbols.delete),
                label: const Text("清除"),
              ),
            ],
          ),
        ),
        SettingsTile(
          description: "背景透明度",
          hint: "支持 30% - 100% 调节。高透明度下已自动启用文字保真保护。",
          action: SizedBox(
            width: 260,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0.3,
                    max: 1.0,
                    value: settings.backgroundImageOpacity.clamp(0.3, 1.0),
                    onChanged: hasBackground
                        ? (value) async {
                            setState(() {
                              settings.backgroundImageOpacity = value;
                            });
                            settings.notifyBackgroundChanged();
                            await settings.saveSettings();
                          }
                        : null,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    "${(settings.backgroundImageOpacity.clamp(0.3, 1.0) * 100).round()}%",
                    textAlign: TextAlign.end,
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProgressBarTypeControl extends StatelessWidget {
  const ProgressBarTypeControl({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressBarType>(
      valueListenable: AppSettings.instance.progressBarTypeNotifier,
      builder: (context, currentType, _) {
        return SettingsTile(
          description: "音频进度条样式",
          hint: currentType.description,
          action: SegmentedButton<ProgressBarType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<ProgressBarType>(
                value: ProgressBarType.fluidGlow,
                icon: Icon(Symbols.linear_scale),
                label: Text("流体微光"),
              ),
              ButtonSegment<ProgressBarType>(
                value: ProgressBarType.adaptiveWaveform,
                icon: Icon(Symbols.graphic_eq),
                label: Text("动态声波"),
              ),
              ButtonSegment<ProgressBarType>(
                value: ProgressBarType.dualLayerRhythm,
                icon: Icon(Symbols.blur_on),
                label: Text("灵动呼吸"),
              ),
            ],
            selected: {currentType},
            onSelectionChanged: (newSelection) {
              final selected = newSelection.first;
              AppSettings.instance.progressBarType = selected;
            },
          ),
        );
      },
    );
  }
}

class UiScaleControl extends StatelessWidget {
  const UiScaleControl({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final currentScale = theme.uiScale;
    final percent = (currentScale * 100).round();
    final String tag = switch (percent) {
      100 => '标准',
      115 || 125 => '推荐',
      150 => '高分屏',
      _ => '',
    };
    final displayLabel = tag.isNotEmpty ? '$percent% ($tag)' : '$percent%';

    final isDefault = (currentScale - 1.0).abs() < 0.005;

    return SettingsTile(
      description: "界面缩放 / UI Scale",
      hint: "当前缩放：$displayLabel。弹窗选择缩放比例，包含下拉菜单与屏幕推荐档位。",
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            icon: const Icon(Symbols.aspect_ratio_rounded),
            label: Text("$displayLabel · 配置缩放"),
            onPressed: () => showUiScaleDialog(context),
          ),
          if (!isDefault)
            TextButton.icon(
              icon: const Icon(Symbols.restart_alt_rounded),
              label: const Text("恢复 100%"),
              onPressed: () async {
                await ThemeProvider.instance.applyUiScale(1.0);
              },
            ),
        ],
      ),
    );
  }
}

