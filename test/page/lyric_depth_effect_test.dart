import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_depth_effect.dart';

void main() {
  test('lyric depth blur is distance graded and capped', () {
    expect(
      resolveLyricDepthBlurSigma(
        distanceFromCurrent: 0,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      0,
    );
    // 紧邻行 (distance: 1) 默认应用浅景深弥散，确保焦点留在当前行
    expect(
      resolveLyricDepthBlurSigma(
        distanceFromCurrent: 1,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      greaterThan(1.0),
    );
    // 兼容传统模式：若显式设置 blurAdjacent: false 则保持 0
    expect(
      resolveLyricDepthBlurSigma(
        distanceFromCurrent: 1,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
        blurAdjacent: false,
      ),
      0,
    );
    expect(
      resolveLyricDepthBlurSigma(
        distanceFromCurrent: 8,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      lyricDepthMaxBlurSigma,
    );
    expect(createLyricDepthBlurFilter(lyricDepthMaxBlurSigma), isNotNull);
  });

  test('lyric depth blur only applies to contextual lines in visual mode', () {
    expect(
      shouldApplyLyricDepthBlur(
        distanceFromCurrent: 2,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      isTrue,
    );
    expect(
      shouldApplyLyricDepthBlur(
        distanceFromCurrent: 0,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      isFalse,
    );
    expect(
      shouldApplyLyricDepthBlur(
        distanceFromCurrent: 2,
        enabled: false,
        effectsLevel: UiEffectsLevel.visual,
      ),
      isFalse,
    );
    expect(
      shouldApplyLyricDepthBlur(
        distanceFromCurrent: 2,
        enabled: true,
        effectsLevel: UiEffectsLevel.balanced,
      ),
      isFalse,
    );
  });

  test('lyric opacity preserves readable adjacent context', () {
    final current = resolveLyricLineOpacity(
      distanceFromCurrent: 0,
      isPastLine: false,
    );
    final adjacent = resolveLyricLineOpacity(
      distanceFromCurrent: 1,
      isPastLine: false,
    );
    final far = resolveLyricLineOpacity(
      distanceFromCurrent: 5,
      isPastLine: false,
    );

    expect(current, 1);
    expect(adjacent, greaterThan(0.5));
    expect(far, lessThan(adjacent));
  });

  test('lyric depth blur focuses current line with optical falloff when blurAdjacent is true', () {
    // Current line (distance 0) is strictly 0.0 blur (clear focus)
    expect(
      resolveLyricDepthBlurSigma(
        distanceFromCurrent: 0,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
        blurAdjacent: true,
      ),
      0.0,
    );

    // Non-current adjacent line (distance 1) has soft focus
    final futureAdj = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 1,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      blurAdjacent: true,
      isPastLine: false,
    );
    final pastAdj = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 1,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      blurAdjacent: true,
      isPastLine: true,
    );
    expect(futureAdj, greaterThan(1.0));
    expect(pastAdj, greaterThan(futureAdj));

    // Non-current secondary line (distance 2) has medium blur
    final distance2 = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 2,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      blurAdjacent: true,
    );
    expect(distance2, greaterThan(futureAdj));

    // Distant lines (distance 4+) reach maximum bokeh cap
    final distance4 = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 4,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      blurAdjacent: true,
    );
    expect(distance4, equals(lyricDepthMaxBlurSigma));
    expect(lyricDepthMaxBlurSigma, greaterThan(5.0));
  });

  testWidgets('AnimatedLyricDepthBlur avoids ImageFiltered overhead when in focus (sigma <= 0.05)', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AnimatedLyricDepthBlur(
          sigma: 0.0,
          child: Text('当前清晰歌词'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前清晰歌词'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('AnimatedLyricDepthBlur smoothly applies ImageFiltered when defocused (sigma > 0)', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AnimatedLyricDepthBlur(
          sigma: 3.5,
          child: Text('非当前虚化歌词'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('非当前虚化歌词'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  test('AppSettings lyricDepthBlurNotifier updates reactively', () {
    final settings = AppSettings.instance;
    final initial = settings.lyricDepthBlur;
    var notifyCount = 0;
    void listener() => notifyCount++;

    settings.lyricDepthBlurNotifier.addListener(listener);
    try {
      settings.lyricDepthBlur = !initial;
      expect(notifyCount, 1);
      expect(settings.lyricDepthBlurNotifier.value, !initial);

      // Re-assigning same value should not trigger unnecessary notification
      settings.lyricDepthBlur = !initial;
      expect(notifyCount, 1);
    } finally {
      settings.lyricDepthBlurNotifier.removeListener(listener);
      settings.lyricDepthBlur = initial;
    }
  });

  test('interactive hover temporarily reduces blur and elevates opacity for seek inspection', () {
    final normalSigma = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 2,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      isHovered: false,
    );
    final hoveredSigma = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 2,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      isHovered: true,
    );

    expect(normalSigma, greaterThan(2.0));
    expect(hoveredSigma, equals(0.3));

    final normalOpacity = resolveLyricLineOpacity(
      distanceFromCurrent: 2,
      isPastLine: false,
      isHovered: false,
    );
    final hoveredOpacity = resolveLyricLineOpacity(
      distanceFromCurrent: 2,
      isPastLine: false,
      isHovered: true,
    );
    expect(hoveredOpacity, equals(0.95));
    expect(hoveredOpacity, greaterThan(normalOpacity));
  });

  test('depth blur bokeh luminance curve preserves text visibility over washed out backgrounds', () {
    final blurOnOpacity = resolveLyricLineOpacity(
      distanceFromCurrent: 1,
      isPastLine: false,
      depthBlurEnabled: true,
    );
    final blurOffOpacity = resolveLyricLineOpacity(
      distanceFromCurrent: 1,
      isPastLine: false,
      depthBlurEnabled: false,
    );
    expect(blurOnOpacity, greaterThan(blurOffOpacity));

    final blurOnFar = resolveLyricLineOpacity(
      distanceFromCurrent: 3,
      isPastLine: false,
      depthBlurEnabled: true,
    );
    final blurOffFar = resolveLyricLineOpacity(
      distanceFromCurrent: 3,
      isPastLine: false,
      depthBlurEnabled: false,
    );
    expect(blurOnFar, greaterThan(blurOffFar));
  });

  test('directional reading flow prioritizes future lines for anticipation', () {
    final futureAdj = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 1,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      isPastLine: false,
    );
    final pastAdj = resolveLyricDepthBlurSigma(
      distanceFromCurrent: 1,
      enabled: true,
      effectsLevel: UiEffectsLevel.visual,
      isPastLine: true,
    );
    expect(pastAdj, greaterThan(futureAdj));

    final futureOpacity = resolveLyricLineOpacity(
      distanceFromCurrent: 1,
      isPastLine: false,
      depthBlurEnabled: true,
    );
    final pastOpacity = resolveLyricLineOpacity(
      distanceFromCurrent: 1,
      isPastLine: true,
      depthBlurEnabled: true,
    );
    expect(futureOpacity, greaterThan(pastOpacity));
  });
}
