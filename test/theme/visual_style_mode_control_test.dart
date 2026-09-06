import 'package:qisheng_player/page/settings_page/theme_settings.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('settings page correctly exposes new visual styles and backdrop materials', (
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
          child: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  WindowBackdropModeControl(),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('UI 视觉风格'), findsNothing);
    expect(find.text('纯净卡片'), findsNothing);
    expect(find.text('无界悬浮'), findsNothing);
    expect(find.text('液态玻璃'), findsNothing);

    expect(find.text('窗口底座材质'), findsOneWidget);
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('默认渐变'), findsNothing);
    expect(find.text('增强云母'), findsNothing);
    expect(find.text('亚克力'), findsNothing);
    expect(find.text('弥散流彩'), findsOneWidget);
    expect(find.text('水波纹'), findsOneWidget);
    expect(find.text('极光漫染'), findsOneWidget);
    expect(find.text('琉璃透镜'), findsNothing);
  });
}
