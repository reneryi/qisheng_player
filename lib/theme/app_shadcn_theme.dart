import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class AppShadcnTheme {
  const AppShadcnTheme._();

  static shadcn.ThemeData build({
    required material.ColorScheme colorScheme,
    String? fontFamily,
  }) {
    final isDark = colorScheme.brightness == material.Brightness.dark;
    return shadcn.ThemeData(
      colorScheme: isDark
          ? shadcn.ColorSchemes.darkSlate
          : shadcn.ColorSchemes.lightSlate,
      radius: 0.72,
      scaling: 1.0,
      typography: shadcn.Typography.geist(
        sans: material.TextStyle(fontFamily: fontFamily),
        mono: material.TextStyle(fontFamily: fontFamily),
      ),
      surfaceOpacity: isDark ? 0.86 : 0.94,
      surfaceBlur: 18,
      enableFeedback: false,
      density: shadcn.Density.compactDensity,
    );
  }
}
