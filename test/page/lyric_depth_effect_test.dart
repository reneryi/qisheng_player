import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_depth_effect.dart';

void main() {
  test('lyric depth blur uses the stronger shared sigma', () {
    expect(lyricDepthBlurSigma, 3.2);
    expect(createLyricDepthBlurFilter(), isNotNull);
  });

  test('lyric depth blur only applies to contextual lines in visual mode', () {
    expect(
      shouldApplyLyricDepthBlur(
        isCurrentLine: false,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      isTrue,
    );
    expect(
      shouldApplyLyricDepthBlur(
        isCurrentLine: true,
        enabled: true,
        effectsLevel: UiEffectsLevel.visual,
      ),
      isFalse,
    );
    expect(
      shouldApplyLyricDepthBlur(
        isCurrentLine: false,
        enabled: false,
        effectsLevel: UiEffectsLevel.visual,
      ),
      isFalse,
    );
    expect(
      shouldApplyLyricDepthBlur(
        isCurrentLine: false,
        enabled: true,
        effectsLevel: UiEffectsLevel.balanced,
      ),
      isFalse,
    );
  });
}
