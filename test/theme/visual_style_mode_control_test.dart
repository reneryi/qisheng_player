import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/page/settings_page/theme_settings.dart';
import 'package:coriander_player/theme/app_theme.dart';
import 'package:coriander_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _buildTheme(UiVisualStyleMode mode) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(base, visualStyleMode: mode),
    effectsLevel: UiEffectsLevel.balanced,
    visualStyleMode: mode,
  );
}

void main() {
  testWidgets('VisualStyleModeControl updates provider and settings', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    provider.visualStyleMode = UiVisualStyleMode.glass;
    AppSettings.instance.uiVisualStyleMode = UiVisualStyleMode.glass;

    await tester.pumpWidget(
      MaterialApp(
        theme: _buildTheme(UiVisualStyleMode.glass),
        home: const Scaffold(
          body: Center(
            child: VisualStyleModeControl(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('高对比'));
    await tester.pumpAndSettle();

    expect(provider.visualStyleMode, UiVisualStyleMode.contrast);
    expect(AppSettings.instance.uiVisualStyleMode, UiVisualStyleMode.contrast);

    await tester.tap(find.text('玻璃'));
    await tester.pumpAndSettle();

    expect(provider.visualStyleMode, UiVisualStyleMode.glass);
    expect(AppSettings.instance.uiVisualStyleMode, UiVisualStyleMode.glass);
  });
}
