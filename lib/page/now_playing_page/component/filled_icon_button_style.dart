import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class LargeFilledIconButtonStyle extends ButtonStyle {
  const LargeFilledIconButtonStyle({
    required this.primary,
    required this.scheme,
    required this.surfaces,
    required this.accents,
    required this.visuals,
  }) : super(
          animationDuration: const Duration(milliseconds: 180),
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final bool primary;
  final ColorScheme scheme;
  final AppSurfaceTokens surfaces;
  final AppAccentTokens accents;
  final AppVisualTokens visuals;

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) {
          return primary ? accents.accent : scheme.secondary;
        }
        if (states.contains(WidgetState.hovered)) {
          return primary
              ? Color.lerp(accents.accentContainer, accents.accent, 0.2)
              : Color.lerp(
                  scheme.secondaryContainer,
                  scheme.secondary,
                  0.12,
                );
        }
        return primary ? accents.accentContainer : scheme.secondaryContainer;
      });

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return primary ? accents.onAccent : scheme.onSecondaryContainer;
      });

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((states) {
        final color = primary ? accents.onAccent : scheme.onSecondaryContainer;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return color.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.1);
        }
        return Colors.transparent;
      });

  @override
  WidgetStateProperty<double>? get elevation =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return 1.2;
        if (states.contains(WidgetState.hovered)) return 4.6;
        return 2.2;
      });

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      WidgetStateProperty.resolveWith((states) {
        final baseAlpha = accents.accentGlow.a * visuals.buttonGlowOpacity;
        if (states.contains(WidgetState.pressed)) {
          return accents.accentGlow.withValues(
            alpha: baseAlpha * visuals.buttonPressedGlowScale,
          );
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return accents.accentGlow.withValues(
            alpha: baseAlpha * visuals.buttonHoverGlowScale,
          );
        }
        return accents.accentGlow.withValues(alpha: baseAlpha);
      });

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return EdgeInsets.fromLTRB(
            8,
            8 + visuals.buttonPressOffset,
            8,
            8 - visuals.buttonPressOffset,
          );
        }
        return const EdgeInsets.all(8.0);
      });

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(64.0, 64.0));

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0);

  @override
  WidgetStateProperty<BorderSide?>? get side =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(
            color: accents.accentFocusRing.withValues(
              alpha: accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
            ),
            width: 1.5,
          );
        }
        return BorderSide(color: surfaces.strokeSubtle.withValues(alpha: 0.62));
      });

  @override
  WidgetStateProperty<OutlinedBorder>? get shape =>
      const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());

  @override
  WidgetStateProperty<MouseCursor?>? get mouseCursor =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return SystemMouseCursors.basic;
        }
        return SystemMouseCursors.click;
      });

  @override
  VisualDensity? get visualDensity => VisualDensity.standard;
}
