import 'dart:ui';

import 'package:qisheng_player/app_settings.dart';

const double lyricDepthMaxBlurSigma = 0.65;

double resolveLyricDepthBlurSigma({
  required int distanceFromCurrent,
  required bool enabled,
  required UiEffectsLevel effectsLevel,
}) {
  if (!enabled ||
      effectsLevel != UiEffectsLevel.visual ||
      distanceFromCurrent <= 0) {
    return 0;
  }
  return switch (distanceFromCurrent) {
    1 => 0.0,
    2 => 0.28,
    _ => lyricDepthMaxBlurSigma,
  };
}

double resolveLyricLineOpacity({
  required int distanceFromCurrent,
  required bool isPastLine,
}) {
  return switch (distanceFromCurrent) {
    <= 0 => 1.0,
    1 => isPastLine ? 0.64 : 0.58,
    2 => isPastLine ? 0.46 : 0.4,
    _ => isPastLine ? 0.32 : 0.26,
  };
}

ImageFilter createLyricDepthBlurFilter(double sigma) => ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.decal,
    );

bool shouldApplyLyricDepthBlur({
  required int distanceFromCurrent,
  required bool enabled,
  required UiEffectsLevel effectsLevel,
}) {
  return resolveLyricDepthBlurSigma(
        distanceFromCurrent: distanceFromCurrent,
        enabled: enabled,
        effectsLevel: effectsLevel,
      ) >
      0;
}
