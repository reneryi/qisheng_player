import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveThemeDominantColor falls back when dynamic color is absent', () {
    expect(
      resolveThemeDominantColor(
        fallbackColor: const Color(0xFF53A4FF),
      ),
      const Color(0xFF53A4FF),
    );

    expect(
      resolveThemeDominantColor(
        fallbackColor: const Color(0xFF53A4FF),
        dynamicDominantColor: const Color(0xFF123456),
      ),
      const Color(0xFF123456),
    );
  });

  test('buildDynamicBackgroundGradient returns a 3-stop darkened gradient', () {
    final gradient = buildDynamicBackgroundGradient(
        const Color(0xFF53A4FF), Brightness.dark);

    expect(gradient, hasLength(3));
    expect(gradient.first.computeLuminance(),
        lessThan(const Color(0xFF53A4FF).computeLuminance()));
    expect(gradient.last.computeLuminance(),
        lessThan(gradient[1].computeLuminance()));
  });

  test('neutral colors stay neutral in dynamic backgrounds', () {
    const neutral = Color(0xFF777777);
    expect(isNeutralColor(neutral), isTrue);

    final darkGradient = buildDynamicBackgroundGradient(neutral, Brightness.dark);
    final lightGradient = buildDynamicBackgroundGradient(neutral, Brightness.light);
    expect(darkGradient, hasLength(3));
    expect(lightGradient, hasLength(3));
    expect(
        HSLColor.fromColor(buildGlassTint(neutral, Brightness.dark)).saturation,
        lessThan(0.001));
  });

  test('buildGlassTint brightens dominant color by brightness mode', () {
    final darkTint = buildGlassTint(
      const Color(0xFF305080),
      Brightness.dark,
    );
    final lightTint = buildGlassTint(
      const Color(0xFF305080),
      Brightness.light,
    );

    expect(
        darkTint.computeLuminance(), greaterThan(lightTint.computeLuminance()));
  });

  test('buildDynamicSurfaceGradient creates primary-colored variants', () {
    final gradient = buildDynamicSurfaceGradient(
      const Color(0xFFE06A32),
      Brightness.dark,
    );

    expect(gradient, hasLength(2));
    expect(
      HSLColor.fromColor(gradient.first).hue,
      closeTo(HSLColor.fromColor(const Color(0xFFE06A32)).hue, 1),
    );
    expect(gradient.first.computeLuminance(),
        greaterThan(gradient.last.computeLuminance()));
  });

  test('dark surface gradient lifts dark artwork while preserving contrast',
      () {
    const darkBlue = Color(0xFF102A43);
    final gradient = buildDynamicSurfaceGradient(darkBlue, Brightness.dark);
    final sourceLightness = HSLColor.fromColor(darkBlue).lightness;
    final firstLightness = HSLColor.fromColor(gradient.first).lightness;
    final lastLightness = HSLColor.fromColor(gradient.last).lightness;

    expect(firstLightness, greaterThan(sourceLightness));
    expect(firstLightness - lastLightness, greaterThan(0.08));
    expect(
      HSLColor.fromColor(gradient.first).hue,
      closeTo(HSLColor.fromColor(darkBlue).hue, 1),
    );
  });

  test('light surface gradient keeps the existing lightness formula', () {
    const color = Color(0xFF537EA6);
    final gradient = buildDynamicSurfaceGradient(color, Brightness.light);
    final base = HSLColor.fromColor(color).lightness.clamp(0.28, 0.68);

    expect(
      HSLColor.fromColor(gradient.first).lightness,
      closeTo((base * 1.08).clamp(0.0, 1.0), 0.01),
    );
    expect(
      HSLColor.fromColor(gradient.last).lightness,
      closeTo((base * 0.92).clamp(0.0, 1.0), 0.01),
    );
  });

  test('AlbumPalette assigns perceptually separated real candidates', () {
    final palette = AlbumPalette.fromColors(
      const [
        Color(0xFFCC3344),
        Color(0xFFC83A49),
        Color(0xFF285FCC),
        Color(0xFF42A05C),
        Color(0xFF777777),
      ],
      fallback: const Color(0xFFABCDEF),
    );

    expect(palette.primary, const Color(0xFFCC3344));
    expect(
      perceptualColorDistance(palette.primary, palette.secondary),
      greaterThanOrEqualTo(0.10),
    );
    expect(
      perceptualColorDistance(palette.primary, palette.accent),
      greaterThanOrEqualTo(0.08),
    );
    expect(
      perceptualColorDistance(palette.secondary, palette.accent),
      greaterThanOrEqualTo(0.08),
    );
    expect(palette.muted, const Color(0xFF777777));
  });

  test('AlbumPalette derives same-family roles for near-monochrome art', () {
    final palette = AlbumPalette.fromColors(
      const [
        Color(0xFF594678),
        Color(0xFF5D497C),
        Color(0xFF554273),
      ],
      fallback: const Color(0xFFABCDEF),
    );
    final sourceHue = HSLColor.fromColor(palette.primary).hue;

    for (final color in [palette.secondary, palette.accent]) {
      final hue = HSLColor.fromColor(color).hue;
      final hueDistance = (hue - sourceHue).abs();
      expect(hueDistance.clamp(0, 360 - hueDistance), lessThanOrEqualTo(15));
    }
    expect(
      perceptualColorDistance(palette.primary, palette.secondary),
      greaterThan(0.08),
    );
    expect(palette.secondary, isNot(palette.accent));
  });

  test('AlbumPalette keeps derived neutral roles grayscale', () {
    final palette = AlbumPalette.fromColors(
      const [Color(0xFF777777)],
      fallback: const Color(0xFFABCDEF),
    );

    expect(
      palette.colors.every(
        (color) => HSLColor.fromColor(color).saturation < 0.001,
      ),
      isTrue,
    );
    expect(palette.primary, isNot(palette.secondary));
    expect(palette.secondary, isNot(palette.accent));
  });

  group('pureNeutralGradient default diagonal gradient tests', () {
    test('night dark gradient uses elegant 3-stop deep cyan diagonal palette', () {
      final darkGradient = pureNeutralGradient(Brightness.dark);
      expect(darkGradient, hasLength(3));
      expect(darkGradient[0], const Color(0xFF072229)); // 左上：深邃苍青
      expect(darkGradient[1], const Color(0xFF0C303A)); // 正中：微亮幽水青
      expect(darkGradient[2], const Color(0xFF041418)); // 右下：沉稳墨青黑

      // 验证全色阶色相均处于雅致的苍青/黛青色谱区间（190°~195°）
      for (final color in darkGradient) {
        final hsl = HSLColor.fromColor(color);
        expect(hsl.hue, inInclusiveRange(190.0, 195.0));
      }

      // 验证对角流光渐变明度层次：正中呈现微透光感膨胀，右下提供坚实暗阶下潜
      final l0 = HSLColor.fromColor(darkGradient[0]).lightness;
      final l1 = HSLColor.fromColor(darkGradient[1]).lightness;
      final l2 = HSLColor.fromColor(darkGradient[2]).lightness;
      expect(l1, greaterThan(l0));
      expect(l0, greaterThan(l2));
      expect(l2, lessThan(0.08));
    });

    test('day light gradient uses soft, non-glaring matte warm paper white palette', () {
      final lightGradient = pureNeutralGradient(Brightness.light);
      expect(lightGradient, hasLength(3));
      expect(lightGradient[0], const Color(0xFFF0F0EC)); // 左上：柔和暖云白
      expect(lightGradient[1], const Color(0xFFE8E8E4)); // 正中：哑光柔和纸白
      expect(lightGradient[2], const Color(0xFFDFDFD9)); // 右下：温润浅米灰

      // 验证峰值通道亮度受控，彻底根除高能量冷蓝（B通道<=240，消除刺眼强光）
      for (final color in lightGradient) {
        final rgbB = (color.b * 255).round();
        expect(rgbB, lessThanOrEqualTo(240));
      }

      // 验证 135° 对角阶梯递减平滑
      final l0 = HSLColor.fromColor(lightGradient[0]).lightness;
      final l1 = HSLColor.fromColor(lightGradient[1]).lightness;
      final l2 = HSLColor.fromColor(lightGradient[2]).lightness;
      expect(l0, greaterThan(l1));
      expect(l1, greaterThan(l2));
    });
  });
}

