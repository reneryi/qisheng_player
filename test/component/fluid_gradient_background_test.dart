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

  test('AlbumPalette correctly identifies neutral colors and preserves neutral palette', () {
    // 纯白、纯黑、灰度色
    expect(AlbumPalette.isNeutral(const Color(0xFFFFFFFF)), isTrue);
    expect(AlbumPalette.isNeutral(const Color(0xFF000000)), isTrue);
    expect(AlbumPalette.isNeutral(const Color(0xFF777777)), isTrue);
    expect(AlbumPalette.isNeutral(const Color(0xFF336699)), isFalse);

    // 中性色 fallback
    final neutralPalette = AlbumPalette.fallback(const Color(0xFF888888));
    for (final c in neutralPalette.colors) {
      final hsl = HSLColor.fromColor(c);
      expect(hsl.saturation, equals(0.0));
    }

    // 中性色 forDarkMode
    final darkNeutral = neutralPalette.forDarkMode();
    for (final c in darkNeutral.colors) {
      final hsl = HSLColor.fromColor(c);
      expect(hsl.saturation, equals(0.0));
    }
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

  testWidgets('defaultGradient backdrop renders full opaque gradient', (
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

    provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.defaultGradient,
      appliedMode: WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: false,
      nativeApplySucceeded: false,
    );
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
    for (final color in gradient.colors) {
      expect(color.a, equals(1.0));
    }
  });

  group('WaterRippleManager multi-ripple physics tests', () {
    test('addClickRipple creates independent click ripples without overwriting', () {
      final manager = WaterRippleManager();
      expect(manager.ripples, isEmpty);

      // 模拟第一次点击
      manager.addClickRipple(const Offset(0.2, 0.3), 1.0);
      expect(manager.ripples.length, equals(1));
      expect(manager.ripples[0].origin, equals(const Offset(0.2, 0.3)));
      expect(manager.ripples[0].type, equals(RippleType.click));
      expect(manager.ripples[0].birthTime, equals(1.0));

      // 模拟第二次独立点击
      manager.addClickRipple(const Offset(0.7, 0.8), 1.5);
      expect(manager.ripples.length, equals(2));
      expect(manager.ripples[0].origin, equals(const Offset(0.2, 0.3)));
      expect(manager.ripples[1].origin, equals(const Offset(0.7, 0.8)));
      expect(manager.ripples[1].birthTime, equals(1.5));
    });

    test('onPointerMove throttles high frequency and micro movements', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 极微小移动 (5px)，不应生成波纹
      manager.onPointerMove(
        normalizedPos: const Offset(0.505, 0.5),
        screenSize: screenSize,
        currentTime: 1.0,
      );
      expect(manager.ripples, isEmpty);

      // 满足距离 (>= 85px) 但时间太短 (< 220ms)
      manager.onPointerMove(
        normalizedPos: const Offset(0.60, 0.5),
        screenSize: screenSize,
        currentTime: 1.10,
      );
      expect(manager.ripples, isEmpty);

      // 满足距离和时间阈值 (100px, 250ms) 且速度有效
      manager.onPointerMove(
        normalizedPos: const Offset(0.70, 0.5),
        screenSize: screenSize,
        currentTime: 1.35,
      );
      expect(manager.ripples.length, equals(1));
      expect(manager.ripples[0].type, equals(RippleType.trail));
      expect(manager.ripples[0].amplitude, greaterThan(0.0));
    });

    test('updateAmbientRain maintains at least 3 active rain ripples concurrently', () {
      final manager = WaterRippleManager();

      // 首次调用触发初始化 3 个处于不同扩散周期的舒缓雨滴
      manager.updateAmbientRain(1.0);
      expect(manager.ripples.length, equals(3));
      for (final ripple in manager.ripples) {
        expect(ripple.type, equals(RippleType.rain));
        expect(ripple.duration, equals(3.2));
      }

      // 极短时间间隔内（0.1s），已满足至少3个雨滴且未到下一次调度时刻，不额外滥发
      manager.updateAmbientRain(1.1);
      expect(manager.ripples.length, equals(3));

      // 随着时间推移自然落水并淘汰旧雨滴，持续维持至少 3 个活跃雨滴
      manager.updateAmbientRain(2.5);
      expect(manager.ripples.length, greaterThanOrEqualTo(3));
    });

    test('onBassSample triggers bass kick ripple on transient peaks with cooldown', () {
      final manager = WaterRippleManager();

      // 低能量频谱，不触发
      manager.onBassSample([0.1, 0.1, 0.1], 1.0);
      expect(manager.ripples, isEmpty);

      // 强劲低音冲击 (Sub-bass peak > 0.42 and delta > 0.12)
      manager.onBassSample([0.8, 0.85, 0.75], 1.1);
      expect(manager.ripples.length, equals(1));
      expect(manager.ripples[0].type, equals(RippleType.bass));
      expect(manager.ripples[0].origin, equals(const Offset(0.5, 0.5)));

      // 冷却时间内的强低音 (100ms < 450ms cooldown)，被抑制
      manager.onBassSample([0.9, 0.9, 0.8], 1.2);
      expect(manager.ripples.length, equals(1));

      // 冷却时间后的强低音 (500ms > 450ms cooldown)
      manager.onBassSample([0.85, 0.9, 0.8], 1.7);
      expect(manager.ripples.length, equals(2));
    });

    test('pruneExpired correctly discards ripples after duration', () {
      final manager = WaterRippleManager();

      manager.addClickRipple(const Offset(0.5, 0.5), 1.0); // 持续 2.2s，到 3.2s 过期
      expect(manager.ripples.length, equals(1));

      manager.pruneExpired(2.0);
      expect(manager.ripples.length, equals(1));

      manager.pruneExpired(3.5);
      expect(manager.ripples, isEmpty);
    });
  });

  testWidgets('waterRipple mode renders CustomPaint with water ripple shader', (
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

    provider.windowBackdropMode = WindowBackdropMode.waterRipple;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.waterRipple,
      appliedMode: WindowBackdropMode.waterRipple,
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
            windowBackdropMode: WindowBackdropMode.waterRipple,
          ),
          home: FluidGradientBackground(child: child),
        ),
      );
    }

    await tester.pumpWidget(app(const SizedBox(key: ValueKey('shell'))));
    // 等待 shader 异步加载
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FluidGradientBackground), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // 模拟点击
    await tester.tap(find.byType(FluidGradientBackground));
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('defaultGradient renders pure neutral colors unaffected by vibrant album palette', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    final previousThemeMode = provider.themeMode;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
      provider.themeMode = previousThemeMode;
      provider.setDynamicAlbumPaletteForTesting(null);
    });

    provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.defaultGradient,
      appliedMode: WindowBackdropMode.defaultGradient,
      nativeBackdropSupported: false,
      nativeApplySucceeded: false,
    );
    // 高饱和度专辑调色板
    provider.setDynamicAlbumPaletteForTesting(
      const AlbumPalette(
        primary: Color(0xFFFF0055), // 鲜艳荧光红
        secondary: Color(0xFF00FFCC),
        accent: Color(0xFFFFCC00),
        muted: Color(0xFF8844AA),
        highlight: Color(0xFFFFFFFF),
      ),
    );

    // 1. 日间模式测试
    provider.applyThemeMode(ThemeMode.light);
    Widget buildApp() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
            ),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.defaultGradient,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('test_child')),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final decoratedLight = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FluidGradientBackground),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final lightGradient = (decoratedLight.decoration as BoxDecoration).gradient! as LinearGradient;
    final expectedLight = pureNeutralGradient(Brightness.light);
    expect(lightGradient.colors.length, equals(expectedLight.length));
    for (int i = 0; i < expectedLight.length; i++) {
      expect(lightGradient.colors[i], equals(expectedLight[i]));
    }

    // 2. 暗色模式测试
    provider.applyThemeMode(ThemeMode.dark);
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.defaultGradient,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('test_child')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decoratedDark = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FluidGradientBackground),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final darkGradient = (decoratedDark.decoration as BoxDecoration).gradient! as LinearGradient;
    final expectedDark = pureNeutralGradient(Brightness.dark);
    expect(darkGradient.colors.length, equals(expectedDark.length));
    for (int i = 0; i < expectedDark.length; i++) {
      expect(darkGradient.colors[i], equals(expectedDark[i]));
    }
  });

  testWidgets('meshFlow mode renders Stack with DecoratedBox and CustomPaint', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
    });

    provider.windowBackdropMode = WindowBackdropMode.meshFlow;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.meshFlow,
      appliedMode: WindowBackdropMode.meshFlow,
      nativeBackdropSupported: false,
      nativeApplySucceeded: false,
    );

    Widget app() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.meshFlow,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('test_child')),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    // 等待 shader 异步加载
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FluidGradientBackground), findsOneWidget);
    // 验证在 shader 加载后，流彩模式下具有底层复合 DecoratedBox 与表层 CustomPaint
    final decoratedBoxes = find.descendant(
      of: find.byType(FluidGradientBackground),
      matching: find.byType(DecoratedBox),
    );
    expect(decoratedBoxes, findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);

    // 深度断言：验证底层复合 DecoratedBox 严格承载基于 secondary 的 dynamicBackgroundGradient
    final baseDecoratedBox = tester.widget<DecoratedBox>(decoratedBoxes.first);
    final baseGradient =
        (baseDecoratedBox.decoration as BoxDecoration).gradient! as LinearGradient;
    final expectedBase = buildDynamicBackgroundGradient(
      provider.albumPalette.secondary,
      provider.effectiveBrightness,
    );
    expect(baseGradient.colors.length, equals(expectedBase.length));
    for (int i = 0; i < expectedBase.length; i++) {
      expect(baseGradient.colors[i], equals(expectedBase[i]));
    }
  });

  testWidgets('meshFlow mode gracefully renders meshBaseGradient when shader program is not yet loaded', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
    });

    provider.windowBackdropMode = WindowBackdropMode.meshFlow;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.meshFlow,
      appliedMode: WindowBackdropMode.meshFlow,
      nativeBackdropSupported: false,
      nativeApplySucceeded: false,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.meshFlow,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('test_child')),
          ),
        ),
      ),
    );

    // 立即断言（在 shader 异步加载完成前或无着色器环境下）
    // 必须优雅降级为基于专辑色彩的 meshBaseGradient，杜绝突兀白屏或纯中性渐变跳跃
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FluidGradientBackground),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final gradient =
        (decorated.decoration as BoxDecoration).gradient! as LinearGradient;
    final expectedBase = buildDynamicBackgroundGradient(
      provider.albumPalette.secondary,
      provider.effectiveBrightness,
    );
    expect(gradient.colors.length, equals(expectedBase.length));
    for (int i = 0; i < expectedBase.length; i++) {
      expect(gradient.colors[i], equals(expectedBase[i]));
    }
  });

  testWidgets('defaultGradient performs 350ms Oklab smooth transition on day/night switch', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousThemeMode = provider.themeMode;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.themeMode = previousThemeMode;
    });

    provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
    provider.applyThemeMode(ThemeMode.light);

    Widget buildApp() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
            ),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.defaultGradient,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('test_child')),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 初始状态：日间纯净中性白
    final decoratedLight = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FluidGradientBackground),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final initialGradient = (decoratedLight.decoration as BoxDecoration).gradient! as LinearGradient;
    final expectedLight = pureNeutralGradient(Brightness.light);
    expect(initialGradient.colors.first, equals(expectedLight.first));

    // 切换至夜间模式
    provider.applyThemeMode(ThemeMode.dark);
    await tester.pump(); // 触发 didChangeDependencies 与动画开始

    // 前进 175ms（半程）
    await tester.pump(const Duration(milliseconds: 175));
    final decoratedMid = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FluidGradientBackground),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final midGradient = (decoratedMid.decoration as BoxDecoration).gradient! as LinearGradient;
    final expectedDark = pureNeutralGradient(Brightness.dark);

    // 中间帧色相既不等于纯白天色，也不等于纯黑夜色
    expect(midGradient.colors.first, isNot(equals(expectedLight.first)));
    expect(midGradient.colors.first, isNot(equals(expectedDark.first)));

    // 前进至动画结束（额外 200ms）
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final decoratedDark = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FluidGradientBackground),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final endGradient = (decoratedDark.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(endGradient.colors.first, equals(expectedDark.first));
  });

  test('ThemeProvider backgroundGradient returns buildDynamicBackgroundGradient for meshFlow', () {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
    });

    provider.windowBackdropMode = WindowBackdropMode.meshFlow;
    final gradients = provider.backgroundGradient;
    expect(
      gradients,
      equals(buildDynamicBackgroundGradient(
        provider.albumPalette.secondary,
        provider.effectiveBrightness,
      )),
    );
  });

  test('ThemeProvider backgroundGradient returns pureNeutralGradient for defaultGradient when tint disabled', () {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousTint = AppSettings.instance.themeColorTintBackground;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      AppSettings.instance.themeColorTintBackground = previousTint;
    });

    AppSettings.instance.themeColorTintBackground = false;
    provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
    final gradients = provider.backgroundGradient;
    expect(gradients, equals(pureNeutralGradient(provider.effectiveBrightness)));
  });

  test('ThemeProvider backgroundGradient returns tinted gradient for defaultGradient when tint enabled', () {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousTint = AppSettings.instance.themeColorTintBackground;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      AppSettings.instance.themeColorTintBackground = previousTint;
    });

    AppSettings.instance.themeColorTintBackground = true;
    provider.windowBackdropMode = WindowBackdropMode.defaultGradient;
    final gradients = provider.backgroundGradient;
    expect(gradients.length, equals(3));
  });
}

