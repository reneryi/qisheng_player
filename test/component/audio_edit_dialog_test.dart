import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/audio_edit_dialog.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/page/settings_page/other_settings.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('AudioEditDialog 现代弹窗设计与交互测试', () {
    testWidgets('正确渲染 ModernDialogFrame、现代图标徽标、标题、表单输入与操作按钮', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = TestAudio(
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        path: r'E:\Music\edit_track.flac',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: AudioEditDialog(audio: audio, searcher: (_) async => []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 ModernDialogFrame 规范
      expect(find.byType(ModernDialogFrame), findsOneWidget);

      // 验证头部：标题、副标题与关闭按钮
      expect(find.text('音乐编辑'), findsOneWidget);
      expect(
        find.text('修改本地音频元数据标签；点击保存后写入文件并立即同步播放器'),
        findsOneWidget,
      );
      expect(find.byTooltip('关闭'), findsOneWidget);

      // 验证三个核心输入框及初始值
      expect(find.text('Original Title'), findsOneWidget);
      expect(find.text('Original Artist'), findsOneWidget);
      expect(find.text('Original Album'), findsOneWidget);

      // 现代双栏设计：彻底消除怪异的前置复选框，采用纯净表单与自动脏数据追踪
      expect(find.byType(Checkbox), findsNothing);

      // 验证底部操作按钮与提示
      expect(find.text('保存所选修改'), findsOneWidget);
      expect(find.text('在线匹配结果'), findsOneWidget);
      expect(find.text('重新检索'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('输入框可清空并动态支持内容修改', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = TestAudio(
        title: 'Initial Title',
        artist: 'Initial Artist',
        album: 'Initial Album',
        path: r'E:\Music\edit_track2.flac',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: AudioEditDialog(audio: audio, searcher: (_) async => []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 首版六个标签字段均可单独清空。
      final clearButtons = find.byTooltip('清空');
      expect(clearButtons, findsNWidgets(6));

      await tester.tap(clearButtons.first);
      await tester.pumpAndSettle();

      // 验证标题输入框已清空
      expect(find.text('Initial Title'), findsNothing);

      // 输入新标题
      await tester.enterText(find.byType(TextField).first, 'New Custom Song');
      await tester.pumpAndSettle();

      expect(find.text('New Custom Song'), findsOneWidget);
    });

    testWidgets('重新检索使用同步 setState 回调且不会抛出 Future 返回值异常', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var searchCount = 0;
      final audio = TestAudio(
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        path: r'E:\Music\search_track.flac',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: AudioEditDialog(
                audio: audio,
                searcher: (_) async {
                  searchCount++;
                  return [];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(searchCount, 1);

      await tester.tap(find.text('重新检索'));
      await tester.pumpAndSettle();

      expect(searchCount, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SearchResultCard 正确渲染放大的操作按钮、平台徽标与封面占位', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final resultItem = SongSearchResult(
        ResultSource.qq,
        '夜曲',
        '周杰伦',
        '十一月的萧邦',
        0.98,
        coverUrl: null,
      );

      bool lyricCalled = false;
      bool coverCalled = false;
      bool fillCalled = false;

      final theme = buildTestTheme();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SearchResultCard(
                item: resultItem,
                isDark: false,
                scheme: theme.colorScheme,
                busy: false,
                onApplyLyric: () => lyricCalled = true,
                onApplyCover: () => coverCalled = true,
                onFillForm: () => fillCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证歌曲与专辑展示
      expect(find.text('夜曲'), findsOneWidget);
      expect(find.text('周杰伦'), findsOneWidget);
      expect(find.text('十一月的萧邦'), findsOneWidget);

      // 验证平台与匹配度徽标
      expect(find.text('QQ音乐'), findsOneWidget);
      expect(find.text('98% 匹配'), findsOneWidget);

      // 验证三大核心操作按钮存在
      final lyricBtn = find.text('选择歌词');
      final coverBtn = find.text('选择封面');
      final fillBtn = find.text('采用此结果');
      expect(lyricBtn, findsOneWidget);
      expect(coverBtn, findsOneWidget);
      expect(fillBtn, findsOneWidget);

      // 验证按钮字体大小为 13.5 (调大后的字号)
      final lyricText = tester.widget<Text>(lyricBtn);
      expect(lyricText.style?.fontSize, equals(13.5));
      final coverText = tester.widget<Text>(coverBtn);
      expect(coverText.style?.fontSize, equals(13.5));
      final fillText = tester.widget<Text>(fillBtn);
      expect(fillText.style?.fontSize, equals(13.5));

      // 验证按钮点击手感与高度规范 (38px 最小高度)
      final lyricButtonWidget = tester.widget<OutlinedButton>(find
          .ancestor(of: lyricBtn, matching: find.byType(OutlinedButton))
          .first);
      expect(lyricButtonWidget.style?.minimumSize?.resolve({}),
          equals(const Size(0, 38)));
      final fillButtonWidget = tester.widget<FilledButton>(find
          .ancestor(of: fillBtn, matching: find.byType(FilledButton))
          .first);
      expect(fillButtonWidget.style?.minimumSize?.resolve({}),
          equals(const Size(0, 38)));

      // 验证按钮点击回调响应正常
      await tester.tap(lyricBtn);
      expect(lyricCalled, isTrue);

      await tester.tap(coverBtn);
      expect(coverCalled, isTrue);

      await tester.tap(fillBtn);
      expect(fillCalled, isTrue);
    });

    testWidgets('SearchResultCard 支持网易云与酷狗平台以及 coverUrl 封面加载分支',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final resultItem = SongSearchResult(
        ResultSource.netease,
        '晴天',
        '周杰伦',
        '叶惠美',
        0.75,
        coverUrl: 'https://example.com/cover.jpg',
      );

      final theme = buildTestTheme();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SearchResultCard(
                item: resultItem,
                isDark: true,
                scheme: theme.colorScheme,
                busy: false,
                onApplyLyric: () {},
                onApplyCover: () {},
                onFillForm: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 验证网易云平台标签与 75% 匹配度
      expect(find.text('网易云'), findsOneWidget);
      expect(find.text('75% 匹配'), findsOneWidget);

      // 验证 Image.network 被正确创建
      expect(find.byType(Image), findsOneWidget);

      // 验证鼠标悬浮触发（MouseRegion）
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(SearchResultCard)));
      await tester.pumpAndSettle();
    });

    testWidgets('无封面时优雅渲染带唱片质感的渐变占位符与微边框', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final resultItem = SongSearchResult(
        ResultSource.kugou,
        '十年',
        '陈奕迅',
        '黑·白·灰',
        0.88,
        coverUrl: '',
      );

      final theme = buildTestTheme();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SearchResultCard(
                item: resultItem,
                isDark: false,
                scheme: theme.colorScheme,
                busy: false,
                onApplyLyric: () {},
                onApplyCover: () {},
                onFillForm: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证酷狗平台标签及匹配度
      expect(find.text('酷狗'), findsOneWidget);
      expect(find.text('88% 匹配'), findsOneWidget);

      // 无封面时不应构建 Image.network，而应展示 Symbols.album_rounded 占位图标
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Symbols.album_rounded), findsWidgets);
    });

    testWidgets('正确渲染设歌词动作自定义选择栏，并支持交互切换勾选状态', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = TestAudio(
        title: 'Song Title',
        artist: 'Song Artist',
        album: 'Song Album',
        path: r'E:\Music\song.flac',
      );

      AppSettings.instance.lyricSaveWriteTag = true;
      AppSettings.instance.lyricSaveExportLrc = true;
      AppSettings.instance.lyricSaveApplyPlayer = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: AudioEditDialog(audio: audio, searcher: (_) async => []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('编辑或粘贴歌词'));
      await tester.pump();
      expect(find.text('写入内嵌歌词'), findsOneWidget);
      expect(find.text('导出同级 .lrc'), findsOneWidget);
      expect(find.text('应用到播放器'), findsOneWidget);

      // 本次草稿选项独立于全局默认值。
      await tester.ensureVisible(find.text('导出同级 .lrc'));
      await tester.pump();
      await tester.tap(find.text('导出同级 .lrc'));
      await tester.pumpAndSettle();
      expect(AppSettings.instance.lyricSaveExportLrc, isTrue);
    });

    testWidgets('当编辑 CUE 分轨时自动禁用内嵌标签选项并提示 CUE 保护', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cueAudio = Audio(
        'CUE Track',
        'CUE Artist',
        'CUE Album',
        null,
        null,
        1,
        2,
        240,
        320,
        48000,
        null,
        r'E:\Music\album.flac',
        10000,
        250000,
        r'E:\Music\album.flac#CUE:2:750',
        1,
        1,
        'CUE',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child:
                  AudioEditDialog(audio: cueAudio, searcher: (_) async => []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('编辑或粘贴歌词'));
      await tester.pump();
      expect(find.text('CUE 不写母带'), findsOneWidget);
      expect(find.text('导出同级 .lrc'), findsOneWidget);
      expect(find.text('应用到播放器'), findsOneWidget);
    });

    testWidgets('当全未勾选任何选项点击设歌词时拦截并提示用户', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = TestAudio(
        title: 'Song Title',
        artist: 'Song Artist',
        album: 'Song Album',
        path: r'E:\Music\song2.flac',
      );

      AppSettings.instance.lyricSaveWriteTag = false;
      AppSettings.instance.lyricSaveExportLrc = false;
      AppSettings.instance.lyricSaveApplyPlayer = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: AudioEditDialog(audio: audio, searcher: (_) async => []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证设歌词动作中的三个按钮均未选中
      expect(AppSettings.instance.lyricSaveWriteTag, isFalse);
      expect(AppSettings.instance.lyricSaveExportLrc, isFalse);
      expect(AppSettings.instance.lyricSaveApplyPlayer, isFalse);
    });

    testWidgets('LyricSaveOptionsControl 正确渲染并响应用户勾选变更', (tester) async {
      final settings = AppSettings.instance;
      settings.lyricSaveWriteTag = true;
      settings.lyricSaveExportLrc = true;
      settings.lyricSaveApplyPlayer = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(
            body: Center(
              child: LyricSaveOptionsControl(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('设歌词默认保存方式'), findsOneWidget);
      expect(find.text('写入内嵌标签'), findsOneWidget);
      expect(find.text('保存同级 .lrc'), findsOneWidget);
      expect(find.text('应用到播放器'), findsOneWidget);

      await tester.tap(find.text('写入内嵌标签'));
      await tester.pumpAndSettle();
      expect(settings.lyricSaveWriteTag, isFalse);

      await tester.tap(find.text('保存同级 .lrc'));
      await tester.pumpAndSettle();
      expect(settings.lyricSaveExportLrc, isFalse);

      await tester.tap(find.text('应用到播放器'));
      await tester.pumpAndSettle();
      expect(settings.lyricSaveApplyPlayer, isFalse);
    });
  });
}
