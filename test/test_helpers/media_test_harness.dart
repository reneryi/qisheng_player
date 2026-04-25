import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/play_service/desktop_lyric_service.dart';
import 'package:coriander_player/play_service/lyric_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

ThemeData buildTestTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

class TestAudio extends Audio {
  TestAudio({
    required String title,
    required String artist,
    required String album,
    String? composer,
    String? arranger,
    required String path,
  }) : super(
          title,
          artist,
          album,
          composer,
          arranger,
          1,
          1,
          240,
          320,
          48000,
          null,
          null,
          null,
          null,
          path,
          1,
          1,
          'Lofty',
        );

  final ImageProvider _image = MemoryImage(
    Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0xF8,
      0xCF,
      0xC0,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x00,
      0xC9,
      0xFE,
      0x92,
      0xEF,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]),
  );

  @override
  Future<ImageProvider?> get cover async => _image;

  @override
  Future<ImageProvider?> get mediumCover async => _image;

  @override
  Future<ImageProvider?> get largeCover async => _image;
}

class FakePlaybackController extends PlaybackController {
  FakePlaybackController({
    required Audio audio,
    required List<Audio> queue,
    PlayerState initialState = PlayerState.paused,
  })  : _nowPlaying = audio,
        _playlist = ValueNotifier<List<Audio>>(queue),
        _playMode = ValueNotifier<PlayMode>(PlayMode.loop),
        _volume = ValueNotifier<double>(0.5),
        _playerState = initialState;

  final ValueNotifier<List<Audio>> _playlist;
  final ValueNotifier<PlayMode> _playMode;
  final ValueNotifier<double> _volume;
  final StreamController<double> _positionController =
      StreamController<double>.broadcast();
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  Audio? _nowPlaying;
  int _playlistIndex = 0;
  double _position = 0;
  final double _length = 240;
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
  void lastAudio() {}

  @override
  void nextAudio() {}

  @override
  void pause() {
    _playerState = PlayerState.paused;
    _stateController.add(_playerState);
  }

  @override
  void playAgain() {
    _playerState = PlayerState.playing;
    _stateController.add(_playerState);
  }

  @override
  void playIndexOfPlaylist(int audioIndex) {
    _playlistIndex = audioIndex;
    _nowPlaying = _playlist.value[audioIndex];
    notifyListeners();
  }

  @override
  void removeAudioFromPlaylistByPath(String path) {
    _playlist.value =
        _playlist.value.where((audio) => audio.path != path).toList();
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
  }

  @override
  void start() {
    _playerState = PlayerState.playing;
    _stateController.add(_playerState);
  }

  @override
  void dispose() {
    _positionController.close();
    _stateController.close();
    _playlist.dispose();
    _playMode.dispose();
    _volume.dispose();
    super.dispose();
  }
}

class FakeLyricController extends LyricController {
  FakeLyricController(this._lyric);

  final Lyric _lyric;
  final StreamController<int> _lineController =
      StreamController<int>.broadcast();

  @override
  Future<Lyric?> get currLyricFuture async => _lyric;

  @override
  int get currentLyricLineIndex => 0;

  @override
  Stream<int> get lyricLineStream => _lineController.stream;

  void emitLine(int line) {
    _lineController.add(line);
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

class FakeDesktopLyricController extends DesktopLyricController {
  @override
  Future<Process?> get desktopLyric async => null;

  @override
  bool get isLocked => false;

  @override
  bool get isStarting => false;

  @override
  Future<bool> get canSendMessage async => false;

  @override
  void killDesktopLyric({bool disablePreference = true}) {}

  @override
  void sendLyricLineMessage(LyricLine line) {}

  @override
  void sendNowPlayingMessage(Audio nowPlaying) {}

  @override
  void sendPlayerStateMessage(bool isPlaying) {}

  @override
  void sendThemeMessage(ColorScheme scheme) {}

  @override
  void sendThemeModeMessage(bool darkMode) {}

  @override
  void sendUnlockMessage() {}

  @override
  Future<void> startDesktopLyric() async {}
}

Widget buildMediaHarness({
  required PlaybackController playbackController,
  required LyricController lyricController,
  required DesktopLyricController desktopLyricController,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PlaybackController>.value(
        value: playbackController,
      ),
      ChangeNotifierProvider<LyricController>.value(
        value: lyricController,
      ),
      ChangeNotifierProvider<DesktopLyricController>.value(
        value: desktopLyricController,
      ),
    ],
    child: MaterialApp(
      theme: buildTestTheme(),
      home: Scaffold(body: child),
    ),
  );
}

List<LrcLine> buildLongLrcLines() {
  return List.generate(40, (index) {
    return LrcLine(
      Duration(seconds: index * 5),
      '第 ${index + 1} 行歌词，内容非常长非常长，用来验证沉浸模式下的居中歌词滚动不会出现 overflow，并且每一行都保持可读。',
      isBlank: false,
      length: const Duration(seconds: 5),
    );
  });
}

List<Audio> buildLongQueue() {
  return List.generate(
    28,
    (index) => TestAudio(
      title:
          'A very long title for queue item ${index + 1} that should still stay inside the queue panel',
      artist: 'An exceptionally long artist name ${index + 1}',
      album: 'Album ${index + 1}',
      path: 'E:\\Music\\queue_item_$index.flac',
    ),
  );
}
