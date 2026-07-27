import 'dart:math' as math;

import 'package:flutter/material.dart';

class AlbumPalette {
  const AlbumPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.muted,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color muted;

  factory AlbumPalette.fallback(Color color) {
    return AlbumPalette(
      primary: color,
      secondary: color,
      accent: color,
      muted: color,
    );
  }

  factory AlbumPalette.fromColors(
    List<Color> colors, {
    required Color fallback,
  }) {
    if (colors.isEmpty) return AlbumPalette.fallback(fallback);

    final primary = colors.first;
    final secondaryCandidate = _selectSecondary(colors, primary);
    final secondary = secondaryCandidate == null ||
            perceptualColorDistance(primary, secondaryCandidate) < 0.10
        ? _deriveRoleColor(primary, const [], preferLighter: true)
        : secondaryCandidate;
    final accentCandidate = _selectAccent(
      colors,
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
    final muted = _selectMuted(colors, primary, secondary, accent);

    return AlbumPalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
      muted: muted,
    );
  }

  List<Color> get colors => [primary, secondary, accent, muted];
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
  if (candidates.isEmpty) return secondary;

  return candidates.reduce((left, right) {
    final leftIndex = colors.indexOf(left);
    final rightIndex = colors.indexOf(right);
    final leftScore = HSLColor.fromColor(left).saturation + leftIndex * 0.025;
    final rightScore =
        HSLColor.fromColor(right).saturation + rightIndex * 0.025;
    return leftScore <= rightScore ? left : right;
  });
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
