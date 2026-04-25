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
    Color at(int index, Color fallbackColor) {
      if (index >= colors.length) return fallbackColor;
      return colors[index];
    }

    final primary = at(0, fallback);
    final secondary = at(1, primary);
    final accent = at(2, secondary);
    final muted = at(3, secondary);

    return AlbumPalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
      muted: muted,
    );
  }

  List<Color> get colors => [primary, secondary, accent, muted];
}
