import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/page/settings_page/create_issue.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/utils.dart';

ThemeData _buildTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SettingsIssuePage renders PageScaffold, CpSurface cards, input fields and action bar',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          theme: _buildTheme(),
          home: const Scaffold(
            body: SettingsIssuePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证 PageScaffold 头部结构与标题
      expect(find.byType(PageScaffold), findsOneWidget);
      expect(find.text('报告问题'), findsOneWidget);
      expect(
        find.text('提交软件缺陷、崩溃异常或改进建议，帮助歧声播放器变得更好。'),
        findsOneWidget,
      );

      // 2. 验证顶部返回按钮与图标
      expect(find.byTooltip('返回设置'), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_back_rounded), findsAtLeast(1));

      // 3. 验证 CpSurface 磨砂卡片层级
      expect(find.byType(CpSurface), findsAtLeast(3));

      // 4. 验证问题信息卡片内容与输入框
      expect(find.text('问题信息'), findsOneWidget);
      expect(find.text('问题标题'), findsOneWidget);
      expect(find.text('问题详细描述'), findsOneWidget);

      // 5. 验证运行日志与环境卡片及控制按键
      expect(find.text('运行日志与环境'), findsOneWidget);
      expect(find.byKey(const ValueKey('copy-log-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('refresh-log-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-log-btn')), findsOneWidget);

      // 验证诊断日志中包含播放器版本信息
      expect(find.textContaining('歧声播放器运行诊断日志'), findsOneWidget);
      expect(find.textContaining('v${AppSettings.version}'), findsOneWidget);

      // 6. 验证底部操作栏按钮
      expect(find.byKey(const ValueKey('back-to-settings-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-github-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-inapp-btn')), findsOneWidget);
      expect(find.text('在 GitHub 网页提交'), findsOneWidget);
      expect(find.text('应用内提交'), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsIssuePage header back button pops the page back to settings route',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: app_paths.SETTINGS_PAGE,
        routes: [
          GoRoute(
            path: app_paths.SETTINGS_PAGE,
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey('goto-issue-btn'),
                  onPressed: () => context.push(app_paths.SETTINGS_ISSUE_PAGE),
                  child: const Text('进入问题反馈页'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: app_paths.SETTINGS_ISSUE_PAGE,
            builder: (context, state) => const Scaffold(
              body: SettingsIssuePage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          theme: _buildTheme(),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      // 处于设置页
      expect(find.byKey(const ValueKey('goto-issue-btn')), findsOneWidget);
      expect(find.byType(SettingsIssuePage), findsNothing);

      // 点击进入问题反馈页
      await tester.tap(find.byKey(const ValueKey('goto-issue-btn')));
      await tester.pumpAndSettle();

      // 成功显示问题反馈页
      expect(find.byType(SettingsIssuePage), findsOneWidget);

      // 点击顶部标题旁的返回按钮
      await tester.tap(find.byTooltip('返回设置'));
      await tester.pumpAndSettle();

      // 验证已平滑返回设置页
      expect(find.byType(SettingsIssuePage), findsNothing);
      expect(find.byKey(const ValueKey('goto-issue-btn')), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsIssuePage footer back button pops the page back to settings route',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: app_paths.SETTINGS_PAGE,
        routes: [
          GoRoute(
            path: app_paths.SETTINGS_PAGE,
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey('goto-issue-btn'),
                  onPressed: () => context.push(app_paths.SETTINGS_ISSUE_PAGE),
                  child: const Text('进入问题反馈页'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: app_paths.SETTINGS_ISSUE_PAGE,
            builder: (context, state) => const Scaffold(
              body: SettingsIssuePage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          theme: _buildTheme(),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goto-issue-btn')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsIssuePage), findsOneWidget);

      // 点击底部操作栏的“返回设置”按钮
      await tester.tap(find.byKey(const ValueKey('back-to-settings-btn')));
      await tester.pumpAndSettle();

      // 验证已平滑退出
      expect(find.byType(SettingsIssuePage), findsNothing);
      expect(find.byKey(const ValueKey('goto-issue-btn')), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsIssuePage log actions: clear, refresh and copy function correctly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? mockClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            mockClipboardText = (methodCall.arguments as Map?)?['text'] as String?;
            return null;
          } else if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': mockClipboardText};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          theme: _buildTheme(),
          home: const Scaffold(
            body: SettingsIssuePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始状态下存在诊断日志
      expect(find.textContaining('歧声播放器运行诊断日志'), findsOneWidget);

      // 1. 测试清空日志
      await tester.tap(find.byKey(const ValueKey('clear-log-btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('歧声播放器运行诊断日志'), findsNothing);
      expect(find.text('日志已清空'), findsOneWidget);

      // 2. 测试刷新日志
      await tester.tap(find.byKey(const ValueKey('refresh-log-btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('歧声播放器运行诊断日志'), findsOneWidget);
      expect(find.text('日志已刷新'), findsOneWidget);

      // 3. 测试复制日志到剪贴板
      await tester.tap(find.byKey(const ValueKey('copy-log-btn')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('日志已复制到剪贴板'), findsOneWidget);
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, contains('歧声播放器运行诊断日志'));
      expect(clipboardData?.text, contains('v${AppSettings.version}'));
    },
  );

  testWidgets(
    'SettingsIssuePage "在 GitHub 网页提交" creates pre-filled URI with title, desc and diagnostics',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? launchedUri;

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          theme: _buildTheme(),
          home: Scaffold(
            body: SettingsIssuePage(
              onLaunchUrl: ({required String uri}) async {
                launchedUri = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题与描述
      final titleFinder = find.widgetWithText(TextField, '问题标题');
      final descFinder = find.widgetWithText(TextField, '问题详细描述');

      await tester.enterText(titleFinder, '音频播放时偶发无声');
      await tester.enterText(descFinder, '重现步骤：播放 FLAC 格式音频，快进到 30 秒时无声音输出。');
      await tester.pumpAndSettle();

      // 点击“在 GitHub 网页提交”
      await tester.tap(find.byKey(const ValueKey('submit-github-btn')));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      final uri = Uri.parse(launchedUri!);
      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(
        uri.path,
        '/${AppSettings.releaseRepoOwner}/${AppSettings.releaseRepoName}/issues/new',
      );
      expect(uri.queryParameters['title'], '音频播放时偶发无声');
      final body = uri.queryParameters['body'] ?? '';
      expect(body, contains('重现步骤：播放 FLAC 格式音频，快进到 30 秒时无声音输出。'));
      expect(body, contains('歧声播放器版本: ${AppSettings.version}'));
      expect(body, contains('运行日志'));
      expect(body, contains('歧声播放器运行诊断日志'));
    },
  );

  testWidgets(
    'SettingsIssuePage in-app submit validates empty title and notifies if token unconfigured',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: SCAFFOLD_MESSAGER,
          theme: _buildTheme(),
          home: const Scaffold(
            body: SettingsIssuePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 标题为空时点击提交
      await tester.tap(find.byKey(const ValueKey('submit-inapp-btn')));
      await tester.pumpAndSettle();

      expect(find.text('请输入问题标题'), findsOneWidget);

      // 2. 填入标题后点击提交（默认未配置 token）
      final titleFinder = find.widgetWithText(TextField, '问题标题');
      await tester.enterText(titleFinder, '某些界面缩放异常');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('submit-inapp-btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('应用内反馈 Token 未配置，请点击“在 GitHub 网页提交”'),
        findsOneWidget,
      );
    },
  );

  testWidgets('CreateIssueTile renders properly and has bug_report icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: const Scaffold(
          body: CreateIssueTile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报告问题'), findsOneWidget);
    expect(find.text('创建问题'), findsOneWidget);
    expect(find.byIcon(Symbols.bug_report_rounded), findsOneWidget);
  });
}
