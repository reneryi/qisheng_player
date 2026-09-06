import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('PageScaffold places title action beside title', (tester) async {
    tester.view.physicalSize = const Size(1400, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: Scaffold(
          body: PageScaffold(
            title: '音乐',
            subtitle: '263 首乐曀',
            titleAction: IconButton(
              key: const ValueKey('title-search'),
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
            secondaryActions: [
              IconButton(
                key: const ValueKey('sort-action'),
                onPressed: () {},
                icon: const Icon(Icons.sort),
              ),
            ],
            body: const Placeholder(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleCenter = tester.getCenter(find.text('音乐'));
    final searchCenter =
        tester.getCenter(find.byKey(const ValueKey('title-search')));
    expect(searchCenter.dx, greaterThan(titleCenter.dx));
    expect((searchCenter.dy - titleCenter.dy).abs(), lessThan(8));
  });

  testWidgets('PageScaffold keeps primary and secondary actions on one row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: Scaffold(
          body: PageScaffold(
            title: '文件夹',
            subtitle: '5 个文件夹',
            primaryAction: FilledButton(
              key: const ValueKey('primary-action'),
              onPressed: () {},
              child: const Text('管理文件夹'),
            ),
            secondaryActions: [
              OutlinedButton(
                key: const ValueKey('sort-action'),
                onPressed: () {},
                child: const Text('路径'),
              ),
              IconButton(
                key: const ValueKey('view-action'),
                onPressed: () {},
                icon: const Icon(Icons.view_list),
              ),
            ],
            body: const Placeholder(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final primaryCenter =
        tester.getCenter(find.byKey(const ValueKey('primary-action')));
    final sortCenter =
        tester.getCenter(find.byKey(const ValueKey('sort-action')));
    final viewRight =
        tester.getTopRight(find.byKey(const ValueKey('view-action'))).dx;
    expect((primaryCenter.dy - sortCenter.dy).abs(), lessThan(4));
    expect(viewRight, greaterThan(1320));
  });

  testWidgets(
      'PageScaffold keeps actions on the same header row on narrower desktop widths',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(980, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: Scaffold(
          body: PageScaffold(
            title: '媒体庀',
            subtitle: '测试头部布局',
            primaryAction: FilledButton(
              onPressed: () {},
              child: const Text('主操佀'),
            ),
            secondaryActions: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('筛选'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('排序'),
              ),
            ],
            body: const Placeholder(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final primaryCenter = tester.getCenter(find.text('主操佀'));
    final filterCenter = tester.getCenter(find.text('筛选'));
    final sortCenter = tester.getCenter(find.text('排序'));

    expect((primaryCenter.dy - filterCenter.dy).abs(), lessThan(6));
    expect((filterCenter.dy - sortCenter.dy).abs(), lessThan(6));
  });

  testWidgets('PageScaffold empty header gap does not hit action widgets',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: Scaffold(
          body: PageScaffold(
            title: '音乐',
            subtitle: '263 首乐曀',
            primaryAction: FilledButton(
              key: const ValueKey('shuffle-action'),
              onPressed: () {},
              child: const Text('随机播放'),
            ),
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 280,
                child: TextField(
                  key: const ValueKey('header-gap-focus-field'),
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: '筛选'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleRect = tester.getRect(find.text('音乐'));
    final actionRect =
        tester.getRect(find.byKey(const ValueKey('shuffle-action')));
    final hitPoint = Offset(
      (titleRect.right + actionRect.left) / 2,
      titleRect.center.dy,
    );
    final hitWidgets = _hitWidgetTypes(tester.hitTestOnBinding(hitPoint));

    expect(hitWidgets, isNot(contains('FilledButton')));
    expect(hitWidgets, isNot(contains('ButtonStyleButton')));
    expect(hitWidgets, isNot(contains('IconButton')));
    expect(hitWidgets, isNot(contains('GestureDetector')));

    await tester.tap(find.byKey(const ValueKey('header-gap-focus-field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(hitPoint);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });
}

List<String> _hitWidgetTypes(HitTestResult result) {
  return result.path.map((entry) {
    final target = entry.target;
    if (target is RenderObject) {
      final creator = target.debugCreator;
      final widget =
          creator == null ? null : (creator as dynamic).element.widget;
      if (widget != null) {
        return widget.runtimeType.toString();
      }
    }
    return target.runtimeType.toString();
  }).toList(growable: false);
}
