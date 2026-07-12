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

    expect(dark, hasLength(3));
    expect(light, hasLength(3));
    expect(dark, isNot(light));
    expect(
        dark.first,
        Color.alphaBlend(
          Colors.black.withValues(alpha: 0.55),
          palette.primary,
        ));
    expect(
        light.last,
        Color.alphaBlend(
          Colors.white.withValues(alpha: 0.85),
          palette.muted,
        ));
  });
}
