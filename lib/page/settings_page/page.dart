import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/ui/app_section.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/page/settings_page/artist_separator_editor.dart';
import 'package:qisheng_player/page/settings_page/check_update.dart';
import 'package:qisheng_player/page/settings_page/create_issue.dart';
import 'package:qisheng_player/page/settings_page/other_settings.dart';
import 'package:qisheng_player/page/settings_page/theme_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';

enum _SettingsCategory {
  appearance('外观与特效', Symbols.palette),
  playback('播放与音频', Symbols.music_note),
  system('系统与热键', Symbols.keyboard),
  about('关于与更新', Symbols.info);

  const _SettingsCategory(this.title, this.icon);
  final String title;
  final IconData icon;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsCategory _selectedCategory = _SettingsCategory.appearance;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: "设置",
      secondaryActions: const [],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          if (!isWide) {
            return _buildNarrowLayout(context);
          }
          return _buildWideSplitLayout(context);
        },
      ),
    );
  }

  Widget _buildWideSplitLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧分类导航
          SizedBox(
            width: 220,
            child: ListView.separated(
              itemCount: _SettingsCategory.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final category = _SettingsCategory.values[index];
                final selected = _selectedCategory == category;

                return CpMotionPressable(
                  borderRadius: BorderRadius.circular(14),
                  selected: selected,
                  border: false,
                  hoverScale: 1.0,
                  pressScale: 0.98,
                  hoverShadow: false,
                  selectedGlow: false,
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: motion.controlTransitionDuration,
                    curve: motion.normal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          category.icon,
                          size: 20,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 28),
          // 右侧对应内容区
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(_selectedCategory),
                child: ListView(
                  padding: const EdgeInsets.only(right: 16, bottom: 40),
                  children: _buildCategoryContent(_selectedCategory),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: _SettingsCategory.values.map((category) {
              final selected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category.title),
                  avatar: Icon(category.icon, size: 16),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  showCheckmark: false,
                  backgroundColor: Colors.transparent,
                  selectedColor: scheme.primary.withValues(alpha: 0.16),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: _buildCategoryContent(_selectedCategory),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryContent(_SettingsCategory category) {
    switch (category) {
      case _SettingsCategory.appearance:
        return const [
          AppSection(
            title: '窗口底座材质',
            description: '控制物理画布材质（Windows 11 Mica / 亚克力 / 弥散流彩 / 水波纹 / 琉璃透镜）与自定义壁纸。',
            children: [
              WindowBackdropModeControl(),
              BackgroundImageSettings(),
            ],
          ),
          AppSection(
            title: 'UI 表面与色彩风格',
            description: '纯净实体卡片、无界悬浮与液态玻璃等控件表面视觉语言。',
            children: [
              VisualStyleModeControl(),
              DynamicThemeSwitch(),
              ThemeColorTintBackgroundSwitch(),
              UseSystemThemeSwitch(),
              ThemeSelector(),
              UseSystemThemeModeSwitch(),
              ThemeModeControl(),
              SelectFontCombobox(),
            ],
          ),
          AppSection(
            title: '动效档位与交互反馈',
            description: '120Hz 高帧率动画、弹簧物理微交互与歌词景深模糊。',
            children: [
              LyricDepthBlurSwitch(),
            ],
          ),
        ];
      case _SettingsCategory.playback:
        return const [
          AppSection(
            title: '播放行为',
            description: '播放行为、歌词来源和音量均衡等日常设置。',
            children: [
              DefaultLyricSourceControl(),
              VolumeLevelingSwitch(),
              VolumeLevelingPreampControl(),
              ArtistSeparatorEditor(),
            ],
          ),
        ];
      case _SettingsCategory.system:
        return const [
          AppSection(
            title: '系统与快捷键',
            description: '全局热键与系统级交互配置。',
            children: [
              HotkeySettingsTile(),
            ],
          ),
        ];
      case _SettingsCategory.about:
        return const [
          AppSection(
            title: '关于与反馈',
            description: '检查最新版本与向开发者反馈问题。',
            children: [
              CreateIssueTile(),
              CheckForUpdate(),
            ],
          ),
        ];
    }
  }
}
