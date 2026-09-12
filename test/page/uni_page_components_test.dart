import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/page/uni_page_components.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('SortMethodComboBox 现代菜单交互测试', () {
    testWidgets('渲染当前排序方式，打开菜单时高亮当前选中项并带有 Checkmark，点击选项切换排序', (tester) async {
      final methods = [
        SortMethodDesc<String>(
          icon: Symbols.title,
          name: '按标题排序',
          method: (list, order) {},
        ),
        SortMethodDesc<String>(
          icon: Symbols.schedule,
          name: '按时间排序',
          method: (list, order) {},
        ),
      ];

      SortMethodDesc<String> currentMethod = methods[0];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: SortMethodComboBox<String>(
                    contentList: const ['a', 'b'],
                    sortMethods: methods,
                    currSortMethod: currentMethod,
                    setSortMethod: (selected) {
                      setState(() {
                        currentMethod = selected;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证未展开前显示当前排序名称
      expect(find.text('按标题排序'), findsOneWidget);
      expect(find.text('按时间排序'), findsNothing);

      // 点击打开菜单
      await tester.tap(find.byType(SortMethodComboBox<String>));
      await tester.pumpAndSettle();

      // 菜单展开后显示所有选项
      expect(find.text('按标题排序'), findsWidgets);
      expect(find.text('按时间排序'), findsOneWidget);
      // 验证选中项带有 checkmark
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // 点击按时间排序
      await tester.tap(find.text('按时间排序'));
      await tester.pumpAndSettle();

      // 验证状态已更新
      expect(currentMethod.name, equals('按时间排序'));
      expect(find.text('按时间排序'), findsOneWidget);
    });
  });

  group('选择歌单弹窗 ModernDialogFrame 重构测试', () {
    testWidgets('AddAllToPlaylist 调起现代化毛玻璃选歌单对话框并返回选中的歌单', (tester) async {
      PLAYLISTS.clear();
      final p1 = Playlist('纯音乐集', {});
      final p2 = Playlist('车载流行', {});
      PLAYLISTS.addAll([p1, p2]);

      final controller = MultiSelectController<Audio>();

      Playlist? pickedPlaylist;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      // 模拟点击添加至歌单，调起重构后的选择歌单现代对话框
                      final addAllWidget = AddAllToPlaylist(
                        multiSelectController: controller,
                      );
                      pickedPlaylist = await addAllWidget.pickTargetPlaylistForTest(context);
                    },
                    child: const Text('打开选歌单'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开选歌单'));
      await tester.pumpAndSettle();

      // 验证现代弹窗规范
      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(find.text('选择歌单'), findsOneWidget);
      expect(find.text('将选中的歌曲添加至歌单'), findsOneWidget);
      expect(find.text('纯音乐集'), findsOneWidget);
      expect(find.text('车载流行'), findsOneWidget);

      // 点击纯音乐集
      await tester.tap(find.text('纯音乐集'));
      await tester.pumpAndSettle();

      // 验证弹窗关闭并成功返回该歌单
      expect(find.byType(ModernDialogFrame), findsNothing);
      expect(pickedPlaylist?.name, equals('纯音乐集'));
    });
  });

  group('DeleteSelectedAudios 删除歌曲现代对话框测试', () {
    testWidgets('触发删除时弹出 ModernDialogFrame，提供仅移除与删除源文件操作选项', (tester) async {
      final controller = MultiSelectController<Audio>();
      final audio1 = TestAudio(
        title: '测试音频1',
        artist: '歌手',
        album: '专辑',
        path: 'path1.mp3',
      );
      final contentList = [audio1];
      controller.selected.add(audio1);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: DeleteSelectedAudios(
                multiSelectController: controller,
                contentList: contentList,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DeleteSelectedAudios));
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsOneWidget);
      expect(find.text('删除选中歌曲'), findsOneWidget);
      expect(find.text('已选择 1 首歌曲'), findsOneWidget);
      expect(find.text('仅从播放器移除'), findsOneWidget);
      expect(find.text('删除源文件'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(ModernDialogFrame), findsNothing);
    });
  });
}
