import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_controls_visibility.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/page/settings_page/theme_settings.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppPreference.instance.nowPlayingPagePref.autoHideControlBar = true;
  });

  group('NowPlayingPagePreference autoHideControlBar tests', () {
    test('Default autoHideControlBar is true', () {
      final pref = NowPlayingPagePreference(
        NowPlayingViewMode.withLyric,
        LyricTextAlign.left,
        true,
        22.0,
        18.0,
      );
      expect(pref.autoHideControlBar, isTrue);
      expect(pref.autoHideControlBarNotifier.value, isTrue);
    });

    test('toMap and fromMap serialize and deserialize autoHideControlBar', () {
      final pref = NowPlayingPagePreference(
        NowPlayingViewMode.withLyric,
        LyricTextAlign.left,
        true,
        22.0,
        18.0,
        false,
      );
      expect(pref.autoHideControlBar, isFalse);
      final map = pref.toMap();
      expect(map['autoHideControlBar'], isFalse);

      final restored = NowPlayingPagePreference.fromMap(map);
      expect(restored.autoHideControlBar, isFalse);
      expect(restored.autoHideControlBarNotifier.value, isFalse);

      // Default fallback when key is absent
      final fallback = NowPlayingPagePreference.fromMap({});
      expect(fallback.autoHideControlBar, isTrue);
    });

    test('Updating autoHideControlBar triggers autoHideControlBarNotifier', () {
      final pref = AppPreference.instance.nowPlayingPagePref;
      pref.autoHideControlBar = true;

      int notifyCount = 0;
      void listener() => notifyCount++;
      pref.autoHideControlBarNotifier.addListener(listener);

      pref.autoHideControlBar = false;
      expect(pref.autoHideControlBarNotifier.value, isFalse);
      expect(notifyCount, 1);

      // Idempotent assignment does not re-trigger
      pref.autoHideControlBar = false;
      expect(notifyCount, 1);

      pref.autoHideControlBar = true;
      expect(pref.autoHideControlBarNotifier.value, isTrue);
      expect(notifyCount, 2);

      pref.autoHideControlBarNotifier.removeListener(listener);
    });
  });

  group('SettingsPage NowPlayingAutoHideControlBarSwitch tests', () {
    testWidgets('Renders properly and toggles preference', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(
            body: NowPlayingAutoHideControlBarSwitch(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('播放详情页播控栏自动隐藏'), findsOneWidget);
      final switchFinder = find.byKey(const ValueKey('settings-auto-hide-switch'));
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      // Tap switch to turn OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(AppPreference.instance.nowPlayingPagePref.autoHideControlBar, isFalse);
      final switchAfterTap = tester.widget<Switch>(switchFinder);
      expect(switchAfterTap.value, isFalse);

      // Tap switch to turn ON again
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(AppPreference.instance.nowPlayingPagePref.autoHideControlBar, isTrue);
      final switchFinal = tester.widget<Switch>(switchFinder);
      expect(switchFinal.value, isTrue);
    });
  });

  group('LyricViewControls _AutoHideControlBarBtn tests', () {
    Widget buildLyricControlsHarness() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LyricViewController()),
          ChangeNotifierProvider(create: (_) => LyricControlsVisibilityController()),
        ],
        child: MaterialApp(
          theme: buildTestTheme(),
          home: const Scaffold(
            body: LyricViewControls(),
          ),
        ),
      );
    }

    testWidgets('Renders eye button with correct icon and tooltip according to state',
        (tester) async {
      AppPreference.instance.nowPlayingPagePref.autoHideControlBar = true;

      await tester.pumpWidget(buildLyricControlsHarness());
      await tester.pumpAndSettle();

      final btnFinder = find.byKey(const ValueKey('now-playing-auto-hide-btn'));
      expect(btnFinder, findsOneWidget);

      // When autoHide is true, icon is visibility_off_rounded and tooltip is "常驻播控栏"
      expect(find.byIcon(Symbols.visibility_off_rounded), findsOneWidget);
      expect(find.byTooltip('常驻播控栏'), findsOneWidget);

      // Tap to toggle autoHide to false
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(AppPreference.instance.nowPlayingPagePref.autoHideControlBar, isFalse);
      // When autoHide is false, icon is visibility_rounded and tooltip is "自动隐藏播控栏"
      expect(find.byIcon(Symbols.visibility_rounded), findsOneWidget);
      expect(find.byTooltip('自动隐藏播控栏'), findsOneWidget);

      // Tap again to toggle back to true
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(AppPreference.instance.nowPlayingPagePref.autoHideControlBar, isTrue);
      expect(find.byIcon(Symbols.visibility_off_rounded), findsOneWidget);
      expect(find.byTooltip('常驻播控栏'), findsOneWidget);
    });

    testWidgets('Eye button is located underneath the two font size buttons',
        (tester) async {
      await tester.pumpWidget(buildLyricControlsHarness());
      await tester.pumpAndSettle();

      final increaseFinder = find.byIcon(Symbols.text_increase);
      final decreaseFinder = find.byIcon(Symbols.text_decrease);
      final eyeFinder = find.byKey(const ValueKey('now-playing-auto-hide-btn'));

      expect(increaseFinder, findsOneWidget);
      expect(decreaseFinder, findsOneWidget);
      expect(eyeFinder, findsOneWidget);

      final increaseRect = tester.getRect(increaseFinder);
      final decreaseRect = tester.getRect(decreaseFinder);
      final eyeRect = tester.getRect(eyeFinder);

      // Eye button top must be below the bottom of both font size buttons
      expect(eyeRect.top, greaterThanOrEqualTo(increaseRect.bottom));
      expect(eyeRect.top, greaterThanOrEqualTo(decreaseRect.bottom));
    });
  });

  group('Bidirectional sync between Settings switch and NowPlaying button', () {
    testWidgets('Settings switch updates NowPlaying eye button and vice versa',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LyricViewController()),
            ChangeNotifierProvider(create: (_) => LyricControlsVisibilityController()),
          ],
          child: MaterialApp(
            theme: buildTestTheme(),
            home: const Scaffold(
              body: Column(
                children: [
                  NowPlayingAutoHideControlBarSwitch(),
                  LyricViewControls(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const ValueKey('settings-auto-hide-switch'));
      final eyeBtnFinder = find.byKey(const ValueKey('now-playing-auto-hide-btn'));

      // Initially both are true
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(find.byIcon(Symbols.visibility_off_rounded), findsOneWidget);

      // 1. Toggle via Settings switch -> NowPlaying eye button updates
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(AppPreference.instance.nowPlayingPagePref.autoHideControlBar, isFalse);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(find.byIcon(Symbols.visibility_rounded), findsOneWidget);

      // 2. Toggle via NowPlaying eye button -> Settings switch updates
      await tester.tap(eyeBtnFinder);
      await tester.pumpAndSettle();

      expect(AppPreference.instance.nowPlayingPagePref.autoHideControlBar, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(find.byIcon(Symbols.visibility_off_rounded), findsOneWidget);
    });
  });

  group('NowPlayingPage bottom bar auto-hide behavior tests', () {
    testWidgets(
        'Bottom bar stays visible when autoHideControlBar is false and does not hide after 5s',
        (tester) async {
      AppPreference.instance.nowPlayingPagePref.autoHideControlBar = false;

      final audio = TestAudio(
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        path: r'E:\Music\test.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: const NowPlayingPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Find bottom player bar
      final bottomBarFinder = find.byType(BottomPlayerBar);
      expect(bottomBarFinder, findsOneWidget);

      final opacityFinder = find.byKey(const ValueKey('auto-hide-bottom-player-bar-opacity'));
      expect(opacityFinder, findsOneWidget);
      final initialOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(initialOpacity.opacity, equals(1.0));

      // Advance time by 6 seconds (idle beyond 5s threshold)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 500));

      // Opacity should STILL be 1.0 because autoHideControlBar is false
      final opacityAfter6s = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(opacityAfter6s.opacity, equals(1.0));
    });

    testWidgets(
        'Bottom bar fades out after 5s when autoHideControlBar is true',
        (tester) async {
      AppPreference.instance.nowPlayingPagePref.autoHideControlBar = true;

      final audio = TestAudio(
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        path: r'E:\Music\test.flac',
      );
      final playback = FakePlaybackController(audio: audio, queue: [audio]);
      final lyric = FakeLyricController(Lrc(const [], LrcSource.local));

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: lyric,
          desktopLyricController: FakeDesktopLyricController(),
          child: const NowPlayingPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final opacityFinder = find.byKey(const ValueKey('auto-hide-bottom-player-bar-opacity'));
      expect(opacityFinder, findsOneWidget);
      final initialOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(initialOpacity.opacity, equals(1.0));

      // Advance time by 6 seconds (idle beyond 5s threshold)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 500));

      // Opacity should now be 0.0 because autoHideControlBar is true
      final opacityAfter6s = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(opacityAfter6s.opacity, equals(0.0));
    });
  });
}
