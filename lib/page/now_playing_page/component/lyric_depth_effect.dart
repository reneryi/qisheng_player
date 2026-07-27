import 'dart:ui';

import 'package:qisheng_player/app_settings.dart';

const double lyricDepthBlurSigma = 3.2;

ImageFilter createLyricDepthBlurFilter() => ImageFilter.blur(
      sigmaX: lyricDepthBlurSigma,
      sigmaY: lyricDepthBlurSigma,
      tileMode: TileMode.decal,
    );

bool shouldApplyLyricDepthBlur({
  required bool isCurrentLine,
  required bool enabled,
  required UiEffectsLevel effectsLevel,
}) {
  return !isCurrentLine && enabled && effectsLevel == UiEffectsLevel.visual;
}
