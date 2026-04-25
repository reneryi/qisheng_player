import 'package:coriander_player/component/album_artwork_hero.dart';
import 'package:coriander_player/component/album_tile.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/navigation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  test('albumArtworkHeroTag is stable and separate from Now Playing', () {
    final album = _buildAlbum(
      name: 'Hero Album',
      path: r'E:\Music\hero.flac',
    );

    expect(
      albumArtworkHeroTag(album),
      'album-artwork:Hero Album:E:\\Music\\hero.flac',
    );
    expect(albumArtworkHeroTag(album), isNot('now-playing-artwork'));
    expect(albumArtworkHeroTag(Album(name: 'Empty Album')), isNull);
  });

  test('AppNavigationState gates album hero sources during transition', () {
    final navigation = AppNavigationState.instance;
    final source = Object();
    final otherSource = Object();
    const tag = 'album-artwork:Album:E:\\Music\\album.flac';

    expect(
      navigation.beginAlbumArtworkHeroNavigation(
        tag: tag,
        sourceKey: source,
      ),
      isTrue,
    );
    expect(
      navigation.beginAlbumArtworkHeroNavigation(
        tag: tag,
        sourceKey: otherSource,
      ),
      isFalse,
    );
    expect(
      navigation.canBuildAlbumArtworkHero(tag: tag, sourceKey: source),
      isTrue,
    );
    expect(
      navigation.canBuildAlbumArtworkHero(tag: tag, sourceKey: otherSource),
      isFalse,
    );
    expect(navigation.canBuildAlbumArtworkHero(tag: tag), isTrue);
    expect(
      navigation.canBuildAlbumArtworkHero(tag: 'album-artwork:Other:path'),
      isFalse,
    );

    navigation.endAlbumArtworkHeroNavigation(source);
    expect(navigation.albumArtworkHeroTransition.value, isNull);
  });

  testWidgets('AlbumTile only builds Hero when enabled and cover exists',
      (tester) async {
    final album = _buildAlbum(
      name: 'Visible Album',
      path: r'E:\Music\visible.flac',
    );

    await tester.pumpWidget(_frame(AlbumTile(album: album)));
    await tester.pump();
    expect(find.byType(Hero), findsNothing);

    await tester.pumpWidget(_frame(AlbumTile(album: album, enableHero: true)));
    await tester.pump();
    expect(find.byType(Hero), findsOneWidget);
    expect(
      tester.widget<Hero>(find.byType(Hero)).tag,
      albumArtworkHeroTag(album),
    );

    await tester.pumpWidget(
      _frame(AlbumTile(album: Album(name: 'No Cover'), enableHero: true)),
    );
    await tester.pump();
    expect(find.byType(Hero), findsNothing);
  });
}

Album _buildAlbum({
  required String name,
  required String path,
}) {
  final album = Album(name: name);
  album.works.add(
    TestAudio(
      title: '$name Track',
      artist: 'Artist',
      album: name,
      path: path,
    ),
  );
  return album;
}

Widget _frame(Widget child) {
  return MaterialApp(
    theme: buildTestTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}
