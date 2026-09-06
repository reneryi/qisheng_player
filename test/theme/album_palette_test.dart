import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/theme/album_palette.dart';

void main() {
  test('four to six extracted colors produce five stable roles', () {
    const fallback = Color(0xFF336699);
    for (final count in [4, 5, 6]) {
      final palette = AlbumPalette.fromColors(
        List.generate(
            count,
            (index) => Color.fromARGB(
                255, 40 + index * 30, 80 + index * 20, 120 + index * 15)),
        fallback: fallback,
      );
      expect(palette.colors, hasLength(5));
      expect(palette.primary, isNotNull);
      expect(palette.highlight, isNotNull);
    }
  });

  test('neutral fallback remains neutral across all roles', () {
    final palette = AlbumPalette.fromColors(
      const [Color(0xFF777777), Color(0xFFAAAAAA), Color(0xFF333333)],
      fallback: Colors.black,
    );
    for (final color in palette.colors) {
      expect(AlbumPalette.isNeutral(color), isTrue);
      expect(HSLColor.fromColor(color).saturation, lessThan(0.001));
    }
  });

  test('Oklab palette interpolation returns a valid midpoint', () {
    const left = AlbumPalette(
      primary: Color(0xFFFF0000),
      secondary: Color(0xFF00FF00),
      accent: Color(0xFF0000FF),
      muted: Color(0xFF222222),
      highlight: Color(0xFFFFFFFF),
    );
    const right = AlbumPalette(
      primary: Color(0xFF00FFFF),
      secondary: Color(0xFFFF00FF),
      accent: Color(0xFFFFFF00),
      muted: Color(0xFF888888),
      highlight: Color(0xFFEEEEEE),
    );
    final middle = AlbumPalette.lerp(left, right, 0.5)!;
    expect(middle.colors.every((color) => color.a > 0), isTrue);
    expect(middle.primary, isNot(left.primary));
    expect(middle.primary, isNot(right.primary));
  });

  test('forLightMode preserves saturation and comfortable watercolor lightness', () {
    const palette = AlbumPalette(
      primary: Color(0xFFCC3344),
      secondary: Color(0xFF285FCC),
      accent: Color(0xFF42A05C),
      muted: Color(0xFF886655),
      highlight: Color(0xFFEECC88),
    );
    final lightPalette = palette.forLightMode();

    for (final color in [lightPalette.primary, lightPalette.secondary, lightPalette.accent]) {
      final hsl = HSLColor.fromColor(color);
      // 饱和度保留在鲜活区间（不少于 0.38），明度适中，不致漂白成死白
      expect(hsl.saturation, greaterThanOrEqualTo(0.38));
      expect(hsl.lightness, inInclusiveRange(0.42, 0.75));
    }

    // muted 与 highlight 保持柔和水彩底衬且保留色彩（杜绝死白）
    expect(HSLColor.fromColor(lightPalette.muted).lightness, greaterThan(0.68));
    expect(HSLColor.fromColor(lightPalette.highlight).lightness, greaterThan(0.70));
  });

  test('AlbumPalette.lerpColor smoothly interpolates between two colors in Oklab space', () {
    const red = Color(0xFFFF0000);
    const cyan = Color(0xFF00FFFF);
    final mid = AlbumPalette.lerpColor(red, cyan, 0.5);
    expect(mid.a, greaterThan(0));
    expect(mid, isNot(red));
    expect(mid, isNot(cyan));
  });

  test('single extracted color derives distinct, harmonious secondary and accent with perceptual contrast', () {
    // 即使封面只有单一蓝色，也应派生出清晰但和谐的次主色与强调色，而非几乎无变化的同色
    final palette = AlbumPalette.fromColors(
      const [Color(0xFF2266AA)],
      fallback: Colors.blue,
    );
    final primaryDistSecondary =
        perceptualColorDistance(palette.primary, palette.secondary);
    final primaryDistAccent =
        perceptualColorDistance(palette.primary, palette.accent);
    final secondaryDistAccent =
        perceptualColorDistance(palette.secondary, palette.accent);

    expect(primaryDistSecondary, greaterThan(0.04));
    expect(primaryDistAccent, greaterThan(0.05));
    expect(secondaryDistAccent, greaterThan(0.04));
  });

  test('multi-color input with cold and warm tones faithfully selects distinct secondary and accent', () {
    // 模拟类似 Wild Ones 的蔚蓝天空与暖红手部输入
    final palette = AlbumPalette.fromColors(
      const [
        Color(0xFF7291B2), // 蔚蓝
        Color(0xFF7D3726), // 暖红褐
        Color(0xFF656672), // 灰蓝底色
        Color(0xFFAEAFBB), // 浅灰白高光
      ],
      fallback: Colors.blue,
    );

    // secondary 应当成功吸收暖红褐，拉开冷暖对比
    final secHsl = HSLColor.fromColor(palette.secondary);
    expect(secHsl.hue, inInclusiveRange(0.0, 50.0)); // 偏暖红色系
    expect(perceptualColorDistance(palette.primary, palette.secondary), greaterThan(0.15));
  });

  test('forDarkMode preserves brightness hierarchy without flattening all roles to single lightness', () {
    const palette = AlbumPalette(
      primary: Color(0xFF336699),
      secondary: Color(0xFF993344),
      accent: Color(0xFF44AA66),
      muted: Color(0xFF222B38),
      highlight: Color(0xFFCCDDEE),
    );
    final darkPalette = palette.forDarkMode();

    final primaryL = HSLColor.fromColor(darkPalette.primary).lightness;
    final mutedL = HSLColor.fromColor(darkPalette.muted).lightness;
    final highlightL = HSLColor.fromColor(darkPalette.highlight).lightness;

    // 层次必须清晰：高光 > 主色 > 底色
    expect(highlightL, greaterThan(primaryL));
    expect(primaryL, greaterThan(mutedL));
  });

  test('pureHueLuminance correctly reflects human photopic visual efficiency across spectrum', () {
    final yYellow = AlbumPalette.pureHueLuminance(60.0);
    final yLime = AlbumPalette.pureHueLuminance(90.0);
    final yCyan = AlbumPalette.pureHueLuminance(180.0);
    final yGreen = AlbumPalette.pureHueLuminance(120.0);
    final yOrange = AlbumPalette.pureHueLuminance(30.0);
    final yMagenta = AlbumPalette.pureHueLuminance(300.0);
    final yRed = AlbumPalette.pureHueLuminance(0.0);
    final yBlue = AlbumPalette.pureHueLuminance(240.0);

    // 黄色最高 (接近 0.93)，青/绿极高 (> 0.70)，橙较高 (~0.57)，蓝色最低 (~0.072)
    expect(yYellow, greaterThan(0.90));
    expect(yLime, greaterThan(0.80));
    expect(yCyan, greaterThan(0.75));
    expect(yGreen, greaterThan(0.70));
    expect(yOrange, greaterThan(0.50));
    expect(yBlue, lessThan(0.10));

    expect(yYellow, greaterThan(yOrange));
    expect(yOrange, greaterThan(yRed));
    expect(yRed, greaterThan(yBlue));
    expect(yMagenta, inInclusiveRange(0.25, 0.30));
  });

  test('high-luminance colors (yellow, orange, lime, green, cyan) are safely clamped to prevent overexposure in dark mode', () {
    // 覆盖橙色 (图中的鹿晗 1.1 同款色彩)、柠檬黄、荧光青、草木绿、青翠
    final testColors = <String, Color>{
      'orange': const Color(0xFFFF7700),
      'yellow': const Color(0xFFFFD700),
      'lime': const Color(0xFFA6FF00),
      'green': const Color(0xFF00E655),
      'cyan': const Color(0xFF00E5FF),
    };

    for (final entry in testColors.entries) {
      final name = entry.key;
      final raw = entry.value;
      final palette = AlbumPalette.fallback(raw).forDarkMode();

      final primaryHsl = HSLColor.fromColor(palette.primary);
      final secHsl = HSLColor.fromColor(palette.secondary);
      final accentHsl = HSLColor.fromColor(palette.accent);
      final highlightHsl = HSLColor.fromColor(palette.highlight);
      final mutedHsl = HSLColor.fromColor(palette.muted);

      // 1. 所有角色的明度上限均被有效压低，绝不允许产生接近白天的 0.55+ / 0.70 暴晒感
      expect(primaryHsl.lightness, lessThanOrEqualTo(0.52),
          reason: '$name primary lightness ${primaryHsl.lightness} is overexposed');
      expect(secHsl.lightness, lessThanOrEqualTo(0.54),
          reason: '$name secondary lightness ${secHsl.lightness} is overexposed');
      expect(accentHsl.lightness, lessThanOrEqualTo(0.58),
          reason: '$name accent lightness ${accentHsl.lightness} is overexposed');
      expect(highlightHsl.lightness, lessThanOrEqualTo(0.64),
          reason: '$name highlight lightness ${highlightHsl.lightness} is overexposed');

      // 2. 极高明度色（黄、青、嫩绿）的饱和度上限被控制在 <= 0.88，杜绝刺眼放射性荧光
      if (name == 'yellow' || name == 'lime' || name == 'cyan') {
        expect(primaryHsl.saturation, lessThanOrEqualTo(0.88),
            reason: '$name primary saturation over-saturated');
        expect(secHsl.saturation, lessThanOrEqualTo(0.88),
            reason: '$name secondary saturation over-saturated');
      }

      // 3. 严格维持角色层次：高光 > 主色 > 底色
      expect(highlightHsl.lightness, greaterThan(primaryHsl.lightness),
          reason: '$name highlight should be brighter than primary');
      expect(primaryHsl.lightness, greaterThan(mutedHsl.lightness),
          reason: '$name primary should be brighter than muted');
    }
  });

  test('cool colors (blue, purple) maintain rich depth and vividness without being excessively dimmed', () {
    const blue = Color(0xFF1E88E5);
    final palette = AlbumPalette.fallback(blue).forDarkMode();

    final primaryHsl = HSLColor.fromColor(palette.primary);
    final highlightHsl = HSLColor.fromColor(palette.highlight);

    // 蓝色由于自身感知亮度极低，不应被过度下压
    expect(primaryHsl.lightness, inInclusiveRange(0.40, 0.55));
    expect(highlightHsl.lightness, inInclusiveRange(0.60, 0.70));
  });

  test('high-luminance colors do not bleach out into dead white in light mode', () {
    final testColors = [
      const Color(0xFFFFE600), // 亮黄
      const Color(0xFF00FFFF), // 亮青
      const Color(0xFF76FF03), // 亮青绿
    ];

    for (final color in testColors) {
      final palette = AlbumPalette.fallback(color).forLightMode();
      final highlightHsl = HSLColor.fromColor(palette.highlight);

      // 高光明度绝不超过 0.82，保留柔美水彩质感，杜绝漂白成无字天书式的刺眼死白
      expect(highlightHsl.lightness, lessThanOrEqualTo(0.82));
      expect(highlightHsl.saturation, greaterThanOrEqualTo(0.40));
    }
  });
}


