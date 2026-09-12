import 'package:qisheng_player/entry.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/media_test_harness.dart';

void main() {
  test('SlideTransitionPage matches global route transition timing', () {
    const slidePage = SlideTransitionPage<void>(child: SizedBox.shrink());
    const detailPage = DetailTransitionPage<void>(child: SizedBox.shrink());
    const nowPlayingPage =
        NowPlayingTransitionPage<void>(child: SizedBox.shrink());

    expect(slidePage.transitionDuration, const Duration(milliseconds: 360));
    expect(
      slidePage.reverseTransitionDuration,
      const Duration(milliseconds: 260),
    );
    expect(detailPage.transitionDuration, const Duration(milliseconds: 400));
    expect(
      detailPage.reverseTransitionDuration,
      const Duration(milliseconds: 320),
    );
    expect(
        nowPlayingPage.transitionDuration, const Duration(milliseconds: 520));
    expect(
      nowPlayingPage.reverseTransitionDuration,
      const Duration(milliseconds: 450),
    );
  });

  testWidgets('detail route fades its outgoing page completely during coverage',
      (tester) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );
    final secondaryAnimation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 400),
      value: 0.5,
    );
    addTearDown(animation.dispose);
    addTearDown(secondaryAnimation.dispose);

    const page = DetailTransitionPage<void>(
      child: ColoredBox(color: Colors.red),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Builder(
          builder: (context) => page.transitionsBuilder(
            context,
            animation,
            secondaryAnimation,
            page.child,
          ),
        ),
      ),
    );

    final incoming = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('detail-route-incoming-opacity')),
    );
    final outgoing = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('detail-route-outgoing-opacity')),
    );
    expect(incoming.opacity.value, greaterThan(0.12));
    expect(incoming.opacity.value, lessThanOrEqualTo(1));
    expect(outgoing.opacity.value, lessThan(1));
    expect(outgoing.opacity.value, greaterThan(0));

    secondaryAnimation.value = 1;
    await tester.pump();
    final fullyFadedOutgoing = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('detail-route-outgoing-opacity')),
    );
    expect(fullyFadedOutgoing.opacity.value, closeTo(0, 1e-6));
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
    await tester.pump();
    expect(opacity().opacity, 1);
    expect(pointer().ignoring, isFalse);
  });

  testWidgets(
      'now playing transition has transparent barrier and no shadow overlay', (
    tester,
  ) async {
    const page = NowPlayingTransitionPage<void>(
      child: SizedBox(key: ValueKey('now-playing-content')),
    );
    expect(page.barrierColor, Colors.transparent);
    expect(page.opaque, isFalse);

    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 520),
      value: 1.0,
    );
    addTearDown(animation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Builder(
          builder: (context) {
            final transitionWidget = page.transitionsBuilder(
              context,
              animation,
              const AlwaysStoppedAnimation(0),
              page.child,
            );
            expect(transitionWidget, isA<SlideTransition>());
            final slide = transitionWidget as SlideTransition;
            expect(slide.child, isA<NowPlayingRouteTransitionScope>());
            final scope = slide.child as NowPlayingRouteTransitionScope;
            expect(scope.child, page.child);
            return transitionWidget;
          },
        ),
      ),
    );

    expect(find.byType(NowPlayingRouteTransitionScope), findsOneWidget);
    // 确保绝对不存在任何 DecoratedBox 阴影遮罩覆盖在页面外
    expect(
      find.descendant(
        of: find.byType(SlideTransition),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('UI scaling with FittedBox covers full window and delivers pointer events at far bounds', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool tapped = false;
    const scale = 1.25;

    await tester.pumpWidget(
      MaterialApp(
        home: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final scaledWidth = width / scale;
            final scaledHeight = height / scale;
            return SizedBox(
              width: width,
              height: height,
              child: FittedBox(
                fit: BoxFit.fill,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: scaledWidth,
                  height: scaledHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => tapped = true,
                          child: const SizedBox(
                            width: 50,
                            height: 50,
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap at bottom-right of 800x600 (e.g. 780, 580)
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
