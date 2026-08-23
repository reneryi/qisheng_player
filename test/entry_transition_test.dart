import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/media_test_harness.dart';

void main() {
  test('SlideTransitionPage matches global route transition timing', () {
    const slidePage = SlideTransitionPage<void>(child: SizedBox.shrink());
    const nowPlayingPage =
        NowPlayingTransitionPage<void>(child: SizedBox.shrink());

    expect(slidePage.transitionDuration, nowPlayingPage.transitionDuration);
    expect(
      slidePage.reverseTransitionDuration,
      nowPlayingPage.reverseTransitionDuration,
    );
    // 极简主义测试：验证空间 Hero 转场的持续时间已更新为 520ms 和 380ms
    expect(slidePage.transitionDuration, const Duration(milliseconds: 520));
    expect(
      slidePage.reverseTransitionDuration,
      const Duration(milliseconds: 380),
    );
  });

  testWidgets(
      'NowPlayingRouteTransitionScope stays limited to now playing route',
      (tester) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 430),
      value: 1,
    );
    addTearDown(animation.dispose);

    Widget buildTransition(
      Widget Function(BuildContext context) builder,
    ) {
      return MaterialApp(
        theme: buildTestTheme(),
        home: Builder(builder: builder),
      );
    }

    const slidePage = SlideTransitionPage<void>(child: SizedBox.shrink());
    await tester.pumpWidget(
      buildTransition(
        (context) => slidePage.transitionsBuilder(
          context,
          animation,
          const AlwaysStoppedAnimation(0),
          const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(NowPlayingRouteTransitionScope), findsNothing);

    const nowPlayingPage =
        NowPlayingTransitionPage<void>(child: SizedBox.shrink());
    await tester.pumpWidget(
      buildTransition(
        (context) => nowPlayingPage.transitionsBuilder(
          context,
          animation,
          const AlwaysStoppedAnimation(0),
          const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(NowPlayingRouteTransitionScope), findsOneWidget);
  });

  testWidgets('now playing route fully hides and disables its underlay', (
    tester,
  ) async {
    final primary = AnimationController(
      vsync: tester,
      value: 1,
      duration: const Duration(milliseconds: 520),
    );
    final secondary = AnimationController(
      vsync: tester,
      value: 0,
      duration: const Duration(milliseconds: 520),
    );
    addTearDown(primary.dispose);
    addTearDown(secondary.dispose);
    AppNavigationState.instance.setNowPlayingPageActive(true);
    addTearDown(
      () => AppNavigationState.instance.setNowPlayingPageActive(false),
    );

    const page = SlideTransitionPage<void>(
      child: ColoredBox(
        key: ValueKey('shell-underlay'),
        color: Colors.red,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Builder(
          builder: (context) => page.transitionsBuilder(
            context,
            primary,
            secondary,
            page.child,
          ),
        ),
      ),
    );

    Opacity underlayOpacity() => tester.widget<Opacity>(
          find.byKey(const ValueKey('now-playing-underlay-opacity')),
        );
    IgnorePointer underlayPointer() => tester.widget<IgnorePointer>(
          find.byKey(const ValueKey('now-playing-underlay-pointer')),
        );

    expect(underlayOpacity().opacity, 1);
    expect(underlayPointer().ignoring, isFalse);

    secondary.value = 1;
    await tester.pump();
    expect(underlayOpacity().opacity, 0);
    expect(underlayPointer().ignoring, isTrue);

    secondary.value = 0.6;
    await tester.pump();
    expect(underlayOpacity().opacity, 0);

    secondary.value = 0.24;
    await tester.pump();
    expect(underlayOpacity().opacity, inExclusiveRange(0, 1));
  });

  testWidgets('now playing hides the complete shell and delays exit reveal', (
    tester,
  ) async {
    AppNavigationState.instance.setNowPlayingPageActive(false);
    addTearDown(
      () => AppNavigationState.instance.setNowPlayingPageActive(false),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: NowPlayingShellUnderlay(
          child: ColoredBox(
            key: ValueKey('complete-shell'),
            color: Colors.red,
          ),
        ),
      ),
    );

    AnimatedOpacity opacity() => tester.widget<AnimatedOpacity>(
          find.byKey(const ValueKey('now-playing-shell-underlay-opacity')),
        );
    IgnorePointer pointer() => tester.widget<IgnorePointer>(
          find.byKey(const ValueKey('now-playing-shell-underlay-pointer')),
        );

    expect(opacity().opacity, 1);
    expect(pointer().ignoring, isFalse);

    AppNavigationState.instance.setNowPlayingPageActive(true);
    await tester.pump();
    expect(opacity().opacity, 0);
    expect(pointer().ignoring, isTrue);

    AppNavigationState.instance.setNowPlayingPageActive(false);
    await tester.pump(const Duration(milliseconds: 119));
    expect(opacity().opacity, 0);
    expect(pointer().ignoring, isTrue);

    await tester.pump(const Duration(milliseconds: 2));
    expect(opacity().opacity, 1);
    expect(pointer().ignoring, isFalse);
  });
}
