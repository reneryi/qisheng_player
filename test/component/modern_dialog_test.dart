import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/page/playlists_page.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('ModernDialog 全局弹窗与手势静音防护测试', () {
    testWidgets('barrierDismissible 为 false 时点击遮罩不关闭且静默消费手势', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModernDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const ModernDialogFrame(
                        child: Text('Modal Dialog Content'),
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开弹窗
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Modal Dialog Content'), findsOneWidget);

      // 点击弹窗外部左上角空白遮罩区域
      await tester.tapAt(const Offset(50, 50));
      // 推进动画（包含微晃动画）
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 验证弹窗依然存在（未被关闭）且无任何异常抛出
      expect(find.text('Modal Dialog Content'), findsOneWidget);
    });

    testWidgets('barrierDismissible 为 true 时点击遮罩能平滑关闭', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModernDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => const ModernDialogFrame(
                        child: Text('Dismissible Dialog Content'),
                      ),
                    );
                  },
                  child: const Text('Open Dismissible'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开弹窗
      await tester.tap(find.text('Open Dismissible'));
      await tester.pumpAndSettle();

      expect(find.text('Dismissible Dialog Content'), findsOneWidget);

      // 点击弹窗外部左上角空白遮罩区域
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // 验证弹窗已成功关闭
      expect(find.text('Dismissible Dialog Content'), findsNothing);
    });

    testWidgets('ModernDialogFrame 完整渲染毛玻璃高斯模糊与动态取色渐变修饰', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(
            body: Center(
              child: ModernDialogFrame(
                maxWidth: 400,
                child: Text('Frame Test'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frame Test'), findsOneWidget);
      // 验证包含 BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
      // 验证包含 ClipRRect
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('歌单表单对话框重构交互测试', () {
    testWidgets('新建歌单：初始禁用、输入有效名称后激活、重名校验、提交返回', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? submittedName;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    submittedName = await showModernDialog<String>(
                      context: context,
                      builder: (context) => const NewPlaylistDialog(
                        existingNames: ['我的收藏', '摇滚精选'],
                      ),
                    );
                  },
                  child: const Text('Open New Playlist'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open New Playlist'));
      await tester.pumpAndSettle();

      // 验证标题与副标题渲染
      expect(find.text('新建歌单'), findsOneWidget);
      expect(find.text('创建专属歌单，整理您的心仪音乐收藏'), findsOneWidget);

      // 验证初始状态下“创建”按钮处于禁用态
      final createButtonFinder = find.widgetWithText(FilledButton, '创建');
      expect(createButtonFinder, findsOneWidget);
      final FilledButton initialButton = tester.widget(createButtonFinder);
      expect(initialButton.onPressed, isNull);

      // 输入已存在的名称进行重名测试
      await tester.enterText(find.byType(TextField), '我的收藏');
      await tester.pumpAndSettle();

      // 验证出现错误提示且按钮保持禁用
      expect(find.text('歌单名称已存在'), findsOneWidget);
      final FilledButton duplicateButton = tester.widget(createButtonFinder);
      expect(duplicateButton.onPressed, isNull);

      // 点击清空按钮
      await tester.tap(find.byTooltip('清空'));
      await tester.pumpAndSettle();
      expect(find.text('我的收藏'), findsNothing);

      // 输入有效的新歌单名
      await tester.enterText(find.byType(TextField), '车载民谣');
      await tester.pumpAndSettle();

      // 验证错误消失且按钮已激活
      expect(find.text('歌单名称已存在'), findsNothing);
      final FilledButton enabledButton = tester.widget(createButtonFinder);
      expect(enabledButton.onPressed, isNotNull);

      // 点击创建提交
      await tester.tap(createButtonFinder);
      await tester.pumpAndSettle();

      // 验证对话框关闭且返回了输入的新歌单名
      expect(find.text('新建歌单'), findsNothing);
      expect(submittedName, equals('车载民谣'));
    });

    testWidgets('修改歌单：初始回显旧名称、未改动时禁用保存、修改后成功提交', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? submittedName;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    submittedName = await showModernDialog<String>(
                      context: context,
                      builder: (context) => const EditPlaylistDialog(
                        initialName: '轻音乐',
                        existingNames: ['轻音乐', '古典乐'],
                      ),
                    );
                  },
                  child: const Text('Open Edit Playlist'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Edit Playlist'));
      await tester.pumpAndSettle();

      // 验证标题与原名称回显
      expect(find.text('修改歌单'), findsOneWidget);
      expect(find.text('轻音乐'), findsOneWidget);

      // 初始与原名称一致时禁用保存
      final saveButtonFinder = find.widgetWithText(FilledButton, '保存');
      expect(saveButtonFinder, findsOneWidget);
      final FilledButton initialButton = tester.widget(saveButtonFinder);
      expect(initialButton.onPressed, isNull);

      // 改为新名字
      await tester.enterText(find.byType(TextField), '睡前轻音乐');
      await tester.pumpAndSettle();

      // 按钮激活并保存
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(submittedName, equals('睡前轻音乐'));
    });
  });
}


