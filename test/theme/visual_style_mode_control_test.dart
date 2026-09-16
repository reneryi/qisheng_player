import 'package:qisheng_player/page/settings_page/theme_settings.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('qisheng_player/window_controls'),
      (MethodCall call) async {
        if (call.method == 'set_window_backdrop_mode') {
          return {
            'applied_mode': call.arguments['mode'] ?? 'none',
            'native_backdrop_supported': true,
            'fallback_reason': null,
          };
        }
        return null;
      },
    );
  });

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

    // Verify SegmentedButton is used instead of ChoiceChip
    expect(find.byType(SegmentedButton<WindowBackdropMode>), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('WindowBackdropModeControl switches backdrop mode via SegmentedButton', (
    tester,
  ) async {
    final theme = ThemeProvider.instance;
    final settings = AppSettings.instance;
    theme.windowBackdropMode = WindowBackdropMode.defaultGradient;
    settings.windowBackdropMode = WindowBackdropMode.defaultGradient;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF53A4FF),
            brightness: Brightness.dark,
          ),
          effectsLevel: UiEffectsLevel.balanced,
        ),
        home: ChangeNotifierProvider<ThemeProvider>.value(
          value: theme,
          child: const Scaffold(
            body: WindowBackdropModeControl(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<WindowBackdropMode>), findsOneWidget);

    // Tap "弥散流彩"
    await tester.tap(find.text('弥散流彩'));
    await tester.pumpAndSettle();

    expect(settings.windowBackdropMode, equals(WindowBackdropMode.meshFlow));
    expect(theme.windowBackdropMode, equals(WindowBackdropMode.meshFlow));

    // Tap "水波纹"
    await tester.tap(find.text('水波纹'));
    await tester.pumpAndSettle();

    expect(settings.windowBackdropMode, equals(WindowBackdropMode.waterRipple));
    expect(theme.windowBackdropMode, equals(WindowBackdropMode.waterRipple));
  });
}
