import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/build_index_state_view.dart';
import 'package:qisheng_player/component/settings_tile.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/library_reload_service.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/utils.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:material_symbols_icons/symbols.dart';

class DefaultLyricSourceControl extends StatefulWidget {
  const DefaultLyricSourceControl({super.key});

  @override
  State<DefaultLyricSourceControl> createState() =>
      _DefaultLyricSourceControlState();
}

class _DefaultLyricSourceControlState extends State<DefaultLyricSourceControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "首选歌词来源",
      action: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<bool>(
            value: true,
            icon: Icon(Symbols.cloud_off_rounded),
            label: Text("本地"),
          ),
          ButtonSegment<bool>(
            value: false,
            icon: Icon(Symbols.cloud_rounded),
            label: Text("在线"),
          ),
        ],
        selected: {settings.localLyricFirst},
        onSelectionChanged: (newSelection) async {
          if (newSelection.first == settings.localLyricFirst) return;

          setState(() {
            settings.localLyricFirst = newSelection.first;
          });
          await settings.saveSettings();
        },
      ),
    );
  }
}

class LyricSaveOptionsControl extends StatefulWidget {
  const LyricSaveOptionsControl({super.key});

  @override
  State<LyricSaveOptionsControl> createState() =>
      _LyricSaveOptionsControlState();
}

class _LyricSaveOptionsControlState extends State<LyricSaveOptionsControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "设歌词默认保存方式",
      action: Wrap(
        spacing: 10.0,
        runSpacing: 8.0,
        children: [
          _LyricOptionButton(
            label: "写入内嵌标签",
            icon: Symbols.save_rounded,
            tooltip: "获取歌词后默认写入音频文件内嵌标签（ID3v2 / FLAC / MP4）",
            selected: settings.lyricSaveWriteTag,
            onTap: () {
              setState(() {
                settings.lyricSaveWriteTag = !settings.lyricSaveWriteTag;
              });
              settings.saveSettings();
            },
          ),
          _LyricOptionButton(
            label: "保存同级 .lrc",
            icon: Symbols.description_rounded,
            tooltip: "获取歌词后在音频同级目录生成同名 .lrc 歌词文件",
            selected: settings.lyricSaveExportLrc,
            onTap: () {
              setState(() {
                settings.lyricSaveExportLrc = !settings.lyricSaveExportLrc;
              });
              settings.saveSettings();
            },
          ),
          _LyricOptionButton(
            label: "应用到播放器",
            icon: Symbols.play_circle_rounded,
            tooltip: "获取歌词后直接应用并同步显示于当前播放器",
            selected: settings.lyricSaveApplyPlayer,
            onTap: () {
              setState(() {
                settings.lyricSaveApplyPlayer = !settings.lyricSaveApplyPlayer;
              });
              settings.saveSettings();
            },
          ),
        ],
      ),
    );
  }
}

class _LyricOptionButton extends StatelessWidget {
  const _LyricOptionButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final surfaces = context.surfaces;
    final isDark = scheme.brightness == Brightness.dark;

    final activeBg = accents.accentContainer;
    final inactiveBg = isDark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);

    final activeFg = accents.onAccent;
    final inactiveFg = scheme.onSurface.withValues(alpha: 0.78);

    final activeBorder = accents.accent.withValues(alpha: 0.55);
    final inactiveBorder = scheme.outlineVariant.withValues(alpha: 0.45);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(surfaces.radiusXl),
          splashColor: accents.hoverTint,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(surfaces.radiusXl),
              border: Border.all(
                color: selected ? activeBorder : inactiveBorder,
                width: selected ? 1.4 : 1.0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accents.accentGlow.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? activeFg
                      : scheme.onSurfaceVariant.withValues(alpha: 0.70),
                  fill: 1.0,
                  weight: selected ? 700 : 600,
                  grade: 0.25,
                  opticalSize: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? activeFg : inactiveFg,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? activeFg : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? activeFg
                          : scheme.onSurfaceVariant.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Symbols.check_rounded,
                          size: 13,
                          color: activeBg,
                          fill: 1.0,
                          weight: 700,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LyricMaintenanceTile extends StatefulWidget {
  const LyricMaintenanceTile({super.key});

  @override
  State<LyricMaintenanceTile> createState() => _LyricMaintenanceTileState();
}

class _LyricMaintenanceTileState extends State<LyricMaintenanceTile> {
  bool _cleaning = false;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "歌词源维护",
      action: FilledButton.tonalIcon(
        icon: _cleaning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Symbols.cleaning_services_rounded),
        label: const Text("清理失效记录"),
        onPressed: _cleaning
            ? null
            : () async {
                setState(() => _cleaning = true);
                try {
                  final count = await pruneMissingLyricSources();
                  if (context.mounted) {
                    showTextOnSnackBar("已清理 $count 条失效歌词映射（已保护 CUE 分轨）");
                  }
                } catch (err) {
                  if (context.mounted) {
                    showTextOnSnackBar("清理失败：$err");
                  }
                } finally {
                  if (mounted) setState(() => _cleaning = false);
                }
              },
      ),
    );
  }
}

class AudioLibraryEditor extends StatelessWidget {
  const AudioLibraryEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "文件夹管理",
      action: FilledButton.icon(
        icon: const Icon(Symbols.folder_rounded),
        label: const Text("文件夹管理"),
        onPressed: () {
          showModernDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AudioLibraryEditorDialog(),
          );
        },
      ),
    );
  }
}

class AudioLibraryEditorDialog extends StatefulWidget {
  const AudioLibraryEditorDialog({super.key});

  @override
  State<AudioLibraryEditorDialog> createState() =>
      _AudioLibraryEditorDialogState();
}

class _AudioLibraryEditorDialogState extends State<AudioLibraryEditorDialog> {
  final folders = List.generate(
    AudioLibrary.instance.folders.length,
    (i) => AudioLibrary.instance.folders[i].path,
  );

  final applicationSupportDirectory = getAppDataDir();

  bool editing = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ModernDialogFrame(
      maxWidth: 580,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: SizedBox(
        height: 460,
        child: Column(
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
                    Symbols.folder_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "管理文件夹",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "关闭",
                  icon: Icon(
                    Symbols.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14.0),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: editing
                      ? ListView.builder(
                          itemCount: folders.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(folders[i], maxLines: 1),
                            trailing: IconButton(
                              tooltip: "移除",
                              color: scheme.error,
                              onPressed: () {
                                setState(() {
                                  folders.removeAt(i);
                                });
                              },
                              icon: const Icon(Symbols.delete_rounded),
                            ),
                          ),
                        )
                      : FutureBuilder(
                          future: applicationSupportDirectory,
                          builder: (context, snapshot) {
                            if (snapshot.data == null) {
                              return const Center(
                                child: Text("无法获取应用数据目录。"),
                              );
                            }

                            return Center(
                              child: BuildIndexStateView(
                                indexPath: snapshot.data!,
                                folders: folders,
                                whenIndexBuilt: () async {
                                  final status =
                                      await libraryReloadCoordinator.reload(
                                    afterReload: PlayService
                                        .instance
                                        .playbackService
                                        .reconcileLibraryReferences,
                                  );
                                  if (status != AudioLibraryLoadStatus.loaded) {
                                    showTextOnSnackBar(
                                      "曲库索引加载失败，请重新扫描音乐文件夹",
                                    );
                                    return;
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final dirPicker = DirectoryPicker();
                    dirPicker.title = "选择文件夹";

                    final dir = dirPicker.getDirectory();
                    if (dir == null) return;

                    setState(() {
                      folders.add(dir.path);
                    });
                  },
                  child: const Text("添加"),
                ),
                const SizedBox(width: 8.0),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("取消"),
                ),
                const SizedBox(width: 8.0),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      editing = false;
                    });
                  },
                  child: const Text("确定"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class VolumeLevelingSwitch extends StatelessWidget {
  const VolumeLevelingSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final playbackService = PlayService.instance.playbackService;
    return ValueListenableBuilder(
      valueListenable: playbackService.enableVolumeLeveling,
      builder: (context, enabled, _) => SettingsTile(
        description: "音量均衡（ReplayGain）",
        action: Switch(
          value: enabled,
          onChanged: playbackService.setEnableVolumeLeveling,
        ),
      ),
    );
  }
}

class VolumeLevelingPreampControl extends StatelessWidget {
  const VolumeLevelingPreampControl({super.key});

  @override
  Widget build(BuildContext context) {
    final playbackService = PlayService.instance.playbackService;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: playbackService.volumeLevelingPreampDb,
      builder: (context, preampDb, _) => ValueListenableBuilder(
        valueListenable: playbackService.enableVolumeLeveling,
        builder: (context, enabled, _) => SettingsTile(
          description: "音量均衡预增益",
          action: SizedBox(
            width: 260,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    min: -12.0,
                    max: 12.0,
                    value: preampDb,
                    label: "${preampDb.toStringAsFixed(1)} dB",
                    onChanged: enabled
                        ? playbackService.setVolumeLevelingPreampDb
                        : null,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    "${preampDb.toStringAsFixed(1)} dB",
                    textAlign: TextAlign.end,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HotkeySettingsTile extends StatelessWidget {
  const HotkeySettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "快捷键设置",
      action: FilledButton.icon(
        onPressed: () async {
          await showModernDialog(
            context: context,
            builder: (context) => const _HotkeySettingsDialog(),
          );
        },
        icon: const Icon(Symbols.keyboard_rounded),
        label: const Text("配置快捷键"),
      ),
    );
  }
}

class _HotkeySettingsDialog extends StatefulWidget {
  const _HotkeySettingsDialog();

  @override
  State<_HotkeySettingsDialog> createState() => _HotkeySettingsDialogState();
}

class _HotkeySettingsDialogState extends State<_HotkeySettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ModernDialogFrame(
      maxWidth: 640,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: SizedBox(
        height: 520,
        child: Column(
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
                    Symbols.keyboard_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "快捷键设置",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "关闭",
                  icon: Icon(
                    Symbols.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "提示：支持后台快捷键（系统级），但后台不响应播放/暂停、桌面歌词开关、返回、前进、退出程序。",
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  itemCount: HotkeyAction.values.length,
                  itemBuilder: (context, i) {
                    final action = HotkeyAction.values[i];
                    final binding = HotkeysHelper.getBinding(action);
                    return ListTile(
                      title: Text(action.label),
                      subtitle: Text(HotkeysHelper.describeBinding(binding)),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: "录制快捷键",
                            onPressed: () async {
                              final captured =
                                  await showModernDialog<HotkeyBindingPreference>(
                                context: context,
                                builder: (context) =>
                                    _HotkeyCaptureDialog(action: action),
                              );
                              if (captured == null) return;
                              await HotkeysHelper.updateBinding(
                                  action, captured);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Symbols.keyboard_rounded),
                          ),
                          IconButton(
                            tooltip: "恢复默认",
                            onPressed: () async {
                              await HotkeysHelper.resetToDefault(action);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Symbols.restore_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    for (final action in HotkeyAction.values) {
                      await HotkeysHelper.resetToDefault(action);
                    }
                    if (mounted) setState(() {});
                  },
                  child: const Text("全部恢复默认"),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("完成"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _HotkeyCaptureDialog extends StatefulWidget {
  const _HotkeyCaptureDialog({required this.action});

  final HotkeyAction action;

  @override
  State<_HotkeyCaptureDialog> createState() => _HotkeyCaptureDialogState();
}

class _HotkeyCaptureDialogState extends State<_HotkeyCaptureDialog> {
  final _focusNode = FocusNode();
  String _hint = "请按下目标快捷键（支持 Ctrl/Shift/Alt/Meta + 任意键）";

  bool _isModifier(PhysicalKeyboardKey key) {
    return key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight ||
        key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight ||
        key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight ||
        key == PhysicalKeyboardKey.metaLeft ||
        key == PhysicalKeyboardKey.metaRight;
  }

  HotkeyBindingPreference _fromEvent(KeyEvent event) {
    final modifiers = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) {
      modifiers.add("control");
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      modifiers.add("shift");
    }
    if (HardwareKeyboard.instance.isAltPressed) {
      modifiers.add("alt");
    }
    if (HardwareKeyboard.instance.isMetaPressed) {
      modifiers.add("meta");
    }
    return HotkeyBindingPreference(event.physicalKey.usbHidUsage, modifiers);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ModernDialogFrame(
      maxWidth: 460,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
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
                  Symbols.keyboard_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "录制快捷键：${widget.action.label}",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: "关闭",
                icon: Icon(
                  Symbols.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          KeyboardListener(
            autofocus: true,
            focusNode: _focusNode,
            onKeyEvent: (event) {
              if (event is! KeyDownEvent) return;
              if (_isModifier(event.physicalKey)) {
                setState(() {
                  _hint = "已按下修饰键，请继续按主键";
                });
                return;
              }
              Navigator.pop(context, _fromEvent(event));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainer,
              ),
              child: Text(
                _hint,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    HotkeyBindingPreference(
                      PhysicalKeyboardKey.browserBack.usbHidUsage,
                      const [],
                    ),
                  );
                },
                child: const Text("鼠标侧键后退"),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    HotkeyBindingPreference(
                      PhysicalKeyboardKey.browserForward.usbHidUsage,
                      const [],
                    ),
                  );
                },
                child: const Text("鼠标侧键前进"),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
    );
  }
}

class CloseActionControl extends StatefulWidget {
  const CloseActionControl({super.key});

  @override
  State<CloseActionControl> createState() => _CloseActionControlState();
}

class _CloseActionControlState extends State<CloseActionControl> {
  final settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "关闭主窗口时",
      action: SegmentedButton<CloseAction>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<CloseAction>(
            value: CloseAction.minimizeToTray,
            icon: Icon(Symbols.vertical_align_bottom_rounded),
            label: Text("最小化到托盘"),
          ),
          ButtonSegment<CloseAction>(
            value: CloseAction.exitApp,
            icon: Icon(Symbols.power_settings_new_rounded),
            label: Text("退出程序"),
          ),
        ],
        selected: {settings.closeAction},
        onSelectionChanged: (newSelection) async {
          if (newSelection.first == settings.closeAction) return;

          setState(() {
            settings.closeAction = newSelection.first;
          });
          await settings.saveSettings();
        },
      ),
    );
  }
}
