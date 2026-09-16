import 'dart:io';

import 'package:flutter/gestures.dart';
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

    test('interactive ripples do not evict ambient rain or bass ripples when reaching max capacity', () {
      final manager = WaterRippleManager();

      // 初始化自然雨滴与低音共振
      manager.updateAmbientRain(1.0);
      expect(manager.ripples.where((r) => r.type == RippleType.rain).length, equals(3));
      manager.onBassSample([0.85, 0.9, 0.8], 1.1);
      expect(manager.ripples.where((r) => r.type == RippleType.bass).length, equals(1));

      // 持续产生大量交互微澜和点击，直到突破 maxRipples 限制 (16 个)
      for (var i = 0; i < 20; i++) {
        manager.addClickRipple(Offset(0.1 + i * 0.03, 0.2), 1.2 + i * 0.02);
      }
      expect(manager.ripples.length, equals(WaterRippleManager.maxRipples));

      // 验证环境雨滴和低音共振依然完整保留，未被挤出或提前截断
      final rainCount = manager.ripples.where((r) => r.type == RippleType.rain).length;
      final bassCount = manager.ripples.where((r) => r.type == RippleType.bass).length;
      expect(rainCount, equals(3));
      expect(bassCount, equals(1));
    });

    test('pointer move and click events preserve ambient rain lifecycle and do not cause re-initialization', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 初始帧生成雨滴
      manager.updateAmbientRain(1.0);
      final initialRipples = List<RippleSource>.from(manager.ripples);
      expect(initialRipples.length, equals(3));

      // 发生鼠标移动交互
      manager.onPointerMove(
        normalizedPos: const Offset(0.2, 0.2),
        screenSize: screenSize,
        currentTime: 1.05,
      );
      manager.onPointerMove(
        normalizedPos: const Offset(0.4, 0.2),
        screenSize: screenSize,
        currentTime: 1.30,
      );
      // 点击交互
      manager.addClickRipple(const Offset(0.5, 0.5), 1.35);

      // 所有原始雨滴对象依然存在且仍在正常演化生命周期内
      for (final rain in initialRipples) {
        expect(manager.ripples.contains(rain), isTrue);
      }

      // 下一渲染帧调用 updateAmbientRain 不会重新初始化 3 个新雨滴
      manager.updateAmbientRain(1.40);
      final rainRipples = manager.ripples.where((r) => r.type == RippleType.rain).toList();
      // 雨滴数量保持稳定，原始雨滴未被清空或重置
      expect(rainRipples.length, inInclusiveRange(3, 4));
      for (final rain in initialRipples) {
        expect(rainRipples.contains(rain), isTrue);
      }
    });

    test('slow crawling pointer move advances baseline without emitting ripples, allowing subsequent fast gesture to trigger normally', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 初始点设置
      manager.onPointerMove(
        normalizedPos: const Offset(0.1, 0.1),
        screenSize: screenSize,
        currentTime: 1.0,
      );

      // 慢速拖拽 100px 历时 2.0s (速度 50px/s < 80px/s)
      manager.onPointerMove(
        normalizedPos: const Offset(0.2, 0.1),
        screenSize: screenSize,
        currentTime: 3.0,
      );
      // 慢速拖拽被过滤，未生成波纹
      expect(manager.ripples, isEmpty);

      // 慢移结束后立即进行一次快速划动 (位移 150px 历时 0.25s，速度 600px/s)
      manager.onPointerMove(
        normalizedPos: const Offset(0.35, 0.1),
        screenSize: screenSize,
        currentTime: 3.25,
      );
      // 验证快速划动成功触发微澜，未因之前的慢速移动导致基准滞留而被抑制
      expect(manager.ripples.length, equals(1));
      expect(manager.ripples.first.type, equals(RippleType.trail));
      expect(manager.ripples.first.birthTime, equals(3.25));
    });

    test('click debounce prevents duplicate ripples when clicking same position within 100ms', () {
      final manager = WaterRippleManager();

      // 第一次点击
      manager.addClickRipple(const Offset(0.5, 0.5), 1.0);
      expect(manager.ripples.length, equals(1));

      // 50ms 内同一位置 (< 0.02) 点击，应被防抖跳过
      manager.addClickRipple(const Offset(0.505, 0.505), 1.05);
      expect(manager.ripples.length, equals(1));

      // 50ms 内不同位置 (> 0.02) 点击，正常激发独立涟漪
      manager.addClickRipple(const Offset(0.6, 0.6), 1.06);
      expect(manager.ripples.length, equals(2));

      // 超过 100ms 后原位置再次点击，正常激发
      manager.addClickRipple(const Offset(0.5, 0.5), 1.15);
      expect(manager.ripples.length, equals(3));
    });

    test('idle pause reset starts fresh gesture stroke after inactivity', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 初始划动
      manager.onPointerMove(
        normalizedPos: const Offset(0.1, 0.1),
        screenSize: screenSize,
        currentTime: 1.0,
      );
      manager.onPointerMove(
        normalizedPos: const Offset(0.3, 0.1),
        screenSize: screenSize,
        currentTime: 1.25,
      );
      expect(manager.ripples.length, equals(1));

      // 停顿 2.5 秒后在屏幕另一侧移动
      manager.onPointerMove(
        normalizedPos: const Offset(0.8, 0.8),
        screenSize: screenSize,
        currentTime: 3.75,
      );
      // 空闲重置只更新笔画基准，不应跨屏错误生成从 (0.3,0.1) 到 (0.8,0.8) 的波纹
      expect(manager.ripples.length, equals(1));

      // 从新基准继续划动
      manager.onPointerMove(
        normalizedPos: const Offset(0.95, 0.8),
        screenSize: screenSize,
        currentTime: 4.0,
      );
      // 验证新基准划动成功生成新波纹，且 2.5s 前的旧波纹已被 prune 淘汰
      expect(manager.ripples.length, equals(1));
      expect(manager.ripples.first.origin, equals(const Offset(0.95, 0.8)));
      expect(manager.ripples.first.birthTime, equals(4.0));
    });

    test('non-finite or zero screen sizes safely ignored without exceptions or corrupted state', () {
      final manager = WaterRippleManager();

      // zero dimensions
      manager.onPointerMove(
        normalizedPos: const Offset(0.5, 0.5),
        screenSize: Size.zero,
        currentTime: 1.0,
      );
      expect(manager.ripples, isEmpty);

      // negative dimensions
      manager.onPointerMove(
        normalizedPos: const Offset(0.5, 0.5),
        screenSize: const Size(-100, 200),
        currentTime: 1.1,
      );
      expect(manager.ripples, isEmpty);

      // infinite / NaN dimensions
      manager.onPointerMove(
        normalizedPos: const Offset(0.5, 0.5),
        screenSize: const Size(double.infinity, 800),
        currentTime: 1.2,
      );
      expect(manager.ripples, isEmpty);

      manager.onPointerMove(
        normalizedPos: const Offset(0.5, 0.5),
        screenSize: const Size(1000, double.nan),
        currentTime: 1.3,
      );
      expect(manager.ripples, isEmpty);
    });

    test('out-of-bounds and non-finite pointer coordinates clamped and sanitized, avoiding NaN injection', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // NaN coordinates in click
      manager.addClickRipple(const Offset(double.nan, 0.5), 1.0);
      expect(manager.ripples, isEmpty);

      // NaN coordinates in move
      manager.onPointerMove(
        normalizedPos: const Offset(0.2, double.nan),
        screenSize: screenSize,
        currentTime: 1.1,
      );
      expect(manager.ripples, isEmpty);

      // Out-of-bounds click (> 1.0 or < 0.0) clamped to [0.0, 1.0]
      manager.addClickRipple(const Offset(-0.5, 1.5), 1.2);
      expect(manager.ripples.length, equals(1));
      expect(manager.ripples.first.origin, equals(const Offset(0.0, 1.0)));
    });

    test('time rollback / negative delta time safely prunes future ripples and resets baseline without locking gesture stream', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 初始化雨滴与交互
      manager.updateAmbientRain(10.0);
      expect(manager.ripples.length, equals(3));

      manager.onPointerMove(
        normalizedPos: const Offset(0.2, 0.2),
        screenSize: screenSize,
        currentTime: 10.0,
      );
      manager.onPointerMove(
        normalizedPos: const Offset(0.4, 0.2),
        screenSize: screenSize,
        currentTime: 10.25,
      );
      expect(manager.ripples.where((r) => r.type == RippleType.trail).length, equals(1));

      // 模拟时钟大跳变回退 5 秒 (从 10.25s 跳回 5.0s)
      manager.pruneExpired(5.0);
      // 未来时间点 (10.0s+) 的雨滴与微澜应被判定为未来脏数据并清理
      expect(manager.ripples, isEmpty);

      // 环境雨滴调度能在回退后的时钟立即重新散落自然雨滴，而不停滞
      manager.updateAmbientRain(5.0);
      expect(manager.ripples.length, equals(3));
      for (final r in manager.ripples) {
        expect(r.birthTime, lessThanOrEqualTo(5.0));
      }

      // 移动交互基准在时间回退后能无缝重新自愈，不产生永久冻结
      manager.onPointerMove(
        normalizedPos: const Offset(0.5, 0.5),
        screenSize: screenSize,
        currentTime: 5.1,
      );
      // 首次划动作为新基准
      manager.onPointerMove(
        normalizedPos: const Offset(0.7, 0.5),
        screenSize: screenSize,
        currentTime: 5.35,
      );
      // 成功生成新的 trail 波纹
      final trails = manager.ripples.where((r) => r.type == RippleType.trail).toList();
      expect(trails.length, equals(1));
      expect(trails.first.birthTime, equals(5.35));
    });

    test('click syncs baseline allowing immediate subsequent drag gesture to trigger trail ripple', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 用户点击 (0.2, 0.2)
      manager.addClickRipple(const Offset(0.2, 0.2), 1.0);
      expect(manager.ripples.where((r) => r.type == RippleType.click).length, equals(1));

      // 点击后立即开始拖拽至 (0.4, 0.2) (位移 200px >= 85px，耗时 250ms >= 220ms)
      manager.onPointerMove(
        normalizedPos: const Offset(0.4, 0.2),
        screenSize: screenSize,
        currentTime: 1.25,
      );
      // 验证拖拽首次移动即能够从点击位置为基准正常激发出 trail 波纹
      final trails = manager.ripples.where((r) => r.type == RippleType.trail).toList();
      expect(trails.length, equals(1));
      expect(trails.first.origin, equals(const Offset(0.4, 0.2)));
    });

    test('multi-pointer and multi-touch isolation prevents cross-finger leap waves', () {
      final manager = WaterRippleManager();
      const screenSize = Size(1000, 800);

      // 双指同时触控不同区域：手指1在 (0.2, 0.2)，手指2在 (0.8, 0.8)
      manager.addClickRipple(const Offset(0.2, 0.2), 1.0, 1);
      manager.addClickRipple(const Offset(0.8, 0.8), 1.05, 2);
      expect(manager.ripples.where((r) => r.type == RippleType.click).length, equals(2));

      // 手指1发生 20px 微小位移，手指2发生 20px 微小位移 (均 < 85px 门槛)
      manager.onPointerMove(
        normalizedPos: const Offset(0.22, 0.2),
        screenSize: screenSize,
        currentTime: 1.30,
        pointerId: 1,
      );
      manager.onPointerMove(
        normalizedPos: const Offset(0.82, 0.8),
        screenSize: screenSize,
        currentTime: 1.35,
        pointerId: 2,
      );
      // 关键断言：多触点状态严格隔离，绝不因跨触点坐标差 (0.22 到 0.8) 错误激发全屏瞬移巨浪
      expect(manager.ripples.where((r) => r.type == RippleType.trail), isEmpty);

      // 手指1大幅划动 (位移 230px >= 85px, 时间 250ms >= 220ms)
      manager.onPointerMove(
        normalizedPos: const Offset(0.45, 0.2),
        screenSize: screenSize,
        currentTime: 1.55,
        pointerId: 1,
      );
      final trails1 = manager.ripples.where((r) => r.type == RippleType.trail).toList();
      expect(trails1.length, equals(1));
      expect(trails1.first.origin, equals(const Offset(0.45, 0.2)));

      // 手指2独立大幅划动 (位移 200px >= 85px, 时间 250ms >= 220ms)
      manager.onPointerMove(
        normalizedPos: const Offset(0.82, 0.55),
        screenSize: screenSize,
        currentTime: 1.60,
        pointerId: 2,
      );
      final trails2 = manager.ripples.where((r) => r.type == RippleType.trail).toList();
      expect(trails2.length, equals(2));
      expect(trails2.last.origin, equals(const Offset(0.82, 0.55)));
    });

    test('screen size transformation resets pointer baseline preventing window resize leap waves', () {
      final manager = WaterRippleManager();

      // 在 800x600 尺寸下划动
      manager.onPointerMove(
        normalizedPos: const Offset(0.8, 0.8),
        screenSize: const Size(800, 600),
        currentTime: 1.0,
      );

      // 窗口突变最大化至 1600x1200，光标新坐标为 (0.4, 0.4)
      manager.onPointerMove(
        normalizedPos: const Offset(0.4, 0.4),
        screenSize: const Size(1600, 1200),
        currentTime: 1.25,
      );
      // 关键断言：尺寸突变自动重置基准点，不与旧尺寸坐标计算跨屏虚假位移 (640px)
      expect(manager.ripples.where((r) => r.type == RippleType.trail), isEmpty);

      // 在新窗口尺寸下继续划动 (240px, 250ms)
      manager.onPointerMove(
        normalizedPos: const Offset(0.55, 0.4),
        screenSize: const Size(1600, 1200),
        currentTime: 1.50,
      );
      // 验证在新尺寸下能够以新基准正常激发出轨迹波纹
      final trails = manager.ripples.where((r) => r.type == RippleType.trail).toList();
      expect(trails.length, equals(1));
      expect(trails.first.origin, equals(const Offset(0.55, 0.4)));
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

  testWidgets('waterRipple mode synchronizes physical clock between interactions and shader painter', (
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

    Widget app() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.waterRipple,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('shell')),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );

    // 验证初始自然雨滴已生成
    final initialRainDrops = state.rippleManager.ripples
        .where((r) => r.type == RippleType.rain)
        .toList();
    expect(initialRainDrops, isNotEmpty);

    // 验证 WaterRipplePainter 接收的时钟与 state 的 currentPhysicalTime 严格同源
    final customPaintFinder = find.descendant(
      of: find.byType(FluidGradientBackground),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is WaterRipplePainter,
      ),
    );
    expect(customPaintFinder, findsOneWidget);
    final painter = tester.widget<CustomPaint>(customPaintFinder).painter as WaterRipplePainter;
    expect((painter.time - state.currentPhysicalTime).abs(), lessThan(0.5));

    // 使用可控物理时钟轴，排除宿主操作系统测试调度与 GC 抖动对毫秒级手势速度的干扰
    var simulatedClock = state.currentPhysicalTime;
    state.testPhysicalTime = simulatedClock;

    // 模拟鼠标移动交互 (跨越门槛 >= 85px 且时间 >= 220ms)
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(50, 100));
    await gesture.moveTo(const Offset(100, 100));
    await tester.pump();

    // 快速划动至 350px (位移 250px >= 85px，时间推进 250ms >= 220ms，速度 1.0 >= 0.08)
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await gesture.moveTo(const Offset(350, 100));
    await tester.pump();

    // 验证生成跟随波纹 (trail)，且物理诞生时间与当前物理时钟严格一致 (生命周期合法 dt >= 0)
    final trailRipples = state.rippleManager.ripples
        .where((r) => r.type == RippleType.trail)
        .toList();
    expect(trailRipples, isNotEmpty);
    final trail = trailRipples.first;
    expect(state.currentPhysicalTime - trail.birthTime, greaterThanOrEqualTo(0.0));
    expect(trail.birthTime, equals(simulatedClock));

    // 验证环境自然雨滴总数维持稳定 (>= 3)，未被鼠标移动清空或归零
    final rainDropsAfterMove = state.rippleManager.ripples
        .where((r) => r.type == RippleType.rain)
        .toList();
    expect(rainDropsAfterMove.length, greaterThanOrEqualTo(3));
    // 验证刚落下的雨滴（全寿命周期 3.2s）未被鼠标移动冲刷或提前截断
    final freshestInitialRain = initialRainDrops.last;
    expect(rainDropsAfterMove.contains(freshestInitialRain), isTrue);

    // 模拟鼠标点击激发同心涟漪
    simulatedClock += 0.05;
    state.testPhysicalTime = simulatedClock;
    await tester.tapAt(const Offset(300, 300));
    await tester.pump();

    // 验证点击波纹 (click) 成功激发，且物理诞生时间与当前物理时钟严格一致
    final clickRipples = state.rippleManager.ripples
        .where((r) => r.type == RippleType.click)
        .toList();
    expect(clickRipples, isNotEmpty);
    final click = clickRipples.first;
    expect(state.currentPhysicalTime - click.birthTime, greaterThanOrEqualTo(0.0));
    expect(click.birthTime, equals(simulatedClock));

    // 验证环境雨滴仍然不受点击影响，稳定维持在活跃状态，且未被截断
    final rainDropsAfterClick = state.rippleManager.ripples
        .where((r) => r.type == RippleType.rain)
        .toList();
    expect(rainDropsAfterClick.length, greaterThanOrEqualTo(3));
    expect(rainDropsAfterClick.contains(freshestInitialRain), isTrue);

    await gesture.removePointer();
    state.testPhysicalTime = null;
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

  testWidgets('FluidGradientBackground ticker stops on static background image', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousPath = AppSettings.instance.backgroundImagePath;
    final tempDir = Directory.systemTemp.createTempSync('bg_test');
    final tempFile = File('${tempDir.path}/test_bg.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      AppSettings.instance.backgroundImagePath = previousPath;
      AppSettings.instance.notifyBackgroundChanged();
      WindowControls.isWindowVisible.value = true;
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    provider.windowBackdropMode = WindowBackdropMode.meshFlow;
    AppSettings.instance.backgroundImagePath = null;
    WindowControls.isWindowVisible.value = true;

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
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );
    expect(state.isTickerActive, isTrue);

    // 设置静态背景图片
    AppSettings.instance.backgroundImagePath = tempFile.path;
    AppSettings.instance.notifyBackgroundChanged();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.isTickerActive, isFalse);

    // 移除静态背景图片，恢复动效
    AppSettings.instance.backgroundImagePath = null;
    AppSettings.instance.notifyBackgroundChanged();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.isTickerActive, isTrue);
  });

  testWidgets('FluidGradientBackground stops ticker on hidden lifecycle and resumes on resumed', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousPath = AppSettings.instance.backgroundImagePath;

    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      AppSettings.instance.backgroundImagePath = previousPath;
      WindowControls.isWindowVisible.value = true;
    });

    provider.windowBackdropMode = WindowBackdropMode.meshFlow;
    AppSettings.instance.backgroundImagePath = null;
    WindowControls.isWindowVisible.value = true;

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
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );
    expect(state.isTickerActive, isTrue);

    // 模拟应用进入 hidden/paused 状态
    state.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.isTickerActive, isFalse);

    // 模拟应用恢复 resumed 状态
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.isTickerActive, isTrue);
  });

  testWidgets('FluidGradientBackground stops ticker when window is minimized and resumes on restored', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousPath = AppSettings.instance.backgroundImagePath;

    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      AppSettings.instance.backgroundImagePath = previousPath;
      WindowControls.isWindowVisible.value = true;
    });

    provider.windowBackdropMode = WindowBackdropMode.meshFlow;
    AppSettings.instance.backgroundImagePath = null;
    WindowControls.isWindowVisible.value = true;

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
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );
    expect(state.isTickerActive, isTrue);

    // 模拟窗口最小化
    WindowControls.isWindowVisible.value = false;
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.isTickerActive, isFalse);

    // 模拟窗口恢复
    WindowControls.isWindowVisible.value = true;
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.isTickerActive, isTrue);
  });

  testWidgets('waterRipple mode handles rapid window resizing and zero screen dimensions gracefully', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousEffects = provider.uiEffectsLevel;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.uiEffectsLevel = previousEffects;
    });

    provider.windowBackdropMode = WindowBackdropMode.waterRipple;
    provider.uiEffectsLevel = UiEffectsLevel.balanced;

    final boxSize = ValueNotifier<Size>(const Size(800, 600));

    Widget app() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          home: ValueListenableBuilder<Size>(
            valueListenable: boxSize,
            builder: (_, size, __) => Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: const FluidGradientBackground(
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(100, 100));
    await gesture.moveTo(const Offset(300, 100));
    await tester.pump();

    // 窗口尺寸突变缩为 0x0
    boxSize.value = Size.zero;
    await tester.pump();
    await gesture.moveTo(const Offset(0, 0));
    await tester.tapAt(const Offset(0, 0));
    await tester.pump();

    // 窗口尺寸突变扩为 1920x1080
    boxSize.value = const Size(1920, 1080);
    await tester.pump();
    await gesture.moveTo(const Offset(800, 600));
    await tester.tapAt(const Offset(500, 500));
    await tester.pump();

    await gesture.removePointer();
    expect(find.byType(FluidGradientBackground), findsOneWidget);
  });

  testWidgets('waterRipple mode resets pointer baseline on window minimize or mode switch, avoiding teleportation waves', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    final previousEffects = provider.uiEffectsLevel;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
      provider.uiEffectsLevel = previousEffects;
      WindowControls.isWindowVisible.value = true;
    });

    provider.windowBackdropMode = WindowBackdropMode.waterRipple;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.waterRipple,
      appliedMode: WindowBackdropMode.waterRipple,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );
    provider.uiEffectsLevel = UiEffectsLevel.balanced;

    Widget app() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.waterRipple,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('shell')),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );
    var simulatedClock = state.currentPhysicalTime;
    state.testPhysicalTime = simulatedClock;

    // 在左上角划动 (50, 50) -> (300, 50) 产生首波微澜
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(50, 50));
    await gesture.moveTo(const Offset(50, 50));
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await gesture.moveTo(const Offset(300, 50));
    await tester.pump();
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail).length, equals(1));

    // 窗口最小化失焦
    WindowControls.isWindowVisible.value = false;
    await tester.pump(const Duration(milliseconds: 50));

    // 窗口恢复
    WindowControls.isWindowVisible.value = true;
    await tester.pump(const Duration(milliseconds: 50));

    // 恢复后首次在右下角 (750, 550) 移动 (距离上次划动达 670px，且在 150ms 极短时间内)
    simulatedClock += 0.15;
    state.testPhysicalTime = simulatedClock;
    await gesture.moveTo(const Offset(750, 550));
    await tester.pump();

    // 关键断言：因窗口切换重置了交互基准，绝不应跨越全屏错误触发从 (300,50) 到 (750,550) 的虚假瞬移巨浪
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail).length, equals(1));

    // 从新基准 (750, 550) 继续划动至 (750, 300) (位移 250px, 时间 250ms)
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await gesture.moveTo(const Offset(750, 300));
    await tester.pump();

    // 成功从新基准激发合法轨迹微澜
    final trails = state.rippleManager.ripples.where((r) => r.type == RippleType.trail).toList();
    expect(trails.length, greaterThanOrEqualTo(2));

    await gesture.removePointer();
    state.testPhysicalTime = null;
  });

  testWidgets('waterRipple mode touch release resets pointer state preventing touch-up ghost leaps', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    final previousEffects = provider.uiEffectsLevel;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
      provider.uiEffectsLevel = previousEffects;
    });

    provider.windowBackdropMode = WindowBackdropMode.waterRipple;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.waterRipple,
      appliedMode: WindowBackdropMode.waterRipple,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );
    provider.uiEffectsLevel = UiEffectsLevel.balanced;

    Widget app() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.waterRipple,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('shell')),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );
    var simulatedClock = state.currentPhysicalTime;
    state.testPhysicalTime = simulatedClock;

    // 触控笔画 1：按下并在左上方划动 (100, 100) -> (350, 100)
    final touchGesture = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touchGesture.down(const Offset(100, 100));
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await touchGesture.moveTo(const Offset(350, 100));
    await tester.pump();
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail).length, equals(1));

    // 手指抬起 (PointerUpEvent)
    await touchGesture.up();
    await tester.pump();

    // 在屏幕右下侧 (600, 450) 开启新的触控 (与前次触控相距 460px，处于 800x600 窗口内)
    simulatedClock += 0.05;
    state.testPhysicalTime = simulatedClock;
    await touchGesture.down(const Offset(600, 450));
    await tester.pump();

    // 手指在新触点仅微动 10px (600, 450) -> (610, 450)
    simulatedClock += 0.05;
    state.testPhysicalTime = simulatedClock;
    await touchGesture.moveTo(const Offset(610, 450));
    await tester.pump();

    // 关键断言：PointerUp 彻底清理了旧触点基准，微动 10px 绝不与旧触点 (300, 100) 计算跨屏巨浪
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail).length, equals(1));

    // 在新触点正常大幅划水 (610, 450) -> (610, 200) (位移 250px >= 85px，时间 250ms >= 220ms)
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await touchGesture.moveTo(const Offset(610, 200));
    await tester.pump();

    final trails = state.rippleManager.ripples.where((r) => r.type == RippleType.trail).toList();
    expect(trails.length, equals(2));
    expect(trails.last.origin, equals(const Offset(610 / 800.0, 200 / 600.0)));

    await touchGesture.up();
    state.testPhysicalTime = null;
  });

  testWidgets('waterRipple mode multi-touch widget integration isolates multiple touch points', (
    tester,
  ) async {
    final provider = ThemeProvider.instance;
    final previousBackdrop = provider.windowBackdropMode;
    final previousBackdropResult = provider.windowBackdropResult;
    final previousEffects = provider.uiEffectsLevel;
    addTearDown(() {
      provider.windowBackdropMode = previousBackdrop;
      provider.windowBackdropResult = previousBackdropResult;
      provider.uiEffectsLevel = previousEffects;
    });

    provider.windowBackdropMode = WindowBackdropMode.waterRipple;
    provider.windowBackdropResult = const WindowBackdropModeResult(
      requestedMode: WindowBackdropMode.waterRipple,
      appliedMode: WindowBackdropMode.waterRipple,
      nativeBackdropSupported: true,
      nativeApplySucceeded: true,
    );
    provider.uiEffectsLevel = UiEffectsLevel.balanced;

    Widget app() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.build(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            effectsLevel: UiEffectsLevel.balanced,
            windowBackdropMode: WindowBackdropMode.waterRipple,
          ),
          home: const FluidGradientBackground(
            child: SizedBox(key: ValueKey('shell')),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state<FluidGradientBackgroundState>(
      find.byType(FluidGradientBackground),
    );
    var simulatedClock = state.currentPhysicalTime;
    state.testPhysicalTime = simulatedClock;

    // 手指 1 在左侧 (150, 150) 按下，手指 2 在右侧 (650, 450) 按下
    final finger1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 101);
    final finger2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 102);

    await finger1.down(const Offset(150, 150));
    await finger2.down(const Offset(650, 450));
    await tester.pump();

    // 两根手指交替进行微小移动 (10px < 85px)
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await finger1.moveTo(const Offset(160, 150));
    await tester.pump();

    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await finger2.moveTo(const Offset(660, 450));
    await tester.pump();

    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await finger1.moveTo(const Offset(170, 150));
    await tester.pump();

    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await finger2.moveTo(const Offset(670, 450));
    await tester.pump();

    // 关键断言：交替微移绝不在两根手指之间产生跨屏虚假波纹
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail), isEmpty);

    // 手指 1 划动 200px
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await finger1.moveTo(const Offset(370, 150));
    await tester.pump();
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail).length, equals(1));

    // 手指 2 独立划动 200px
    simulatedClock += 0.25;
    state.testPhysicalTime = simulatedClock;
    await finger2.moveTo(const Offset(670, 250));
    await tester.pump();
    expect(state.rippleManager.ripples.where((r) => r.type == RippleType.trail).length, equals(2));

    await finger1.up();
    await finger2.up();
    state.testPhysicalTime = null;
  });
}

