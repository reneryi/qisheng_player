import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';

import '../test_helpers/media_test_harness.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: buildTestTheme(),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('NowPlayingArtworkRectTween', () {
    test('artwork hero arc keeps exact endpoints and a restrained apex', () {
      final tween = NowPlayingArtworkRectTween(
        begin: const Rect.fromLTWH(20, 700, 56, 56),
        end: const Rect.fromLTWH(300, 120, 420, 420),
      );

      expect(tween.lerp(0), tween.begin);
      expect(tween.lerp(1), tween.end);

      final linearMidpoint = Rect.lerp(tween.begin, tween.end, 0.5)!;
      final curvedMidpoint = tween.lerp(0.5)!;
      expect(curvedMidpoint.top, lessThan(linearMidpoint.top));
      expect(
        linearMidpoint.top - curvedMidpoint.top,
        lessThanOrEqualTo(40.01),
      );
    });

    test('handles null begin or end gracefully', () {
      final tweenNullBegin = NowPlayingArtworkRectTween(
        begin: null,
        end: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(tweenNullBegin.lerp(0.5), isNull);

      final tweenNullEnd = NowPlayingArtworkRectTween(
        begin: const Rect.fromLTWH(0, 0, 100, 100),
        end: null,
      );
      expect(tweenNullEnd.lerp(0.5), isNull);
    });

    test('zero distance tween preserves exact rectangle without NaN', () {
      const rect = Rect.fromLTWH(100, 100, 50, 50);
      final tween = NowPlayingArtworkRectTween(begin: rect, end: rect);
      expect(tween.lerp(0.5), equals(rect));
    });
  });

  group('NowPlayingArtworkHeroFrame', () {
    testWidgets('renders child inside ClipRRect with specified radius', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const SizedBox(
            width: 100,
            height: 100,
            child: NowPlayingArtworkHeroFrame(
              radius: 18.0,
              elevation: 1.5,
              showShadow: true,
              child: Text('framed-content'),
            ),
          ),
        ),
      );

      expect(find.text('framed-content'), findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(18.0)));

      final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(18.0)));
      expect(decoration.boxShadow, isNotNull);
    });

    testWidgets('disables shadow when showShadow is false', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const SizedBox(
            width: 100,
            height: 100,
            child: NowPlayingArtworkHeroFrame(
              radius: 12.0,
              showShadow: false,
              child: Text('no-shadow'),
            ),
          ),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);
    });
  });

  group('NowPlayingArtworkCard', () {
    testWidgets('renders placeholder note icon when audio is null', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const SizedBox(
            width: 80,
            height: 80,
            child: NowPlayingArtworkCard(
              audio: null,
              radius: 20.0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Symbols.music_note), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
    });

    testWidgets('renders Image directly when coverProvider is supplied', (tester) async {
      final mockProvider = MemoryImage(Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]));

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            width: 120,
            height: 120,
            child: NowPlayingArtworkCard(
              audio: null,
              coverProvider: mockProvider,
              radius: 24.0,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, equals(mockProvider));
      expect(imageWidget.fit, equals(BoxFit.cover));
    });

    testWidgets('uses cached cover synchronously without rendering placeholder', (tester) async {
      final testAudio = TestAudio(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        path: '/path/to/cached_song.mp3',
      );
      final mockProvider = MemoryImage(Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]));

      NowPlayingArtworkCard.cacheSyncCover(testAudio, mockProvider);
      expect(NowPlayingArtworkCard.getSyncCover(testAudio), equals(mockProvider));

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            width: 100,
            height: 100,
            child: NowPlayingArtworkCard(
              audio: testAudio,
              radius: 16.0,
            ),
          ),
        ),
      );

      // On initial pump without delay, cached Image must be rendered immediately
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Symbols.music_note), findsNothing);
    });
  });

  group('nowPlayingArtworkFlightShuttleBuilder', () {
    testWidgets('renders flight shuttle smoothly during hero transition', (tester) async {
      Widget buildFlightTest({
        required double fromRadius,
        required double toRadius,
      }) {
        return _buildTestApp(
          Hero(
            tag: nowPlayingArtworkHeroTag,
            flightShuttleBuilder: nowPlayingArtworkFlightShuttleBuilder,
            child: NowPlayingArtworkCard(
              audio: null,
              radius: fromRadius,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildFlightTest(fromRadius: 26.0, toRadius: 24.0));
      expect(find.byType(NowPlayingArtworkCard), findsOneWidget);
    });
  });
}
