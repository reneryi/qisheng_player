import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/build_index_state_view.dart';
import 'package:coriander_player/component/settings_tile.dart';
import 'package:coriander_player/hotkeys_helper.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/lyric/lyric_source.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            icon: Icon(Symbols.cloud_off),
            label: Text("本地"),
          ),
          ButtonSegment<bool>(
            value: false,
            icon: Icon(Symbols.cloud),
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

class AudioLibraryEditor extends StatelessWidget {
  const AudioLibraryEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "文件夹管理",
      action: FilledButton.icon(
        icon: const Icon(Symbols.folder),
        label: const Text("文件夹管理"),
        onPressed: () {
          showDialog(
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

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        height: 450.0,
        width: 450.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "管理文件夹",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
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
                              icon: const Icon(Symbols.delete),
                            ),
                          ),
                        )
                      : FutureBuilder(
                          future: applicationSupportDirectory,
                          builder: (context, snapshot) {
                            if (snapshot.data == null) {
                              return const Center(
                                child: Text("Fail to get app data dir."),
                              );
                            }

                            return Center(
                              child: BuildIndexStateView(
                                indexPath: snapshot.data!,
                                folders: folders,
                                whenIndexBuilt: () async {
                                  await Future.wait([
                                    AudioLibrary.initFromIndex(),
                                    readPlaylists(),
                                    readLyricSources(),
                                  ]);
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
              const SizedBox(height: 16.0),
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
                  TextButton(
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
          await showDialog(
            context: context,
            builder: (context) => const _HotkeySettingsDialog(),
          );
        },
        icon: const Icon(Symbols.keyboard),
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
    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        width: 640,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "快捷键设置",
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "提示：支持后台快捷键（系统级），但后台不响应播放/暂停、桌面歌词开关、返回上一页、退出程序。",
                style: TextStyle(color: scheme.onSurface),
              ),
              const SizedBox(height: 12),
              Expanded(
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
                                  await showDialog<HotkeyBindingPreference>(
                                context: context,
                                builder: (context) =>
                                    _HotkeyCaptureDialog(action: action),
                              );
                              if (captured == null) return;
                              await HotkeysHelper.updateBinding(
                                  action, captured);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Symbols.keyboard),
                          ),
                          IconButton(
                            tooltip: "恢复默认",
                            onPressed: () async {
                              await HotkeysHelper.resetToDefault(action);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Symbols.restore),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "录制快捷键：${widget.action.label}",
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.surfaceContainer,
                  ),
                  child: Text(
                    _hint,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
