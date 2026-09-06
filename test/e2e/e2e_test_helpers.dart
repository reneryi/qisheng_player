import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';

final Uint8List kSolidPngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0xC9, 0xFE, 0x92, 0xEF, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

ThemeData buildE2ETestTheme({Brightness brightness = Brightness.dark}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: brightness,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

class E2ETestAudio extends Audio {
  E2ETestAudio({
    required String title,
    required String artist,
    required String album,
    String? composer,
    String? arranger,
    required String path,
    int duration = 240,
    int bitrate = 320,
    int sampleRate = 48000,
    String audioType = 'FLAC',
    bool provideCover = true,
  })  : _hasCover = provideCover,
        super(
          title,
          artist,
          album,
          composer,
          arranger,
          1,
          1,
          duration,
          bitrate,
          sampleRate,
          null,
          null,
          null,
          null,
          path,
          1,
          1,
          audioType,
        );

  final bool _hasCover;
  final ImageProvider _image = MemoryImage(kSolidPngBytes);

  @override
  Future<ImageProvider?> get cover async => _hasCover ? _image : null;

  @override
  Future<ImageProvider?> get mediumCover async => _hasCover ? _image : null;

  @override
  Future<ImageProvider?> get largeCover async => _hasCover ? _image : null;
}

class E2EPlaybackController extends PlaybackController {
  E2EPlaybackController({
    Audio? initialAudio,
    List<Audio>? initialQueue,
    PlayerState initialState = PlayerState.paused,
    double initialDuration = 240.0,
    double initialVolume = 0.8,
  })  : _nowPlaying = initialAudio,
        _playlist = ValueNotifier<List<Audio>>(
          initialQueue ?? (initialAudio != null ? [initialAudio] : []),
        ),
        _playMode = ValueNotifier<PlayMode>(PlayMode.loop),
        _volume = ValueNotifier<double>(initialVolume),
        _spectrum = ValueNotifier<List<double>>(<double>[]),
        _playerState = initialState,
        _length = initialDuration;

  final ValueNotifier<List<Audio>> _playlist;
  final ValueNotifier<PlayMode> _playMode;
  final ValueNotifier<double> _volume;
  final ValueNotifier<List<double>> _spectrum;
  final StreamController<double> _positionController =
      StreamController<double>.broadcast();
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  Audio? _nowPlaying;
  int _playlistIndex = 0;
  double _position = 0;
  double _length;
  PlayerState _playerState;

  @override
  Audio? get nowPlaying => _nowPlaying;

  @override
  int get playlistIndex => _playlistIndex;

  @override
  ValueNotifier<List<Audio>> get playlist => _playlist;

  @override
  Stream<double> get positionStream => _positionController.stream;

  @override
  double get length => _length;

  @override
  double get position => _position;

  @override
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  @override
  PlayerState get playerState => _playerState;

  @override
  ValueNotifier<double> get volumeDspNotifier => _volume;

  @override
  double get volumeDsp => _volume.value;

  @override
  ValueNotifier<PlayMode> get playMode => _playMode;

  @override
  ValueNotifier<List<double>> get audioSpectrum => _spectrum;

  @override
  void lastAudio() {
    if (_playlist.value.isEmpty) return;
    _playlistIndex = (_playlistIndex - 1 + _playlist.value.length) % _playlist.value.length;
    _nowPlaying = _playlist.value[_playlistIndex];
    notifyListeners();
  }

  @override
  void nextAudio() {
    if (_playlist.value.isEmpty) return;
    _playlistIndex = (_playlistIndex + 1) % _playlist.value.length;
    _nowPlaying = _playlist.value[_playlistIndex];
    notifyListeners();
  }

  @override
  void pause() {
    _playerState = PlayerState.paused;
    _stateController.add(_playerState);
    notifyListeners();
  }

  @override
  void playAgain() {
    _playerState = PlayerState.playing;
    _position = 0;
    _positionController.add(_position);
    _stateController.add(_playerState);
    notifyListeners();
  }

  @override
  void playIndexOfPlaylist(int audioIndex) {
    if (audioIndex >= 0 && audioIndex < _playlist.value.length) {
      _playlistIndex = audioIndex;
      _nowPlaying = _playlist.value[audioIndex];
      _playerState = PlayerState.playing;
      _stateController.add(_playerState);
      notifyListeners();
    }
  }

  @override
  void removeAudioFromPlaylistByPath(String path) {
    _playlist.value =
        _playlist.value.where((audio) => audio.path != path).toList();
    if (_nowPlaying?.path == path) {
      _nowPlaying = _playlist.value.isNotEmpty ? _playlist.value.first : null;
      _playlistIndex = 0;
    }
    notifyListeners();
  }

  @override
  void reorderPlaylist(int oldIndex, int newIndex) {
    final updated = List<Audio>.from(_playlist.value);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    _playlist.value = updated;
    notifyListeners();
  }

  @override
  void seek(double position) {
    _position = position;
    _positionController.add(position);
    notifyListeners();
  }

  @override
  void setPlayMode(PlayMode playMode) {
    _playMode.value = playMode;
    notifyListeners();
  }

  @override
  void setVolumeDsp(double volume) {
    _volume.value = volume;
    notifyListeners();
  }

  @override
  void start() {
    _playerState = PlayerState.playing;
    _stateController.add(_playerState);
    notifyListeners();
  }

  void setAudioLength(double length) {
    _length = length;
    notifyListeners();
  }

  void setNowPlaying(Audio? audio, {List<Audio>? queue}) {
    _nowPlaying = audio;
    if (queue != null) {
      _playlist.value = queue;
      _playlistIndex = audio == null
          ? 0
          : queue.indexWhere((item) => item.path == audio.path);
      if (_playlistIndex < 0) {
        _playlistIndex = 0;
      }
    }
    notifyListeners();
  }

  void emitSpectrum(List<double> spectrum) {
    _spectrum.value = spectrum;
  }

  @override
  void dispose() {
    _positionController.close();
    _stateController.close();
    _playlist.dispose();
    _playMode.dispose();
    _volume.dispose();
    _spectrum.dispose();
    super.dispose();
  }
}

class E2ELyricController extends LyricController {
  E2ELyricController([Lyric? initialLyric])
      : _lyric = initialLyric ??
            Lrc([
              LrcLine(const Duration(seconds: 0), 'Test Lyric Line 1',
                  isBlank: false, length: const Duration(seconds: 5)),
              LrcLine(const Duration(seconds: 5), 'Test Lyric Line 2',
                  isBlank: false, length: const Duration(seconds: 5)),
            ], LrcSource.local);

  Lyric _lyric;
  final StreamController<int> _lineController =
      StreamController<int>.broadcast();
  int _currentLineIndex = 0;

  @override
  Future<Lyric?> get currLyricFuture async => _lyric;

  @override
  int get currentLyricLineIndex => _currentLineIndex;

  @override
  Stream<int> get lyricLineStream => _lineController.stream;

  void emitLine(int line) {
    _currentLineIndex = line;
    _lineController.add(line);
    notifyListeners();
  }

  void setLyric(Lyric lyric) {
    _lyric = lyric;
    _currentLineIndex = 0;
    notifyListeners();
  }

  @override
  void findCurrLyricLine() {}

  @override
  void refreshCurrentLyricLine() {}

  @override
  void dispose() {
    _lineController.close();
    super.dispose();
  }
}

class E2EDesktopLyricController extends DesktopLyricController {
  final List<LyricLine> sentLyricLines = [];
  final List<Audio> sentNowPlaying = [];
  final List<bool> sentPlayerStates = [];

  @override
  Future<Process?> get desktopLyric async => null;

  @override
  bool get isLocked => false;

  @override
  bool get isStarting => false;

  @override
  Future<bool> get canSendMessage async => true;

  @override
  void killDesktopLyric({bool disablePreference = true}) {}

  @override
  void sendLyricLineMessage(LyricLine line) {
    sentLyricLines.add(line);
  }

  @override
  void sendNowPlayingMessage(Audio nowPlaying) {
    sentNowPlaying.add(nowPlaying);
  }

  @override
  void sendPlayerStateMessage(bool isPlaying) {
    sentPlayerStates.add(isPlaying);
  }

  @override
  void sendThemeMessage(ColorScheme scheme) {}

  @override
  void sendThemeModeMessage(bool darkMode) {}

  @override
  void sendUnlockMessage() {}

  @override
  Future<void> startDesktopLyric() async {}
}

Widget buildE2ETestHarness({
  required Widget child,
  PlaybackController? playbackController,
  LyricController? lyricController,
  DesktopLyricController? desktopLyricController,
  Brightness brightness = Brightness.dark,
  Size screenSize = const Size(1280, 800),
}) {
  final defaultAudio = E2ETestAudio(
    title: 'Autumn Voyage',
    artist: 'Luna Eclipse',
    album: 'Cosmic Horizons',
    path: 'E:\\Music\\test_track.flac',
  );

  final effectivePlayback = playbackController ??
      E2EPlaybackController(
        initialAudio: defaultAudio,
        initialState: PlayerState.playing,
      );
  final effectiveLyric = lyricController ?? E2ELyricController();
  final effectiveDesktopLyric =
      desktopLyricController ?? E2EDesktopLyricController();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: ThemeProvider.instance),
      ChangeNotifierProvider<PlaybackController>.value(
        value: effectivePlayback,
      ),
      ChangeNotifierProvider<LyricController>.value(
        value: effectiveLyric,
      ),
      ChangeNotifierProvider<DesktopLyricController>.value(
        value: effectiveDesktopLyric,
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildE2ETestTheme(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: Scaffold(
          body: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: child,
          ),
        ),
      ),
    ),
  );
}

extension WidgetTesterE2E on WidgetTester {
  Future<void> pumpAndAdvance([Duration duration = const Duration(milliseconds: 300)]) async {
    await pump();
    await pump(duration);
    await pump();
  }
}

List<LrcLine> generateMockLrcLines(int count) {
  return List.generate(count, (i) {
    return LrcLine(
      Duration(seconds: i * 4),
      'Lyric verse #$i - poetic melody resonates across time and space.',
      isBlank: false,
      length: const Duration(seconds: 4),
    );
  });
}

List<E2ETestAudio> generateMockPlaylist(int count) {
  return List.generate(count, (i) {
    return E2ETestAudio(
      title: 'Track #$i Horizon Flight',
      artist: 'Artist Ensemble $i',
      album: 'Symphony Collection ${i ~/ 5}',
      path: 'E:\\Music\\album_track_$i.flac',
      duration: 180 + i * 15,
      bitrate: i % 2 == 0 ? 320 : 1411,
      sampleRate: i % 2 == 0 ? 44100 : 96000,
      audioType: i % 2 == 0 ? 'MP3' : 'FLAC',
    );
  });
}


