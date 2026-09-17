import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/metadata_provider.dart';
import 'package:qisheng_player/library/online_cover_store.dart';
import 'package:qisheng_player/music_matcher.dart';

import '../test_helpers/media_test_harness.dart';

final _png = Uint8List.fromList(
    File('assets/branding/qisheng_app_icon.png').readAsBytesSync());

class _Provider implements MetadataProvider {
  _Provider({this.fail = false});
  final bool fail;
  int searches = 0;
  @override
  ResultSource get source => ResultSource.netease;

  @override
  Future<List<SongSearchResult>> searchSongs(
      String query, Audio witness) async {
    searches++;
    if (fail) throw const SocketException('offline');
    return [
      SongSearchResult(source, witness.title, 'Artist', 'Album', 1,
          artistRefs: const [OnlineArtistRef('Artist', 'artist-1')])
    ];
  }

  @override
  Future<List<MetadataCandidate>> searchEntities(String query, String kind,
      {String albumArtist = ''}) async =>
      [
        if (query == 'Kelly Clarkson' && kind == 'artist')
          MetadataCandidate(
            source: source,
            id: 'artist-kelly',
            name: 'Kelly Clarkson',
            kind: 'artist',
            imageUrl: 'https://example.test/kelly.png',
            evidence: true,
          ),
        if (query == 'Catch My Breath' && kind == 'album')
          MetadataCandidate(
            source: source,
            id: 'album-catch',
            name: 'Catch My Breath',
            kind: 'album',
            artist: 'Kelly Clarkson',
            imageUrl: 'https://example.test/catch.png',
            evidence: true,
          ),
        if (query == 'Unknown Query' && kind == 'album')
          MetadataCandidate(
            source: source,
            id: 'album-other',
            name: 'Different Album',
            kind: 'album',
            artist: 'Different Artist',
            imageUrl: 'https://example.test/diff.png',
          ),
      ];

  @override
  Future<MetadataCandidate> detail(MetadataCandidate candidate) async =>
      MetadataCandidate(
          source: source,
          id: candidate.id,
          name: candidate.name,
          kind: candidate.kind,
          imageUrl: 'https://example.test/image.png',
          evidence: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('late automatic image cannot replace a manual selection', () async {
    final directory = await Directory.systemTemp.createTemp('artwork-store-');
    addTearDown(() => directory.delete(recursive: true));
    final downloadStarted = Completer<void>();
    final download = Completer<Uint8List>();
    final events = <String>[];
    final store = ArtworkStore.testing(
        directory: directory,
        providers: [_Provider()],
        downloader: (_) {
          downloadStarted.complete();
          events.add('download-started');
          return download.future.then((bytes) {
            events.add('download-returned');
            return bytes;
          });
        });
    final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.flac');
    final id = entityId('artist', normalizeEntityName('Artist'));

    await store.associate(
        audio,
        SongSearchResult(ResultSource.netease, 'Song', 'Artist', 'Album', 1,
            artistRefs: const [OnlineArtistRef('Artist', 'artist-1')]));
    final automatic = store.imageFor(id, 'Artist', 'artist', [audio], '');
    await downloadStarted.future.timeout(const Duration(seconds: 5),
        onTimeout: () => throw StateError('automatic download did not start'));
    await store.local(id, _png).timeout(const Duration(seconds: 5),
        onTimeout: () => throw StateError('local image did not persist'));
    download.complete(_png);
    await automatic.timeout(const Duration(seconds: 5),
        onTimeout: () => throw StateError('automatic did not finish: $events'));

    expect(store.isManual(id), isTrue);
    expect(store.storedFileName(id), isNotNull);
  });

  test('automatic failures are cached for 24 hours', () async {
    final directory = await Directory.systemTemp.createTemp('artwork-failure-');
    addTearDown(() => directory.delete(recursive: true));
    final provider = _Provider(fail: true);
    final store = ArtworkStore.testing(
        directory: directory,
        providers: [provider],
        downloader: (_) async => _png);
    final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\song.flac');
    final id = entityId('artist', normalizeEntityName('Artist'));

    expect(await store.imageFor(id, 'Artist', 'artist', [audio], ''), isNull);
    expect(await store.imageFor(id, 'Artist', 'artist', [audio], ''), isNull);
    expect(provider.searches, 1);
  });

  test('associate unblocks Kugou source and binds album and artist', () async {
    final directory = await Directory.systemTemp.createTemp('artwork-kugou-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ArtworkStore.testing(
        directory: directory,
        providers: [_Provider()],
        downloader: (_) async => _png);
    final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\kugou_song.flac');

    final kugouResult = SongSearchResult(
      ResultSource.kugou,
      'Song',
      'Artist',
      'Album',
      1,
      albumId: '98852971',
      coverUrl: 'http://imge.kugou.com/stdmusic/800/cover.jpg',
      artistRefs: const [OnlineArtistRef('Artist', 'artist-kugou-1')],
    );

    await store.associate(audio, kugouResult, prefetch: false);

    expect(store.boundAlbum(audio), isNotNull);
    final profilesFile = File('${directory.path}/profiles.json');
    expect(profilesFile.existsSync(), isTrue);
    final jsonContent = jsonDecode(profilesFile.readAsStringSync());
    final albumEntityId = entityId('album', 'kugou:98852971');
    expect(jsonContent['records'][albumEntityId], isNotNull);
  });

  test('associate decouples single track coverUrl from album candidate', () async {
    final directory = await Directory.systemTemp.createTemp('artwork-decouple-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ArtworkStore.testing(
        directory: directory,
        providers: [_Provider()],
        downloader: (_) async => _png);
    final audio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\track.flac');

    final result = SongSearchResult(
      ResultSource.netease,
      'Song',
      'Artist',
      'Album',
      1,
      albumId: 'album-100',
      coverUrl: 'http://p1.music.126.net/single_track_cover.jpg',
      artistRefs: const [OnlineArtistRef('Artist', 'artist-1')],
    );

    await store.associate(audio, result, prefetch: false);

    final albumEntityId = entityId('album', 'netease:album-100');
    final profilesFile = File('${directory.path}/profiles.json');
    final jsonContent = jsonDecode(profilesFile.readAsStringSync());
    final albumRecord = jsonContent['records'][albumEntityId];
    expect(albumRecord, isNotNull);
    expect(albumRecord['candidate']['url'], isNull);
  });

  test('ArtworkStore.download sends User-Agent: QishengPlayer/${AppSettings.version}', () async {
    final prevHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      String? capturedUserAgent;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        capturedUserAgent = request.headers.value(HttpHeaders.userAgentHeader);
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.headers.contentLength = _png.length;
        request.response.add(_png);
        request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final url = 'http://${server.address.host}:${server.port}/test_cover.png';
      final bytes = await ArtworkStore.download(url);

      expect(bytes, equals(_png));
      expect(capturedUserAgent, 'QishengPlayer/${AppSettings.version}');
    } finally {
      HttpOverrides.global = prevHttpOverrides;
    }
  });

  test('ArtworkStore.autoMatchEntity succeeds on high confidence candidate', () async {
    final directory = await Directory.systemTemp.createTemp('artwork-automatch-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ArtworkStore.testing(
      directory: directory,
      providers: [_Provider()],
      downloader: (_) async => _png,
    );

    final audio = TestAudio(
      title: 'Catch My Breath',
      artist: 'Kelly Clarkson',
      album: 'Catch My Breath',
      path: r'E:\Music\catch.flac',
    );

    // 1. 测试歌手头像一键智能匹配
    final artistId = entityId('artist', normalizeEntityName('Kelly Clarkson'));
    final artistResult = await store.autoMatchEntity(
      id: artistId,
      name: 'Kelly Clarkson',
      kind: 'artist',
      works: [audio],
    );
    expect(artistResult.status, AutoMatchStatus.success);
    expect(store.isManual(artistId), isTrue);

    // 2. 测试专辑封面一键智能匹配
    final albumId = entityId('album', 'Catch My Breath');
    final albumResult = await store.autoMatchEntity(
      id: albumId,
      name: 'Catch My Breath',
      kind: 'album',
      works: [audio],
      albumArtist: 'Kelly Clarkson',
    );
    expect(albumResult.status, AutoMatchStatus.success);
    expect(store.isManual(albumId), isTrue);
  });

  test('ArtworkStore.autoMatchEntity rejects low confidence candidate', () async {
    final directory = await Directory.systemTemp.createTemp('artwork-lowconf-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ArtworkStore.testing(
      directory: directory,
      providers: [_Provider()],
      downloader: (_) async => _png,
    );

    final audio = TestAudio(
      title: 'Some Title',
      artist: 'Some Artist',
      album: 'Some Album',
      path: r'E:\Music\some.flac',
    );

    final albumId = entityId('album', 'Unknown Query');
    final result = await store.autoMatchEntity(
      id: albumId,
      name: 'Unknown Query',
      kind: 'album',
      works: [audio],
      albumArtist: 'Some Artist',
    );
    // 因为返回的不同专辑且艺术家不匹配，置信度不足，拒绝盲目采纳
    expect(result.status, AutoMatchStatus.lowConfidence);
  });

  test('ArtworkStore.optimizeImageBytes preserves normal images and validates', () async {
    final optimized = await ArtworkStore.optimizeImageBytes(_png);
    expect(optimized.length, greaterThan(0));
    expect(detectCoverExtension(optimized), isNotNull);
  });
}
