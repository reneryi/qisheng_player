import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 栖声播放器 5 色调和专辑调色板模型
class AlbumPalette {
  const AlbumPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.muted,
    required this.highlight,
  });

  /// 主导色 (Primary Dominant)
  final Color primary;

  /// 次主色 / 灵动色 (Vibrant Secondary)
  final Color secondary;

  /// 强调色 (Vibrant Accent)
  final Color accent;

  /// 柔和环境底色 (Soft Muted / Ambient)
  final Color muted;

  /// 高光点缀色 (Highlight Glow)
  final Color highlight;

  factory AlbumPalette.fallback(Color color) {
    final hsl = HSLColor.fromColor(color);
    final isDark = hsl.lightness < 0.5;
    return AlbumPalette(
      primary: color,
      secondary: hsl.withHue((hsl.hue + 25) % 360).toColor(),
      accent: hsl.withHue((hsl.hue - 30 + 360) % 360).toColor(),
      muted: hsl
          .withSaturation((hsl.saturation * 0.5).clamp(0.0, 1.0))
          .withLightness(isDark ? 0.12 : 0.88)
          .toColor(),
      highlight: hsl
          .withLightness((hsl.lightness + (isDark ? 0.25 : -0.25)).clamp(0.0, 1.0))
          .toColor(),
    );
  }

  factory AlbumPalette.fromColors(
    List<Color> rawColors, {
    required Color fallback,
  }) {
    if (rawColors.isEmpty) return AlbumPalette.fallback(fallback);

    // 1. 色彩清洗：过滤极度发灰的脏色
    final cleanedColors = rawColors.map(_cleanColor).toList();
    final primary = cleanedColors.first;

    // 2. 提取次主色
    final secondaryCandidate = _selectSecondary(cleanedColors, primary);
    final secondary = secondaryCandidate == null ||
            perceptualColorDistance(primary, secondaryCandidate) < 0.10
        ? _deriveRoleColor(primary, const [], preferLighter: true)
        : secondaryCandidate;

    // 3. 提取强调色
    final accentCandidate = _selectAccent(
      cleanedColors,
      primary: primary,
      secondary: secondary,
    );
    final accent = accentCandidate == null ||
            math.min(
                  perceptualColorDistance(primary, accentCandidate),
                  perceptualColorDistance(secondary, accentCandidate),
                ) <
                0.08
        ? _deriveRoleColor(
            primary,
            [secondary],
            preferLighter: false,
          )
        : accentCandidate;

    // 4. 提取柔和底色
    final muted = _selectMuted(cleanedColors, primary, secondary, accent);

    // 5. 提取高光色
    final highlight = _selectHighlight(cleanedColors, primary, secondary, accent, muted);

    return AlbumPalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
      muted: muted,
      highlight: highlight,
    );
  }

  List<Color> get colors => [primary, secondary, accent, muted, highlight];
}

/// 对提取色进行色彩清洗与饱和度/明度适度校准
Color _cleanColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  // 若饱和度过低且非纯黑白，提升微量饱和度以消除灰浊感
  if (hsl.saturation > 0.03 && hsl.saturation < 0.18) {
    return hsl.withSaturation(0.22).toColor();
  }
  return color;
}

Color? _selectSecondary(List<Color> colors, Color primary) {
  if (colors.length < 2) return null;
  Color? selected;
  var bestScore = double.negativeInfinity;
  for (var index = 1; index < colors.length; index++) {
    final distance = perceptualColorDistance(primary, colors[index]);
    final salience = 1 / (index + 1);
    final score = distance * 0.82 + salience * 0.18;
    if (score > bestScore) {
      bestScore = score;
      selected = colors[index];
    }
  }
  return selected;
}

Color? _selectAccent(
  List<Color> colors, {
  required Color primary,
  required Color secondary,
}) {
  Color? selected;
  var bestScore = double.negativeInfinity;
  for (var index = 1; index < colors.length; index++) {
    final candidate = colors[index];
    if (candidate == secondary) continue;
    final distance = math.min(
      perceptualColorDistance(primary, candidate),
      perceptualColorDistance(secondary, candidate),
    );
    final salience = 1 / (index + 1);
    final score = distance * 0.86 + salience * 0.14;
    if (score > bestScore) {
      bestScore = score;
      selected = candidate;
    }
  }
  return selected;
}

Color _selectMuted(
  List<Color> colors,
  Color primary,
  Color secondary,
  Color accent,
) {
  final candidates = colors.where(
    (color) => color != primary && color != secondary && color != accent,
  );
  if (candidates.isEmpty) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.5).clamp(0.08, 0.25))
        .toColor();
  }

  return candidates.reduce((left, right) {
    final leftHsl = HSLColor.fromColor(left);
    final rightHsl = HSLColor.fromColor(right);
    return leftHsl.saturation <= rightHsl.saturation ? left : right;
  });
}

Color _selectHighlight(
  List<Color> colors,
  Color primary,
  Color secondary,
  Color accent,
  Color muted,
) {
  final candidates = colors.where(
    (c) => c != primary && c != secondary && c != accent && c != muted,
  );
  if (candidates.isNotEmpty) {
    return candidates.reduce((left, right) {
      final leftHsl = HSLColor.fromColor(left);
      final rightHsl = HSLColor.fromColor(right);
      return leftHsl.lightness >= rightHsl.lightness ? left : right;
    });
  }

  final hsl = HSLColor.fromColor(primary);
  return hsl.withLightness((hsl.lightness * 1.35).clamp(0.70, 0.95)).toColor();
}

Color _deriveRoleColor(
  Color source,
  List<Color> existing, {
  required bool preferLighter,
}) {
  final hsl = HSLColor.fromColor(source);
  final neutral = hsl.saturation < 0.08;
  final hueOffsets = neutral ? const [0.0] : const [-14.0, -7.0, 7.0, 14.0];
  final saturationOffsets = neutral ? const [0.0] : const [-0.08, 0.0, 0.08];
  final lightnessOffsets = preferLighter
      ? const [0.14, 0.10, -0.14, -0.10]
      : const [-0.14, -0.10, 0.14, 0.10];

  Color? selected;
  var bestScore = double.negativeInfinity;
  for (final hueOffset in hueOffsets) {
    for (final saturationOffset in saturationOffsets) {
      for (final lightnessOffset in lightnessOffsets) {
        final candidate = hsl
            .withHue((hsl.hue + hueOffset + 360) % 360)
            .withSaturation(
              neutral
                  ? 0
                  : (hsl.saturation + saturationOffset).clamp(0.08, 0.88),
            )
            .withLightness(
              (hsl.lightness + lightnessOffset).clamp(0.16, 0.84),
            )
            .toColor();
        final distances = [
          perceptualColorDistance(source, candidate),
          for (final color in existing)
            perceptualColorDistance(color, candidate),
        ];
        final minimumDistance = distances.reduce(math.min);
        final preference =
            lightnessOffset.sign == (preferLighter ? 1.0 : -1.0) ? 0.004 : 0.0;
        final score = minimumDistance + preference;
        if (score > bestScore) {
          bestScore = score;
          selected = candidate;
        }
      }
    }
  }
  return selected ?? source;
}

double perceptualColorDistance(Color left, Color right) {
  final leftLab = _toOklab(left);
  final rightLab = _toOklab(right);
  final dl = leftLab.$1 - rightLab.$1;
  final da = leftLab.$2 - rightLab.$2;
  final db = leftLab.$3 - rightLab.$3;
  return math.sqrt(dl * dl + da * da + db * db);
}

(double, double, double) _toOklab(Color color) {
  double linearize(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  final red = linearize(color.r);
  final green = linearize(color.g);
  final blue = linearize(color.b);
  final l = math
      .pow(
        0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue,
        1 / 3,
      )
      .toDouble();
  final m = math
      .pow(
        0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue,
        1 / 3,
      )
      .toDouble();
  final s = math
      .pow(
        0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue,
        1 / 3,
      )
      .toDouble();
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}
