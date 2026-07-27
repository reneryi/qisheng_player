import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/fluid_gradient_background.dart';
import 'package:qisheng_player/theme/album_palette.dart';

void main() {
  const palette = AlbumPalette(
    primary: Color(0xFF336699),
    secondary: Color(0xFFCC8844),
    accent: Color(0xFF44AA88),
    muted: Color(0xFF777777),
  );

  test('fluid colors are derived from the shared album palette', () {
    final dark = resolveFluidGradientColors(palette, Brightness.dark);
    final light = resolveFluidGradientColors(palette, Brightness.light);
    final averageLuminance = (palette.primary.computeLuminance() +
            palette.secondary.computeLuminance() +
            palette.accent.computeLuminance()) /
        3;

    expect(dark, hasLength(3));
    expect(light, hasLength(3));
    expect(dark, isNot(light));
    expect(
        dark.first,
        Color.alphaBlend(
          Colors.black.withValues(
            alpha: (0.16 + averageLuminance * 0.10).clamp(0.12, 0.28),
          ),
          palette.primary,
        ));
    expect(
        light.last,
        Color.alphaBlend(
          Colors.white.withValues(
            alpha:
                (0.10 + (1 - averageLuminance) * 0.06).clamp(0.08, 0.18) + 0.08,
          ),
          palette.accent,
        ));
    expect(dark.toSet(), hasLength(3));
    expect(dark, isNot(contains(palette.muted)));
    expect(
      resolveFluidBaseColor(const [
        Color(0xFF336699),
        Color(0xFFCC8844),
        Color(0xFF44AA88),
      ]),
      Color.lerp(
        Color.lerp(palette.primary, palette.secondary, 0.24),
        palette.accent,
        0.10,
      ),
    );

    const neutral = AlbumPalette(
      primary: Color(0xFF666666),
      secondary: Color(0xFF888888),
      accent: Color(0xFF777777),
      muted: Color(0xFF555555),
    );
    final neutralScrim = resolveFluidScrimOpacity(
      resolveFluidGradientColors(neutral, Brightness.dark),
      Brightness.dark,
    );
    expect(neutralScrim, lessThan(0.30));
    final lightScrim = resolveFluidScrimOpacity(
      resolveFluidGradientColors(palette, Brightness.light),
      Brightness.light,
    );
    expect(lightScrim, lessThan(0.29));
  });
}
