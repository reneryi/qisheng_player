import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/title_bar.dart';
import 'package:qisheng_player/main.dart' hide main;
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/src/bass/bass_player.dart';
import 'package:qisheng_player/src/rust/api/smtc_flutter.dart';
import 'package:qisheng_player/src/rust/frb_generated.dart';
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/window_controls.dart';

class _TestFakeSmtc implements SmtcFlutter {
  final _controller = StreamController<SMTCControlEvent>.broadcast();
  bool _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  bool get isDisposed => _disposed;

  @override
  Future<void> close() async => _controller.close();

  @override
  Stream<SMTCControlEvent> subscribeToControlEvents() => _controller.stream;

  @override
  Future<void> updateDisplay({
    required String title,
    required String artist,
    required String album,
    required int duration,
    required String path,
  }) async {}

  @override
  Future<void> updateState({required SMTCState state}) async {}

  @override
  Future<void> updateTimeProperties({required int progress}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _TestFakeSmtc fakeSmtc;
  late PlaybackService testPlayback;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('challenger_m1_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );

    fakeSmtc = _TestFakeSmtc();
    testPlayback = PlaybackService(
      PlayService.instance,
      player: BassPlayer(),
      smtc: fakeSmtc,
      preferenceOverride: PlaybackPreference(
        PlayMode.forward,
        1.0,
        false,
        0.0,
        null,
        const [],
        0,
        0.0,
      ),
    );
    PlayService.setPlaybackServiceForTesting(testPlayback);
  });

  tearDownAll(() async {
    PlayService.setPlaybackServiceForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

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
  // GROUP 1: WindowControls.setInitialLayoutMode & showWindow Adversarial Suite
  // =========================================================================
  group('Adversarial 1: WindowControls.setInitialLayoutMode & showWindow Robustness', () {
    test('1.1: Repeated & high-frequency setInitialLayoutMode calls (1000 iterations) maintain idempotence and listener stability', () {
      int listenerNotificationCount = 0;
      void onLayoutChanged() {
        listenerNotificationCount++;
      }

      WindowControls.layoutMode.addListener(onLayoutChanged);

      // 1.1a: 连续 500 次设置相同值 (true)，仅在第一次状态转换（normal -> maximized）时触发监听
      for (int i = 0; i < 500; i++) {
        WindowControls.setInitialLayoutMode(true);
      }
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);
      expect(listenerNotificationCount, 1,
          reason: 'Only the initial transition from normal to maximized should notify listeners.');

      // 1.1b: 接下来 500 次交替翻转 (false, true, false, true...)
      for (int i = 0; i < 500; i++) {
        final target = (i % 2 == 1); // false, true, false, true...
        WindowControls.setInitialLayoutMode(target);
      }
      // 500 次交替翻转产生 500 次通知，加上之前的 1 次，共 501 次通知
      expect(listenerNotificationCount, 501);

      WindowControls.layoutMode.removeListener(onLayoutChanged);
    });

    test('1.2: Disordered calls: showWindow before setInitialLayoutMode and concurrent interleaving', () async {
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

      // 乱序执行：在未调用 setInitialLayoutMode 前，先并发触发多次 showWindow
      final disorderedFutures = <Future<void>>[
        WindowControls.showWindow(maximize: true),
        WindowControls.showWindow(maximize: false),
        WindowControls.showWindow(maximize: true),
      ];

      // 并在执行过程中交错调用 setInitialLayoutMode
      WindowControls.setInitialLayoutMode(false);
      WindowControls.setInitialLayoutMode(true);

      await Future.wait(disorderedFutures);

      expect(WindowControls.isWindowVisible.value, isTrue);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.maximized);
      expect(
        methodCalls.where((c) => c.method == 'show_window').length,
        equals(3),
        reason: 'All show_window requests should complete without deadlocks or unhandled errors',
      );

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

    test('1.3: Unconfigured settings scenario (fresh install, missing settings.json): default state safety', () async {
      // 模拟未配置或默认状态下的 AppSettings 实例
      final settings = AppSettings.instance;
      expect(settings.isWindowMaximized, isFalse);

      // 在没有任何本地 settings 写入的情况下调用 setInitialLayoutMode
      WindowControls.setInitialLayoutMode(settings.isWindowMaximized);
      expect(WindowControls.layoutMode.value, WindowLayoutMode.normal);
      expect(WindowControls.shellGap, 10.0);

      // 验证 showWindow 在此状态下安全执行
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async => null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );

      await expectLater(
        WindowControls.showWindow(maximize: settings.isWindowMaximized),
        completes,
      );

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

    test('1.4: Platform channel error injection: PlatformException & MissingPluginException immunity', () async {
      // 模拟平台通道抛出异常（例如平台插件未连接、Win32 原生层崩溃或异常返回）
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('qisheng_player/window_controls'),
        (MethodCall call) async {
          throw PlatformException(code: 'WIN32_ERROR', message: 'Simulated Window handle invalid');
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          throw MissingPluginException('window_manager not available');
        },
      );

      // WindowControls.showWindow 必须具有防御式降级机制，不能让异常向上传播崩溃主线程
      await expectLater(
        WindowControls.showWindow(maximize: true),
        completes,
      );
      expect(WindowControls.isWindowVisible.value, isTrue);

      await expectLater(
        WindowControls.syncWindowLayoutMode(),
        completes,
      );

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
  // GROUP 2: Background Asynchronous Pipelines Error Isolation & Main Thread Immunity
  // =========================================================================
  group('Adversarial 2: Background Pipelines (loadPrefFont & recoverAudioMetadata) Error Isolation', () {
    test('2.1: loadPrefFont with missing file, corrupt path, or invalid directory does not crash main thread', () async {
      final settings = AppSettings.instance;
      
      // 测试用例 A: 字体文件不存在
      settings.fontFamily = 'NonExistentFontFamily';
      settings.fontPath = 'Z:\\completely_fake_dir\\non_existent_font.ttf';

      // 验证执行 loadPrefFont 绝不向调用者抛出未捕获异常
      await expectLater(loadPrefFont(), completes);
      expect(ThemeProvider.instance.fontFamily, 'NonExistentFontFamily');

      // 测试用例 B: 路径指向已存在的非字体文件（模拟格式损坏或乱码文件）
      final corruptFile = File('${tempDir.path}\\corrupt_font.ttf');
      await corruptFile.writeAsString('THIS IS NOT A VALID TTF FONT HEADER');
      settings.fontPath = corruptFile.path;
      settings.fontFamily = 'CorruptedFontFamily';

      await expectLater(loadPrefFont(), completes);

      // 测试用例 C: fontPath 为空，fontFamily 为系统字体名
      settings.fontPath = null;
      settings.fontFamily = 'Segoe UI';
      await expectLater(loadPrefFont(), completes);
    });

    test('2.2: loadPrefFont high-concurrency reentrancy (50 simultaneous invocations)', () async {
      final settings = AppSettings.instance;
      settings.fontFamily = 'ConcurrentFontTest';
      settings.fontPath = '${tempDir.path}\\concurrent_font.ttf';

      // 模拟 50 个并发调用同时触发
      final futures = List.generate(50, (_) => loadPrefFont());
      await expectLater(Future.wait(futures), completes);
    });

    test('2.3: recoverAudioMetadata error handling pipeline resilience for asynchronous errors', () async {
      // 检验主线程中的 recoverAudioMetadata 异步异常截获流水线：
      // 在 main.dart 中采用的形式为：
      // unawaited(recoverAudioMetadata(supportPath: supportPath).then((warnings) {
      //   for (final warning in warnings) { ... }
      // }).catchError((error, stackTrace) { ... }))
      
      final completer = Completer<List<String>>();
      bool catchErrorTriggered = false;
      Object? capturedError;

      // 模拟与 main.dart 完全一致的调用结构：.then 返回 void
      unawaited(completer.future.then<void>((warnings) {
        for (final warning in warnings) {
          assert(warning.isNotEmpty);
        }
      }).catchError((error, stackTrace) {
        catchErrorTriggered = true;
        capturedError = error;
      }));

      // 触发异步异常（例如损坏的元数据 journal 或文件系统只读异常）
      completer.completeError(
        const FileSystemException('Corrupted journal file', 'C:\\qisheng\\journal.bin'),
      );

      // 等待微任务队列清空
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(catchErrorTriggered, isTrue);
      expect(capturedError, isA<FileSystemException>());
    });

    test('2.4: Evaluation of synchronous throw behavior if recoverAudioMetadata is invoked before RustLib is initialized', () {
      // 实证挑战：验证若 RustLib 未完成初始化或 api getter 为空时，recoverAudioMetadata 是否会抛出同步异常
      // 观察 lib/src/rust/api/metadata_editor.dart:
      // Future<List<String>> recoverAudioMetadata({required String supportPath}) =>
      //     RustLib.instance.api.crateApiMetadataEditorRecoverAudioMetadata(supportPath: supportPath);
      // 因为 recoverAudioMetadata 是非 async 箭头函数，如果 RustLib.instance._api 为 null，
      // RustLib.instance.api 会同步抛出 StateError。
      
      try {
        // ignore: invalid_use_of_internal_member
        final api = RustLib.instance.api;
        expect(api, isNotNull);
      } on StateError catch (e) {
        // 证实：未初始化时直接抛出同步 StateError！
        expect(e.message, contains('flutter_rust_bridge has not been initialized'));
      }
    });

    test('2.5: EMPIRICAL PROOF: unawaited(recoverAudioMetadata().then(...).catchError(...)) crashes synchronously if RustLib is not ready', () {
      // 假设 RustLib.instance._api 为 null（即 RustLib.init() 仍在执行中，未完成）
      // 我们创建一个与 recoverAudioMetadata 完全相同签名的函数（非 async，内部同步访问未就绪的依赖）
      Future<List<String>> unreadyRecoverAudioMetadata() =>
          throw StateError('flutter_rust_bridge has not been initialized.');

      // 验证 Worker M1 在 main.dart 中的调用写法：
      // unawaited(recoverAudioMetadata(supportPath: supportPath).then(...).catchError(...))
      // 证明：此写法无法捕获同步异常，同步异常会直接穿透并杀死 main()！
      expect(
        () {
          unawaited(unreadyRecoverAudioMetadata().then((warnings) {
            // ...
          }).catchError((error, stackTrace) {
            // 开发者误以为 catchError 能截获所有错误，但其实对同步 throw 毫无作用！
          }));
        },
        throwsA(isA<StateError>()),
        reason: 'Synchronous invocation of recoverAudioMetadata bypasses catchError and crashes main()!',
      );
    });
  });

  // =========================================================================
  // GROUP 3: Maximize Button Rect Debouncing Tolerance Algorithm Adversarial Suite
  // =========================================================================
  group('Adversarial 3: Maximize Button Rect Debounce Tolerance & Precision Invariants', () {
    // 提取 TitleBar 中的防抖核心数学判定公式进行严格的浮点对抗与单调性测试：
    // bool shouldDebounce(Rect lastRect, Rect currentRect, double lastDpr, double currentDpr)
    bool shouldDebounce({
      required Rect? lastRect,
      required Rect currentRect,
      required double? lastDpr,
      required double currentDpr,
    }) {
      if (lastRect != null &&
          lastDpr != null &&
          (lastDpr - currentDpr).abs() < 0.001 &&
          (lastRect.left - currentRect.left).abs() < 0.5 &&
          (lastRect.top - currentRect.top).abs() < 0.5 &&
          (lastRect.width - currentRect.width).abs() < 0.5 &&
          (lastRect.height - currentRect.height).abs() < 0.5) {
        return true;
      }
      return false;
    }

    test('3.1: Float coordinate boundary tolerance: exact threshold and strict monotonicity', () {
      const baseRect = Rect.fromLTWH(100.0, 50.0, 46.0, 32.0);
      const baseDpr = 1.0;

      // 3.1a: 边界极限值验证
      // delta = 0.49999999999999 -> 必须返回 true (防抖，不触发 IPC)
      final justBelowThreshold = Rect.fromLTWH(
        baseRect.left + 0.49999999999999,
        baseRect.top,
        baseRect.width,
        baseRect.height,
      );
      expect(
        shouldDebounce(
          lastRect: baseRect,
          currentRect: justBelowThreshold,
          lastDpr: baseDpr,
          currentDpr: baseDpr,
        ),
        isTrue,
        reason: 'Delta < 0.5 must be debounced',
      );

      // delta = 0.50000000000000 -> 必须返回 false (不防抖，触发 IPC)
      final exactThreshold = Rect.fromLTWH(
        baseRect.left + 0.5,
        baseRect.top,
        baseRect.width,
        baseRect.height,
      );
      expect(
        shouldDebounce(
          lastRect: baseRect,
          currentRect: exactThreshold,
          lastDpr: baseDpr,
          currentDpr: baseDpr,
        ),
        isFalse,
        reason: 'Delta == 0.5 must trigger IPC update',
      );

      // delta = 0.50000000000001 -> 必须返回 false (不防抖，触发 IPC)
      final justAboveThreshold = Rect.fromLTWH(
        baseRect.left + 0.50000000000001,
        baseRect.top,
        baseRect.width,
        baseRect.height,
      );
      expect(
        shouldDebounce(
          lastRect: baseRect,
          currentRect: justAboveThreshold,
          lastDpr: baseDpr,
          currentDpr: baseDpr,
        ),
        isFalse,
        reason: 'Delta > 0.5 must trigger IPC update',
      );

      // 3.1b: 针对 left, top, width, height 4 个维度分别测试单调性
      for (final dim in ['left', 'top', 'width', 'height']) {
        for (int step = 0; step <= 20; step++) {
          final delta = step * 0.05; // 避免 += 0.05 累加器微小浮点下溢
          if ((delta - 0.5).abs() < 1e-6) continue; // 跳过精确等于 0.5 的阈值点（已在 3.1a 专项检验）
          final testRect = switch (dim) {
            'left' => Rect.fromLTWH(baseRect.left + delta, baseRect.top, baseRect.width, baseRect.height),
            'top' => Rect.fromLTWH(baseRect.left, baseRect.top + delta, baseRect.width, baseRect.height),
            'width' => Rect.fromLTWH(baseRect.left, baseRect.top, baseRect.width + delta, baseRect.height),
            'height' => Rect.fromLTWH(baseRect.left, baseRect.top, baseRect.width, baseRect.height + delta),
            _ => baseRect,
          };
          final debounced = shouldDebounce(
            lastRect: baseRect,
            currentRect: testRect,
            lastDpr: baseDpr,
            currentDpr: baseDpr,
          );
          if (delta < 0.5) {
            expect(debounced, isTrue, reason: 'Dimension $dim with delta $delta must debounce');
          } else {
            expect(debounced, isFalse, reason: 'Dimension $dim with delta $delta must trigger update');
          }
        }
      }
    });

    test('3.2: DPR precision boundaries and Windows display scaling transitions', () {
      const baseRect = Rect.fromLTWH(100.0, 50.0, 46.0, 32.0);
      const baseDpr = 1.0;

      // 3.2a: DPR 微小浮点抖动 (< 0.001) 必须被防抖吸收
      // 在 IEEE 754 中，1.000999 与 1.0 的差值严格小于 0.001
      expect(
        shouldDebounce(
          lastRect: baseRect,
          currentRect: baseRect,
          lastDpr: baseDpr,
          currentDpr: 1.000999,
        ),
        isTrue,
      );

      // 3.2b: DPR 达到阈值 0.001 以上（例如 1.001001）时必须触发更新
      expect(
        shouldDebounce(
          lastRect: baseRect,
          currentRect: baseRect,
          lastDpr: baseDpr,
          currentDpr: 1.001001,
        ),
        isFalse,
      );

      // 3.2c: Windows 标准 DPI 缩放切换（100% -> 125% -> 150% -> 175% -> 200%）必须 100% 触发更新
      final standardScales = [1.25, 1.5, 1.75, 2.0, 2.25, 2.5];
      for (final scale in standardScales) {
        expect(
          shouldDebounce(
            lastRect: baseRect,
            currentRect: baseRect,
            lastDpr: baseDpr,
            currentDpr: scale,
          ),
          isFalse,
          reason: 'Scale change to $scale must trigger IPC update',
        );
      }
    });

    test('3.3: High-frequency sub-pixel oscillation / Jitter absorption (60 FPS scenario)', () {
      const baseRect = Rect.fromLTWH(500.0, 0.0, 46.0, 32.0);
      const dpr = 1.0;

      Rect? lastReportedRect = baseRect;
      double? lastReportedDpr = dpr;
      int ipcReportCount = 0;

      // 模拟 120 帧高频微幅抖动（在 baseRect.left 附近 +/- 0.35px 振荡）
      final random = math.Random(1337);
      for (int frame = 0; frame < 120; frame++) {
        final jitter = (random.nextDouble() - 0.5) * 0.7; // 范围 [-0.35, +0.35]
        final currentRect = Rect.fromLTWH(
          baseRect.left + jitter,
          baseRect.top,
          baseRect.width,
          baseRect.height,
        );

        final debounced = shouldDebounce(
          lastRect: lastReportedRect,
          currentRect: currentRect,
          lastDpr: lastReportedDpr,
          currentDpr: dpr,
        );

        if (!debounced) {
          ipcReportCount++;
          lastReportedRect = currentRect;
          lastReportedDpr = dpr;
        }
      }

      // 核心断言：120 帧微小抖动必须 100% 被防抖过滤，零 IPC 触发！
      expect(ipcReportCount, 0,
          reason: 'Sub-pixel jitter within +/-0.35px must never trigger IPC calls');
    });

    test('3.4: Slow gradual drift test: guarantees drift never accumulates silently undetected', () {
      const baseRect = Rect.fromLTWH(100.0, 50.0, 46.0, 32.0);
      const dpr = 1.0;

      Rect? lastReportedRect = baseRect;
      double? lastReportedDpr = dpr;
      final reportedOffsets = <double>[baseRect.left];

      // 每帧移动 0.1px，总共移动 30 步 (3.0px)
      for (int step = 1; step <= 30; step++) {
        final currentOffset = baseRect.left + step * 0.1;
        final currentRect = Rect.fromLTWH(
          currentOffset,
          baseRect.top,
          baseRect.width,
          baseRect.height,
        );

        final debounced = shouldDebounce(
          lastRect: lastReportedRect,
          currentRect: currentRect,
          lastDpr: lastReportedDpr,
          currentDpr: dpr,
        );

        if (!debounced) {
          reportedOffsets.add(currentOffset);
          lastReportedRect = currentRect;
          lastReportedDpr = dpr;
        }
      }

      // 检验：因为每达到 0.5px 就上报一次并重置基准，
      // 在 3.0px 的总行程中，应该大约每 5 步（0.5px）上报一次，总上报次数应为 6 次（不含初始）
      expect(reportedOffsets.length, 7); // 初始 100.0 + 6 次上报
      for (int i = 1; i < reportedOffsets.length; i++) {
        final stepDistance = reportedOffsets[i] - reportedOffsets[i - 1];
        expect(stepDistance, closeTo(0.5, 1e-6),
            reason: 'Each reported drift step must be exactly 0.5px');
      }
    });

    test('3.5: Multi-monitor negative coordinates stability', () {
      // 位于副屏（主屏左侧或上方）时的负坐标
      const negativeRect = Rect.fromLTWH(-1920.0, -1080.0, 46.0, 32.0);
      const dpr = 1.0;

      // 负坐标下的 0.4px 抖动必须防抖
      expect(
        shouldDebounce(
          lastRect: negativeRect,
          currentRect: const Rect.fromLTWH(-1919.6, -1080.0, 46.0, 32.0),
          lastDpr: dpr,
          currentDpr: dpr,
        ),
        isTrue,
      );

      // 负坐标下的 0.5px 变化必须触发上报
      expect(
        shouldDebounce(
          lastRect: negativeRect,
          currentRect: const Rect.fromLTWH(-1919.5, -1080.0, 46.0, 32.0),
          lastDpr: dpr,
          currentDpr: dpr,
        ),
        isFalse,
      );
    });

    testWidgets('3.6: TitleBar widget integration: maximize button rect reporting and lifecycle cleanup', (tester) async {
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

      // 挂载 TitleBar
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 48,
              width: 800,
              child: TitleBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证初次挂载时上报了有效尺寸
      final initialRectCalls = methodCalls
          .where((c) => c.method == 'set_maximize_button_rect')
          .toList();
      expect(initialRectCalls.isNotEmpty, isTrue);
      final firstArgs = initialRectCalls.first.arguments as Map;
      expect(firstArgs['width'], greaterThan(0));
      expect(firstArgs['height'], greaterThan(0));

      methodCalls.clear();

      // 触发无尺寸改变的 pump，验证防抖机制阻止了重复 IPC 上报
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        methodCalls.where((c) => c.method == 'set_maximize_button_rect').isEmpty,
        isTrue,
        reason: 'Static frame without geometry shift must not spam set_maximize_button_rect IPC',
      );

      // 卸载 TitleBar，验证 dispose 时清理归零
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final cleanupCalls = methodCalls
          .where((c) => c.method == 'set_maximize_button_rect')
          .toList();
      expect(cleanupCalls.isNotEmpty, isTrue);
      final lastArgs = cleanupCalls.last.arguments as Map;
      expect(lastArgs['left'], 0.0);
      expect(lastArgs['top'], 0.0);
      expect(lastArgs['width'], 0.0);
      expect(lastArgs['height'], 0.0);

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
}
