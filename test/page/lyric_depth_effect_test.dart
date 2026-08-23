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
    expect(
      resolveLyricDepthBlurSigma(
        distanceFromCurrent: 1,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
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
}
