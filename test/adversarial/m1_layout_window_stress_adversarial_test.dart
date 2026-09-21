import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/main_layout_frame.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/window_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WindowControls.layoutMode.value = WindowLayoutMode.normal;
    WindowControls.isWindowVisible.value = true;
    AppSettings.instance.isWindowMaximized = false;
  });

  tearDown(() {
    WindowControls.layoutMode.value = WindowLayoutMode.normal;
    WindowControls.isWindowVisible.value = true;
    AppSettings.instance.isWindowMaximized = false;
  });

  // =========================================================================
  // GROUP 1: MainLayoutFrame AnimatedPadding Dynamic Stress & Continuity
  // =========================================================================
  group('MainLayoutFrame Stress: AnimatedPadding Continuity & Rapid Oscillation', () {
    testWidgets(
      'M1-S1.1: Rapid chaotic layoutMode toggling (normal <-> maximized) preserves numerical bounds and smooth continuity without jump',
      (tester) async {
        late double dockHeight;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                dockHeight = context.chrome.dockHeight;
                return const Scaffold(
                  body: MainLayoutFrame(
                    titleBar: SizedBox(height: 40, key: ValueKey('stress_title_bar')),
                    overlay: SizedBox(height: 60, key: ValueKey('stress_overlay_bar')),
                    child: SizedBox.expand(child: Text('Main Content')),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final normalDockInset = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: dockHeight,
          shellGap: 10.0,
        );
        final maximizedDockInset = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: dockHeight,
          shellGap: 20.0,
        );

        // 初始 normal 状态下检验
        final innerPaddingFinder = find.descendant(
          of: find.byType(AnimatedPadding),
          matching: find.byType(Padding),
        ).first;
        final initialPadding = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect(initialPadding.bottom, closeTo(normalDockInset, 1e-4));

        // 模拟连续 50 次混沌时间切换（从 1ms 到 40ms）
        final random = math.Random(42);
        double lastObservedBottom = initialPadding.bottom;

        for (int i = 0; i < 50; i++) {
          final nextMode = (i % 2 == 0) ? WindowLayoutMode.maximized : WindowLayoutMode.normal;
          WindowControls.layoutMode.value = nextMode;

          final stepMs = 1 + random.nextInt(35);
          await tester.pump(Duration(milliseconds: stepMs));

          expect(tester.takeException(), isNull, reason: 'Iteration $i threw exception');

          final currentPadding = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
          final currentBottom = currentPadding.bottom;

          // 核心数学不变量检查：
          // 1. 底栏 Padding 绝不能低于 normalDockInset 或高于 maximizedDockInset
          expect(
            currentBottom,
            greaterThanOrEqualTo(normalDockInset - 1e-3),
            reason: 'Iteration $i: bottom padding ($currentBottom) dropped below lower bound $normalDockInset',
          );
          expect(
            currentBottom,
            lessThanOrEqualTo(maximizedDockInset + 1e-3),
            reason: 'Iteration $i: bottom padding ($currentBottom) exceeded upper bound $maximizedDockInset',
          );

          // 2. 单步 delta 绝不能发生瞬间撕裂跳跃（在 35ms 内 Curves.easeOutCubic 变化量受物理速度约束）
          final delta = (currentBottom - lastObservedBottom).abs();
          expect(
            delta,
            lessThanOrEqualTo(maximizedDockInset - normalDockInset + 1e-3),
            reason: 'Iteration $i: single frame padding jump of $delta px detected!',
          );

          lastObservedBottom = currentBottom;
        }

        // 最终收敛性验证：让它完全 settle
        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pumpAndSettle();
        final finalMaximizedPadding = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect(finalMaximizedPadding.bottom, closeTo(maximizedDockInset, 1e-4));

        WindowControls.layoutMode.value = WindowLayoutMode.normal;
        await tester.pumpAndSettle();
        final finalNormalPadding = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect(finalNormalPadding.bottom, closeTo(normalDockInset, 1e-4));
      },
    );

    testWidgets(
      'M1-S1.2: Intermediate animation interruption preserves velocity continuity without position snapping',
      (tester) async {
        late double dockHeight;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                dockHeight = context.chrome.dockHeight;
                return const Scaffold(
                  body: MainLayoutFrame(
                    titleBar: SizedBox(height: 40),
                    overlay: SizedBox(height: 60),
                    child: SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final normalDockInset = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: dockHeight,
          shellGap: 10.0,
        );
        final maximizedDockInset = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: dockHeight,
          shellGap: 20.0,
        );

        final innerPaddingFinder = find.descendant(
          of: find.byType(AnimatedPadding),
          matching: find.byType(Padding),
        ).first;

        // 1. Normal -> Maximized: pump 首帧触发 didUpdateWidget 启动动效，随后推进 80ms (总时长 200ms)
        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final p80 = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect(p80.bottom, inExclusiveRange(normalDockInset, maximizedDockInset));
        final valueAtInterrupt = p80.bottom;

        // 2. 中途打断：立即切回 Normal，并只推进 1 毫秒
        WindowControls.layoutMode.value = WindowLayoutMode.normal;
        await tester.pump(const Duration(milliseconds: 1));

        final pImmediatelyAfter = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        // 关键断言：打断瞬间绝对不得瞬间重置回 normal 或跳跃至 maximized
        expect(
          (pImmediatelyAfter.bottom - valueAtInterrupt).abs(),
          lessThan(0.5),
          reason: 'AnimatedPadding snapped position on animation reversal!',
        );

        // 3. 继续推进 60ms，padding 必须平滑单调递减朝 normalDockInset 靠拢
        await tester.pump(const Duration(milliseconds: 60));
        final pDescending = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect(pDescending.bottom, lessThan(pImmediatelyAfter.bottom));
        expect(pDescending.bottom, greaterThan(normalDockInset));

        // 4. 第二次中途打断：在反向途中再次切回 Maximized
        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pump(const Duration(milliseconds: 1));
        final pReInterrupt = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect((pReInterrupt.bottom - pDescending.bottom).abs(), lessThan(0.5));

        // 5. 走完全部动画，平稳到达 maximizedDockInset
        await tester.pumpAndSettle();
        final pSettled = tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets;
        expect(pSettled.bottom, closeTo(maximizedDockInset, 1e-4));
      },
    );

    testWidgets(
      'M1-S1.3: Dynamic overlay attach/detach and reserveDockSpace toggle during in-flight layoutMode transition',
      (tester) async {
        var showOverlay = true;
        var reserveSpace = true;
        late StateSetter updateState;
        late double dockHeight;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                dockHeight = context.chrome.dockHeight;
                return Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      updateState = setState;
                      return MainLayoutFrame(
                        titleBar: const SizedBox(height: 40),
                        overlay: showOverlay ? const SizedBox(height: 60, key: ValueKey('ov_bar')) : null,
                        reserveDockSpace: reserveSpace,
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final normalDockInset = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: dockHeight,
          shellGap: 10.0,
        );
        final maximizedDockInset = resolveMainLayoutDockInset(
          reserveDockSpace: true,
          hasOverlay: true,
          dockHeight: dockHeight,
          shellGap: 20.0,
        );

        final innerPaddingFinder = find.descendant(
          of: find.byType(AnimatedPadding),
          matching: find.byType(Padding),
        ).first;

        // 初始：reserveDockSpace=true, hasOverlay=true
        expect((tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets).bottom, closeTo(normalDockInset, 1e-4));

        // 触发最大化并在第 50ms 卸载 overlay
        WindowControls.layoutMode.value = WindowLayoutMode.maximized;
        await tester.pump(const Duration(milliseconds: 50));

        updateState(() => showOverlay = false);
        await tester.pump(const Duration(milliseconds: 30));

        expect(tester.takeException(), isNull);

        // 当 overlay 为 null 时，reserveDockSpace 为 true 时 dockInset 应收敛至 shellGap (maximized 下为 20)
        await tester.pumpAndSettle();
        expect((tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets).bottom, closeTo(20.0, 1e-4));

        // 再次动态关闭 reserveDockSpace -> dockInset 应收敛至 0.0
        updateState(() => reserveSpace = false);
        await tester.pumpAndSettle();
        expect((tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets).bottom, closeTo(0.0, 1e-4));

        // 重新挂载 overlay 与开启 reserveDockSpace
        updateState(() {
          showOverlay = true;
          reserveSpace = true;
        });
        await tester.pumpAndSettle();
        expect((tester.widget<Padding>(innerPaddingFinder).padding as EdgeInsets).bottom, closeTo(maximizedDockInset, 1e-4));
      },
    );

    testWidgets(
      'M1-S1.4: Child widget state integrity and build count stability during layoutMode oscillation',
      (tester) async {
        final textController = TextEditingController(text: 'Persistent Input');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MainLayoutFrame(
                titleBar: const SizedBox(height: 40),
                overlay: const SizedBox(height: 60),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return TextField(controller: textController);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 高频切换 15 次
        for (int i = 0; i < 15; i++) {
          WindowControls.layoutMode.value =
              (i % 2 == 0) ? WindowLayoutMode.maximized : WindowLayoutMode.normal;
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();

        // 验证文本控件状态未被重新挂载或丢失
        expect(textController.text, equals('Persistent Input'));
        expect(find.text('Persistent Input'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // =========================================================================
  // GROUP 2: Window Listener Concurrency & State Invariants
  // =========================================================================
  group('Window Listener Concurrency & Event Race Invariants', () {
    test('M1-S2.1: Interleaved concurrent native IPC and WindowListener events maintain strict state synchronization', () async {
      WindowControls.ensureMethodChannelHandler();

      // 验证原生 IPC 与设置项单向驱动的一致性
      final modes = [
        'maximized',
        'normal',
        'fullscreen',
        'maximized',
        'normal',
      ];

      for (final mode in modes) {
        await WindowControls.handleMethodCall(
          MethodCall('on_window_layout_changed', {'mode': mode}),
        );

        final expectedMode = switch (mode) {
          'maximized' => WindowLayoutMode.maximized,
          'fullscreen' => WindowLayoutMode.fullscreen,
          _ => WindowLayoutMode.normal,
        };

        expect(WindowControls.layoutMode.value, equals(expectedMode));
        if (expectedMode == WindowLayoutMode.maximized) {
          expect(AppSettings.instance.isWindowMaximized, isTrue);
        } else if (expectedMode == WindowLayoutMode.normal) {
          expect(AppSettings.instance.isWindowMaximized, isFalse);
        }
      }
    });

    test('M1-S2.2: Concurrently firing tray and window visibility events maintains isWindowVisible invariants', () async {
      WindowControls.ensureMethodChannelHandler();

      final futures = <Future<dynamic>>[];
      // 模拟密集并发的托盘最小化/还原消息
      for (int i = 0; i < 20; i++) {
        if (i % 2 == 0) {
          futures.add(WindowControls.handleMethodCall(
            const MethodCall('window_minimized_to_tray'),
          ));
        } else {
          futures.add(WindowControls.handleMethodCall(
            const MethodCall('window_restored_from_tray'),
          ));
        }
      }

      await Future.wait(futures);
      // 最后一条消息是 i=19 (奇数)，对应 window_restored_from_tray
      expect(WindowControls.isWindowVisible.value, isTrue);
    });

    test('M1-S2.3: Cold start recovery flow: setInitialLayoutMode and showWindow contracts', () async {
      final methodCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'get_window_layout_mode') {
            return 'maximized';
          }
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      // 1. 模拟冷启动：历史设置为已最大化
      AppSettings.instance.isWindowMaximized = true;

      // 2. Dart 同步执行 setInitialLayoutMode(true)
      WindowControls.setInitialLayoutMode(true);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.maximized));
      expect(WindowControls.shellGap, equals(20.0));

      // 3. 首帧渲染完成后触发 showWindow(maximize: true)
      await WindowControls.showWindow(maximize: true);

      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.maximized));

      // 验证原生 IPC 调用了 show_window 且携带 maximize: true
      final showCall = methodCalls.firstWhere((c) => c.method == 'show_window');
      expect((showCall.arguments as Map)['maximize'], isTrue);

      // 清理 mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    test('M1-S2.4: Cold start recovery flow with normal window: no accidental maximization', () async {
      final methodCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          methodCalls.add(call);
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      // 1. 模拟冷启动：历史设置为普通窗口
      AppSettings.instance.isWindowMaximized = false;

      // 2. 同步执行 setInitialLayoutMode(false)
      WindowControls.setInitialLayoutMode(false);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.normal));
      expect(WindowControls.shellGap, equals(10.0));

      // 3. 首帧完成后触发 showWindow(maximize: false)
      await WindowControls.showWindow(maximize: false);

      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(WindowControls.layoutMode.value, equals(WindowLayoutMode.normal));

      final showCall = methodCalls.firstWhere((c) => c.method == 'show_window');
      expect((showCall.arguments as Map)['maximize'], isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });
  });

  // =========================================================================
  // GROUP 3: TitleBar Maximize Button Dirty Rect & Debounce Invariants
  // =========================================================================
  group('TitleBar Maximize Button Dirty Rect & Debounce Invariants', () {
    testWidgets('M1-S3.1: Consecutive rebuilds without rect change suppress redundant IPC calls', (tester) async {
      final rectCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          if (call.method == 'set_maximize_button_rect') {
            rectCalls.add(call);
          }
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('qisheng_player/window_controls'),
          null,
        );
      });

      late StateSetter stateSetter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                stateSetter = setState;
                return const Align(
                  alignment: Alignment.topRight,
                  child: WindowControlls(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCalls = rectCalls.length;
      expect(initialCalls, greaterThanOrEqualTo(1));

      // 触发 20 次空重构（未发生坐标变化）
      for (int i = 0; i < 20; i++) {
        stateSetter(() {});
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 防抖断言：重构 20 次期间，脏矩形检测必须拦截所有无变化的重复 IPC 上报
      expect(rectCalls.length, equals(initialCalls),
          reason: 'Dirty rect debounce leaked redundant IPC calls on static rebuilds!');
    });

    testWidgets('M1-S3.2: LayoutMode change inside MainLayoutFrame updates rect due to topInset displacement', (tester) async {
      final rectCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          if (call.method == 'set_maximize_button_rect') {
            rectCalls.add(call);
          }
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('qisheng_player/window_controls'),
          null,
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainLayoutFrame(
              titleBar: Align(
                alignment: Alignment.topRight,
                child: WindowControlls(),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = rectCalls.length;
      expect(initialCount, greaterThanOrEqualTo(1));
      final initialTop = (rectCalls.last.arguments as Map)['top'] as double;
      // 在 normal 模式下，topInset 为 12.0
      expect(initialTop, closeTo(12.0, 1.0));

      // 1. 切换到最大化模式：MainLayoutFrame 的 topInset 从 12.0 变为 20.0 (移动 8px)
      WindowControls.layoutMode.value = WindowLayoutMode.maximized;
      await tester.pumpAndSettle();

      expect(rectCalls.length, greaterThan(initialCount),
          reason: 'Switching to maximized mode did not trigger rect update despite topInset shifting!');
      final maximizedTop = (rectCalls.last.arguments as Map)['top'] as double;
      expect(maximizedTop, closeTo(20.0, 1.0));
      final countAfterMaximize = rectCalls.length;

      // 2. 模拟重复触发相同布局模式（无坐标移动）
      WindowControls.layoutMode.value = WindowLayoutMode.maximized;
      await tester.pumpAndSettle();

      // 防抖断言：由于坐标未发生变化，脏矩形防抖必须过滤掉重复的 IPC 调用
      expect(rectCalls.length, equals(countAfterMaximize),
          reason: 'Duplicate maximized layout event leaked redundant IPC call!');

      // 3. 还原回 normal 模式：topInset 变回 12.0
      WindowControls.layoutMode.value = WindowLayoutMode.normal;
      await tester.pumpAndSettle();

      expect(rectCalls.length, greaterThan(countAfterMaximize));
      final restoredTop = (rectCalls.last.arguments as Map)['top'] as double;
      expect(restoredTop, closeTo(12.0, 1.0));
    });
  });
}
