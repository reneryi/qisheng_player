import 'package:qisheng_player/entry.dart';
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
}
