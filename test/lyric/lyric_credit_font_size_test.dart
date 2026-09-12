import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/audio_lyric_preview_panel.dart';
import 'package:qisheng_player/component/horizontal_lyric_view.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric_line_parser.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';

import '../test_helpers/media_test_harness.dart';

class FakeLyricViewController extends ChangeNotifier implements LyricViewController {
  @override
  double lyricFontSize = 24.0;

  @override
  double translationFontSize = 18.0;

  @override
  LyricTextAlign lyricTextAlign = LyricTextAlign.center;

  @override
  bool showTranslation = true;

  @override
  NowPlayingPagePreference get nowPlayingPagePref => AppPreference.instance.nowPlayingPagePref;

  @override
  void switchLyricTextAlign() {}

  @override
  void increaseFontSize() {
    lyricFontSize += 1;
    notifyListeners();
  }

  @override
  void decreaseFontSize() {
    lyricFontSize -= 1;
    notifyListeners();
  }

  @override
  void resetFontSize() {}

  @override
  void setFontSize(double size) {
    lyricFontSize = size;
    notifyListeners();
  }

  @override
  void toggleShowTranslation() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyricLineParser 演职员信息判定完整性测试', () {
    test('正确将作词、作曲、编曲、制作人、发行等行解析为 isCredit: true', () {
      final samples = [
        '作词: 方文山',
        '作词：方文山',
        '作曲: 周杰伦',
        '作曲：周杰伦',
        '编曲: 钟兴民',
        '编曲：林迈可',
        '制作人: 周杰伦',
        '制作人：周杰伦',
        '监制: 杨峻荣',
        '和声: 周杰伦',
        '混音: 蔡荣丰',
        '母带: 蔡荣丰',
        '吉他: 蔡科俊',
        '贝斯: 钟兴民',
        '鼓: 陈柏州',
        '键盘: 钟兴民',
        '弦乐: 钟兴民',
        '出品: 杰威尔音乐',
        '发行: 索尼音乐',
        'Lyrics by: Jay Chou',
        'Composed by: Jay Chou',
        'Arranged by: Michael Lin',
        'Produced by: Jay Chou',
        'All rights reserved',
        'Copyright 2026 JVR Music',
      ];

      for (final sample in samples) {
        final parsed = LyricLineParser.parse(sample);
        expect(parsed.isCredit, isTrue, reason: '未能将 "$sample" 识别为演职员/元数据行');
      }
    });

    test('普通歌词与时间戳文本解析为 isCredit: false', () {
      final normalLyrics = [
        '天青色等烟雨 而我在等你',
        '炊烟袅袅升起 隔江千万里',
        '在瓶底书汉隶仿前朝的飘逸',
        '就当我为遇见你伏笔',
        '月色被打捞起 晕开了结局',
        '如传世的青花瓷自顾自美丽',
        '昨天',
        '明日',
        'Hello World',
      ];

      for (final lyric in normalLyrics) {
        final parsed = LyricLineParser.parse(lyric);
        expect(parsed.isCredit, isFalse, reason: '普通歌词 "$lyric" 被误判为演职员行');
      }
    });
  });

  group('LyricViewTile 演职员字号 100% 对齐测试', () {
    testWidgets('演职员信息行字号与普通未高亮歌词完全 100% 一致 (24.0px)', (tester) async {
      final controller = FakeLyricViewController()..lyricFontSize = 24.0;

      final creditLine = LrcLine(Duration.zero, '作词：方文山', isBlank: false);
      final normalLine = LrcLine(const Duration(seconds: 5), '天青色等烟雨', isBlank: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: ChangeNotifierProvider<LyricViewController>.value(
              value: controller,
              child: Column(
                children: [
                  LyricViewTile(
                    line: creditLine,
                    opacity: 0.72,
                    isCurrentLine: false,
                    isPastLine: false,
                    distanceFromCurrent: 2,
                  ),
                  LyricViewTile(
                    line: normalLine,
                    opacity: 0.72,
                    isCurrentLine: false,
                    isPastLine: false,
                    distanceFromCurrent: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final creditText = tester.widget<Text>(find.text('作词：方文山'));
      final normalText = tester.widget<Text>(find.text('天青色等烟雨'));

      // 核心断言：演职员信息字号与普通未高亮歌词字号 100% 相等
      expect(creditText.style?.fontSize, 24.0);
      expect(normalText.style?.fontSize, 24.0);
      expect(creditText.style?.fontSize, equals(normalText.style?.fontSize));

      // 验证演职员行字重为常规 w400，保持良好层级
      expect(creditText.style?.fontWeight, FontWeight.w400);

      // 验证没有过去的 0.72 缩放与 15px clamp
      expect(creditText.style?.fontSize, isNot(lessThanOrEqualTo(15.0)));
      expect(creditText.style?.fontSize, isNot(closeTo(24.0 * 0.72, 0.5)));
    });

    testWidgets('增大歌词字号至 36.0 时，演职员字号同步等比例放大至 36.0 (彻底解除 15.0 限制)',
        (tester) async {
      final controller = FakeLyricViewController()..lyricFontSize = 36.0;

      final creditLine = LrcLine(Duration.zero, '编曲：钟兴民', isBlank: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: ChangeNotifierProvider<LyricViewController>.value(
              value: controller,
              child: LyricViewTile(
                line: creditLine,
                opacity: 0.72,
                isCurrentLine: false,
                isPastLine: false,
                distanceFromCurrent: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('编曲：钟兴民'));
      expect(text.style?.fontSize, 36.0);
      expect(text.style?.fontSize, isNot(15.0));
    });
  });

  group('ImmersiveNowPlayingView 居中杂志视图演职员字号 100% 对齐测试', () {
    testWidgets('在标准模式 (compact: false) 下演职员字号为 20.0，与普通副歌词 100% 一致', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = TestAudio(
        title: '青花瓷',
        artist: '周杰伦',
        album: '我很忙',
        path: r'E:\Music\test.flac',
      );
      final lyric = Lrc(
        [
          LrcLine(Duration.zero, '作词：方文山', isBlank: false),
          LrcLine(const Duration(seconds: 5), '天青色等烟雨', isBlank: false),
        ],
        LrcSource.local,
      );

      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyricService = FakeLyricController(lyric);
      final desktopLyric = FakeDesktopLyricController();

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const ImmersiveNowPlayingView(
            compact: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final creditAnimated = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('作词：方文山'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );
      final normalAnimated = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('天青色等烟雨'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );

      // 居中视图标准模式：副歌词 _secondaryFontSize 为 20.0
      expect(creditAnimated.style.fontSize, 20.0);
      expect(normalAnimated.style.fontSize, 20.0);
      expect(creditAnimated.style.fontSize, equals(normalAnimated.style.fontSize));
      expect(creditAnimated.style.fontSize, isNot(15.0));
    });

    testWidgets('在紧凑模式 (compact: true) 下演职员字号为 16.0，与紧凑副歌词 100% 一致', (tester) async {
      final audio = TestAudio(
        title: '青花瓷',
        artist: '周杰伦',
        album: '我很忙',
        path: r'E:\Music\test.flac',
      );
      final lyric = Lrc(
        [
          LrcLine(Duration.zero, '作曲：周杰伦', isBlank: false),
          LrcLine(const Duration(seconds: 5), '炊烟袅袅升起', isBlank: false),
        ],
        LrcSource.local,
      );

      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyricService = FakeLyricController(lyric);
      final desktopLyric = FakeDesktopLyricController();

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const ImmersiveNowPlayingView(
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final creditAnimated = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('作曲：周杰伦'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );
      final normalAnimated = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('炊烟袅袅升起'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );

      // 居中视图紧凑模式：副歌词 _secondaryFontSize 为 16.0
      expect(creditAnimated.style.fontSize, 16.0);
      expect(normalAnimated.style.fontSize, 16.0);
      expect(creditAnimated.style.fontSize, equals(normalAnimated.style.fontSize));
      expect(creditAnimated.style.fontSize, isNot(13.0));
    });
  });

  group('HorizontalLyricView 与 AudioLyricPreviewPanel 字号一致性测试', () {
    testWidgets('HorizontalLyricView 中演职员行以 14.0 像素渲染 (消除 13.5 缩小)', (tester) async {
      final audio = TestAudio(
        title: '青花瓷',
        artist: '周杰伦',
        album: '我很忙',
        path: r'E:\Music\test.flac',
      );
      final lyric = Lrc(
        [
          LrcLine(Duration.zero, '制作人：周杰伦', isBlank: false),
        ],
        LrcSource.local,
      );

      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyricService = FakeLyricController(lyric);
      final desktopLyric = FakeDesktopLyricController();

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const HorizontalLyricView(),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('制作人：周杰伦'));
      expect(text.style?.fontSize, 14.0);
      expect(text.style?.fontSize, isNot(13.5));
    });

    testWidgets('AudioLyricPreviewPanel 中演职员行以 13.0 像素渲染 (与普通未高亮行 13.0 100% 对齐)',
        (tester) async {
      final audio = TestAudio(
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        path: r'E:\Music\test.flac',
      );
      final lyric = Lrc(
        [
          LrcLine(Duration.zero, '出品：杰威尔音乐', isBlank: false),
          LrcLine(const Duration(seconds: 10), '天青色等烟雨', isBlank: false),
        ],
        LrcSource.local,
      );

      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyricService = FakeLyricController(lyric);
      final desktopLyric = FakeDesktopLyricController();

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const AudioLyricPreviewPanel(),
        ),
      );
      await tester.pumpAndSettle();

      // 找到包含 '出品：杰威尔音乐' 的 AnimatedDefaultTextStyle 祖先
      final textFinder = find.text('出品：杰威尔音乐');
      expect(textFinder, findsOneWidget);

      final animatedStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: textFinder,
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );

      expect(animatedStyle.style.fontSize, 13.0);
      expect(animatedStyle.style.fontSize, isNot(11.0));
      expect(animatedStyle.style.fontSize, isNot(12.0));
    });
  });
}
