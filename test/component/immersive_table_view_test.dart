import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/artist_tile.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/page/albums_page.dart';
import 'package:qisheng_player/page/artists_page.dart';
import 'package:qisheng_player/page/uni_page.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  setUp(() {
    AudioLibrary.instance.artistCollection.clear();
    AudioLibrary.instance.albumCollection.clear();
  });

  group('Immersive table view - ArtistTile', () {
    testWidgets('ArtistTile in table view is transparent when unselected and unhovered', (tester) async {
      final artist = Artist(name: 'Test Artist');
      AudioLibrary.instance.artistCollection[artist.name] = artist;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: ArtistTile(artist: artist),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressableFinder = find.byType(CpMotionPressable);
      expect(pressableFinder, findsOneWidget);
      final pressable = tester.widget<CpMotionPressable>(pressableFinder);

      // 默认状态下背景与边框完全沉浸透明
      expect(pressable.decoration?.color, Colors.transparent);
      expect(pressable.decoration?.border?.top.color, Colors.transparent);
      expect(pressable.selected, isFalse);

      // 悬停时 hoverDecoration 应包含高亮边框和悬浮底色
      expect(pressable.hoverDecoration?.color, isNot(Colors.transparent));
      expect(pressable.hoverDecoration?.border?.top.color, isNot(Colors.transparent));
    });

    testWidgets('ArtistTile in table view displays highlight frame and tint when selected', (tester) async {
      final artist = Artist(name: 'Selected Artist');
      AudioLibrary.instance.artistCollection[artist.name] = artist;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: ArtistTile(artist: artist, selected: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressableFinder = find.byType(CpMotionPressable);
      expect(pressableFinder, findsOneWidget);
      final pressable = tester.widget<CpMotionPressable>(pressableFinder);

      // 选中状态下应显式显示高亮外框和背景色
      expect(pressable.selected, isTrue);
      expect(pressable.decoration?.color, isNot(Colors.transparent));
      expect(pressable.decoration?.border?.top.color, isNot(Colors.transparent));
    });

    testWidgets('ArtistTile toggles selection when multi-select mode is enabled', (tester) async {
      final artist = Artist(name: 'MultiSelect Artist');
      AudioLibrary.instance.artistCollection[artist.name] = artist;
      final controller = MultiSelectController<Artist>();
      controller.useMultiSelectView(true);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: ArtistTile(
                  artist: artist,
                  multiSelectController: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selected.contains(artist), isFalse);

      // Tap on the tile in multi-select mode
      await tester.tap(find.byType(ArtistTile));
      await tester.pumpAndSettle();

      expect(controller.selected.contains(artist), isTrue);

      final pressable = tester.widget<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(pressable.selected, isTrue);
      expect(pressable.decoration?.color, isNot(Colors.transparent));

      // Tap again to unselect
      await tester.tap(find.byType(ArtistTile));
      await tester.pumpAndSettle();

      expect(controller.selected.contains(artist), isFalse);
      final unselectedPressable = tester.widget<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(unselectedPressable.selected, isFalse);
    });

    testWidgets('ArtistTile correctly unselects via controller even if selected: true was passed initially', (tester) async {
      final artist = Artist(name: 'Preselected Artist');
      AudioLibrary.instance.artistCollection[artist.name] = artist;
      final controller = MultiSelectController<Artist>();
      controller.useMultiSelectView(true);
      controller.select(artist);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: ArtistTile(
                  artist: artist,
                  selected: true,
                  multiSelectController: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to unselect
      await tester.tap(find.byType(ArtistTile));
      await tester.pumpAndSettle();

      expect(controller.selected.contains(artist), isFalse);
      final pressable = tester.widget<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(pressable.selected, isFalse);
      expect(pressable.decoration?.color, Colors.transparent);
    });

    testWidgets('ArtistTile renders artist name without redundant outer Tooltip', (tester) async {
      final artist = Artist(name: 'Tooltip Artist');
      AudioLibrary.instance.artistCollection[artist.name] = artist;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: ArtistTile(artist: artist),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltipFinder = find.descendant(
        of: find.byType(ArtistTile),
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsNothing);
      expect(find.text('Tooltip Artist'), findsOneWidget);
    });
  });

  group('Immersive table view - AlbumTile', () {
    testWidgets('AlbumTile in table view is transparent when unselected and unhovered', (tester) async {
      final album = Album(name: 'Test Album');
      AudioLibrary.instance.albumCollection[album.name] = album;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: AlbumTile(album: album),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressableFinder = find.byType(CpMotionPressable);
      expect(pressableFinder, findsOneWidget);
      final pressable = tester.widget<CpMotionPressable>(pressableFinder);

      // 默认状态下背景与边框完全沉浸透明
      expect(pressable.decoration?.color, Colors.transparent);
      expect(pressable.decoration?.border?.top.color, Colors.transparent);
      expect(pressable.selected, isFalse);

      // 悬停配置包含高亮边框和悬浮底色
      expect(pressable.hoverDecoration?.color, isNot(Colors.transparent));
      expect(pressable.hoverDecoration?.border?.top.color, isNot(Colors.transparent));
    });

    testWidgets('AlbumTile in table view displays highlight frame and tint when selected', (tester) async {
      final album = Album(name: 'Selected Album');
      AudioLibrary.instance.albumCollection[album.name] = album;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: AlbumTile(album: album, selected: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressableFinder = find.byType(CpMotionPressable);
      expect(pressableFinder, findsOneWidget);
      final pressable = tester.widget<CpMotionPressable>(pressableFinder);

      // 选中状态下应显式显示高亮外框和背景色
      expect(pressable.selected, isTrue);
      expect(pressable.decoration?.color, isNot(Colors.transparent));
      expect(pressable.decoration?.border?.top.color, isNot(Colors.transparent));
    });

    testWidgets('AlbumTile toggles selection when multi-select mode is enabled', (tester) async {
      final album = Album(name: 'MultiSelect Album');
      AudioLibrary.instance.albumCollection[album.name] = album;
      final controller = MultiSelectController<Album>();
      controller.useMultiSelectView(true);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: AlbumTile(
                  album: album,
                  multiSelectController: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selected.contains(album), isFalse);

      // Tap on the tile in multi-select mode
      await tester.tap(find.byType(AlbumTile));
      await tester.pumpAndSettle();

      expect(controller.selected.contains(album), isTrue);

      final pressable = tester.widget<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(pressable.selected, isTrue);
      expect(pressable.decoration?.color, isNot(Colors.transparent));

      // Tap again to unselect
      await tester.tap(find.byType(AlbumTile));
      await tester.pumpAndSettle();

      expect(controller.selected.contains(album), isFalse);
      final unselectedPressable = tester.widget<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(unselectedPressable.selected, isFalse);
    });

    testWidgets('AlbumTile correctly unselects via controller even if selected: true was passed initially', (tester) async {
      final album = Album(name: 'Preselected Album');
      AudioLibrary.instance.albumCollection[album.name] = album;
      final controller = MultiSelectController<Album>();
      controller.useMultiSelectView(true);
      controller.select(album);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: AlbumTile(
                  album: album,
                  selected: true,
                  multiSelectController: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to unselect
      await tester.tap(find.byType(AlbumTile));
      await tester.pumpAndSettle();

      expect(controller.selected.contains(album), isFalse);
      final pressable = tester.widget<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(pressable.selected, isFalse);
      expect(pressable.decoration?.color, Colors.transparent);
    });

    testWidgets('AlbumTile renders album name without redundant outer Tooltip', (tester) async {
      final album = Album(name: 'Tooltip Album');
      AudioLibrary.instance.albumCollection[album.name] = album;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.table,
              child: SizedBox(
                width: 250,
                height: 72,
                child: AlbumTile(album: album),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltipFinder = find.descendant(
        of: find.byType(AlbumTile),
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsNothing);
      expect(find.text('Tooltip Album'), findsOneWidget);
    });
  });

  group('Page-level immersive table view integration', () {
    testWidgets('ArtistsPage and AlbumsPage in table view render tiles with transparent default background', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final artist = Artist(name: 'Artist 1');
      AudioLibrary.instance.artistCollection[artist.name] = artist;
      AppPreference.instance.artistsPagePref = PagePreference(0, SortOrder.ascending, ContentView.table);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(
            body: ArtistsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressables = tester.widgetList<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(pressables, isNotEmpty);
      for (final p in pressables) {
        expect(p.decoration?.color, Colors.transparent);
        expect(p.decoration?.border?.top.color, Colors.transparent);
        expect(p.selected, isFalse);
      }
    });

    testWidgets('AlbumsPage in table view renders tiles with transparent default background', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final album = Album(name: 'Album 1');
      AudioLibrary.instance.albumCollection[album.name] = album;
      AppPreference.instance.albumsPagePref = PagePreference(0, SortOrder.ascending, ContentView.table);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(
            body: AlbumsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressables = tester.widgetList<CpMotionPressable>(find.byType(CpMotionPressable));
      expect(pressables, isNotEmpty);
      for (final p in pressables) {
        expect(p.decoration?.color, Colors.transparent);
        expect(p.decoration?.border?.top.color, Colors.transparent);
        expect(p.selected, isFalse);
      }
    });
  });
}
