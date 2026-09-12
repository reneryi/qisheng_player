import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/audio_lyric_preview_panel.dart';
import 'package:qisheng_player/component/horizontal_lyric_view.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_source_view.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';

import '../test_helpers/media_test_harness.dart';

class AdversarialLyricViewController extends ChangeNotifier implements LyricViewController {
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

  late TestAudio normalAudio;
  late SongSearchResult normalQQ;
  late SongSearchResult normalKugou;
  late SongSearchResult normalNetease;
  late Lrc normalLocalLrc;
  late Lrc normalOnlineLrc;

  setUp(() {
    LYRIC_SOURCES.clear();

    normalAudio = TestAudio(
      title: '测试曲目',
      artist: '测试歌手',
      album: '测试专辑',
      path: r'E:\Music\test_adversarial.flac',
    );

    normalQQ = SongSearchResult(
      ResultSource.qq,
      '测试曲目',
      '测试歌手',
      '测试专辑',
      0.95,
      qqSongId: 99901,
    );

    normalKugou = SongSearchResult(
      ResultSource.kugou,
      '测试曲目',
      '测试歌手',
      '测试专辑',
      0.82,
      kugouSongHash: 'KUGOU_ADV_HASH',
    );

    normalNetease = SongSearchResult(
      ResultSource.netease,
      '测试曲目',
      '测试歌手',
      '测试专辑',
      0.55,
      neteaseSongId: 'NETEASE_ADV_ID',
    );

    normalLocalLrc = Lrc(
      [
        LrcLine(Duration.zero, '作词：词作者', isBlank: false),
        LrcLine(const Duration(seconds: 3), '作曲：曲作者', isBlank: false),
        LrcLine(const Duration(seconds: 6), '第一句普通歌词文本', isBlank: false),
        LrcLine(const Duration(seconds: 10), '第二句普通歌词文本', isBlank: false),
      ],
      LrcSource.local,
    );

    normalOnlineLrc = Lrc(
      [
        LrcLine(Duration.zero, '作词：方文山', isBlank: false),
        LrcLine(const Duration(seconds: 5), '天青色等烟雨 而我在等你', isBlank: false),
      ],
      LrcSource.web,
    );
  });

  tearDown(() {
    LYRIC_SOURCES.clear();
  });

  // ===========================================================================
  // 1. 视口极限对抗挑战 (Viewport Limit Stress Tests)
  // ===========================================================================
  group('1. 视口极限对抗挑战 (Viewport Limit Stress Tests)', () {
    testWidgets('极限视口 300x200 下在线匹配卡片渲染无 RenderFlex overflow 异常', (tester) async {
      tester.view.physicalSize = const Size(300, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([normalQQ, normalKugou]),
                initialLocalLyricFuture: Future.value(normalLocalLrc),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '300x200 极限视口下存在布局异常');
    });

    testWidgets('极限视口 300x200 下本地歌词选项卡渲染无 RenderFlex overflow 异常', (tester) async {
      tester.view.physicalSize = const Size(300, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 设置默认使用本地歌词，使弹窗直接以本地选项卡打开
      LYRIC_SOURCES[normalAudio.path] = LyricSource(LyricSourceType.local);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([normalQQ]),
                initialLocalLyricFuture: Future.value(normalLocalLrc),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(find.text('已检测到本地歌词'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '300x200 本地选项卡下发生 RenderFlex overflow 异常');
    });

    testWidgets('低分辨率 400x300 下在线与本地选项卡来回切换无 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([normalQQ, normalKugou, normalNetease]),
                initialLocalLyricFuture: Future.value(normalLocalLrc),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 切换本地
      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 切换回在线
      await tester.tap(find.text('在线匹配歌词'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('矮屏视口 600x350 下完整渲染与列表上下滚动无 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(600, 350);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final manyResults = List.generate(
        8,
        (i) => SongSearchResult(
          ResultSource.qq,
          '曲目 $i',
          '歌手 $i',
          '专辑 $i',
          0.90 - i * 0.05,
          qqSongId: 1000 + i,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value(manyResults),
                initialLocalLyricFuture: Future.value(normalLocalLrc),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 列表滚动压力测试
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '矮屏 600x350 滚动在线列表时产生溢出');
    });

    testWidgets('TextScaler 2.0x 超大字号下 800x600 视口无 RenderFlex overflow 异常', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Center(
                child: SetLyricSourceDialog(
                  audio: normalAudio,
                  initialSearchFuture: Future.value([normalQQ, normalKugou]),
                  initialLocalLyricFuture: Future.value(normalLocalLrc),
                  onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'TextScaler 2.0x 下在线选项卡发生溢出');

      // 切换本地选项卡
      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'TextScaler 2.0x 下本地选项卡发生溢出');
    });

    testWidgets('矮屏复合挑战：600x350 视口 + TextScaler 2.0x 超大字号', (tester) async {
      tester.view.physicalSize = const Size(600, 350);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(600, 350),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Center(
                child: SetLyricSourceDialog(
                  audio: normalAudio,
                  initialSearchFuture: Future.value([normalQQ, normalKugou]),
                  initialLocalLyricFuture: Future.value(normalLocalLrc),
                  onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '600x350 + TextScaler 2.0x 出现 RenderFlex overflow');
    });

    testWidgets('极限复合挑战：400x300 小窗口 + TextScaler 2.0x 超大字号无 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 300),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Center(
                child: SetLyricSourceDialog(
                  audio: normalAudio,
                  initialSearchFuture: Future.value([normalQQ]),
                  initialLocalLyricFuture: Future.value(normalLocalLrc),
                  onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '400x300 + TextScaler 2.0x 出现 RenderFlex overflow');
    });

    testWidgets('底部展示“恢复自动匹配”时在 400x300 视口下无 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      LYRIC_SOURCES[normalAudio.path] = LyricSource(LyricSourceType.local);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([normalQQ]),
                initialLocalLyricFuture: Future.value(normalLocalLrc),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('恢复自动匹配'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // 2. 边界数据对抗挑战 (Boundary Data Stress Tests)
  // ===========================================================================
  group('2. 边界数据对抗挑战 (Boundary Data Stress Tests)', () {
    testWidgets('空歌词数据边界：Lrc 歌词行列表为空时卡片与本地页面正确展示无异常', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final emptyLrc = Lrc([], LrcSource.local);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([normalQQ]),
                initialLocalLyricFuture: Future.value(emptyLrc),
                onlineLyricBuilder: (_) => Future.value(emptyLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 在线卡片空歌词展示“暂无歌词”
      expect(find.text('暂无歌词'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 切换本地选项卡
      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();

      expect(find.text('未检测到本地歌词'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('极端超长歌曲名、艺术家名与专辑名边界条件测试', (tester) async {
      tester.view.physicalSize = const Size(500, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final superLongAudio = TestAudio(
        title: '这是一个超级无敌长的歌曲标题，包含大量测试文字用来验证排版是否会发生溢出异常，甚至包含特殊字符!@#%&*()_+=~`[]{}|:;"<>,.?/以及Emoji🎶🎵🎤🎸🎹',
        artist: '超级长的艺术家姓名第一人 feat. 超级长的艺术家姓名第二人 with 某某大型交响乐团合唱团',
        album: '极其漫长的专辑名称之宇宙终极交响史诗特别纪念版 Deluxe Remastered 2026 Anniversary Edition',
        path: r'E:\Music\super_long_track.flac',
      );

      final superLongResult = SongSearchResult(
        ResultSource.qq,
        '超级长的歌曲标题' * 10,
        '超级长歌手名字' * 8,
        '超级长专辑名字' * 8,
        0.92,
        qqSongId: 88888,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: superLongAudio,
                initialSearchFuture: Future.value([superLongResult]),
                initialLocalLyricFuture: Future.value(normalLocalLrc),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证在 500x400 下超长文字正常缩略截断，零 overflow
      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '超长标题或艺术家导致 RenderFlex overflow');
    });

    testWidgets('单行超长歌词边界：1000 字符歌词文本在预览区不产生溢出', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final superLongLine = '超长单行歌词' * 100; // 600 字符
      final ultraLrc = Lrc(
        [
          LrcLine(Duration.zero, superLongLine, isBlank: false),
        ],
        LrcSource.local,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([normalQQ]),
                initialLocalLyricFuture: Future.value(ultraLrc),
                onlineLyricBuilder: (_) => Future.value(ultraLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 在线卡片内预览行
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 本地选项卡预览
      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();

      expect(find.text('已检测到本地歌词'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '单行超长歌词导致预览区溢出');
    });

    testWidgets('零在线匹配结果边界：展示未找到匹配指引与重新检索按钮', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([]),
                initialLocalLyricFuture: Future.value(null),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('未找到匹配的在线歌词'), findsOneWidget);
      expect(find.text('可尝试重新检索或使用本地歌词'), findsOneWidget);
      expect(find.text('重新检索'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('本地无歌词文件边界：优雅展示提示文字与指引信息', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([]),
                initialLocalLyricFuture: Future.value(null),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();

      expect(find.text('未检测到本地歌词'), findsOneWidget);
      expect(find.text('同级外挂 .lrc 文件：未检测到'), findsOneWidget);
      expect(find.textContaining('可将与音频文件同名的 .lrc 歌词文件放置在音频所在目录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('匹配度分数边界测试：0.00 (0% 匹配) 与 1.00 (100% 匹配)', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final zeroScoreResult = SongSearchResult(
        ResultSource.qq,
        '零匹配歌曲',
        '未知歌手',
        '未知专辑',
        0.0,
        qqSongId: 1,
      );

      final perfectScoreResult = SongSearchResult(
        ResultSource.kugou,
        '满分匹配歌曲',
        '完美歌手',
        '完美专辑',
        1.0,
        kugouSongHash: 'PERFECT_HASH',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: normalAudio,
                initialSearchFuture: Future.value([zeroScoreResult, perfectScoreResult]),
                initialLocalLyricFuture: Future.value(null),
                onlineLyricBuilder: (_) => Future.value(normalOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0% 匹配'), findsOneWidget);
      expect(find.text('100% 匹配'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // 3. 演职员信息字号挑战 (Cast & Credits Font Size Strict 1.0x Ratio Tests)
  // ===========================================================================
  group('3. 演职员信息字号挑战 (Cast & Credits Font Size Strict 1.0x Ratio Tests)', () {
    testWidgets('LyricViewTile: 字号设为 12.0px 时，演职员行与未高亮歌词行字体尺寸比严格恒为 1.0 (100%)', (tester) async {
      final controller = AdversarialLyricViewController()..lyricFontSize = 12.0;

      final creditLine = LrcLine(Duration.zero, '作词：方文山', isBlank: false);
      final normalLine = LrcLine(const Duration(seconds: 5), '天青色等烟雨 而我在等你', isBlank: false);

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
      final normalText = tester.widget<Text>(find.text('天青色等烟雨 而我在等你'));

      final creditFontSize = creditText.style?.fontSize;
      final normalFontSize = normalText.style?.fontSize;

      expect(creditFontSize, 12.0);
      expect(normalFontSize, 12.0);

      // 比值严格恒为 1.0 (100%)
      final ratio = creditFontSize! / normalFontSize!;
      expect(ratio, 1.0, reason: '12px 下演职员行与未高亮歌词行字体尺寸比值偏离 1.0');
    });

    testWidgets('LyricViewTile: 字号设为 24.0px 时，演职员行与未高亮歌词行字体尺寸比严格恒为 1.0 (100%)', (tester) async {
      final controller = AdversarialLyricViewController()..lyricFontSize = 24.0;

      final creditLine = LrcLine(Duration.zero, '作曲：周杰伦', isBlank: false);
      final normalLine = LrcLine(const Duration(seconds: 5), '炊烟袅袅升起 隔江千万里', isBlank: false);

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

      final creditText = tester.widget<Text>(find.text('作曲：周杰伦'));
      final normalText = tester.widget<Text>(find.text('炊烟袅袅升起 隔江千万里'));

      final creditFontSize = creditText.style?.fontSize;
      final normalFontSize = normalText.style?.fontSize;

      expect(creditFontSize, 24.0);
      expect(normalFontSize, 24.0);

      // 比值严格恒为 1.0 (100%)
      final ratio = creditFontSize! / normalFontSize!;
      expect(ratio, 1.0, reason: '24px 下演职员行与未高亮歌词行字体尺寸比值偏离 1.0');
    });

    testWidgets('LyricViewTile: 字号设为 48.0px 极端大字号时，演职员行与未高亮歌词行字体尺寸比严格恒为 1.0 (100%)', (tester) async {
      final controller = AdversarialLyricViewController()..lyricFontSize = 48.0;

      final creditLine = LrcLine(Duration.zero, '编曲：钟兴民', isBlank: false);
      final normalLine = LrcLine(const Duration(seconds: 5), '在瓶底书汉隶仿前朝的飘逸', isBlank: false);

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

      final creditText = tester.widget<Text>(find.text('编曲：钟兴民'));
      final normalText = tester.widget<Text>(find.text('在瓶底书汉隶仿前朝的飘逸'));

      final creditFontSize = creditText.style?.fontSize;
      final normalFontSize = normalText.style?.fontSize;

      expect(creditFontSize, 48.0);
      expect(normalFontSize, 48.0);

      // 比值严格恒为 1.0 (100%)
      final ratio = creditFontSize! / normalFontSize!;
      expect(ratio, 1.0, reason: '48px 极端大字号下演职员行与未高亮歌词行字体尺寸比值偏离 1.0 (仍有 clamp 遗留)');
    });

    testWidgets('LyricViewTile: 演职员行在高亮聚焦 (isCurrentLine: true) 时字号保持 base fontSize 不膨胀且字重维持 w400', (tester) async {
      final controller = AdversarialLyricViewController()..lyricFontSize = 24.0;

      final creditLine = LrcLine(Duration.zero, '制作人：周杰伦', isBlank: false);
      final normalLine = LrcLine(const Duration(seconds: 5), '就当我为遇见你伏笔', isBlank: false);

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
                    opacity: 1.0,
                    isCurrentLine: true, // 高亮聚焦
                    isPastLine: false,
                    distanceFromCurrent: 0,
                  ),
                  LyricViewTile(
                    line: normalLine,
                    opacity: 1.0,
                    isCurrentLine: true, // 高亮聚焦普通行
                    isPastLine: false,
                    distanceFromCurrent: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final creditText = tester.widget<Text>(find.text('制作人：周杰伦'));
      final normalText = tester.widget<Text>(find.text('就当我为遇见你伏笔'));

      // 演职员行在高亮时不加 4px，保持 24.0px；普通行膨胀为 28.0px
      expect(creditText.style?.fontSize, 24.0);
      expect(normalText.style?.fontSize, 28.0);
      // 演职员行高亮时不加粗，保持 w400；普通行高亮为 w700
      expect(creditText.style?.fontWeight, FontWeight.w400);
      expect(normalText.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('ImmersiveNowPlayingView: 标准 (20.0px) 与紧凑 (16.0px) 模式下演职员字号比值严格为 1.0', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lyric = Lrc(
        [
          LrcLine(Duration.zero, '混音：蔡荣丰', isBlank: false),
          LrcLine(const Duration(seconds: 5), '月色被打捞起 晕开了结局', isBlank: false),
        ],
        LrcSource.local,
      );

      final playback = FakePlaybackController(audio: normalAudio, queue: [normalAudio]);
      final lyricService = FakeLyricController(lyric);
      final desktopLyric = FakeDesktopLyricController();

      // 标准模式
      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const ImmersiveNowPlayingView(compact: false),
        ),
      );
      await tester.pumpAndSettle();

      final creditAnimatedStd = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('混音：蔡荣丰'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );
      final normalAnimatedStd = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('月色被打捞起 晕开了结局'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );

      expect(creditAnimatedStd.style.fontSize, 20.0);
      expect(normalAnimatedStd.style.fontSize, 20.0);
      expect(creditAnimatedStd.style.fontSize! / normalAnimatedStd.style.fontSize!, 1.0);

      // 紧凑模式
      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const ImmersiveNowPlayingView(compact: true),
        ),
      );
      await tester.pumpAndSettle();

      final creditAnimatedCmp = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('混音：蔡荣丰'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );
      final normalAnimatedCmp = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('月色被打捞起 晕开了结局'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );

      expect(creditAnimatedCmp.style.fontSize, 16.0);
      expect(normalAnimatedCmp.style.fontSize, 16.0);
      expect(creditAnimatedCmp.style.fontSize! / normalAnimatedCmp.style.fontSize!, 1.0);
    });

    testWidgets('AudioLyricPreviewPanel 与 HorizontalLyricView: 演职员字号比值严格恒为 1.0', (tester) async {
      final lyric = Lrc(
        [
          LrcLine(Duration.zero, '监制：杨峻荣', isBlank: false),
          LrcLine(const Duration(seconds: 10), '如传世的青花瓷自顾自美丽', isBlank: false),
        ],
        LrcSource.local,
      );

      final playback = FakePlaybackController(audio: normalAudio, queue: [normalAudio]);
      final lyricService = FakeLyricController(lyric);
      final desktopLyric = FakeDesktopLyricController();

      // AudioLyricPreviewPanel
      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const AudioLyricPreviewPanel(),
        ),
      );
      await tester.pumpAndSettle();

      final creditPanelStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('监制：杨峻荣'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );
      final normalPanelStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.ancestor(
          of: find.text('如传世的青花瓷自顾自美丽'),
          matching: find.byType(AnimatedDefaultTextStyle),
        ).first,
      );

      expect(creditPanelStyle.style.fontSize, 13.0);
      expect(normalPanelStyle.style.fontSize, 13.0);
      expect(creditPanelStyle.style.fontSize! / normalPanelStyle.style.fontSize!, 1.0);

      // HorizontalLyricView
      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyricService,
          desktopLyricController: desktopLyric,
          child: const HorizontalLyricView(),
        ),
      );
      await tester.pumpAndSettle();

      final horizontalText = tester.widget<Text>(find.text('监制：杨峻荣'));
      expect(horizontalText.style?.fontSize, 14.0);
      expect(horizontalText.style?.fontWeight, FontWeight.w400);
    });
  });
}
