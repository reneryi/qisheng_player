import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/component/editorial_bento_header.dart';
import 'package:qisheng_player/component/mini_hardware_deck.dart';
import 'package:qisheng_player/component/signal_path_inspector.dart';
import 'package:qisheng_player/component/ui/lens_glass_surface.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/play_service/audio_spectrum.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';
import 'package:qisheng_player/play_service/lyric_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/theme_provider.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  group('AcousticFeatures & Spectrum Physics Tests', () {
    test('computeAcousticFeatures returns zero for empty or silent spectrum', () {
      expect(computeAcousticFeatures(const []), equals(AcousticFeatures.zero));
      expect(
        computeAcousticFeatures(List<double>.filled(64, 0.0)),
        equals(AcousticFeatures.zero),
      );
    });

    test('computeAcousticFeatures extracts subBass, spectralCentroid, and rms', () {
      final spectrum = List<double>.generate(
        64,
        (i) => i < 4 ? 0.85 : (i < 24 ? 0.35 : 0.10),
      );
      final features = computeAcousticFeatures(spectrum);
      expect(features.isActive, isTrue);
      expect(features.subBassEnergy, closeTo(0.85, 1e-3));
      expect(features.midHarmonicEnergy, closeTo(0.35, 1e-3));
      expect(features.highBrilliance, closeTo(0.10, 1e-3));
      expect(features.spectralCentroid, inInclusiveRange(0.05, 0.55));
      expect(features.rmsEnergy, greaterThan(0.20));
    });
  });

  group('SignalPathSnapshot & SignalPathInspectorDialog Tests', () {
    test('SignalPathSnapshot classifies bitPerfect, highQualityDsp, and standard', () {
      final flacAudio = TestAudio(
        title: 'Master Track',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\master.flac',
      );
      final mp3Audio = TestAudio(
        title: 'Compressed Track',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\compressed.mp3',
      );

      final bitPerfect = SignalPathSnapshot.fromState(
        audio: flacAudio,
        wasapiExclusive: true,
        perceptualVolume: 0.5,
      );
      expect(bitPerfect.quality, equals(SignalPathQuality.bitPerfect));
      expect(bitPerfect.isLossless, isTrue);
      expect(bitPerfect.physicalAmplitude, closeTo(0.125, 1e-4));

      final dspPath = SignalPathSnapshot.fromState(
        audio: flacAudio,
        wasapiExclusive: false,
        perceptualVolume: 0.8,
      );
      expect(dspPath.quality, equals(SignalPathQuality.highQualityDsp));

      final standardPath = SignalPathSnapshot.fromState(
        audio: mp3Audio,
        wasapiExclusive: false,
        perceptualVolume: 1.0,
      );
      expect(standardPath.quality, equals(SignalPathQuality.standard));
      expect(standardPath.isLossless, isFalse);
    });

    testWidgets('SignalPathInspectorDialog renders nodes and toggles WASAPI Exclusive', (
      tester,
    ) async {
      final audio = TestAudio(
        title: 'Inspector Song',
        artist: 'Inspector Artist',
        album: 'Inspector Album',
        path: r'E:\Music\inspector.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc(const [], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Scaffold(
            body: Center(child: SignalPathInspectorDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('signal-path-inspector-dialog')),
        findsOneWidget,
      );
      expect(
        find.text('声学信号链检视器 · Signal Path'),
        findsOneWidget,
      );

      final toggleBtn = find.byKey(
        const ValueKey('signal-path-toggle-exclusive-btn'),
      );
      expect(toggleBtn, findsOneWidget);
      expect(playback.wasapiExclusive.value, isFalse);

      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();
      expect(playback.wasapiExclusive.value, isTrue);
    });
  });

  group('MiniHardwareDeckOverlay & Editorial Tracklist Tests', () {
    testWidgets('MiniHardwareDeckOverlay toggles visibility and controls playback', (
      tester,
    ) async {
      MiniHardwareDeckController.instance.value = false;
      addTearDown(() {
        MiniHardwareDeckController.instance.value = false;
      });

      final audio = TestAudio(
        title: 'Vinyl Song',
        artist: 'Vinyl Artist',
        album: 'Vinyl Album',
        path: r'E:\Music\vinyl.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(
              value: ThemeProvider.instance,
            ),
            ChangeNotifierProvider<PlaybackController>.value(value: playback),
            ChangeNotifierProvider<LyricController>.value(
              value: FakeLyricController(Lrc(const [], LrcSource.local)),
            ),
            ChangeNotifierProvider<DesktopLyricController>.value(
              value: FakeDesktopLyricController(),
            ),
          ],
          child: MaterialApp(
            theme: buildTestTheme(),
            home: const Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  MiniHardwareDeckOverlay(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('mini-hardware-deck-card')),
        findsNothing,
      );

      MiniHardwareDeckController.instance.toggle();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mini-hardware-deck-card')),
        findsOneWidget,
      );
      expect(find.text('DECK · 01'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mini-deck-close-btn')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mini-hardware-deck-card')),
        findsNothing,
      );
    });

    testWidgets('AudioTile with showCover false hides cover and displays editorialSubtitle', (
      tester,
    ) async {
      final audio = TestAudio(
        title: 'Liner Note Song',
        artist: 'Taylor Swift',
        album: '1989',
        composer: 'Max Martin',
        path: r'E:\Music\liner.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc(const [], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: Scaffold(
            body: AudioTile(
              showCover: false,
              editorialSubtitle: 'Taylor Swift  ·  作曲 Max Martin',
              leading: const Text('01'),
              audioIndex: 0,
              playlist: [audio],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01'), findsOneWidget);
      expect(find.text('Liner Note Song'), findsOneWidget);
      expect(find.text('Taylor Swift  ·  作曲 Max Martin'), findsOneWidget);
    });

    testWidgets('LibraryFocusFilterBar filters dimensions and LensGlassSurface renders cleanly', (
      tester,
    ) async {
      var selectedDim = LibraryFocusDimension.all;
      final flac = TestAudio(
        title: 'Lossless Track',
        artist: 'Artist',
        album: 'Album',
        path: r'E:\Music\lossless.flac',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Column(
              children: [
                LibraryFocusFilterBar(
                  allAudios: [flac],
                  activeFocus: selectedDim,
                  onFocusChanged: (dim) => selectedDim = dim,
                ),
                const SizedBox(
                  width: 240,
                  height: 80,
                  child: LensGlassSurface(
                    enableAudioReactivity: false,
                    child: Center(child: Text('Refractive Pod')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('library-focus-filter-bar')),
        findsOneWidget,
      );
      expect(find.text('Refractive Pod'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('focus-pill-lossless')),
      );
      await tester.pump();
      expect(selectedDim, equals(LibraryFocusDimension.lossless));
    });
  });
}
