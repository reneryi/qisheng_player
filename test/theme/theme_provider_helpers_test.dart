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
}
