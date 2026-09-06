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

  /// 判断颜色是否为中性色（黑、白、灰、极低饱和度）
  static bool isNeutral(Color color) {
    final hsl = HSLColor.fromColor(color);
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    return hsl.saturation < 0.08 ||
        (hsl.saturation < 0.16 && (maxC - minC) < 18);
  }

  /// 计算色相在纯色状态下的 Rec. 709 相对感知亮度 (0.0722 ~ 0.9278)
  /// 用于动态调色板中消除黄、琥珀、橙、青、嫩绿等高感知亮度色相的严重过曝
  static double pureHueLuminance(double hue) {
    final h = (hue % 360.0 + 360.0) % 360.0;
    final sector = h / 60.0;
    final i = sector.floor();
    final f = sector - i;
    double r = 0, g = 0, b = 0;
    switch (i) {
      case 0:
        r = 1.0;
        g = f;
        b = 0.0;
        break;
      case 1:
        r = 1.0 - f;
        g = 1.0;
        b = 0.0;
        break;
      case 2:
        r = 0.0;
        g = 1.0;
        b = f;
        break;
      case 3:
        r = 0.0;
        g = 1.0 - f;
        b = 1.0;
        break;
      case 4:
        r = f;
        g = 0.0;
        b = 1.0;
        break;
      default:
        r = 1.0;
        g = 0.0;
        b = 1.0 - f;
        break;
    }
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  factory AlbumPalette.fallback(Color color) {
    final hsl = HSLColor.fromColor(color);
    final isDark = hsl.lightness < 0.5;

    // 若主色是中性色（黑白灰），构建纯正黑白灰明暗阶梯，严禁强行注入红橙饱和度
    if (isNeutral(color)) {
      return AlbumPalette(
        primary: color,
        secondary: hsl
            .withSaturation(0.0)
            .withLightness(isDark ? 0.35 : 0.70)
            .toColor(),
        accent: hsl
            .withSaturation(0.0)
            .withLightness(isDark ? 0.50 : 0.85)
            .toColor(),
        muted: hsl
            .withSaturation(0.0)
            .withLightness(isDark ? 0.12 : 0.92)
            .toColor(),
        highlight: hsl
            .withSaturation(0.0)
            .withLightness(isDark ? 0.75 : 0.98)
            .toColor(),
      );
    }

    final lum = pureHueLuminance(hsl.hue);
    final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
    final baseSat = hsl.saturation.clamp(0.35, (0.85 - excess * 0.15).clamp(0.40, 0.85));
    final secondaryMaxL = 0.72 - excess * 0.18;
    final accentMaxL = 0.76 - excess * 0.20;
    final highlightMaxL = 0.88 - excess * 0.24;

    return AlbumPalette(
      primary: color,
      // 次主色：同色系明暗阶梯与邻近色调和 (+28°)，层次清晰
      secondary: hsl
          .withHue((hsl.hue + 28) % 360)
          .withSaturation(baseSat)
          .withLightness(
              (hsl.lightness + (isDark ? 0.10 : -0.06)).clamp(0.20, secondaryMaxL))
          .toColor(),
      // 强调色：偏暖方向生动微偏 (-32°)，饱满生动
      accent: hsl
          .withHue((hsl.hue - 32 + 360) % 360)
          .withSaturation((baseSat * 1.06).clamp(0.0, 1.0))
          .withLightness(
              (hsl.lightness + (isDark ? 0.12 : -0.08)).clamp(0.22, accentMaxL))
          .toColor(),
      // 柔和底色：同色系深沉底色
      muted: hsl
          .withSaturation((baseSat * 0.35).clamp(0.0, 1.0))
          .withLightness(isDark ? 0.12 : 0.88)
          .toColor(),
      // 高光色：明亮珍珠光泽（根据色相感知亮度抑制过曝）
      highlight: hsl
          .withLightness((isDark ? 0.62 : 0.82).clamp(0.42, highlightMaxL))
          .withSaturation((baseSat * 0.65).clamp(0.35, 0.80))
          .toColor(),
    );
  }

  factory AlbumPalette.fromColors(
    List<Color> rawColors, {
    required Color fallback,
  }) {
    if (rawColors.isEmpty) return AlbumPalette.fallback(fallback);

    // 1. 色彩清洗与去噪（中性色规范化）
    final cleanedColors = rawColors.map(_cleanColor).toList();
    final primary = cleanedColors.first;
    final primaryIsNeutral = isNeutral(primary);

    // 2. 封面色彩忠实提取：优先从封面提取出的真实颜色中挑选次主色与强调色
    final secondaryCandidate = _selectSecondary(cleanedColors, primary);
    final secondary = secondaryCandidate != null &&
            perceptualColorDistance(primary, secondaryCandidate) > 0.075
        ? secondaryCandidate
        : _deriveHarmoniousColor(
            primary,
            hueOffset: 14.0,
            lightnessOffset: 0.14,
            forceNeutral: primaryIsNeutral,
          );

    final accentCandidate = _selectAccent(
      cleanedColors,
      primary: primary,
      secondary: secondary,
    );
    final accent = accentCandidate != null &&
            math.min(
                  perceptualColorDistance(primary, accentCandidate),
                  perceptualColorDistance(secondary, accentCandidate),
                ) >
                0.065
        ? accentCandidate
        : _deriveHarmoniousColor(
            primary,
            hueOffset: -14.0,
            lightnessOffset: -0.12,
            forceNeutral: primaryIsNeutral,
          );

    // 3. 提取或衍生柔和环境底色（优先取深沉阴影色）
    final muted = _selectMuted(cleanedColors, primary, secondary, accent,
        forceNeutral: primaryIsNeutral);

    // 4. 提取或衍生高光珠光点缀色
    final highlight = _selectHighlight(
        cleanedColors, primary, secondary, accent, muted,
        forceNeutral: primaryIsNeutral);

    return AlbumPalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
      muted: muted,
      highlight: highlight,
    );
  }

  List<Color> get colors => [primary, secondary, accent, muted, highlight];

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AlbumPalette &&
            other.primary == primary &&
            other.secondary == secondary &&
            other.accent == accent &&
            other.muted == muted &&
            other.highlight == highlight;
  }

  @override
  int get hashCode => Object.hash(primary, secondary, accent, muted, highlight);

  /// 针对暗色夜间模式进行明度与饱和度调谐（保持各角色原有阶梯层次，避免局部死黑或过曝）
  AlbumPalette forDarkMode() {
    return AlbumPalette(
      primary: _clampForDarkMode(primary, targetMinL: 0.28, targetMaxL: 0.55),
      secondary: _clampForDarkMode(secondary, targetMinL: 0.30, targetMaxL: 0.58),
      accent: _clampForDarkMode(accent, targetMinL: 0.34, targetMaxL: 0.62),
      muted: _clampForDarkMode(muted, targetMinL: 0.12, targetMaxL: 0.25, isMuted: true),
      highlight: _clampForDarkMode(highlight, targetMinL: 0.38, targetMaxL: 0.68, isHighlight: true),
    );
  }

  /// 针对日间明亮模式进行高明度马卡龙水彩调谐（保留色彩饱满度与层次，杜绝局部死白）
  AlbumPalette forLightMode() {
    return AlbumPalette(
      primary: _clampForLightMode(primary, targetMinL: 0.50, targetMaxL: 0.72),
      secondary: _clampForLightMode(secondary, targetMinL: 0.52, targetMaxL: 0.74),
      accent: _clampForLightMode(accent, targetMinL: 0.50, targetMaxL: 0.72),
      muted: _clampForLightMode(muted, targetMinL: 0.70, targetMaxL: 0.86, isMuted: true),
      highlight: _clampForLightMode(highlight, targetMinL: 0.74, targetMaxL: 0.92, isHighlight: true),
    );
  }

  /// 对两个调色板的 5 个角色颜色进行平滑插值过渡（Lerp）
  static AlbumPalette? lerp(AlbumPalette? a, AlbumPalette? b, double t) {
    if (identical(a, b)) return a;
    if (a == null) return b;
    if (b == null) return a;
    return AlbumPalette(
      primary: _lerpOklab(a.primary, b.primary, t),
      secondary: _lerpOklab(a.secondary, b.secondary, t),
      accent: _lerpOklab(a.accent, b.accent, t),
      muted: _lerpOklab(a.muted, b.muted, t),
      highlight: _lerpOklab(a.highlight, b.highlight, t),
    );
  }

  /// 对两个单色进行感知均匀的 Oklab 平滑插值过渡
  static Color lerpColor(Color a, Color b, double t) {
    return _lerpOklab(a, b, t);
  }
}

/// 暗色模式色彩自适应钳位：结合色相感知亮度智能调谐，根除黄/橙/青/绿过曝并保持各角色阶梯层次
Color _clampForDarkMode(
  Color color, {
  required double targetMinL,
  required double targetMaxL,
  bool isMuted = false,
  bool isHighlight = false,
}) {
  final hsl = HSLColor.fromColor(color);
  if (AlbumPalette.isNeutral(color)) {
    final clampedL = isMuted
        ? 0.14
        : (isHighlight ? 0.45 : hsl.lightness.clamp(0.24, 0.36));
    return hsl.withSaturation(0.0).withLightness(clampedL).toColor();
  }

  // 计算色相纯色感知亮度及超标比率
  // 阈值设为 0.30（基准平均感知亮度约 0.46，蓝/紫/洋红均 <= 0.28，黄 0.93，绿 0.72，青 0.79，橙 0.57）
  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);

  // 对过曝倾向严重的暖亮与高感光色（黄、橙、嫩绿、翠绿、青色）进行明度自适应下压
  final maxLReduction = excess * (isHighlight ? 0.24 : (isMuted ? 0.05 : 0.22));
  final minLReduction = excess * (isMuted ? 0.03 : 0.12);
  final effectiveMaxL = (targetMaxL - maxLReduction).clamp(0.16, targetMaxL);
  final effectiveMinL = (targetMinL - minLReduction).clamp(0.08, effectiveMaxL);

  final clampedL = hsl.lightness.clamp(effectiveMinL, effectiveMaxL);

  // 饱和度自适应：冷暗色（蓝/紫）适度提纯保证鲜明，高感知色（黄/橙/青/绿）限制饱和度过冲防止刺眼荧光感
  final satFactor = 1.02 - excess * 0.22;
  final maxSat = (0.84 - excess * 0.18).clamp(0.58, 0.84);
  final minSat = isMuted ? 0.0 : 0.20;
  final clampedS = (hsl.saturation * satFactor).clamp(minSat, maxSat);
  return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
}

/// 亮色模式色彩自适应钳位：适度提亮、保持水彩通透饱和度，优雅融入纸白且杜绝死白与脏色
Color _clampForLightMode(
  Color color, {
  required double targetMinL,
  required double targetMaxL,
  bool isMuted = false,
  bool isHighlight = false,
}) {
  final hsl = HSLColor.fromColor(color);
  if (AlbumPalette.isNeutral(color)) {
    final clampedL = isMuted
        ? 0.74
        : (isHighlight ? 0.88 : hsl.lightness.clamp(0.66, 0.80));
    return hsl.withSaturation(0.0).withLightness(clampedL).toColor();
  }

  // 对高感知亮度色相（黄、青、嫩绿等）在亮色模式下抑制过高明度，防止漂白成死白
  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);

  if (isHighlight) {
    // 亮色模式高光：作为柔和水彩光晕，明度在 0.70 ~ 0.82，温润通透杜绝死白
    final maxL = (0.84 - excess * 0.10).clamp(0.70, 0.82);
    final clampedL = hsl.lightness.clamp(0.66, maxL);
    final clampedS = (hsl.saturation * 1.15).clamp(0.40, 0.75);
    return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
  }

  if (isMuted) {
    // 亮色模式底色：柔和浅水彩背景
    final maxL = (0.86 - excess * 0.08).clamp(0.72, 0.84);
    final clampedL = hsl.lightness.clamp(0.68, maxL);
    final clampedS = (hsl.saturation * 0.50).clamp(0.08, 0.42);
    return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
  }

  // 主色、次主色与强调色：在浅色模式作为前景主要色彩，高感光度色相应当下调明度以确保在白底上的可读性与饱满质感
  final maxLReduction = excess * 0.24;
  final effectiveMaxL = (targetMaxL - maxLReduction).clamp(0.38, targetMaxL);
  final effectiveMinL = (targetMinL - excess * 0.16).clamp(0.30, effectiveMaxL);

  final clampedL = hsl.lightness.clamp(effectiveMinL, effectiveMaxL);
  final clampedS = (hsl.saturation * 1.02).clamp(0.40, (0.90 - excess * 0.12).clamp(0.55, 0.90));
  return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
}

/// 对提取色进行色彩清洗（保留中性色中性，避免对中性色提纯造成杂色）
Color _cleanColor(Color color) {
  if (AlbumPalette.isNeutral(color)) {
    return HSLColor.fromColor(color).withSaturation(0.0).toColor();
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
  Color accent, {
  required bool forceNeutral,
}) {
  final candidates = colors.where(
    (color) => color != primary && color != secondary && color != accent,
  );
  if (candidates.isEmpty) {
    final hsl = HSLColor.fromColor(primary);
    if (forceNeutral) {
      return hsl.withSaturation(0.0).withLightness(0.12).toColor();
    }
    return hsl
        .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
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
  Color muted, {
  required bool forceNeutral,
}) {
  final candidates = colors.where(
    (c) => c != primary && c != secondary && c != accent && c != muted,
  );
  if (candidates.isNotEmpty) {
    final candidate = candidates.reduce((left, right) {
      final leftHsl = HSLColor.fromColor(left);
      final rightHsl = HSLColor.fromColor(right);
      return leftHsl.lightness >= rightHsl.lightness ? left : right;
    });
    final hsl = HSLColor.fromColor(candidate);
    final lum = AlbumPalette.pureHueLuminance(hsl.hue);
    final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
    // 对高感光度色相 candidate 进行防过曝预收敛，避免把刺眼高光原样提取
    final maxL = 0.88 - excess * 0.20;
    if (hsl.lightness > maxL) {
      return hsl.withLightness(maxL).toColor();
    }
    return candidate;
  }

  final hsl = HSLColor.fromColor(primary);
  if (forceNeutral) {
    return hsl.withSaturation(0.0).withLightness(0.85).toColor();
  }
  // 依据主色色相感知亮度智能调和高光明度倍率，避免黄/橙等暖亮主色派生出过曝高光
  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
  final lightnessMultiplier = 1.28 - excess * 0.26;
  final maxLightness = 0.88 - excess * 0.24;
  final targetL = (hsl.lightness * lightnessMultiplier).clamp(0.50, maxLightness);
  final targetS = (hsl.saturation * 0.45).clamp(0.0, (0.75 - excess * 0.20));
  return hsl
      .withLightness(targetL)
      .withSaturation(targetS)
      .toColor();
}

/// 基于主色衍生高协调度、层次分明的临近与明暗阶梯角色色（兼具视觉对比与色彩统一性）
Color _deriveHarmoniousColor(
  Color source, {
  required double hueOffset,
  required double lightnessOffset,
  required bool forceNeutral,
}) {
  final hsl = HSLColor.fromColor(source);
  final isDark = hsl.lightness < 0.5;

  if (forceNeutral || AlbumPalette.isNeutral(source)) {
    final targetL =
        (hsl.lightness + (isDark ? lightnessOffset : -lightnessOffset))
            .clamp(0.12, 0.88);
    return hsl.withSaturation(0.0).withLightness(targetL).toColor();
  }

  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
  final maxL = 0.82 - excess * 0.18;
  final baseSat = hsl.saturation.clamp(0.35, (0.88 - excess * 0.15).clamp(0.40, 0.88));
  return hsl
      .withHue((hsl.hue + hueOffset + 360.0) % 360.0)
      .withSaturation(baseSat)
      .withLightness(
        (hsl.lightness + (isDark ? lightnessOffset : -lightnessOffset))
            .clamp(0.18, maxL),
      )
      .toColor();
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

Color _lerpOklab(Color a, Color b, double t) {
  final left = _toOklab(a);
  final right = _toOklab(b);
  final lab = (
    left.$1 + (right.$1 - left.$1) * t,
    left.$2 + (right.$2 - left.$2) * t,
    left.$3 + (right.$3 - left.$3) * t,
  );
  return _fromOklab(lab, Color.lerp(a, b, t)?.a ?? b.a);
}

Color _fromOklab((double, double, double) lab, double alpha) {
  final l = lab.$1;
  final a = lab.$2;
  final b = lab.$3;
  final lCube = l + 0.3963377774 * a + 0.2158037573 * b;
  final mCube = l - 0.1055613458 * a - 0.0638541728 * b;
  final sCube = l - 0.0894841775 * a - 1.2914855480 * b;
  final lms =
      (lCube * lCube * lCube, mCube * mCube * mCube, sCube * sCube * sCube);
  final red =
      4.0767416621 * lms.$1 - 3.3077115913 * lms.$2 + 0.2309699292 * lms.$3;
  final green =
      -1.2684380046 * lms.$1 + 2.6097574011 * lms.$2 - 0.3413193965 * lms.$3;
  final blue =
      -0.0041960863 * lms.$1 - 0.7034186147 * lms.$2 + 1.7076147010 * lms.$3;

  double encode(double channel) {
    final value = channel.clamp(0.0, 1.0).toDouble();
    return value <= 0.0031308
        ? value * 12.92
        : 1.055 * math.pow(value, 1 / 2.4).toDouble() - 0.055;
  }

  return Color.fromARGB(
    (alpha.clamp(0.0, 1.0) * 255).round(),
    (encode(red) * 255).round().clamp(0, 255),
    (encode(green) * 255).round().clamp(0, 255),
    (encode(blue) * 255).round().clamp(0, 255),
  );
}
