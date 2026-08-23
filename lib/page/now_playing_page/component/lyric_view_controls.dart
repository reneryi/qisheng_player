import 'dart:async';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_controls_visibility.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_source_view.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

enum LyricTextAlign {
  left,
  center,
  right;

  static LyricTextAlign? fromString(String lyricTextAlign) {
    for (var value in LyricTextAlign.values) {
      if (value.name == lyricTextAlign) return value;
    }
    return null;
  }
}

class LyricViewController extends ChangeNotifier {
  final nowPlayingPagePref = AppPreference.instance.nowPlayingPagePref;
  late LyricTextAlign lyricTextAlign = nowPlayingPagePref.lyricTextAlign;
  late bool showTranslation = nowPlayingPagePref.showTranslation;
  late double lyricFontSize = nowPlayingPagePref.lyricFontSize;
  late double translationFontSize = nowPlayingPagePref.translationFontSize;

  void switchLyricTextAlign() {
    lyricTextAlign = switch (lyricTextAlign) {
      LyricTextAlign.left => LyricTextAlign.center,
      LyricTextAlign.center => LyricTextAlign.right,
      LyricTextAlign.right => LyricTextAlign.left,
    };

    nowPlayingPagePref.lyricTextAlign = lyricTextAlign;
    notifyListeners();
    unawaited(AppPreference.instance.save());
  }

  void increaseFontSize() {
    lyricFontSize += 1;
    translationFontSize += 1;

    nowPlayingPagePref.lyricFontSize = lyricFontSize;
    nowPlayingPagePref.translationFontSize = translationFontSize;
    notifyListeners();
    unawaited(AppPreference.instance.save());
  }

  void decreaseFontSize() {
    if (translationFontSize <= 14) return;

    lyricFontSize -= 1;
    translationFontSize -= 1;

    nowPlayingPagePref.lyricFontSize = lyricFontSize;
    nowPlayingPagePref.translationFontSize = translationFontSize;
    notifyListeners();
    unawaited(AppPreference.instance.save());
  }

  // 暴露任意字号更新接口，专为双指捏合平滑缩放手势量身定制
  void setFontSize(double size) {
    lyricFontSize =
        size.clamp(16.0, 48.0); // 限制歌词主字号在 16 到 48 像素之间，保证视障和高分屏的兼容性
    translationFontSize = (lyricFontSize - 4.0)
        .clamp(12.0, 44.0); // 翻译字体大小始终随主字号做等比例偏移（差 4 像素），确保主次层次感

    nowPlayingPagePref.lyricFontSize = lyricFontSize;
    nowPlayingPagePref.translationFontSize = translationFontSize;
    notifyListeners();
    unawaited(AppPreference.instance.save()); // 异步持久化字号配置，下次打开时自动还原
  }

  // 重置字号为默认基准大小 (22px / 100%)
  void resetFontSize() {
    setFontSize(22.0);
  }

  void toggleShowTranslation() {
    showTranslation = !showTranslation;
    nowPlayingPagePref.showTranslation = showTranslation;
    notifyListeners();
    PlayService.instance.lyricService.refreshCurrentLyricLine();
    unawaited(AppPreference.instance.save());
  }
}

class LyricViewControls extends StatelessWidget {
  const LyricViewControls({super.key});

  @override
  Widget build(BuildContext context) {
    final visibilityController =
        context.read<LyricControlsVisibilityController>();
    return MouseRegion(
      onEnter: (_) => visibilityController.setControlsHovered(true),
      onExit: (_) => visibilityController.setControlsHovered(false),
      child: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SetLyricSourceBtn(),
            SizedBox(height: 8.0),
            _LyricAlignSwitchBtn(),
            SizedBox(height: 8.0),
            _TranslationSwitchBtn(),
            SizedBox(height: 8.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IncreaseFontSizeBtn(),
                SizedBox(width: 8.0),
                _DecreaseFontSizeBtn(),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _LyricAlignSwitchBtn extends StatelessWidget {
  const _LyricAlignSwitchBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      enableFeedback: false,
      onPressed: lyricViewController.switchLyricTextAlign,
      tooltip: "切换歌词对齐方向",
      color: scheme.onSecondaryContainer,
      icon: Icon(switch (lyricViewController.lyricTextAlign) {
        LyricTextAlign.left => Symbols.format_align_left,
        LyricTextAlign.center => Symbols.format_align_center,
        LyricTextAlign.right => Symbols.format_align_right,
      }),
    );
  }
}

class _IncreaseFontSizeBtn extends StatelessWidget {
  const _IncreaseFontSizeBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      enableFeedback: false,
      onPressed: lyricViewController.increaseFontSize,
      tooltip: "增大歌词字体",
      color: scheme.onSecondaryContainer,
      icon: const Icon(Symbols.text_increase),
    );
  }
}

class _TranslationSwitchBtn extends StatelessWidget {
  const _TranslationSwitchBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      enableFeedback: false,
      onPressed: lyricViewController.toggleShowTranslation,
      tooltip: lyricViewController.showTranslation ? "隐藏翻译" : "显示翻译",
      color: scheme.onSecondaryContainer,
      icon: Icon(
        lyricViewController.showTranslation
            ? Symbols.subtitles
            : Symbols.subtitles_off,
      ),
    );
  }
}

class _DecreaseFontSizeBtn extends StatelessWidget {
  const _DecreaseFontSizeBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      enableFeedback: false,
      onPressed: lyricViewController.decreaseFontSize,
      tooltip: "减小歌词字体",
      color: scheme.onSecondaryContainer,
      icon: const Icon(Symbols.text_decrease),
    );
  }
}
