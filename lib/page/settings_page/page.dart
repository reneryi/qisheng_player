import 'package:qisheng_player/component/ui/app_section.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/page/settings_page/artist_separator_editor.dart';
import 'package:qisheng_player/page/settings_page/check_update.dart';
import 'package:qisheng_player/page/settings_page/create_issue.dart';
import 'package:qisheng_player/page/settings_page/other_settings.dart';
import 'package:qisheng_player/page/settings_page/theme_settings.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: "设置",
      secondaryActions: const [],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: const [
          AppSection(
            title: '外观',
            description: '深蓝黑拟态壳层、明暗模式和播放器外观偏好。',
            children: [
              DynamicThemeSwitch(),
              UseSystemThemeSwitch(),
              ThemeSelector(),
              UseSystemThemeModeSwitch(),
              ThemeModeControl(),
              VisualStyleModeControl(),
              UiEffectsLevelControl(),
              WindowBackdropModeControl(),
              BackgroundImageSettings(),
              SelectFontCombobox(),
            ],
          ),
          SizedBox(height: 18),
          AppSection(
            title: '播放',
            description: '播放行为、歌词来源和音量均衡等日常设置。',
            children: [
              DefaultLyricSourceControl(),
              VolumeLevelingSwitch(),
              VolumeLevelingPreampControl(),
              ArtistSeparatorEditor(),
            ],
          ),
          SizedBox(height: 18),
          AppSection(
            title: '系统与工具',
            description: '热键、问题反馈和更新检查。',
            children: [
              HotkeySettingsTile(),
              CreateIssueTile(),
              CheckForUpdate(),
            ],
          ),
        ],
      ),
    );
  }
}
