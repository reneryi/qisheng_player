import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/mini_hardware_deck.dart';
import 'package:qisheng_player/component/signal_path_inspector.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/theme_provider.dart';

/// 全局命令与曲库瞬移面板 (Studio Command Palette)
/// 支持键盘优先 (`↑` / `↓` / `Enter` / `Esc`) 快速执行声学控制、材质切换（含琉璃水波纹）、
/// 信号链检视、微缩唱机挂件开关与毫秒级曲库直达。
Future<void> showCommandPaletteDialog(BuildContext context) {
  return showModernDialog<void>(
    context: context,
    builder: (context) => const CommandPaletteDialog(),
  );
}

class _CommandItem {
  const _CommandItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.onExecute,
    this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final String? badge;
  final FutureOr<void> Function(BuildContext context) onExecute;
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(HotkeysHelper.onFocusChanges(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    unawaited(HotkeysHelper.onFocusChanges(false));
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_CommandItem> _buildItems(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final playback = context.read<PlaybackController>();
    final theme = context.read<ThemeProvider>();
    final exclusive = playback.wasapiExclusive.value;
    final miniDeckOpen = MiniHardwareDeckController.instance.value;

    final studioCommands = <_CommandItem>[
      _CommandItem(
        id: 'cmd-signal-path',
        title: '打开声学信号链检视器 (Signal Path Inspector)',
        subtitle: '检视音源无损规格、三次感知音量曲线 (a = p³) 与 WASAPI 硬件直通链路',
        category: '声学工坊',
        icon: Symbols.graphic_eq_rounded,
        badge: exclusive ? 'Bit-Perfect' : 'DSP',
        onExecute: (ctx) {
          Navigator.of(ctx).pop();
          unawaited(showSignalPathInspector(ctx));
        },
      ),
      _CommandItem(
        id: 'cmd-mini-deck',
        title: miniDeckOpen ? '关闭桌面微缩唱机挂件 (Mini Deck)' : '开启桌面微缩唱机挂件 (Mini Deck)',
        subtitle: '切换博朗工业风黑胶唱臂 + 16 段实时 LED 电平表悬浮挂件',
        category: '空间形态',
        icon: Symbols.album_rounded,
        badge: miniDeckOpen ? '运行中' : '微缩态',
        onExecute: (ctx) {
          MiniHardwareDeckController.instance.toggle();
          Navigator.of(ctx).pop();
        },
      ),
      _CommandItem(
        id: 'cmd-backdrop-water-ripple',
        title: '切换窗口材质：琉璃光影水波纹 (Water Ripple)',
        subtitle: '启用 16 波源表面张力色散涟漪、水底焦散光网与低音鼓点共振水面',
        category: '光感材质',
        icon: Symbols.water_drop_rounded,
        badge: theme.windowBackdropMode == WindowBackdropMode.waterRipple
            ? '当前使用'
            : '推荐',
        onExecute: (ctx) {
          unawaited(theme.setWindowBackdropMode(WindowBackdropMode.waterRipple));
          Navigator.of(ctx).pop();
        },
      ),
      _CommandItem(
        id: 'cmd-backdrop-mesh-flow',
        title: '切换窗口材质：弥散流彩光斑 (Mesh Flow)',
        subtitle: '启用 OKLab 防灰丝绒深谷与 7 核自转流体光斑着色器',
        category: '光感材质',
        icon: Symbols.blur_on_rounded,
        badge: theme.windowBackdropMode == WindowBackdropMode.meshFlow
            ? '当前使用'
            : null,
        onExecute: (ctx) {
          unawaited(theme.setWindowBackdropMode(WindowBackdropMode.meshFlow));
          Navigator.of(ctx).pop();
        },
      ),
      _CommandItem(
        id: 'cmd-wasapi-exclusive',
        title: exclusive ? '切换音频输出：系统共享混音' : '切换音频输出：WASAPI 独占直通',
        subtitle: '一键切换硬件时钟独占与常规系统共享模式',
        category: '声学工坊',
        icon: exclusive ? Symbols.lock_open_rounded : Symbols.lock_rounded,
        badge: exclusive ? '独占中' : '共享中',
        onExecute: (ctx) {
          playback.useExclusiveMode(!exclusive);
          Navigator.of(ctx).pop();
        },
      ),
      _CommandItem(
        id: 'cmd-theme-toggle',
        title: theme.effectiveBrightness == Brightness.dark
            ? '切换明暗主题：日间温润和纸白'
            : '切换明暗主题：夜间深邃苍青',
        subtitle: '350ms OKLab 感知均匀平滑过渡',
        category: '视觉主题',
        icon: theme.effectiveBrightness == Brightness.dark
            ? Symbols.light_mode_rounded
            : Symbols.dark_mode_rounded,
        onExecute: (ctx) {
          final next = theme.effectiveBrightness == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          theme.changeThemeMode(next);
          Navigator.of(ctx).pop();
        },
      ),
    ];

    final filteredCommands = query.isEmpty
        ? studioCommands
        : studioCommands
            .where(
              (c) =>
                  c.title.toLowerCase().contains(query) ||
                  c.subtitle.toLowerCase().contains(query) ||
                  c.category.toLowerCase().contains(query),
            )
            .toList();

    final libraryItems = <_CommandItem>[];
    final audios = AudioLibrary.instance.audioCollection;
    final albums = AudioLibrary.instance.albumCollection.values;

    if (query.isNotEmpty) {
      var trackMatches = 0;
      for (var i = 0; i < audios.length && trackMatches < 6; i++) {
        final a = audios[i];
        if (a.title.toLowerCase().contains(query) ||
            a.artist.toLowerCase().contains(query) ||
            a.album.toLowerCase().contains(query)) {
          trackMatches++;
          final index = i;
          libraryItems.add(
            _CommandItem(
              id: 'track-${a.path}',
              title: a.displayTitle,
              subtitle: '${a.displayArtist} · ${a.displayAlbum}',
              category: '立即播放',
              icon: Symbols.play_circle_rounded,
              badge: a.path.split('.').last.toUpperCase(),
              onExecute: (ctx) {
                playback.play(index, audios);
                Navigator.of(ctx).pop();
              },
            ),
          );
        }
      }

      var albumMatches = 0;
      for (final album in albums) {
        if (albumMatches >= 4) break;
        if (album.name.toLowerCase().contains(query)) {
          albumMatches++;
          libraryItems.add(
            _CommandItem(
              id: 'album-${album.id}',
              title: album.name,
              subtitle: '${album.works.length} 首作品 · 专辑详情',
              category: '专辑直达',
              icon: Symbols.album_rounded,
              onExecute: (ctx) {
                Navigator.of(ctx).pop();
                ctx.push(app_paths.ALBUM_DETAIL_PAGE, extra: album);
              },
            ),
          );
        }
      }
    }

    return [...filteredCommands, ...libraryItems];
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
    List<_CommandItem> items,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (items.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % items.length;
        });
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (items.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
        });
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (items.isNotEmpty) {
        final idx = _selectedIndex.clamp(0, items.length - 1);
        items[idx].onExecute(context);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;
    final isDark = scheme.brightness == Brightness.dark;
    final items = _buildItems(context);
    final effectiveSelected =
        items.isEmpty ? 0 : _selectedIndex.clamp(0, items.length - 1);

    return Focus(
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, items),
      child: ModernDialogFrame(
        key: const ValueKey('command-palette-dialog'),
        width: 640,
        maxHeight: 540,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部命令搜索栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                border: Border.all(
                  color: accents.accent.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Symbols.terminal_rounded,
                    color: accents.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('command-palette-input'),
                      controller: _queryController,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() => _selectedIndex = 0),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '输入指令、材质名称（如：水波纹 / 独占 / 唱机）或搜索歌曲、专辑…',
                        hintStyle: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.48),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                    child: Text(
                      'ESC',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 候选指令与曲库列表
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          '未找到匹配的指令或曲库条目',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: math.min(items.length, 12),
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = index == effectiveSelected;
                        return InkWell(
                          key: ValueKey('command-palette-item-${item.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => item.onExecute(context),
                          onHover: (hovering) {
                            if (hovering && _selectedIndex != index) {
                              setState(() => _selectedIndex = index);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selected
                                  ? accents.accent.withValues(
                                      alpha: isDark ? 0.18 : 0.12,
                                    )
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? accents.accent.withValues(
                                        alpha: isDark ? 0.42 : 0.30,
                                      )
                                    : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: selected
                                        ? accents.accent.withValues(alpha: 0.22)
                                        : scheme.onSurface
                                            .withValues(alpha: 0.06),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 18,
                                    color: selected
                                        ? accents.accent
                                        : scheme.onSurface
                                            .withValues(alpha: 0.78),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 13.5,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.65),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: accents.accent
                                          .withValues(alpha: 0.16),
                                    ),
                                    child: Text(
                                      item.badge!,
                                      style: TextStyle(
                                        color: accents.accent,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  item.category,
                                  style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
