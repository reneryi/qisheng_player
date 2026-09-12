import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/ui/modern_dropdown.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('ModernDropdown 现代下拉菜单组件专项测试', () {
    testWidgets('渲染折叠初始态：显示选中项文本、说明与前缀图标', (tester) async {
      final items = [
        const ModernDropdownItem<String>(
          value: 'opt1',
          label: '选项一',
          description: '说明一',
          isRecommended: true,
          tag: '推荐',
        ),
        const ModernDropdownItem<String>(
          value: 'opt2',
          label: '选项二',
          description: '说明二',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ModernDropdown<String>(
                  value: 'opt1',
                  labelText: '测试标签',
                  prefixIcon: const Icon(Symbols.tune),
                  items: items,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('测试标签'), findsOneWidget);
      expect(find.text('选项一'), findsOneWidget);
      expect(find.text('说明一'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
      expect(find.byIcon(Symbols.tune), findsOneWidget);
      expect(find.byIcon(Symbols.keyboard_arrow_down_rounded), findsOneWidget);

      // 菜单未展开时，未选中的选项二不在菜单树中呈现
      expect(find.text('选项二'), findsNothing);
    });

    testWidgets('点击触发卡片平滑展开菜单，点击选项触发 onChanged 回调并自动收起', (tester) async {
      String? selectedValue = 'opt1';
      final items = [
        const ModernDropdownItem<String>(
          value: 'opt1',
          label: '选项一',
          description: '说明一',
        ),
        const ModernDropdownItem<String>(
          value: 'opt2',
          label: '选项二',
          description: '说明二',
          isRecommended: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 340,
                    child: ModernDropdown<String>(
                      value: selectedValue,
                      labelText: '模式选择',
                      items: items,
                      onChanged: (val) {
                        setState(() => selectedValue = val);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击展开
      await tester.tap(find.byType(ModernDropdown<String>));
      await tester.pumpAndSettle();

      // 菜单展开后，可同时查找到选项一与选项二
      expect(find.text('选项二'), findsOneWidget);
      expect(find.text('说明二'), findsOneWidget);

      // 点击选项二
      await tester.tap(find.text('选项二'));
      await tester.pumpAndSettle();

      // 验证状态已更新，且选项二已成为选中项显示在触发卡片中
      expect(selectedValue, equals('opt2'));
      expect(find.text('选项二'), findsOneWidget);
    });

    testWidgets('value 为空时渲染 hintText 占位文本', (tester) async {
      final items = [
        const ModernDropdownItem<int>(value: 1, label: '第一项'),
        const ModernDropdownItem<int>(value: 2, label: '第二项'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ModernDropdown<int>(
                  value: null,
                  hintText: '请选择分类',
                  items: items,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('请选择分类'), findsOneWidget);
    });

    testWidgets('极窄屏幕或紧凑视口下无溢出报错', (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final items = List.generate(
        8,
        (i) => ModernDropdownItem<int>(
          value: i,
          label: '超长文本选项标题第 $i 项适配测试',
          description: '这里是较长的一段辅助描述文本，用于验证截断与自适应',
          isRecommended: i == 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ModernDropdown<int>(
                  value: 0,
                  labelText: '高分屏自适应选择',
                  items: items,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // 打开菜单
      await tester.tap(find.byType(ModernDropdown<int>));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('放置在水平无约束父级（如 Row）中正常回退默认宽度，不发生 isFinite 断言异常', (tester) async {
      final items = [
        const ModernDropdownItem<String>(value: '1', label: '项目一'),
        const ModernDropdownItem<String>(value: '2', label: '项目二'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ModernDropdown<String>(
                    value: '1',
                    items: items,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('项目一'), findsOneWidget);

      await tester.tap(find.byType(ModernDropdown<String>));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('项目二'), findsOneWidget);
    });

    testWidgets('在狭窄宽度下长标题标签自适应省略，不抛出 RenderFlex 溢出异常', (tester) async {
      final items = [
        const ModernDropdownItem<String>(
          value: 'long',
          label: '超长标题文本超长标题文本超长标题文本超长标题文本',
          description: '超长辅助说明文本超长辅助说明文本超长辅助说明文本',
          tag: '推荐',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: ModernDropdown<String>(
                  value: 'long',
                  items: items,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('推荐'), findsOneWidget);
    });
  });
}
