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

  /// 调色板 5 种主色彩的不可变列表，顺序对应 [primary], [secondary], [accent], [muted], [highlight]
  List<Color> get colors => [primary, secondary, accent, muted, highlight];

  Map<String, int> toMap() => {
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'accent': accent.toARGB32(),
        'muted': muted.toARGB32(),
        'highlight': highlight.toARGB32(),
      };

  static AlbumPalette? fromMap(Map? map) {
    if (map == null || map.isEmpty) return null;
    try {
      Color? parseColor(dynamic val) {
        if (val is num) {
          final intVal = val.toInt() & 0xFFFFFFFF;
          final withAlpha =
              (intVal & 0xFF000000) == 0 ? (intVal | 0xFF000000) : intVal;
          return Color(withAlpha);
        }
        if (val is String) {
          String s = val.trim();
          if (s.isEmpty) return null;
          if (s.startsWith('#')) s = s.substring(1);
          if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
          final parsed = int.tryParse(s, radix: 16) ?? int.tryParse(s);
          if (parsed != null) {
            final intVal = parsed & 0xFFFFFFFF;
            final withAlpha =
                (intVal & 0xFF000000) == 0 ? (intVal | 0xFF000000) : intVal;
            return Color(withAlpha);
          }
        }
        return null;
      }

      dynamic getVal(String key) {
        if (map.containsKey(key)) return map[key];
        final lower = key.toLowerCase();
        if (map.containsKey(lower)) return map[lower];
        final capitalized = key[0].toUpperCase() + key.substring(1);
        if (map.containsKey(capitalized)) return map[capitalized];
        return null;
      }

      final primary = parseColor(getVal('primary'));
      if (primary == null) return null;
      final secondary = parseColor(getVal('secondary')) ?? primary;
      final accent = parseColor(getVal('accent')) ?? primary;
      final muted = parseColor(getVal('muted')) ?? primary;
      final highlight = parseColor(getVal('highlight')) ?? primary;
      return AlbumPalette(
        primary: primary,
        secondary: secondary,
        accent: accent,
        muted: muted,
        highlight: highlight,
      );
    } catch (_) {
      return null;
    }
  }

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

    // 若主色是中性色（黑白灰），构建纯正黑白灰明暗阶梯，严禁强行注入杂色饱和度
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
    final baseSat = hsl.saturation
        .clamp(0.35, (0.95 - excess * 0.10).clamp(0.40, 0.95));
    final secondaryMaxL = 0.72 - excess * 0.18;
    final accentMaxL = 0.76 - excess * 0.20;
    final highlightMaxL = 0.88 - excess * 0.24;

    return AlbumPalette(
      primary: color,
      // 次主色：同色系明暗阶梯与邻近色调和 (+22°)，忠于原色且层次清晰
      secondary: hsl
          .withHue((hsl.hue + 22) % 360)
          .withSaturation(baseSat)
          .withLightness(
              (hsl.lightness + (isDark ? 0.10 : -0.06)).clamp(0.20, secondaryMaxL))
          .toColor(),
      // 强调色：邻近微偏 (-22°)，饱满生动
      accent: hsl
          .withHue((hsl.hue - 22 + 360) % 360)
          .withSaturation((baseSat * 1.04).clamp(0.0, 1.0))
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
    final primary = _selectPrimary(cleanedColors);
    final primaryIsNeutral = isNeutral(primary);

    // 2. 封面色彩忠实提取：优先从封面提取出的真实有彩色中挑选高色度对比的次主色与强调色
    // （避免死黑/死白仅凭明度差抢占 secondary/accent，把死黑死白留给专属的 muted 与 highlight）
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
      secondary:
          _clampForDarkMode(secondary, targetMinL: 0.30, targetMaxL: 0.58),
      accent: _clampForDarkMode(accent, targetMinL: 0.34, targetMaxL: 0.62),
      muted: _clampForDarkMode(muted,
          targetMinL: 0.12, targetMaxL: 0.25, isMuted: true),
      highlight: _clampForDarkMode(highlight,
          targetMinL: 0.38, targetMaxL: 0.68, isHighlight: true),
    );
  }

  /// 针对日间明亮模式进行高明度马卡龙水彩调谐（保留色彩饱满度与层次，杜绝局部死白）
  AlbumPalette forLightMode() {
    return AlbumPalette(
      primary: _clampForLightMode(primary, targetMinL: 0.50, targetMaxL: 0.72),
      secondary:
          _clampForLightMode(secondary, targetMinL: 0.52, targetMaxL: 0.74),
      accent: _clampForLightMode(accent, targetMinL: 0.50, targetMaxL: 0.72),
      muted: _clampForLightMode(muted,
          targetMinL: 0.70, targetMaxL: 0.86, isMuted: true),
      highlight: _clampForLightMode(highlight,
          targetMinL: 0.74, targetMaxL: 0.92, isHighlight: true),
    );
  }

  /// Apple Music `LyricsScene` 级流体光斑与极光舞台调色板：
  /// 1. 针对黑白灰封面（`allNeutral`）：严格保持 `0.0` 饱和度的纯正银灰与玄墨阶梯，绝不染色，同时拉开明暗反差使光斑清晰可见；
  /// 2. 针对刻意低饱和度的莫兰迪/冷灰水泥封面（`maxSat < 0.22 && maxChroma < 0.052`）：尊重封面低饱和度克制气质，通过明暗对比塑造光斑；
  /// 3. 针对单色/同色系封面（`maxHueSpan < 34°`）：以主色相为锚点进行 `±22°` 同色系谐波微展与深浅明度雕塑，告别单色平淡；
  /// 4. 针对多色封面（如《Up All Night》绿+黄、《Limitless》玫红+电光紫、《Children Of A Miracle》暖金+深海蓝）：
  ///    参考 Apple Music `LyricsScene` 色彩饱和度增强矩阵（Oversaturation Filter），对提取色进行通透度提纯并拉开各光斑明暗层次。
  AlbumPalette toAtmosphericStagePalette(double darkness) {
    final d = darkness.clamp(0.0, 1.0);
    final allNeutral =
        isNeutral(primary) && isNeutral(secondary) && isNeutral(accent);

    if (allNeutral) {
      const darkNeutral = AlbumPalette(
        primary: Color(0xFF5E6166),
        secondary: Color(0xFF3E4045),
        accent: Color(0xFF787C82),
        muted: Color(0xFF141518),
        highlight: Color(0xFF989CA4),
      );
      const lightNeutral = AlbumPalette(
        primary: Color(0xFFA2A6AE),
        secondary: Color(0xFFB8BCC4),
        accent: Color(0xFF8E929B),
        muted: Color(0xFFD6DAE0),
        highlight: Color(0xFFECEFF4),
      );
      return AlbumPalette.lerp(lightNeutral, darkNeutral, d) ??
          (d > 0.5 ? darkNeutral : lightNeutral);
    }

    final pHsl = HSLColor.fromColor(primary);
    final sHsl = HSLColor.fromColor(secondary);
    final aHsl = HSLColor.fromColor(accent);

    final maxSat = math.max(
      pHsl.saturation,
      math.max(sHsl.saturation, aHsl.saturation),
    );
    final maxChroma = math.max(
      _colorChroma(primary),
      math.max(_colorChroma(secondary), _colorChroma(accent)),
    );
    final isIntentionalMutedCover = maxSat < 0.22 && maxChroma < 0.052;

    final huePS = _hueAngleDiff(primary, secondary);
    final huePA = _hueAngleDiff(primary, accent);
    final hueSA = _hueAngleDiff(secondary, accent);
    final maxHueSpan = math.max(huePS, math.max(huePA, hueSA));
    final isNarrowHue = maxHueSpan < 34.0;

    AlbumPalette working;
    if (isIntentionalMutedCover) {
      // 莫兰迪/冷灰水泥封面（如 Catching On）：保持原有低饱和度高级灰调，绝不拉成刺眼荧光色，依靠明度跨度呈现流体光斑
      final baseHue = pHsl.hue;
      final gentleSat = (pHsl.saturation * 1.32).clamp(0.14, 0.36);
      working = AlbumPalette(
        primary: HSLColor.fromAHSL(1.0, baseHue, gentleSat, 0.42).toColor(),
        secondary: HSLColor.fromAHSL(
          1.0,
          (baseHue + 14.0) % 360.0,
          (gentleSat * 0.95).clamp(0.12, 0.34),
          0.30,
        ).toColor(),
        accent: HSLColor.fromAHSL(
          1.0,
          (baseHue - 14.0 + 360.0) % 360.0,
          (gentleSat * 1.08).clamp(0.16, 0.38),
          0.52,
        ).toColor(),
        muted: HSLColor.fromAHSL(1.0, baseHue, gentleSat * 0.55, 0.12).toColor(),
        highlight:
            HSLColor.fromAHSL(1.0, baseHue, gentleSat * 0.80, 0.64).toColor(),
      );
    } else if (isNarrowHue) {
      // 单色/同色系封面：在忠于主色相的前提下进行 ±22° 同色系双翼舒展与大幅明度阶梯雕塑
      final baseHue = pHsl.hue;
      final lum = pureHueLuminance(baseHue);
      final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
      final maxAllowedSat = (0.88 - excess * 0.12).clamp(0.58, 0.88);
      final vividSat =
          (pHsl.saturation * 1.38 + 0.14).clamp(0.48, maxAllowedSat);

      working = AlbumPalette(
        primary: HSLColor.fromAHSL(1.0, baseHue, vividSat, 0.42).toColor(),
        secondary: HSLColor.fromAHSL(
          1.0,
          (baseHue + 22.0) % 360.0,
          (vividSat * 0.94).clamp(0.44, maxAllowedSat),
          0.29,
        ).toColor(),
        accent: HSLColor.fromAHSL(
          1.0,
          (baseHue - 22.0 + 360.0) % 360.0,
          (vividSat * 1.05).clamp(0.50, maxAllowedSat),
          0.52,
        ).toColor(),
        muted: HSLColor.fromAHSL(
          1.0,
          (baseHue + 10.0) % 360.0,
          (vividSat * 0.48).clamp(0.18, 0.46),
          0.11,
        ).toColor(),
        highlight: HSLColor.fromAHSL(
          1.0,
          (baseHue - 10.0 + 360.0) % 360.0,
          (vividSat * 0.78).clamp(0.36, 0.76),
          0.62,
        ).toColor(),
      );
    } else {
      // 多色封面：应用 Apple Music 标志性的饱和度提纯与明度对比雕塑，让各色光斑鲜活通透
      Color enhanceRole(Color c, double minSat, double targetL) {
        if (isNeutral(c)) {
          return HSLColor.fromAHSL(
            1.0,
            pHsl.hue,
            (pHsl.saturation * 0.85).clamp(0.32, 0.72),
            targetL,
          ).toColor();
        }
        final hsl = HSLColor.fromColor(c);
        final lum = pureHueLuminance(hsl.hue);
        final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);
        final capSat = (0.90 - excess * 0.12).clamp(0.58, 0.90);
        final boostedSat =
            (hsl.saturation * 1.40 + 0.15).clamp(minSat, capSat);
        final blendedL = (hsl.lightness * 0.45 + targetL * 0.55)
            .clamp(0.24, 0.62 - excess * 0.14);
        return hsl.withSaturation(boostedSat).withLightness(blendedL).toColor();
      }

      working = AlbumPalette(
        primary: enhanceRole(primary, 0.50, 0.42),
        secondary: enhanceRole(secondary, 0.54, 0.36),
        accent: enhanceRole(accent, 0.56, 0.48),
        muted: HSLColor.fromColor(isNeutral(muted) ? primary : muted)
            .withSaturation(0.32)
            .withLightness(0.11)
            .toColor(),
        highlight: enhanceRole(
          isNeutral(highlight) ? accent : highlight,
          0.46,
          0.60,
        ),
      );
    }

    final lightPalette = working.forLightMode();
    final darkPalette = working.forDarkMode();
    return AlbumPalette.lerp(lightPalette, darkPalette, d) ??
        (d > 0.5 ? darkPalette : lightPalette);
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

  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);

  final maxLReduction = excess * (isHighlight ? 0.24 : (isMuted ? 0.05 : 0.22));
  final minLReduction = excess * (isMuted ? 0.03 : 0.12);
  final effectiveMaxL = (targetMaxL - maxLReduction).clamp(0.16, targetMaxL);
  final effectiveMinL = (targetMinL - minLReduction).clamp(0.08, effectiveMaxL);

  final clampedL = hsl.lightness.clamp(effectiveMinL, effectiveMaxL);

  final satFactor = 1.0 - excess * 0.04;
  final maxSat = (0.95 - math.pow(excess, 1.6) * 0.14).clamp(0.85, 0.95);
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

  final lum = AlbumPalette.pureHueLuminance(hsl.hue);
  final excess = ((lum - 0.30) / 0.62).clamp(0.0, 1.0);

  if (isHighlight) {
    final maxL = (0.84 - excess * 0.10).clamp(0.70, 0.82);
    final clampedL = hsl.lightness.clamp(0.66, maxL);
    final clampedS = (hsl.saturation * 1.15).clamp(0.40, 0.75);
    return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
  }

  if (isMuted) {
    final maxL = (0.86 - excess * 0.08).clamp(0.72, 0.84);
    final clampedL = hsl.lightness.clamp(0.68, maxL);
    final clampedS = (hsl.saturation * 0.50).clamp(0.08, 0.42);
    return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
  }

  final maxLReduction = excess * 0.24;
  final effectiveMaxL = (targetMaxL - maxLReduction).clamp(0.38, targetMaxL);
  final effectiveMinL = (targetMinL - excess * 0.16).clamp(0.30, effectiveMaxL);

  final clampedL = hsl.lightness.clamp(effectiveMinL, effectiveMaxL);
  final clampedS = (hsl.saturation * 1.02)
      .clamp(0.40, (0.90 - excess * 0.12).clamp(0.55, 0.90));
  return hsl.withLightness(clampedL).withSaturation(clampedS).toColor();
}

/// 对提取色进行色彩清洗（保留中性色中性，避免对中性色提纯造成杂色）
Color _cleanColor(Color color) {
  if (AlbumPalette.isNeutral(color)) {
    return HSLColor.fromColor(color).withSaturation(0.0).toColor();
  }
  return color;
}

/// 智能主色优选：当首位候选色为死黑阴影底色 (L < 0.15) 或过曝浅白底 (L > 0.82) 时，
/// 顺延推举封面上最具代表性的鲜活主体色作为 Primary（若全图为黑白灰封面则保持原状）。
Color _selectPrimary(List<Color> colors) {
  if (colors.length <= 1) return colors.first;
  final first = colors.first;
  final firstHsl = HSLColor.fromColor(first);

  if (firstHsl.lightness < 0.15 || firstHsl.lightness > 0.82) {
    for (var i = 1; i < colors.length; i++) {
      final candidate = colors[i];
      if (AlbumPalette.isNeutral(candidate)) continue;
      final hsl = HSLColor.fromColor(candidate);
      final chroma = _colorChroma(candidate);
      if (hsl.saturation >= 0.24 &&
          chroma >= 0.055 &&
          hsl.lightness >= 0.16 &&
          hsl.lightness <= 0.80) {
        return candidate;
      }
    }
  }
  return first;
}

double _colorChroma(Color color) {
  final lab = _toOklab(color);
  return math.sqrt(lab.$2 * lab.$2 + lab.$3 * lab.$3);
}

double _chromaticDistance(Color left, Color right) {
  final l = _toOklab(left);
  final r = _toOklab(right);
  final da = l.$2 - r.$2;
  final db = l.$3 - r.$3;
  return math.sqrt(da * da + db * db);
}

double _hueAngleDiff(Color a, Color b) {
  final ha = HSLColor.fromColor(a).hue;
  final hb = HSLColor.fromColor(b).hue;
  final diff = (ha - hb).abs();
  return diff > 180.0 ? 360.0 - diff : diff;
}

Color? _selectSecondary(List<Color> colors, Color primary) {
  if (colors.length < 2) return null;
  final primaryIsNeutral = AlbumPalette.isNeutral(primary);
  final hasChromaticCandidate = colors.any((c) {
    if (c == primary || AlbumPalette.isNeutral(c)) return false;
    final l = HSLColor.fromColor(c).lightness;
    return l >= 0.15 && l <= 0.82;
  });

  Color? selected;
  var bestScore = double.negativeInfinity;
  for (var index = 0; index < colors.length; index++) {
    final candidate = colors[index];
    if (candidate == primary) continue;
    final distance = perceptualColorDistance(primary, candidate);
    final chromaDist = _chromaticDistance(primary, candidate);
    final candChroma = _colorChroma(candidate);
    final candL = HSLColor.fromColor(candidate).lightness;
    final salience = 1 / (index + 1);

    // 重点奖励色平面 (a, b) 色相差与色度纯度，防止黑白灰阴影/高光仅靠明度差抢占次主色
    var score = chromaDist * 0.90 +
        candChroma * 0.45 +
        distance * 0.35 +
        salience * 0.20;
    if (!primaryIsNeutral && hasChromaticCandidate) {
      if (AlbumPalette.isNeutral(candidate) ||
          candL < 0.15 ||
          (candL > 0.80 && candChroma < 0.065)) {
        score *= 0.22;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      selected = candidate;
    }
  }
  return selected;
}

Color? _selectAccent(
  List<Color> colors, {
  required Color primary,
  required Color secondary,
}) {
  final primaryIsNeutral = AlbumPalette.isNeutral(primary);
  final hasChromaticCandidate = colors.any((c) {
    if (c == primary || c == secondary || AlbumPalette.isNeutral(c)) {
      return false;
    }
    final l = HSLColor.fromColor(c).lightness;
    return l >= 0.15 && l <= 0.82;
  });

  Color? selected;
  var bestScore = double.negativeInfinity;
  for (var index = 0; index < colors.length; index++) {
    final candidate = colors[index];
    if (candidate == primary || candidate == secondary) continue;
    final distance = math.min(
      perceptualColorDistance(primary, candidate),
      perceptualColorDistance(secondary, candidate),
    );
    final chromaDist = math.min(
      _chromaticDistance(primary, candidate),
      _chromaticDistance(secondary, candidate),
    );
    final candChroma = _colorChroma(candidate);
    final candL = HSLColor.fromColor(candidate).lightness;
    final salience = 1 / (index + 1);

    var score = chromaDist * 0.88 +
        candChroma * 0.48 +
        distance * 0.34 +
        salience * 0.16;
    if (!primaryIsNeutral && hasChromaticCandidate) {
      if (AlbumPalette.isNeutral(candidate) ||
          candL < 0.15 ||
          (candL > 0.80 && candChroma < 0.065)) {
        score *= 0.22;
      }
    }
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
  final baseSat = hsl.saturation
      .clamp(0.35, (0.95 - excess * 0.10).clamp(0.40, 0.95));
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

Color _lerpOklab(Color left, Color right, double t) {
  if (t <= 0.0) return left;
  if (t >= 1.0) return right;
  final clampedT = t.clamp(0.0, 1.0);
  final leftLab = _toOklab(left);
  final rightLab = _toOklab(right);
  final l = leftLab.$1 + (rightLab.$1 - leftLab.$1) * clampedT;
  final a = leftLab.$2 + (rightLab.$2 - leftLab.$2) * clampedT;
  final b = leftLab.$3 + (rightLab.$3 - leftLab.$3) * clampedT;
  final alpha = left.a + (right.a - left.a) * clampedT;
  return _fromOklab(l, a, b, alpha);
}

(double, double, double) _toOklab(Color color) {
  final r = _srgbToLinear(color.r);
  final g = _srgbToLinear(color.g);
  final b = _srgbToLinear(color.b);

  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color _fromOklab(double l, double a, double b, double alpha) {
  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final lCube = l_ * l_ * l_;
  final mCube = m_ * m_ * m_;
  final sCube = s_ * s_ * s_;

  final r = 4.0767416621 * lCube - 3.3077115913 * mCube + 0.2309699292 * sCube;
  final g = -1.2684380046 * lCube + 2.6097574011 * mCube - 0.3413193965 * sCube;
  final bLinear =
      -0.0041960863 * lCube - 0.7034186147 * mCube + 1.7076147010 * sCube;

  return Color.fromARGB(
    (alpha.clamp(0.0, 1.0) * 255).round(),
    (_linearToSrgb(r).clamp(0.0, 1.0) * 255).round(),
    (_linearToSrgb(g).clamp(0.0, 1.0) * 255).round(),
    (_linearToSrgb(bLinear).clamp(0.0, 1.0) * 255).round(),
  );
}

double _srgbToLinear(double value) {
  if (value <= 0.04045) {
    return value / 12.92;
  }
  return math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

double _linearToSrgb(double value) {
  if (value <= 0.0031308) {
    return 12.92 * value;
  }
  return 1.055 * math.pow(value, 1 / 2.4).toDouble() - 0.055;
}

double _cbrt(double value) {
  if (value <= 0) return 0;
  return math.pow(value, 1 / 3).toDouble();
}
