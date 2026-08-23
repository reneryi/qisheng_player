import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/fluid_gradient_background.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/album_palette.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/window_controls.dart';
import 'package:provider/provider.dart';

void main() {
  const palette = AlbumPalette(
    primary: Color(0xFF336699),
    secondary: Color(0xFFCC8844),
    accent: Color(0xFF44AA88),
    muted: Color(0xFF777777),
    highlight: Color(0xFFAACCFF),
  );

  test('5-role album palette preserves roles and colors', () {
    expect(palette.colors, hasLength(5));
    expect(palette.primary, const Color(0xFF336699));
    expect(palette.secondary, const Color(0xFFCC8844));
    expect(palette.accent, const Color(0xFF44AA88));
    expect(palette.muted, const Color(0xFF777777));
    expect(palette.highlight, const Color(0xFFAACCFF));
  });

  testWidgets('defaultGradient renders 135-degree diagonal background', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    final previousEffects = provider.uiEffectsLevel;
    final previousBackgroundPath = AppSettings.instance.backgroundImagePath;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
      provider.uiEffectsLevel = previousEffects;
      AppSettings.instance.backgroundImagePath = previousBackgroundPath;
    });

    provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.defaultGradient,
      appliedMode: WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );
    provider.uiEffectsLevel = UiEffectsLevel.balanced;
    AppSettings.instance.backgroundImagePath = null;

    Widget app(Widget child) {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.defaultGradient,
          ),
          home: FluidGradientBackground(child: child),
        ),
      );
    }

    await tester.pumpWidget(app(const SizedBox(key: ValueKey('shell'))));
    expect(find.byType(FluidGradientBackground), findsOneWidget);
  });

  testWidgets('micaAlt backdrop uses light scrim so native material shows', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    final previousBackgroundPath = AppSettings.instance.backgroundImagePath;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
      AppSettings.instance.backgroundImagePath = previousBackgroundPath;
    });

    provider.windowBackdropMode = WindowBackdropMode.micaAlt;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.micaAlt,
      appliedMode: WindowBackdropMode.micaAlt,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );
    AppSettings.instance.backgroundImagePath = null;

    Widget app(Widget child) {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.micaAlt,
          ),
          home: FluidGradientBackground(child: child),
        ),
      );
    }

    await tester.pumpWidget(app(const SizedBox(key: ValueKey('shell'))));

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(FluidGradientBackground),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    // 微软规范：想看 Mica 材质的覆盖层必须近乎透明（≤ 0.16），
    // 防止再次出现 82% 阻尼底衬遮蔽原生材质的问题。
    for (final color in gradient.colors) {
      expect(color.a, lessThanOrEqualTo(0.16));
    }
  });
}
