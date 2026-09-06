import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/album_detail_page.dart';
import 'package:qisheng_player/page/artist_detail_page.dart';
import 'package:qisheng_player/page/audio_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  setUp(() {
    AudioLibrary.instance.audioCollection.clear();
    AudioLibrary.instance.artistCollection.clear();
    AudioLibrary.instance.albumCollection.clear();
  });

  testWidgets('AudioDetailPage uses refreshed glass detail surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Detail Song',
      artist: 'Detail Artist',
      album: 'Detail Album',
      composer: 'Composer A',
      arranger: 'Arranger B',
      path: r'E:\Music\detail-audio.flac',
    );
    final artist = Artist(name: 'Detail Artist')..works.add(audio);
    final album = Album(name: 'Detail Album')..works.add(audio);
    artist.albumsMap[album.name] = album;
    album.artistsMap[artist.name] = artist;
    AudioLibrary.instance.audioCollection.add(audio);
    AudioLibrary.instance.artistCollection[artist.name] = artist;
    AudioLibrary.instance.albumCollection[album.name] = album;

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController:
            FakePlaybackController(audio: audio, queue: [audio]),
        lyricController: FakeLyricController(
          Lrc(
            [
              LrcLine(
                Duration.zero,
                '歌词',
                isBlank: false,
                length: const Duration(seconds: 3),
              ),
            ],
            LrcSource.local,
          ),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: AudioDetailPage(audio: audio),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('audio-detail-hero-surface')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('audio-detail-content-surface')),
        findsOneWidget);
    expect(find.text('Detail Song'), findsWidgets);
  });

  testWidgets('ArtistDetailPage uses refreshed shared detail surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Artist Page Song',
      artist: 'Artist Page Artist',
      album: 'Artist Page Album',
      path: r'E:\Music\artist-page.flac',
    );
    final album = Album(name: 'Artist Page Album')..works.add(audio);
    final artist = Artist(name: 'Artist Page Artist')
      ..works.add(audio)
      ..albumsMap[album.name] = album;
    album.artistsMap[artist.name] = artist;

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController:
            FakePlaybackController(audio: audio, queue: [audio]),
        lyricController: FakeLyricController(
          Lrc(
            [
              LrcLine(
                Duration.zero,
                '歌词',
                isBlank: false,
                length: const Duration(seconds: 3),
              ),
            ],
            LrcSource.local,
          ),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: ArtistDetailPage(artist: artist),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('uni-detail-hero-surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('uni-detail-content-surface')),
        findsOneWidget);
    expect(find.text('Artist Page Artist'), findsWidgets);
  });

  testWidgets('AlbumDetailPage uses refreshed shared detail surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Album Page Song',
      artist: 'Album Page Artist',
      album: 'Album Page Album',
      path: r'E:\Music\album-page.flac',
    );
    final artist = Artist(name: 'Album Page Artist')..works.add(audio);
    final album = Album(name: 'Album Page Album')
      ..works.add(audio)
      ..artistsMap[artist.name] = artist;
    artist.albumsMap[album.name] = album;

    await tester.pumpWidget(
      buildMediaHarness(
        playbackController:
            FakePlaybackController(audio: audio, queue: [audio]),
        lyricController: FakeLyricController(
          Lrc(
            [
              LrcLine(
                Duration.zero,
                '歌词',
                isBlank: false,
                length: const Duration(seconds: 3),
              ),
            ],
            LrcSource.local,
          ),
        ),
        desktopLyricController: FakeDesktopLyricController(),
        child: AlbumDetailPage(album: album),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('uni-detail-hero-surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('uni-detail-content-surface')),
        findsOneWidget);
    expect(find.text('Album Page Album'), findsWidgets);
  });
}
