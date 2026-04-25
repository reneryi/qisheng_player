import 'dart:io';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/settings_tile.dart';
import 'package:coriander_player/page/settings_page/theme_picker_dialog.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/rust/api/installed_font.dart';
import 'package:coriander_player/theme_provider.dart';
import 'package:coriander_player/utils.dart';
import 'package:coriander_player/window_controls.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

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
      hint: "在玻璃拟态与高对比极简风格之间切换，按钮和面板层级会同步调整。",
      action: SegmentedButton<UiVisualStyleMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<UiVisualStyleMode>(
            value: UiVisualStyleMode.glass,
            icon: Icon(Symbols.blur_on),
            label: Text("玻璃"),
          ),
          ButtonSegment<UiVisualStyleMode>(
            value: UiVisualStyleMode.contrast,
            icon: Icon(Symbols.tune),
            label: Text("高对比"),
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

class UiEffectsLevelControl extends StatefulWidget {
  const UiEffectsLevelControl({super.key});

  @override
  State<UiEffectsLevelControl> createState() => _UiEffectsLevelControlState();
}

class _UiEffectsLevelControlState extends State<UiEffectsLevelControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "UI 效果强度",
      hint: "平衡、视觉和性能模式会影响模糊强度与阴影深度。",
      action: SegmentedButton<UiEffectsLevel>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<UiEffectsLevel>(
            value: UiEffectsLevel.balanced,
            icon: Icon(Symbols.tune),
            label: Text("平衡"),
          ),
          ButtonSegment<UiEffectsLevel>(
            value: UiEffectsLevel.visual,
            icon: Icon(Symbols.auto_awesome),
            label: Text("视觉"),
          ),
          ButtonSegment<UiEffectsLevel>(
            value: UiEffectsLevel.performance,
            icon: Icon(Symbols.speed),
            label: Text("性能"),
          ),
        ],
        selected: {settings.uiEffectsLevel},
        onSelectionChanged: (selection) async {
          final nextLevel = selection.first;
          if (nextLevel == settings.uiEffectsLevel) return;

          setState(() {
            settings.uiEffectsLevel = nextLevel;
          });
          ThemeProvider.instance.applyUiEffectsLevel(nextLevel);
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
  String _effectiveMode = AppSettings.instance.windowBackdropMode.name;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "Windows 背景材质",
      hint: "Auto 会跟随系统策略；不支持的模式会回退。当前实际模式：$_effectiveMode",
      action: SegmentedButton<WindowBackdropMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<WindowBackdropMode>(
            value: WindowBackdropMode.auto,
            icon: Icon(Symbols.auto_awesome),
            label: Text("自动"),
          ),
          ButtonSegment<WindowBackdropMode>(
            value: WindowBackdropMode.mica,
            icon: Icon(Symbols.layers),
            label: Text("Mica"),
          ),
          ButtonSegment<WindowBackdropMode>(
            value: WindowBackdropMode.acrylic,
            icon: Icon(Symbols.blur_on),
            label: Text("Acrylic"),
          ),
          ButtonSegment<WindowBackdropMode>(
            value: WindowBackdropMode.none,
            icon: Icon(Symbols.block),
            label: Text("关闭"),
          ),
        ],
        selected: {settings.windowBackdropMode},
        onSelectionChanged: (selection) async {
          final requested = selection.first;
          if (requested == settings.windowBackdropMode) return;

          final effective = await WindowControls.setWindowBackdropMode(
            requested,
          );
          setState(() {
            settings.windowBackdropMode = requested;
            _effectiveMode = effective;
          });
          await settings.saveSettings();
          if (effective != requested.name && context.mounted) {
            showTextOnSnackBar(
              "背景材质已回退：${requested.name} -> $effective",
            );
          }
        },
      ),
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
      hint: "跟随系统明暗模式设置。",
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

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "自定义字体",
      hint: "应用到页面标题、正文和播放控件文本。",
      action: FilledButton.icon(
        onPressed: () async {
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
          if (selectedFont == null) return;

          try {
            final fontLoader = FontLoader(selectedFont.fullName);
            fontLoader.addFont(
              File(selectedFont.path).readAsBytes().then((value) {
                return ByteData.sublistView(value);
              }),
            );
            await fontLoader.load();
            ThemeProvider.instance.changeFontFamily(selectedFont.fullName);

            final settings = AppSettings.instance;
            settings.fontFamily = selectedFont.fullName;
            settings.fontPath = selectedFont.path;
            await settings.saveSettings();
          } catch (err) {
            ThemeProvider.instance.changeFontFamily(null);
            LOGGER.e("[select font] $err");
            if (context.mounted) {
              showTextOnSnackBar(err.toString());
            }
          }
        },
        label: const Text("选择字体"),
        icon: const Icon(Symbols.text_fields),
      ),
    );
  }
}

class NowPlayingStyleModeControl extends StatefulWidget {
  const NowPlayingStyleModeControl({super.key});

  @override
  State<NowPlayingStyleModeControl> createState() =>
      _NowPlayingStyleModeControlState();
}

class _NowPlayingStyleModeControlState
    extends State<NowPlayingStyleModeControl> {
  final pref = AppPreference.instance.nowPlayingPagePref;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: '正在播放页面模式',
      hint: '默认使用沉浸模式，也可以切换到专业双栏布局。',
      action: SegmentedButton<NowPlayingStyleMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<NowPlayingStyleMode>(
            value: NowPlayingStyleMode.immersive,
            icon: Icon(Icons.blur_on),
            label: Text('沉浸'),
          ),
          ButtonSegment<NowPlayingStyleMode>(
            value: NowPlayingStyleMode.studio,
            icon: Icon(Icons.tune),
            label: Text('专业'),
          ),
        ],
        selected: {pref.styleMode},
        onSelectionChanged: (selection) async {
          if (selection.first == pref.styleMode) return;
          setState(() {
            pref.styleMode = selection.first;
          });
          await AppPreference.instance.save();
        },
      ),
    );
  }
}

class _FontSelector extends StatelessWidget {
  const _FontSelector({required this.installedFont});

  final List<InstalledFont> installedFont;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;
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
              Text("当前字体：${theme.fontFamily ?? "默认"}"),
              const SizedBox(height: 8.0),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView.builder(
                    itemCount: installedFont.length,
                    itemExtent: 48,
                    itemBuilder: (context, i) => ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      title: Text(installedFont[i].fullName),
                      onTap: () => Navigator.pop(context, installedFont[i]),
                    ),
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
          hint: "建议使用 10% - 30%，避免背景图影响文字阅读。",
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
