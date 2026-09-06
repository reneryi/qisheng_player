import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/side_nav.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';

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
  test('table grid offset follows max-extent delegate column calculation', () {
    expect(
      resolveUniPageGridOffset(
        index: 6,
        crossAxisExtent: 800,
        maxCrossAxisExtent: 300,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      144,
    );
    expect(
      resolveUniPageGridOffset(
        index: 3,
        crossAxisExtent: 475,
        maxCrossAxisExtent: 300,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      72,
    );
  });

  test('cover grid offset derives row height from the child aspect ratio', () {
    final offset = resolveUniPageGridOffset(
      index: 4,
      crossAxisExtent: 700,
      maxCrossAxisExtent: 220,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.72,
    );

    expect(offset, closeTo(325.259, 0.001));
  });

  test('table offset follows the side nav reflow geometry', () {
    double offsetAt(double progress, double currentExtent) {
      return resolveSideNavTransitionGridOffset(
        index: 4,
        crossAxisExtent: currentExtent,
        expansionProgress: progress,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 300,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      );
    }

    expect(offsetAt(0, 1250), 0);
    expect(offsetAt(0.5, 1208), 36);
    expect(offsetAt(1, 1166), 72);
  });

  testWidgets('table items continuously reflow between column counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Rect> pumpGrid(double progress, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SideNavAnimatedGridDelegate(
                  expansionProgress: progress,
                  sideNavWidthDelta: 84,
                  maxCrossAxisExtent: 300,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('animated-grid-item-$index'),
                  child: Text('$index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(
        find.byKey(const ValueKey('animated-grid-item-4')),
      );
    }

    final collapsedRect = await pumpGrid(0, 1250);
    final halfwayRect = await pumpGrid(0.5, 1208);
    final expandedRect = await pumpGrid(1, 1166);

    expect(halfwayRect.top, closeTo(36, 0.01));
    expect(
      halfwayRect.top,
      closeTo((collapsedRect.top + expandedRect.top) / 2, 0.01),
    );
    expect(
      halfwayRect.width,
      closeTo((collapsedRect.width + expandedRect.width) / 2, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsing table reflow stages horizontal and vertical motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Rect> pumpGrid(double progress, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SideNavAnimatedGridDelegate(
                  expansionProgress: progress,
                  sideNavWidthDelta: 84,
                  reflowCollapsing: true,
                  maxCrossAxisExtent: 300,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('collapsing-grid-item-$index'),
                  child: Text('$index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(
        find.byKey(const ValueKey('collapsing-grid-item-4')),
      );
    }

    final expandedRect = await pumpGrid(1, 1166);
    final earlyRect = await pumpGrid(0.75, 1187);
    final halfwayRect = await pumpGrid(0.5, 1208);
    final collapsedRect = await pumpGrid(0, 1250);

    expect(expandedRect.top, 72);
    expect(collapsedRect.top, 0);
    expect(earlyRect.top, lessThan(expandedRect.top));
    expect(earlyRect.top, greaterThan(halfwayRect.top));
    expect(halfwayRect.top, greaterThan(collapsedRect.top));
    expect(earlyRect.left, greaterThan(expandedRect.left));
    expect(halfwayRect.left, greaterThan(earlyRect.left));
    expect(collapsedRect.left, greaterThan(halfwayRect.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('interpolated table grid remains virtualized while scrolled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = ScrollController(initialScrollOffset: 720);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1208,
            height: 400,
            child: GridView.builder(
              controller: controller,
              gridDelegate: const SideNavAnimatedGridDelegate(
                expansionProgress: 0.5,
                sideNavWidthDelta: 84,
                maxCrossAxisExtent: 300,
                mainAxisExtent: 64,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 300,
              itemBuilder: (_, index) => SizedBox(
                key: ValueKey('scrolled-grid-item-$index'),
                child: Text('$index'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.jumpTo(2400);
    await tester.pump();

    expect(find.byKey(const ValueKey('scrolled-grid-item-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchanged content revision restores order without resorting',
      (tester) async {
    final preference = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.list,
    );
    var sortCount = 0;

    Widget buildPage(List<int> content, int revision) {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: Scaffold(
            body: UniPage<int>(
              pref: preference,
              title: '测试',
              contentList: content,
              contentRevision: revision,
              contentBuilder: (_, item, __, ___) => Text('$item'),
              enableShufflePlay: false,
              enableSortMethod: true,
              enableSortOrder: false,
              enableContentViewSwitch: false,
              sortMethods: [
                SortMethodDesc<int>(
                  icon: Icons.sort,
                  name: '数字',
                  method: (list, _) {
                    sortCount++;
                    list.sort();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final initial = [3, 1, 2];
    await tester.pumpWidget(buildPage(initial, 0));
    expect(initial, [1, 2, 3]);
    expect(sortCount, 1);

    final unchanged = [3, 1, 2];
    await tester.pumpWidget(buildPage(unchanged, 0));
    expect(unchanged, [1, 2, 3]);
    expect(sortCount, 1);

    final changed = [4, 1, 3];
    await tester.pumpWidget(buildPage(changed, 1));
    expect(changed, [1, 3, 4]);
    expect(sortCount, 2);
  });

  testWidgets('missing initial locate target does not schedule an invalid jump',
      (tester) async {
    final preference = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.table,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(),
        home: Scaffold(
          body: UniPage<int>(
            pref: preference,
            title: '测试',
            contentList: const [1, 2],
            contentBuilder: (_, item, __, ___) => Text('$item'),
            enableShufflePlay: false,
            enableSortMethod: false,
            enableSortOrder: false,
            enableContentViewSwitch: false,
            locateTo: 99,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ordinary UniPage uses a continuous content viewport without an overlay layer',
      (tester) async {
    final preference = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.list,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: Scaffold(
            body: UniPage<int>(
              pref: preference,
              title: '音乐',
              contentList: const [1, 2],
              contentBuilder: (_, item, __, ___) => SizedBox(
                key: ValueKey('continuous-item-$item'),
                child: Text('$item'),
              ),
              enableShufflePlay: false,
              enableSortMethod: false,
              enableSortOrder: false,
              enableContentViewSwitch: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('uni-page-content-viewport')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('uni-page-overlay-layer')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('continuous-item-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UniPage retains the overlay layer for a side index',
      (tester) async {
    final preference = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.list,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: Scaffold(
            body: UniPage<int>(
              pref: preference,
              title: '艺术家',
              contentList: const [1, 2],
              contentBuilder: (_, item, __, ___) => Text('$item'),
              enableShufflePlay: false,
              enableSortMethod: false,
              enableSortOrder: false,
              enableContentViewSwitch: false,
              sideIndexLabels: const ['A', 'B'],
              sideIndexResolver: (_, label) => label == 'B' ? 1 : 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('uni-page-overlay-layer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('uni-page-side-index')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'table items smoothly contract horizontally without row rearrangement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Rect> pumpShrinkGrid(double progress, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SideNavAnimatedGridDelegate(
                  expansionProgress: progress,
                  sideNavWidthDelta: 84,
                  shrinkHorizontally: true,
                  maxCrossAxisExtent: 300,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('shrink-grid-item-$index'),
                  child: Text('$index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(
        find.byKey(const ValueKey('shrink-grid-item-4')),
      );
    }

    final collapsedRect = await pumpShrinkGrid(0, 1250);
    final halfwayRect = await pumpShrinkGrid(0.5, 1208);
    final expandedRect = await pumpShrinkGrid(1, 1166);

    expect(collapsedRect.top, 72.0);
    expect(halfwayRect.top, 72.0);
    expect(expandedRect.top, 72.0);

    expect(collapsedRect.left, 0.0);
    expect(halfwayRect.left, 0.0);
    expect(expandedRect.left, 0.0);

    expect(collapsedRect.width, greaterThan(expandedRect.width));
    expect(
      halfwayRect.width,
      closeTo((collapsedRect.width + expandedRect.width) / 2, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cover grid smoothly contracts horizontally without row rearrangement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Rect> pumpCoverGrid(double progress, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 600,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SideNavAnimatedGridDelegate(
                  expansionProgress: progress,
                  sideNavWidthDelta: 128,
                  shrinkHorizontally: true,
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.65,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: 20,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('cover-grid-item-$index'),
                  child: Text('$index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(
        find.byKey(const ValueKey('cover-grid-item-0')),
      );
    }

    final collapsedRect = await pumpCoverGrid(0, 1278);
    final halfwayRect = await pumpCoverGrid(0.5, 1214);
    final expandedRect = await pumpCoverGrid(1, 1150);

    expect(collapsedRect.top, 0.0);
    expect(halfwayRect.top, 0.0);
    expect(expandedRect.top, 0.0);

    expect(collapsedRect.width, greaterThan(expandedRect.width));
    expect(
      halfwayRect.width,
      closeTo((collapsedRect.width + expandedRect.width) / 2, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UniPage list viewport provides right padding clearance from scrollbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final preference = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.list,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: Scaffold(
            body: UniPage<int>(
              pref: preference,
              title: '音乐',
              contentList: const [1, 2, 3],
              contentBuilder: (_, item, __, ___) => SizedBox(
                key: ValueKey('padded-item-$item'),
                child: Text('$item'),
              ),
              enableShufflePlay: false,
              enableSortMethod: false,
              enableSortOrder: false,
              enableContentViewSwitch: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final item0Rect =
        tester.getRect(find.byKey(const ValueKey('padded-item-1')));
    final viewportRect =
        tester.getRect(find.byKey(const ValueKey('uni-page-content-viewport')));

    expect(viewportRect.right - item0Rect.right, greaterThanOrEqualTo(16.0));
    expect(item0Rect.left - viewportRect.left, greaterThanOrEqualTo(6.0));
  });

  test('resolveSideNavTransitionGridOffset with shrinkHorizontally preserves row index', () {
    // 4 items per row when expanded (extent 1166)
    // Index 4 should always be in row 1, offset 72.0 (mainAxisExtent 64 + mainAxisSpacing 8)
    final offsetCollapsed = resolveSideNavTransitionGridOffset(
      index: 4,
      crossAxisExtent: 1250,
      expansionProgress: 0.0,
      sideNavWidthDelta: 84,
      maxCrossAxisExtent: 300,
      mainAxisExtent: 64,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkHorizontally: true,
    );
    final offsetHalf = resolveSideNavTransitionGridOffset(
      index: 4,
      crossAxisExtent: 1208,
      expansionProgress: 0.5,
      sideNavWidthDelta: 84,
      maxCrossAxisExtent: 300,
      mainAxisExtent: 64,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkHorizontally: true,
    );
    final offsetExpanded = resolveSideNavTransitionGridOffset(
      index: 4,
      crossAxisExtent: 1166,
      expansionProgress: 1.0,
      sideNavWidthDelta: 84,
      maxCrossAxisExtent: 300,
      mainAxisExtent: 64,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkHorizontally: true,
    );

    expect(offsetCollapsed, 72.0);
    expect(offsetHalf, 72.0);
    expect(offsetExpanded, 72.0);
  });

  test('resolveSideNavTransitionGridOffset handles zero and negative aspect ratio robustly', () {
    final zeroAspectOffset = resolveSideNavTransitionGridOffset(
      index: 10,
      crossAxisExtent: 1200,
      expansionProgress: 0.5,
      sideNavWidthDelta: 84,
      maxCrossAxisExtent: 220,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.0,
      shrinkHorizontally: true,
    );
    expect(zeroAspectOffset.isFinite, isTrue);
    expect(zeroAspectOffset.isNaN, isFalse);
  });

  testWidgets('UniPage table and grid views also guarantee right clearance from scrollbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefTable = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.table,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: Scaffold(
            body: UniPage<int>(
              pref: prefTable,
              title: '艺术家',
              contentList: const [1, 2, 3, 4, 5, 6],
              contentBuilder: (_, item, __, ___) => SizedBox(
                key: ValueKey('table-item-$item'),
                child: Text('$item'),
              ),
              enableShufflePlay: false,
              enableSortMethod: false,
              enableSortOrder: false,
              enableContentViewSwitch: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewportRect =
        tester.getRect(find.byKey(const ValueKey('uni-page-content-viewport')));
    // Find rightmost table item in the first row
    var maxRight = 0.0;
    for (int i = 1; i <= 6; i++) {
      final finder = find.byKey(ValueKey('table-item-$i'));
      if (finder.evaluate().isNotEmpty) {
        final rect = tester.getRect(finder);
        if (rect.right > maxRight) {
          maxRight = rect.right;
        }
      }
    }
    expect(viewportRect.right - maxRight, greaterThanOrEqualTo(16.0));
  });

  testWidgets(
      'UniPage table view renders exactly 5 columns on typical desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefTable = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.table,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: Scaffold(
            body: SideNavTransitionScope(
              expansionProgress: 0.0,
              widthDelta: 84.0,
              collapsing: true,
              child: SizedBox(
                width: 1250,
                height: 800,
                child: UniPage<int>(
                  pref: prefTable,
                  title: '艺术家',
                  contentList: const [1, 2, 3, 4, 5, 6, 7],
                  contentBuilder: (_, item, __, ___) => SizedBox(
                    key: ValueKey('five-col-item-$item'),
                    child: Text('$item'),
                  ),
                  enableShufflePlay: false,
                  enableSortMethod: false,
                  enableSortOrder: false,
                  enableContentViewSwitch: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final r1 = tester.getRect(find.byKey(const ValueKey('five-col-item-1')));
    final r2 = tester.getRect(find.byKey(const ValueKey('five-col-item-2')));
    final r3 = tester.getRect(find.byKey(const ValueKey('five-col-item-3')));
    final r4 = tester.getRect(find.byKey(const ValueKey('five-col-item-4')));
    final r5 = tester.getRect(find.byKey(const ValueKey('five-col-item-5')));
    final r6 = tester.getRect(find.byKey(const ValueKey('five-col-item-6')));

    // Items 1 through 5 must all be in the first row
    expect(r1.top, r2.top);
    expect(r2.top, r3.top);
    expect(r3.top, r4.top);
    expect(r4.top, r5.top);

    // Items 1 through 5 must be arranged horizontally from left to right
    expect(r1.left, lessThan(r2.left));
    expect(r2.left, lessThan(r3.left));
    expect(r3.left, lessThan(r4.left));
    expect(r4.left, lessThan(r5.left));

    // Item 6 must wrap to the second row (mainAxisExtent 64 + mainAxisSpacing 8 = 72)
    expect(r6.top, closeTo(r1.top + 72.0, 0.01));
    expect(r6.left, closeTo(r1.left, 0.01));

    // Verify clearance from viewport right edge (safe distance for scrollbar)
    final viewportRect =
        tester.getRect(find.byKey(const ValueKey('uni-page-content-viewport')));
    expect(viewportRect.right - r5.right, greaterThanOrEqualTo(16.0));
  });

  testWidgets(
      '5-column table items smoothly contract horizontally without row rearrangement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Rect> pumpFiveColShrinkGrid(
      double progress,
      double width,
      int targetIndex,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SideNavAnimatedGridDelegate(
                  expansionProgress: progress,
                  sideNavWidthDelta: 84,
                  shrinkHorizontally: true,
                  maxCrossAxisExtent: 250,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('five-shrink-item-$index'),
                  child: Text('$index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(
        find.byKey(ValueKey('five-shrink-item-$targetIndex')),
      );
    }

    // Index 4 is the 5th item (end of row 0)
    final item4Collapsed = await pumpFiveColShrinkGrid(0, 1250, 4);
    final item4Halfway = await pumpFiveColShrinkGrid(0.5, 1208, 4);
    final item4Expanded = await pumpFiveColShrinkGrid(1, 1166, 4);

    expect(item4Collapsed.top, 0.0);
    expect(item4Halfway.top, 0.0);
    expect(item4Expanded.top, 0.0);
    expect(item4Collapsed.width, greaterThan(item4Expanded.width));
    expect(
      item4Halfway.width,
      closeTo((item4Collapsed.width + item4Expanded.width) / 2, 0.1),
    );

    // Index 5 is the 6th item (start of row 1)
    final item5Collapsed = await pumpFiveColShrinkGrid(0, 1250, 5);
    final item5Halfway = await pumpFiveColShrinkGrid(0.5, 1208, 5);
    final item5Expanded = await pumpFiveColShrinkGrid(1, 1166, 5);

    expect(item5Collapsed.top, 72.0);
    expect(item5Halfway.top, 72.0);
    expect(item5Expanded.top, 72.0);

    expect(item5Collapsed.left, 0.0);
    expect(item5Halfway.left, 0.0);
    expect(item5Expanded.left, 0.0);

    expect(item5Collapsed.width, greaterThan(item5Expanded.width));
    expect(
      item5Halfway.width,
      closeTo((item5Collapsed.width + item5Expanded.width) / 2, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  test('resolveSideNavTransitionGridOffset with 5-column table preserves row index', () {
    // 5 items per row when expanded (extent 1166)
    // Index 4 (5th item) must stay in row 0 (offset 0.0)
    expect(
      resolveSideNavTransitionGridOffset(
        index: 4,
        crossAxisExtent: 1250,
        expansionProgress: 0.0,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 250,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkHorizontally: true,
      ),
      0.0,
    );
    expect(
      resolveSideNavTransitionGridOffset(
        index: 4,
        crossAxisExtent: 1208,
        expansionProgress: 0.5,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 250,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkHorizontally: true,
      ),
      0.0,
    );
    expect(
      resolveSideNavTransitionGridOffset(
        index: 4,
        crossAxisExtent: 1166,
        expansionProgress: 1.0,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 250,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkHorizontally: true,
      ),
      0.0,
    );

    // Index 5 (6th item) must stay in row 1 (offset 72.0)
    expect(
      resolveSideNavTransitionGridOffset(
        index: 5,
        crossAxisExtent: 1250,
        expansionProgress: 0.0,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 250,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkHorizontally: true,
      ),
      72.0,
    );
    expect(
      resolveSideNavTransitionGridOffset(
        index: 5,
        crossAxisExtent: 1208,
        expansionProgress: 0.5,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 250,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkHorizontally: true,
      ),
      72.0,
    );
    expect(
      resolveSideNavTransitionGridOffset(
        index: 5,
        crossAxisExtent: 1166,
        expansionProgress: 1.0,
        sideNavWidthDelta: 84,
        maxCrossAxisExtent: 250,
        mainAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkHorizontally: true,
      ),
      72.0,
    );
  });
}
