import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_source_view.dart';

import '../../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAudio testAudio;
  late SongSearchResult qqResult;
  late SongSearchResult kugouResult;
  late SongSearchResult neteaseResult;
  late Lrc mockLocalLrc;
  late Lrc mockOnlineLrc;

  setUp(() {
    LYRIC_SOURCES.clear();

    testAudio = TestAudio(
      title: '青花瓷',
      artist: '周杰伦',
      album: '我很忙',
      path: r'E:\Music\周杰伦 - 青花瓷.flac',
    );

    qqResult = SongSearchResult(
      ResultSource.qq,
      '青花瓷',
      '周杰伦',
      '我很忙',
      0.96,
      qqSongId: 101,
    );

    kugouResult = SongSearchResult(
      ResultSource.kugou,
      '青花瓷',
      '周杰伦',
      '我很忙',
      0.88,
      kugouSongHash: 'KUGOU_HASH_123',
    );

    neteaseResult = SongSearchResult(
      ResultSource.netease,
      '青花瓷 (Live)',
      '周杰伦',
      '演唱会',
      0.65,
      neteaseSongId: 'NETEASE_ID_456',
    );

    mockLocalLrc = Lrc(
      [
        LrcLine(Duration.zero, '素胚勾勒出青花笔锋浓转淡', isBlank: false),
        LrcLine(const Duration(seconds: 5), '瓶身描绘的牡丹一如你初妆', isBlank: false),
        LrcLine(const Duration(seconds: 10), '冉冉檀香透过窗心事我了然', isBlank: false),
      ],
      LrcSource.local,
    );

    mockOnlineLrc = Lrc(
      [
        LrcLine(Duration.zero, '天青色等烟雨 而我在等你', isBlank: false),
        LrcLine(const Duration(seconds: 5), '炊烟袅袅升起 隔江千万里', isBlank: false),
      ],
      LrcSource.web,
    );
  });

  tearDown(() {
    LYRIC_SOURCES.clear();
  });

  group('SetLyricSourceDialog 现代规范与结构渲染测试', () {
    testWidgets('正确渲染 ModernDialogFrame、现代图标徽标、标题、副标题与关闭按钮', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([qqResult, kugouResult, neteaseResult]),
                initialLocalLyricFuture: Future.value(mockLocalLrc),
                onlineLyricBuilder: (_) => Future.value(mockOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 ModernDialogFrame 规范
      expect(find.byType(ModernDialogFrame), findsOneWidget);

      // 验证顶部 Header: 图标徽标、标题、副标题、关闭按钮
      expect(find.byIcon(Symbols.lyrics_rounded), findsOneWidget);
      expect(find.text('歌词源偏好设置'), findsOneWidget);
      expect(find.text('为当前播放歌曲指定特定平台或本地歌词源'), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);

      // 验证 SegmentedButton
      expect(find.text('在线匹配歌词'), findsOneWidget);
      expect(find.text('本地音频歌词'), findsOneWidget);
    });

    testWidgets('点击关闭按钮可正常退出弹窗', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModernDialog<void>(
                    context: context,
                    builder: (dialogCtx) => SetLyricSourceDialog(
                      audio: testAudio,
                      initialSearchFuture: Future.value([]),
                      initialLocalLyricFuture: Future.value(null),
                    ),
                  );
                },
                child: const Text('打开弹窗'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开弹窗'));
      await tester.pumpAndSettle();
      expect(find.byType(SetLyricSourceDialog), findsOneWidget);

      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(SetLyricSourceDialog), findsNothing);
    });
  });

  group('SetLyricSourceDialog 选项卡切换与卡片渲染测试', () {
    testWidgets('SegmentedButton 可在在线匹配与本地歌词间平滑切换', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([qqResult, kugouResult]),
                initialLocalLyricFuture: Future.value(mockLocalLrc),
                onlineLyricBuilder: (_) => Future.value(mockOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始应在在线匹配选项卡
      expect(find.text('QQ音乐'), findsOneWidget);
      expect(find.text('酷狗音乐'), findsOneWidget);

      // 点击本地音频歌词
      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();

      // 验证本地歌词内容呈现
      expect(find.text('已检测到本地歌词'), findsOneWidget);
      expect(find.text('3 行歌词'), findsOneWidget);
      expect(find.text('歌词内容预览：'), findsOneWidget);
      expect(find.text('设为本地歌词'), findsOneWidget);

      // 切换回在线匹配歌词
      await tester.tap(find.text('在线匹配歌词'));
      await tester.pumpAndSettle();
      expect(find.text('QQ音乐'), findsOneWidget);
    });

    testWidgets('在线匹配卡片正确渲染平台微徽标、匹配度指示及操作按钮', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([qqResult, kugouResult, neteaseResult]),
                initialLocalLyricFuture: Future.value(null),
                onlineLyricBuilder: (_) => Future.value(mockOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证三个平台微徽标
      expect(find.text('QQ音乐'), findsOneWidget);
      expect(find.text('酷狗音乐'), findsOneWidget);
      expect(find.text('网易云音乐'), findsOneWidget);

      // 验证匹配度
      expect(find.text('96% 匹配'), findsOneWidget);
      expect(find.text('88% 匹配'), findsOneWidget);
      expect(find.text('65% 匹配'), findsOneWidget);

      // 验证高匹配度图标
      expect(find.byIcon(Symbols.verified_rounded), findsNWidgets(2));

      // 验证歌词格式与实时预览行
      expect(find.text('LRC'), findsNWidgets(3));
      expect(find.text('当前：天青色等烟雨 而我在等你'), findsNWidgets(3));

      // 验证设为默认操作按钮
      expect(find.text('设为默认'), findsNWidgets(3));
    });
  });

  group('SetLyricSourceDialog 设为默认与恢复自动匹配交互测试', () {
    testWidgets('点击在线歌词设为默认成功更新 LYRIC_SOURCES', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      expect(LYRIC_SOURCES[testAudio.path], isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([qqResult]),
                initialLocalLyricFuture: Future.value(null),
                onlineLyricBuilder: (_) => Future.value(mockOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final setDefaultBtn = find.text('设为默认');
      expect(setDefaultBtn, findsOneWidget);
      await tester.tap(setDefaultBtn);
      await tester.pumpAndSettle();

      // 验证已更新 LYRIC_SOURCES
      final source = LYRIC_SOURCES[testAudio.path];
      expect(source, isNotNull);
      expect(source!.source, LyricSourceType.qq);
      expect(source.qqSongId, 101);
    });

    testWidgets('点击设为本地歌词成功更新 LYRIC_SOURCES 为 local', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([]),
                initialLocalLyricFuture: Future.value(mockLocalLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 切换到本地 Tab
      await tester.tap(find.text('本地音频歌词'));
      await tester.pumpAndSettle();

      // 点击设为本地歌词
      await tester.tap(find.text('设为本地歌词'));
      await tester.pumpAndSettle();

      // 验证内存 Map 更新为 local
      expect(LYRIC_SOURCES[testAudio.path]?.source, LyricSourceType.local);
    });

    testWidgets('当已存在自定义偏好时展示恢复自动匹配按钮，点击后清除指定', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      LYRIC_SOURCES[testAudio.path] = LyricSource(LyricSourceType.local);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([]),
                initialLocalLyricFuture: Future.value(mockLocalLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 此时当前偏好为本地，自动默认在本地 Tab
      expect(find.text('当前默认'), findsOneWidget);
      expect(find.text('恢复自动匹配'), findsOneWidget);

      // 点击恢复自动匹配
      await tester.tap(find.text('恢复自动匹配'));
      await tester.pumpAndSettle();

      expect(LYRIC_SOURCES[testAudio.path], isNull);
    });
  });

  group('SetLyricSourceDialog 弹性视口抗溢出测试 (Anti-Overflow)', () {
    testWidgets('在 600x380 矮屏视口下无 RenderFlex overflow 异常', (tester) async {
      tester.view.physicalSize = const Size(600, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([qqResult, kugouResult, neteaseResult]),
                initialLocalLyricFuture: Future.value(mockLocalLrc),
                onlineLyricBuilder: (_) => Future.value(mockOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证弹窗成功渲染且无任何 overflow 异常
      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('在 400x300 极小低分辨率视口下无 RenderFlex overflow 异常', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SetLyricSourceDialog(
                audio: testAudio,
                initialSearchFuture: Future.value([qqResult]),
                initialLocalLyricFuture: Future.value(mockLocalLrc),
                onlineLyricBuilder: (_) => Future.value(mockOnlineLrc),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
