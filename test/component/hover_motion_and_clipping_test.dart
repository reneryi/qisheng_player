import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/album_grid_tile.dart';
import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/artist_tile.dart';
import 'package:qisheng_player/component/audio_grid_tile.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  setUp(() {
    AudioLibrary.instance.artistCollection.clear();
    AudioLibrary.instance.albumCollection.clear();
  });

  group('Hover motion and subtree persistence', () {
    testWidgets('AudioTile: mouse hover maintains subtree element identity and does not rebuild child', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = TestAudio(
        title: 'Hover Track',
        artist: 'Hover Artist',
        album: 'Hover Album',
        path: r'E:\Music\hover_track.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        ChangeNotifierProvider<PlaybackController>.value(
          value: playback,
          child: MaterialApp(
            theme: buildTestTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: AudioTile(
                  audioIndex: 0,
                  playlist: [audio],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('Hover Track');
      expect(titleFinder, findsOneWidget);
      final initialElement = tester.element(titleFinder);

      // Simulate mouse enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(AudioTile)));
      await tester.pump(const Duration(milliseconds: 50));

      // Element identity MUST remain identical (no recreation of subtree)
      final hoveredElement = tester.element(titleFinder);
      expect(identical(initialElement, hoveredElement), isTrue,
          reason: 'Subtree should not be recreated on mouse hover');

      // Mouse exit
      await gesture.moveTo(const Offset(0, 0));
      await tester.pump(const Duration(milliseconds: 50));

      final exitedElement = tester.element(titleFinder);
      expect(identical(initialElement, exitedElement), isTrue,
          reason: 'Subtree should not be recreated on mouse exit');
    });

    testWidgets('ArtistTile: adapts hover motion duration and styling across list and table view scopes', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final song = TestAudio(
        title: 'Track A',
        artist: 'Test Artist',
        album: 'Album A',
        path: r'E:\Music\track_a.flac',
      );
      final artist = Artist(name: 'Test Artist')..works.add(song);
      AudioLibrary.instance.artistCollection['Test Artist'] = artist;

      // 1. Table view scope
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
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressableFinder = find.descendant(
        of: find.byType(ArtistTile),
        matching: find.byType(CpMotionPressable),
      );
      expect(pressableFinder, findsOneWidget);
      final tablePressable = tester.widget<CpMotionPressable>(pressableFinder);

      // In table view, duration should be ~260ms, hoverTranslateY should be -3.0
      expect(tablePressable.animationDuration, const Duration(milliseconds: 260));
      expect(tablePressable.hoverTranslateY, -3.0);
      expect(tablePressable.hoverScale, 1.015);

      // 2. List view scope
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: PageContentViewScope(
              contentView: ContentView.list,
              child: SizedBox(
                width: 600,
                height: 64,
                child: ArtistTile(
                  artist: artist,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listPressable = tester.widget<CpMotionPressable>(pressableFinder);
      // In list view, duration should be 200ms, hoverTranslateY should be -2.0
      expect(listPressable.animationDuration, const Duration(milliseconds: 200));
      expect(listPressable.hoverTranslateY, -2.0);
      expect(listPressable.hoverScale, 1.0);
    });

    testWidgets('AlbumTile: adapts hover motion duration and styling across list and table view scopes', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final album = Album(name: 'Test Album', albumArtist: 'Test Artist');
      final song = TestAudio(
        title: 'Song 1',
        artist: 'Test Artist',
        album: 'Test Album',
        path: r'E:\Music\album_song.flac',
      );
      album.works.add(song);
      AudioLibrary.instance.albumCollection['Test Album'] = album;

      // Table view scope
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
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pressableFinder = find.descendant(
        of: find.byType(AlbumTile),
        matching: find.byType(CpMotionPressable),
      );
      expect(pressableFinder, findsOneWidget);
      final tablePressable = tester.widget<CpMotionPressable>(pressableFinder);
      expect(tablePressable.animationDuration, const Duration(milliseconds: 260));
      expect(tablePressable.hoverTranslateY, -3.0);
    });
  });

  group('AlbumGridTile hover behavior and play button', () {
    testWidgets('AlbumGridTile: does not show circular play button on hover over cover', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final album = Album(name: 'Grid Album', albumArtist: 'Grid Artist');
      final song = TestAudio(
        title: 'Track 1',
        artist: 'Grid Artist',
        album: 'Grid Album',
        path: r'E:\Music\grid_track.flac',
      );
      album.works.add(song);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 260,
              child: AlbumGridTile(album: album),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hover over the tile
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(AlbumGridTile)));
      await tester.pumpAndSettle();

      // There should be NO 38x38 or circular play button on the cover
      final circularPlayButton = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && widget.constraints?.maxWidth == 38;
        }
        return false;
      });
      expect(circularPlayButton, findsNothing, reason: 'Circular play button on cover must be removed');

      // But there IS a dedicated quick play button with tooltip '播放专辑' in the info row
      final quickPlayFinder = find.byTooltip('播放专辑');
      expect(quickPlayFinder, findsOneWidget, reason: 'Dedicated aesthetic quick play button should exist');
    });

    testWidgets('AudioGridTile: does not show circular play button on hover over cover, provides quick play in info row, and preserves subtree', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final audio = TestAudio(
        title: 'Grid Track',
        artist: 'Grid Artist',
        album: 'Grid Album',
        path: r'E:\Music\grid_audio_track.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        ChangeNotifierProvider<PlaybackController>.value(
          value: playback,
          child: MaterialApp(
            theme: buildTestTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 260,
                child: AudioGridTile(
                  audioIndex: 0,
                  playlist: [audio],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('Grid Track');
      expect(titleFinder, findsOneWidget);
      final initialElement = tester.element(titleFinder);

      // Hover over the tile
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(AudioGridTile)));
      await tester.pump(const Duration(milliseconds: 50));

      // 1. Subtree element identity must remain identical (no setState / rebuild on hover)
      final hoveredElement = tester.element(titleFinder);
      expect(identical(initialElement, hoveredElement), isTrue,
          reason: 'AudioGridTile subtree should not be recreated on hover');

      // 2. Cover should NOT have 44x44 or circular play button on hover
      final circularPlayButton = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && widget.constraints?.maxWidth == 44;
        }
        return false;
      });
      expect(circularPlayButton, findsNothing, reason: 'Circular play button on cover must be removed');

      // 3. Quick play button in info row must exist
      final quickPlayFinder = find.byTooltip('播放歌曲');
      expect(quickPlayFinder, findsOneWidget, reason: 'Aesthetic quick play button should exist in info row');
    });
  });

  group('UniPage list clipping', () {
    testWidgets('UniPage: list view configures Clip.hardEdge to prevent content overflowing headers', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final items = List.generate(20, (i) => 'Item $i');
      final preference = PagePreference(0, SortOrder.ascending, ContentView.list);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: UniPage<String>(
              pref: preference,
              title: 'Test Page',
              contentList: items,
              contentBuilder: (context, item, index, controller) => SizedBox(
                height: 64,
                child: Text(item),
              ),
              enableShufflePlay: false,
              enableSortMethod: false,
              enableSortOrder: false,
              enableContentViewSwitch: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listViewFinder);
      expect(listView.clipBehavior, Clip.hardEdge,
          reason: 'ListView must use Clip.hardEdge to prevent scrolled items from rendering over header text');
    });
  });
}
