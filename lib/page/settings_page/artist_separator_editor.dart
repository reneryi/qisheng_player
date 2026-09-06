import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/settings_tile.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/library_reload_service.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ArtistSeparatorEditor extends StatelessWidget {
  const ArtistSeparatorEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "自定义艺术家分隔符",
      action: FilledButton.icon(
        icon: const Icon(Symbols.edit),
        label: const Text("管理艺术家分隔符"),
        onPressed: () {
          showModernDialog(
            context: context,
            builder: (context) => const _ArtistSeparatorEditDialog(),
          );
        },
      ),
    );
  }
}

class _ArtistSeparatorEditDialog extends StatefulWidget {
  const _ArtistSeparatorEditDialog();

  @override
  State<_ArtistSeparatorEditDialog> createState() =>
      __ArtistSeparatorEditDialogState();
}

class __ArtistSeparatorEditDialogState
    extends State<_ArtistSeparatorEditDialog> {
  final appSettings = AppSettings.instance;
  late List<String> separators = List.from(appSettings.artistSeparator);
  Map<String, Widget> children = {};
  final currEditController = TextEditingController();
  bool editing = false;

  void _addArtistSeparator() {
    if (currEditController.text.isEmpty) return;
    setState(
      () {
        children.remove("");
        children[currEditController.text] = ListTile(
          title: Text(currEditController.text),
          trailing: IconButton(
            onPressed: () {
              separators.remove(currEditController.text);
              setState(() {
                children.remove(currEditController.text);
              });
            },
            icon: const Icon(Symbols.remove),
          ),
        );
        editing = false;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    for (var item in separators) {
      children[item] = ListTile(
        title: Text(item),
        trailing: IconButton(
          onPressed: () {
            separators.remove(item);
            setState(() {
              children.remove(item);
            });
          },
          icon: const Icon(Symbols.remove),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ModernDialogFrame(
      maxWidth: 400.0,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: SizedBox(
        height: 380.0,
        child: Column(
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
                    Symbols.edit,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "管理艺术家分隔符",
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
                child: ListView(children: children.values.toList()),
              ),
            ),
            const SizedBox(height: 14.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      editing = true;
                      children[""] = ListTile(
                        title: Focus(
                          onFocusChange: HotkeysHelper.onFocusChanges,
                          child: TextField(
                            controller: currEditController,
                            autofocus: true,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                onPressed: _addArtistSeparator,
                                icon: const Icon(Symbols.done),
                              ),
                            ),
                            onSubmitted: (value) {
                              _addArtistSeparator();
                            },
                          ),
                        ),
                      );
                    });
                  },
                  child: const Text("新增"),
                ),
                const SizedBox(width: 8.0),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("取消"),
                ),
                const SizedBox(width: 8.0),
                FilledButton(
                  onPressed: editing
                      ? null
                      : () async {
                          appSettings.artistSeparator =
                              children.keys.toList();
                          appSettings.artistSplitPattern =
                              appSettings.artistSeparator.join("|");
                          await appSettings.saveSettings();
                          await libraryReloadCoordinator.reload(
                            afterReload: PlayService.instance.playbackService
                                .reconcileLibraryReferences,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text("确定"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
