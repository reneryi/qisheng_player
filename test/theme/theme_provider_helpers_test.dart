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
}
