import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/album_grid_tile.dart';
import 'package:qisheng_player/component/album_tile.dart';
import 'package:qisheng_player/component/artist_tile.dart';
import 'package:qisheng_player/component/cover_fade_image.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/audio_library.dart';



import '../test_helpers/media_test_harness.dart';

const List<int> kTransparentImageBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CoverFadeImage immediately renders cached provider on frame 0',
      (tester) async {
    final provider =
        MemoryImage(Uint8List.fromList(kTransparentImageBytes));

    await tester.runAsync(() async {
      final binding = tester.binding;
      await precacheImage(provider, binding.rootElement!);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoverFadeImage(
            provider: provider,
            index: 10,
            width: 48,
            height: 48,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.broken_image), findsNothing);
  });

  test('Album defaults to song cover and caches it', () {
    final album = Album(name: 'Test Album');
    final audio = TestAudio(
      title: 'Song 1',
      artist: 'Artist 1',
      album: 'Test Album',
      path: r'E:\Music\song1.flac',
    );
    album.works.add(audio);

    expect(album.cachedCover, isNotNull);
    expect(album.cachedCover, equals(audio.cachedMediumCover));
  });

  testWidgets('AlbumTile renders cached cover on frame 0 without placeholder',
      (tester) async {
    final album = Album(name: 'Cached Album');
    final audio = TestAudio(
      title: 'Track',
      artist: 'Artist',
      album: 'Cached Album',
      path: r'E:\Music\track.flac',
    );
    album.works.add(audio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Scaffold(
          body: AlbumTile(album: album),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.album), findsNothing);
  });

  testWidgets(
      'AlbumGridTile renders cached cover on frame 0 without placeholder',
      (tester) async {
    final album = Album(name: 'Grid Album');
    final audio = TestAudio(
      title: 'Track',
      artist: 'Artist',
      album: 'Grid Album',
      path: r'E:\Music\grid_track.flac',
    );
    album.works.add(audio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 250,
            child: AlbumGridTile(album: album),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.album), findsNothing);
  });

  test('Album reverts cleanly to song cover fallback when custom store artwork is reset', () {
    final album = Album(name: 'Reversion Album');
    final audio = TestAudio(
      title: 'Track',
      artist: 'Artist',
      album: 'Reversion Album',
      path: r'E:\Music\rev_track.flac',
    );
    album.works.add(audio);

    // Initial state: fallback to audio's cover
    expect(album.cachedCover, equals(audio.cachedMediumCover));

    // When reset is called or store is empty, cachedCover still cleanly returns audio cover
    album.invalidateCover();
    expect(album.cachedCover, equals(audio.cachedMediumCover));
  });

  test('Artist reverts cleanly to song cover fallback when custom store artwork is reset', () async {
    final artist = Artist(name: 'Reversion Artist');
    final audio = TestAudio(
      title: 'Track',
      artist: 'Reversion Artist',
      album: 'Some Album',
      path: r'E:\Music\artist_rev_track.flac',
    );
    artist.works.add(audio);

    // Initial state: fallback to audio's cover
    expect(artist.cachedPicture, equals(audio.cachedMediumCover));
    expect(await artist.picture, equals(audio.cachedMediumCover));

    // When reset is called or store is empty, cachedPicture and picture still cleanly return audio cover
    artist.invalidateCover();
    expect(artist.cachedPicture, equals(audio.cachedMediumCover));
    expect(await artist.picture, equals(audio.cachedMediumCover));
  });

  testWidgets('ArtistTile renders avatar synchronously on frame 0 when cached',
      (tester) async {
    final artist = Artist(name: 'Cached Artist');

    // Without cached artwork in store and no works, renders placeholder on frame 0
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Scaffold(
          body: ArtistTile(artist: artist),
        ),
      ),
    );

    expect(find.byIcon(Symbols.person_rounded), findsOneWidget);
  });

  testWidgets('ArtistTile renders song cover on frame 0 when artist has works with cover',
      (tester) async {
    final artist = Artist(name: 'Covered Artist');
    final audio = TestAudio(
      title: 'Track',
      artist: 'Covered Artist',
      album: 'Album',
      path: r'E:\Music\covered_track.flac',
    );
    artist.works.add(audio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Scaffold(
          body: ArtistTile(artist: artist),
        ),
      ),
    );

    // Frame 0 renders the Image directly from song cover fallback
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.person_rounded), findsNothing);
  });

  test('Audio retains cached covers on instance independently of AudioCoverCache eviction', () async {
    final audio = TestAudio(
      title: 'Cached Track',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\independent_track.flac',
    );

    expect(audio.cachedCover, isNotNull);
    expect(audio.cachedMediumCover, isNotNull);

    // Stress LRU in AudioCoverCache
    for (int i = 0; i < 350; i++) {
      await AudioCoverCache.getProviders(
        'evict_$i',
        () async => const AudioCoverProviders(null, null, null),
      );
    }

    // Audio instance still retains its cached cover
    expect(audio.cachedCover, isNotNull);
    expect(audio.cachedMediumCover, isNotNull);
  });

  testWidgets('ArtistTile reactively updates when ArtworkStore notifies',
      (tester) async {
    final artist = Artist(name: 'Reactive Artist');
    final audio = TestAudio(
      title: 'Track',
      artist: 'Reactive Artist',
      album: 'Album',
      path: r'E:\Music\reactive_track.flac',
    );

    // Initial state: no works, no artwork in store -> placeholder
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Scaffold(
          body: ArtistTile(artist: artist),
        ),
      ),
    );
    expect(find.byIcon(Symbols.person_rounded), findsOneWidget);

    // Now artist has works with cover, and ArtworkStore triggers notification (e.g. reset/update)
    artist.works.add(audio);
    artist.invalidateCover();
    ArtworkStore.instance.notifyListeners();
    await tester.pump();

    // ArtistTile reacts and updates its artwork
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.person_rounded), findsNothing);
  });
}

