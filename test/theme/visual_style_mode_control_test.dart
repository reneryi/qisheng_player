import 'package:qisheng_player/page/settings_page/page.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('settings page no longer exposes visual style choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          colorScheme: AppTheme.applyChromeSurfaces(
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF53A4FF),
              brightness: Brightness.dark,
            ),
          ),
          effectsLevel: UiEffectsLevel.balanced,
        ),
        home: ChangeNotifierProvider<ThemeProvider>.value(
          value: ThemeProvider.instance,
          child: const Scaffold(body: SettingsPage()),
        ),
      ),
    );

    expect(find.text('UI 视觉风格'), findsNothing);
    expect(find.text('高对比'), findsNothing);
    expect(find.text('极简锐利'), findsNothing);
    expect(find.text('云母 Alt'), findsNothing);
    expect(find.text('亚克力'), findsNothing);
    expect(find.text('添加字体'), findsOneWidget);
  });
}
