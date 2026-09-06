import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/side_nav.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/page/artists_page.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';

import '../test_helpers/media_test_harness.dart';

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
  setUp(() {
    AudioLibrary.instance.artistCollection.clear();
    AppPreference.instance.artistsPagePref = PagePreference(
      0,
      SortOrder.ascending,
      ContentView.table,
    );
  });

  List<Artist> createTestArtists(int count) {
    final artists = <Artist>[];
    for (int i = 1; i <= count; i++) {
      final name = 'Artist $i';
      final song = TestAudio(
        title: 'Track $i',
        artist: name,
        album: 'Album $i',
        path: 'E:\\Music\\track_$i.flac',
      );
      final artist = Artist(name: name)..works.add(song);
      AudioLibrary.instance.artistCollection[name] = artist;
      artists.add(artist);
    }
    return artists;
  }

  testWidgets(
      'ArtistsPage renders exactly 5 columns in typical desktop width with collapsed side nav',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    createTestArtists(7);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: const Scaffold(
            body: SideNavTransitionScope(
              expansionProgress: 0.0,
              widthDelta: 84.0,
              collapsing: true,
              child: SizedBox(
                width: 1250,
                height: 800,
                child: ArtistsPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final findItems = find.byType(Tooltip);
    expect(findItems, findsWidgets);

    // Find all rendered artist tiles
    final tiles = <Rect>[];
    for (int i = 1; i <= 7; i++) {
      final itemFinder = find.text('Artist $i');
      expect(itemFinder, findsOneWidget);
      tiles.add(tester.getRect(itemFinder));
    }

    // First 5 artists must all share the same top (Row 0)
    for (int i = 1; i < 5; i++) {
      expect(tiles[i].top, tiles[0].top);
      expect(tiles[i].left, greaterThan(tiles[i - 1].left));
    }

    // 6th artist (index 5) must wrap to Row 1
    expect(tiles[5].top, closeTo(tiles[0].top + 72.0, 0.01));
    expect(tiles[5].left, closeTo(tiles[0].left, 0.01));

    // 7th artist (index 6) must be second item in Row 1
    expect(tiles[6].top, closeTo(tiles[0].top + 72.0, 0.01));
    expect(tiles[6].left, greaterThan(tiles[5].left));

    // Viewport right edge must have >= 16px clearance from 5th artist right edge
    final viewportRect =
        tester.getRect(find.byKey(const ValueKey('uni-page-content-viewport')));
    expect(viewportRect.right - tiles[4].right, greaterThanOrEqualTo(16.0));
  });

  testWidgets(
      'ArtistsPage renders exactly 5 columns with expanded side nav',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    createTestArtists(7);

    // When side nav is expanded, available width for UniPage decreases by widthDelta (84px)
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: ThemeProvider.instance,
        child: MaterialApp(
          theme: _buildTheme(),
          home: const Scaffold(
            body: SideNavTransitionScope(
              expansionProgress: 1.0,
              widthDelta: 84.0,
              collapsing: false,
              child: SizedBox(
                width: 1166, // 1250 - 84
                height: 800,
                child: ArtistsPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tiles = <Rect>[];
    for (int i = 1; i <= 7; i++) {
      final itemFinder = find.text('Artist $i');
      expect(itemFinder, findsOneWidget);
      tiles.add(tester.getRect(itemFinder));
    }

    // First 5 artists must remain in Row 0
    for (int i = 1; i < 5; i++) {
      expect(tiles[i].top, tiles[0].top);
      expect(tiles[i].left, greaterThan(tiles[i - 1].left));
    }

    // 6th artist (index 5) must wrap to Row 1
    expect(tiles[5].top, closeTo(tiles[0].top + 72.0, 0.01));
    expect(tiles[5].left, closeTo(tiles[0].left, 0.01));

    // Clearance from viewport right edge
    final viewportRect =
        tester.getRect(find.byKey(const ValueKey('uni-page-content-viewport')));
    expect(viewportRect.right - tiles[4].right, greaterThanOrEqualTo(16.0));
  });

  testWidgets(
      'ArtistsPage maintains 5 columns at default window width 1461 and laptop width 1280',
      (tester) async {
    addTearDown(tester.view.reset);

    createTestArtists(7);

    Future<void> verify5ColumnsAtSize({
      required Size windowSize,
      required double contentWidth,
      required double progress,
    }) async {
      tester.view.physicalSize = windowSize;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: ThemeProvider.instance,
          child: MaterialApp(
            theme: _buildTheme(),
            home: Scaffold(
              body: SideNavTransitionScope(
                expansionProgress: progress,
                widthDelta: 84.0,
                collapsing: progress < 0.5,
                child: SizedBox(
                  width: contentWidth,
                  height: windowSize.height,
                  child: const ArtistsPage(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final r1 = tester.getRect(find.text('Artist 1'));
      final r5 = tester.getRect(find.text('Artist 5'));
      final r6 = tester.getRect(find.text('Artist 6'));

      // 5th artist in Row 0, 6th artist in Row 1
      expect(r5.top, r1.top);
      expect(r6.top, closeTo(r1.top + 72.0, 0.01));
      expect(r6.left, closeTo(r1.left, 0.01));

      final viewportRect = tester.getRect(
          find.byKey(const ValueKey('uni-page-content-viewport')));
      expect(viewportRect.right - r5.right, greaterThanOrEqualTo(16.0));
    }

    // Default window width 1461:
    // Collapsed: content width = 1461 - 116 = 1345
    await verify5ColumnsAtSize(
      windowSize: const Size(1461, 898),
      contentWidth: 1345,
      progress: 0.0,
    );

    // Default window width 1461:
    // Expanded: content width = 1461 - 200 = 1261
    await verify5ColumnsAtSize(
      windowSize: const Size(1461, 898),
      contentWidth: 1261,
      progress: 1.0,
    );

    // Laptop width 1280:
    // Collapsed: content width = 1280 - 116 = 1164
    await verify5ColumnsAtSize(
      windowSize: const Size(1280, 800),
      contentWidth: 1164,
      progress: 0.0,
    );

    // Laptop width 1280:
    // Expanded: content width = 1280 - 200 = 1080
    await verify5ColumnsAtSize(
      windowSize: const Size(1280, 800),
      contentWidth: 1080,
      progress: 1.0,
    );
  });
}


