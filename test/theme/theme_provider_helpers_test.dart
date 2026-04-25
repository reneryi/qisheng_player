import 'package:coriander_player/theme/album_palette.dart';
import 'package:coriander_player/theme_provider.dart';
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
    final gradient = buildDynamicBackgroundGradient(const Color(0xFF53A4FF));

    expect(gradient, hasLength(3));
    expect(gradient.first.computeLuminance(),
        lessThan(const Color(0xFF53A4FF).computeLuminance()));
    expect(gradient.last.computeLuminance(),
        lessThan(gradient[1].computeLuminance()));
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

  test('AlbumPalette.fromColors fills missing roles from earlier colors', () {
    final palette = AlbumPalette.fromColors(
      const [
        Color(0xFF112233),
        Color(0xFF445566),
      ],
      fallback: const Color(0xFFABCDEF),
    );

    expect(palette.primary, const Color(0xFF112233));
    expect(palette.secondary, const Color(0xFF445566));
    expect(palette.accent, const Color(0xFF445566));
    expect(palette.muted, const Color(0xFF445566));
  });
}
