import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/theme/app_theme.dart';

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
      return MaterialApp(
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
}
