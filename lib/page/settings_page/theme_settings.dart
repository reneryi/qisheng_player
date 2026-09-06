import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/settings_tile.dart';
import 'package:qisheng_player/page/settings_page/theme_picker_dialog.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/installed_font.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:crypto/crypto.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

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
        final fontLoader = FontLoader(family);
        final bytes = await File(font.path).readAsBytes();
        fontLoader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
        await fontLoader.load();
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
    return SettingsTile(
      description: "主题颜色",
      hint: "手动选择强调色；在背景层级变化时保持稳定。",
      action: FilledButton.icon(
        onPressed: () async {
          final seedColor = await showDialog<Color>(
            context: context,
            builder: (context) => const ThemePickerDialog(),
          );
          if (seedColor == null) return;

          ThemeProvider.instance.applyTheme(seedColor: seedColor);
          AppSettings.instance.defaultTheme = seedColor.toARGB32();
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
    return SettingsTile(
      description: "明暗模式",
      hint: "在明亮和夜间界面之间切换。",
      action: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<ThemeMode>(
            value: ThemeMode.light,
            icon: Icon(Symbols.light_mode),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.dark,
            icon: Icon(Symbols.dark_mode),
          ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (newSelection) async {
          if (newSelection.first == settings.themeMode) return;

          setState(() {
            settings.themeMode = newSelection.first;
          });
          ThemeProvider.instance.applyThemeMode(settings.themeMode);
          await settings.saveSettings();
        },
      ),
    );
  }
}

class VisualStyleModeControl extends StatefulWidget {
  const VisualStyleModeControl({super.key});

  @override
  State<VisualStyleModeControl> createState() => _VisualStyleModeControlState();
}

class _VisualStyleModeControlState extends State<VisualStyleModeControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "UI 视觉风格",
      hint: "在纯净实体卡片、无界极简悬浮与液态玻璃风格之间切换。",
      action: SegmentedButton<UiVisualStyleMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<UiVisualStyleMode>(
            value: UiVisualStyleMode.solidCard,
            icon: Icon(Symbols.layers),
            label: Text("纯净卡片"),
          ),
          ButtonSegment<UiVisualStyleMode>(
            value: UiVisualStyleMode.borderless,
            icon: Icon(Symbols.crop_free),
            label: Text("无界悬浮"),
          ),
          ButtonSegment<UiVisualStyleMode>(
            value: UiVisualStyleMode.liquidGlass,
            icon: Icon(Symbols.water_drop),
            label: Text("液态玻璃"),
          ),
        ],
        selected: {settings.uiVisualStyleMode},
        onSelectionChanged: (selection) async {
          final nextMode = selection.first;
          if (nextMode == settings.uiVisualStyleMode) return;

          setState(() {
            settings.uiVisualStyleMode = nextMode;
          });
          await ThemeProvider.instance.applyVisualStyleMode(nextMode);
          await settings.saveSettings();
        },
      ),
    );
  }
}

class DynamicThemeSwitch extends StatefulWidget {
  const DynamicThemeSwitch({super.key});

  @override
  State<DynamicThemeSwitch> createState() => _DynamicThemeSwitchState();
}

class _DynamicThemeSwitchState extends State<DynamicThemeSwitch> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "动态主题",
      hint: "使用当前封面颜色影响强调色和背景色。",
      action: Switch(
        value: settings.dynamicTheme,
        onChanged: (_) async {
          setState(() {
            settings.dynamicTheme = !settings.dynamicTheme;
          });
          if (!settings.dynamicTheme) {
            ThemeProvider.instance.applyTheme(
              seedColor: Color(settings.defaultTheme),
            );
          } else {
            final audio = PlayService.instance.playbackService.nowPlaying;
            if (audio != null) {
              ThemeProvider.instance.applyThemeFromAudio(audio);
            }
          }
          await settings.saveSettings();
        },
      ),
    );
  }
}

/// 控制主题色（手动选择或动态取色）是否微弱浸润默认渐变背景。
/// 关闭时，默认渐变背景为纯净中性色（夜间午夜蓝 / 日间哑光纸白）。
class ThemeColorTintBackgroundSwitch extends StatefulWidget {
  const ThemeColorTintBackgroundSwitch({super.key});

  @override
  State<ThemeColorTintBackgroundSwitch> createState() =>
      _ThemeColorTintBackgroundSwitchState();
}

class _ThemeColorTintBackgroundSwitchState
    extends State<ThemeColorTintBackgroundSwitch> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "主题色浸润背景",
      hint: settings.themeColorTintBackground
          ? "默认渐变背景会带有极淡的主题色调倾向。关闭后恢复纯净中性渐变。"
          : "默认渐变背景为纯净中性色（夜间午夜蓝 / 日间哑光纸白）。",
      action: Switch(
        value: settings.themeColorTintBackground,
        onChanged: (_) async {
          setState(() {
            settings.themeColorTintBackground =
                !settings.themeColorTintBackground;
          });
          // 通知主题系统重新计算背景渐变
          ThemeProvider.instance.refreshTheme();
          await settings.saveSettings();
        },
      ),
    );
  }
}

class LyricDepthBlurSwitch extends StatefulWidget {
  const LyricDepthBlurSwitch({super.key});

  @override
  State<LyricDepthBlurSwitch> createState() => _LyricDepthBlurSwitchState();
}

class _LyricDepthBlurSwitchState extends State<LyricDepthBlurSwitch> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "歌词景深模糊",
      hint: "模糊非当前歌词行，聚焦当前演唱内容。",
      action: Switch(
        value: settings.lyricDepthBlur,
        onChanged: (value) async {
          setState(() => settings.lyricDepthBlur = value);
          await settings.saveSettings();
        },
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
      WindowBackdropMode.defaultGradient => "默认渐变",
      WindowBackdropMode.micaAlt => "增强云母",
      WindowBackdropMode.acrylic => "亚克力",
      WindowBackdropMode.meshFlow => "弥散流彩",
      WindowBackdropMode.waterRipple => "水波纹",
      WindowBackdropMode.prismaticGlass => "琉璃透镜",
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
      hint: "包含原生云母/亚克力及着色器流体。当前实际模式：$effectiveModeLabel$fallbackHint",
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildBackdropChip(WindowBackdropMode.defaultGradient, "默认渐变"),
          _buildBackdropChip(WindowBackdropMode.micaAlt, "增强云母"),
          _buildBackdropChip(WindowBackdropMode.acrylic, "亚克力"),
          _buildBackdropChip(WindowBackdropMode.meshFlow, "弥散流彩"),
          _buildBackdropChip(WindowBackdropMode.waterRipple, "水波纹"),
          _buildBackdropChip(WindowBackdropMode.prismaticGlass, "琉璃透镜"),
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
    return SettingsTile(
      description: "启动时使用系统主题色",
      hint: "读取系统强调色作为应用主题来源。",
      action: Switch(
        value: settings.useSystemTheme,
        onChanged: (_) async {
          setState(() {
            settings.useSystemTheme = !settings.useSystemTheme;
          });
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
    return SettingsTile(
      description: "启动时使用系统明暗模式",
      hint: "跟随系统明暗模式设置　",
      action: Switch(
        value: settings.useSystemThemeMode,
        onChanged: (_) async {
          setState(() {
            settings.useSystemThemeMode = !settings.useSystemThemeMode;
          });
          await settings.saveSettings();
        },
      ),
    );
  }
}

class SelectFontCombobox extends StatelessWidget {
  const SelectFontCombobox({super.key});

  Future<void> _applyFont(BuildContext context, InstalledFont font) async {
    final fontLoader = FontLoader(font.fullName);
    fontLoader.addFont(
      File(font.path).readAsBytes().then(ByteData.sublistView),
    );
    await fontLoader.load();
    _FontPreviewRegistry.markLoaded(font.fullName);
    ThemeProvider.instance.changeFontFamily(font.fullName);

    final settings = AppSettings.instance;
    settings.fontFamily = font.fullName;
    settings.fontPath = font.path;
    await settings.saveSettings();
  }

  Future<void> _selectInstalledFont(BuildContext context) async {
    final installedFont = await getInstalledFonts();
    if (installedFont == null || installedFont.isEmpty) {
      showTextOnSnackBar("无法读取系统字体");
      return;
    }

    if (!context.mounted) return;
    final selectedFont = await showDialog<InstalledFont>(
      context: context,
      builder: (context) => _FontSelector(installedFont: installedFont),
    );
    if (selectedFont == null || !context.mounted) return;
    await _applyFont(context, selectedFont);
  }

  Future<void> _importFont(BuildContext context) async {
    final picker = OpenFilePicker()
      ..title = "添加字体"
      ..filterSpecification = {
        "字体文件": "*.ttf;*.otf;*.ttc",
      };
    final source = picker.getFile();
    if (source == null) return;

    final inspected = await inspectFontFile(path: source.path);
    if (inspected == null) {
      throw const FormatException("无法识别该字体文件");
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
    await _applyFont(context, managedFont);
    showTextOnSnackBar("已添加字体：${managedFont.fullName}");
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "自定义字体",
      hint: "应用到页面标题、正文和播放控件文本。",
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () async {
              try {
                await _selectInstalledFont(context);
              } catch (err, trace) {
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
        ],
      ),
    );
  }
}

class _FontSelector extends StatelessWidget {
  const _FontSelector({required this.installedFont});

  final List<InstalledFont> installedFont;

  TextStyle _previewStyle(String? family, Color color, {double size = 15}) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: const [
        'MiSans',
        'HarmonyOS Sans SC',
        'OPPO Sans',
        'Segoe UI Variable Text',
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
      ],
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w500,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    _FontPreviewRegistry.markLoaded(theme.fontFamily);
    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        width: 350.0,
        height: 400,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "选择字体",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text('当前字体：${theme.fontFamily ?? "默认"}'),
              const SizedBox(height: 8.0),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView.builder(
                    itemCount: installedFont.length,
                    itemExtent: 64,
                    itemBuilder: (context, i) {
                      final font = installedFont[i];
                      final isCurrent = font.fullName == theme.fontFamily;
                      return FutureBuilder<void>(
                        future: _FontPreviewRegistry.ensureLoaded(font),
                        builder: (context, snapshot) {
                          final previewFamily =
                              snapshot.hasError ? null : font.fullName;
                          return ListTile(
                            enableFeedback: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            trailing: isCurrent
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  )
                                : null,
                            title: Text(
                              font.fullName,
                              style: _previewStyle(
                                previewFamily,
                                scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              "AaBbCc 你好 123",
                              style: _previewStyle(
                                previewFamily,
                                scheme.onSurface.withValues(alpha: 0.64),
                                size: 12,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, font),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("取消"),
                  ),
                ],
              ),
            ],
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
          hint: "选择图片作为背景，内容区域会自动加深遮罩以保证可读性。",
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
          hint: "建议使用 10% - 30%，避免背景图片影响文字阅读。",
          action: SizedBox(
            width: 260,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0.0,
                    max: 0.6,
                    value: settings.backgroundImageOpacity,
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
                    "${(settings.backgroundImageOpacity * 100).round()}%",
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
