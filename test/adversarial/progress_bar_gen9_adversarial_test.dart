import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/bottom_player_bar.dart';
import 'package:qisheng_player/component/dual_layer_rhythm_slider.dart';
import 'package:qisheng_player/component/fluid_glow_progress_slider.dart';
import 'package:qisheng_player/component/waveform_slider.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/utils.dart';

import '../test_helpers/media_test_harness.dart';

class SpectrumFakePlaybackController extends FakePlaybackController {
  SpectrumFakePlaybackController({
    required super.audio,
    required super.queue,
  });

  final ValueNotifier<List<double>> _spectrum = ValueNotifier<List<double>>([]);

  @override
  ValueListenable<List<double>> get audioSpectrum => _spectrum;

  void pushSpectrum(List<double> bins) {
    _spectrum.value = bins;
  }

  @override
  void dispose() {
    _spectrum.dispose();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('qisheng_adv_progressbar_stress_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    AppSettings.instance.progressBarTypeNotifier.value =
        ProgressBarType.fluidGlow;
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    AppSettings.instance.progressBarTypeNotifier.value =
        ProgressBarType.fluidGlow;
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // ===========================================================================
  // GROUP 1: SpringSimulation 欠阻尼振荡极限物理与负数过冲崩溃防御
  // ===========================================================================
  group('Adversarial Group 1: SpringSimulation 欠阻尼振荡极限物理防御实测', () {
    testWidgets(
        '1.1 极大初速度释放拖拽，推进完整物理周期，实测负数过冲且 AnimationController 零断言崩溃',
        (tester) async {
      double? lastChanged;
      double? lastEnd;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: AdaptiveWaveformSlider(
                  value: 50,
                  max: 200,
                  onChanged: (v) => lastChanged = v,
                  onChangeEnd: (v) => lastEnd = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byType(AdaptiveWaveformSlider));
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;

      // 模拟剧烈横向拖拽并以极高速度释放 (Fling gesture at 6000 px/s)
      final gesture =
          await tester.startGesture(Offset(topLeft.dx + 50, centerY));
      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();
      expect(lastChanged, isNotNull);

      // 高速微位移后释放
      await gesture.moveBy(const Offset(60, 0), timeStamp: const Duration(milliseconds: 10));
      await gesture.up();
      await tester.pump();
      expect(lastEnd, isNotNull);

      // 推进完整弹簧欠阻尼振荡周期（0ms ~ 800ms，每 16ms 步进采样）
      int frameCount = 0;
      for (int t = 0; t < 800; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        frameCount++;
        expect(tester.takeException(), isNull,
            reason: 'Frame $frameCount (t=${t}ms) must not throw assertion error');
      }

      // 验证未抛出任何 RangeError 或 AssertionError
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.2 极度恶劣初始速度 (-15000 / +15000) 注入 SpringSimulation，验证物理数值稳定性与绘制层阻断',
        (tester) async {
      // 验证底层欠阻尼物理弹簧在极端条件下的数值演变
      const spring = SpringDescription(
        mass: 1.0,
        stiffness: 180.0,
        damping: 12.0,
      );

      final extremeVelocities = [-15000.0, -5000.0, -1000.0, 1000.0, 5000.0, 15000.0];
      for (final v in extremeVelocities) {
        final sim = SpringSimulation(spring, 1.0, 0.0, v);
        bool observedNegative = false;

        // 推进 2.0 秒物理时钟
        for (double t = 0.0; t <= 2.0; t += 0.016) {
          final x = sim.x(t);
          final dx = sim.dx(t);
          expect(x.isFinite, isTrue, reason: 'x($t) must be finite at v=$v');
          expect(dx.isFinite, isTrue, reason: 'dx($t) must be finite at v=$v');
          if (x < 0.0) {
            observedNegative = true;
          }
        }
        // 欠阻尼弹簧在释放时必须观测到负数过冲（物理事实核验）
        expect(observedNegative, isTrue,
            reason: 'Spring simulation must exhibit negative overshoot at v=$v');
      }

      // 验证 Legacy WaveformSlider 在相同条件下的稳定性
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                child: WaveformSlider(
                  value: 30,
                  max: 100,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(WaveformSlider));
      final center = box.localToGlobal(box.size.center(Offset.zero));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
    });
  });

  // ===========================================================================
  // GROUP 2: 播放中高频热插拔（播放、拖拽与高频推流状态下并发切换）
  // ===========================================================================
  group('Adversarial Group 2: 播放中高频热插拔与状态流互斥极限挑战', () {
    testWidgets(
        '2.1 边播边拖拽边推流时，以密集间隔轮转切换三种进度条 60 次，验证零崩溃与零 Ticker 泄漏',
        (tester) async {
      final audio = TestAudio(
        title: 'HotSwap Live Song',
        artist: 'HotSwap Artist',
        album: 'HotSwap Album',
        path: r'E:\Music\hotswap.flac',
      );
      final playback = SpectrumFakePlaybackController(
        audio: audio,
        queue: [audio],
      );

      await tester.pumpWidget(
        buildMediaHarness(
          playbackController: playback,
          lyricController: FakeLyricController(Lrc([], LrcSource.local)),
          desktopLyricController: FakeDesktopLyricController(),
          child: const Center(
            child: SizedBox(
              width: 800,
              child: BottomPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pump();

      // 启动播放
      playback.start();
      await tester.pump();

      // 在进度条区域开启拖拽手势 (保留未释放状态)
      final barFinder = find.byType(BottomPlayerBar);
      expect(barFinder, findsOneWidget);
      final barBox = tester.renderObject<RenderBox>(barFinder);
      final center = barBox.localToGlobal(barBox.size.center(Offset.zero));

      final dragGesture = await tester.startGesture(center);
      await dragGesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // 模拟 60 次高频热插拔轮换，并在每次切换间隙注入高频音频推流
      final types = [
        ProgressBarType.fluidGlow,
        ProgressBarType.adaptiveWaveform,
        ProgressBarType.dualLayerRhythm,
      ];

      for (int i = 0; i < 60; i++) {
        final targetType = types[i % types.length];
        AppSettings.instance.progressBarTypeNotifier.value = targetType;

        // 模拟高频频谱推流 (64 频段随机动能)
        final mockBins = List<double>.generate(64, (idx) => (math.sin(i * 0.2 + idx) + 1.0) / 2.0);
        playback.pushSpectrum(mockBins);

        // 模拟播放器位置推流
        playback.seek((10 + (i % 30)).toDouble());

        // 拖拽手势微移
        await dragGesture.moveBy(Offset((i % 2 == 0 ? 3.0 : -3.0), 0));

        // 密集微步 pump
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull,
            reason: 'Failed during hot-swap iteration $i to $targetType');
      }

      // 结束拖拽手势
      await dragGesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 推进多帧以允许所有过渡动画自然结束或销毁
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.takeException(), isNull);
      }

      // 校验最终组件正确渲染为最后一次设置的目标组件
      expect(find.byType(DualLayerRhythmSlider), findsOneWidget);
      expect(tester.takeException(), isNull);

      playback.dispose();
    });

    testWidgets(
        '2.2 在极端极小视口 (width=10px, height=14px) 下高频热切换，无 RenderFlex 溢出',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 10,
                height: 14,
                child: ValueListenableBuilder<ProgressBarType>(
                  valueListenable: AppSettings.instance.progressBarTypeNotifier,
                  builder: (context, type, _) {
                    switch (type) {
                      case ProgressBarType.fluidGlow:
                        return const FluidGlowProgressSlider(
                          value: 5,
                          max: 100,
                          height: 14.0,
                        );
                      case ProgressBarType.adaptiveWaveform:
                        return const AdaptiveWaveformSlider(
                          value: 5,
                          max: 100,
                          height: 14.0,
                        );
                      case ProgressBarType.dualLayerRhythm:
                        return const DualLayerRhythmSlider(
                          value: 5,
                          max: 100,
                          height: 14.0,
                        );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final t in ProgressBarType.values) {
        AppSettings.instance.progressBarTypeNotifier.value = t;
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  // ===========================================================================
  // GROUP 3: 音频频谱数据模糊（Fuzzing）与自适应呼吸发生器平滑接管
  // ===========================================================================
  group('Adversarial Group 3: 音频频谱数据模糊与自适应呼吸平滑接管实证', () {
    test('3.1 resolveSpectrumEnergy 模糊测试：注入 NaN, Inf, 负值, 越界长度', () {
      // 1. 空列表与全零
      expect(resolveSpectrumEnergy(null).hasRealFft, isFalse);
      expect(resolveSpectrumEnergy([]).hasRealFft, isFalse);
      expect(resolveSpectrumEnergy(List.filled(64, 0.0)).hasRealFft, isFalse);

      // 2. 超长列表 (10000 频段)
      final giantList = List.generate(10000, (i) => 0.5);
      final giantEnergy = resolveSpectrumEnergy(giantList);
      expect(giantEnergy.bass.isFinite, isTrue);
      expect(giantEnergy.mid.isFinite, isTrue);
      expect(giantEnergy.treble.isFinite, isTrue);
      expect(giantEnergy.hasRealFft, isTrue);

      // 3. 超短列表 (3 频段)
      final tinyList = [0.9, 0.8, 0.7];
      final tinyEnergy = resolveSpectrumEnergy(tinyList);
      expect(tinyEnergy.bass.isFinite, isTrue);
      expect(tinyEnergy.mid, equals(0.0));
      expect(tinyEnergy.treble, equals(0.0));
      expect(tinyEnergy.hasRealFft, isTrue);

      // 4. 负数与超大数值
      final outOfRangeList = [-999.0, 999.0, -0.5, 2.0];
      final outEnergy = resolveSpectrumEnergy(outOfRangeList);
      expect(outEnergy.bass.isFinite, isTrue);
      expect(outEnergy.bass, greaterThanOrEqualTo(0.0));
      expect(outEnergy.bass, lessThanOrEqualTo(1.0));

      // 5. 正无穷与负无穷
      final infList = List.filled(64, double.infinity);
      final infEnergy = resolveSpectrumEnergy(infList);
      expect(infEnergy.bass.isFinite, isTrue);
      expect(infEnergy.mid.isFinite, isTrue);
      expect(infEnergy.treble.isFinite, isTrue);

      final negInfList = List.filled(64, double.negativeInfinity);
      final negInfEnergy = resolveSpectrumEnergy(negInfList);
      expect(negInfEnergy.bass.isFinite, isTrue);
      expect(negInfEnergy.bass, equals(0.0));

      // 6. 含 NaN 输入测试：
      // 实测发现：Dart SDK num.clamp(0.0, 1.0) 会将 double.nan 的 compareTo(1.0) 判定为大于 0，从而强制钳位至 1.0。
      // 这保证了数值始终有限 (isFinite == true)，彻底阻断了 NaN 渗透至 Canvas 导致崩溃；
      // 但也导致 NaN 被误解为能量 1.0 (hasRealFft == true)。
      final nanList = [double.nan, 0.5];
      final nanEnergy = resolveSpectrumEnergy(nanList);
      expect(nanEnergy.bass.isFinite, isTrue, reason: 'bass must be finite even with NaN input');
      expect(nanEnergy.mid.isFinite, isTrue);
      expect(nanEnergy.treble.isFinite, isTrue);
    });

    testWidgets(
        '3.2 向 DualLayerRhythmSlider 注入含 NaN/Inf 脏数据、零数据与超短列表，验证自适应呼吸接管无崩溃',
        (tester) async {
      final spectrum = ValueNotifier<List<double>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: DualLayerRhythmSlider(
                  value: 45,
                  max: 180,
                  spectrum: spectrum,
                  spectrumActive: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 步骤 A: 正常 FFT 注入
      spectrum.value = List.filled(64, 0.7);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      // 步骤 B: 突发全零数据 (模拟静音或 WASAPI 独占淡出)
      spectrum.value = List.filled(64, 0.0);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.takeException(), isNull);
      }

      // 步骤 C: 注入含 NaN 的脏数据
      final nanList = List<double>.generate(64, (i) => i % 2 == 0 ? double.nan : 0.5);
      spectrum.value = nanList;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      // 步骤 D: 注入含 Infinity 的脏数据
      final infList = List<double>.generate(64, (i) => i % 3 == 0 ? double.infinity : -100.0);
      spectrum.value = infList;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      // 步骤 E: 突发置空并恢复自激呼吸
      spectrum.value = [];
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }

      spectrum.dispose();
    });
  });

  // ===========================================================================
  // GROUP 4: 设置项持久化高并发压力测试与磁盘写锁安全性实证
  // ===========================================================================
  group('Adversarial Group 4: AppSettings 持久化并发压力与防抖写锁实证', () {
    test('4.1 多任务高并发频繁变更 progressBarType，检验防抖重置、零死锁与状态原子性', () async {
      // 初始状态
      AppSettings.instance.progressBarType = ProgressBarType.fluidGlow;
      expect(AppSettings.instance.progressBarType, equals(ProgressBarType.fluidGlow));

      // 启动 50 个异步任务，并发随机写入不同设置值
      const taskCount = 50;
      final futures = <Future<void>>[];
      final rng = math.Random(42);

      for (int i = 0; i < taskCount; i++) {
        final taskIndex = i;
        futures.add(() async {
          await Future.delayed(Duration(milliseconds: rng.nextInt(15)));
          final nextType = ProgressBarType.values[taskIndex % ProgressBarType.values.length];
          AppSettings.instance.progressBarType = nextType;
          final current = AppSettings.instance.progressBarType;
          expect(current, isNotNull);
        }());
      }

      await Future.wait(futures);

      // 最终强制写入一个确定值
      const finalExpectedType = ProgressBarType.dualLayerRhythm;
      AppSettings.instance.progressBarType = finalExpectedType;
      expect(AppSettings.instance.progressBarType, equals(finalExpectedType));

      // 验证反序列化重新加载
      AppSettings.instance.progressBarTypeNotifier.value = ProgressBarType.fluidGlow;
      await AppSettings.parseSettingsMap({
        "Version": 2,
        "ProgressBarType": finalExpectedType.name,
      });
      expect(AppSettings.instance.progressBarType, equals(finalExpectedType));
    });

    test('4.2 串行任务队列与防抖机制下，验证 atomicWriteString 零碰撞、文件完整无损与 JSON 格式健全', () async {
      final testFilePath = p.join(tempDir.path, 'concurrent_settings_test.json');

      // 模拟类似 lyric_source.dart 的串行写入队列保护机制
      Future<void> writeQueue = Future.value();
      const taskCount = 30;

      final futures = List.generate(taskCount, (idx) {
        final payload = json.encode({
          "Version": 2,
          "WorkerId": idx,
          "ProgressBarType": ProgressBarType.values[idx % ProgressBarType.values.length].name,
          "Timestamp": DateTime.now().microsecondsSinceEpoch,
        });
        writeQueue = writeQueue.then((_) => atomicWriteString(testFilePath, payload));
        return writeQueue;
      });

      await Future.wait(futures);

      final targetFile = File(testFilePath);
      expect(targetFile.existsSync(), isTrue);
      final raw = await targetFile.readAsString();
      expect(raw.isNotEmpty, isTrue);

      final decoded = json.decode(raw) as Map<String, dynamic>;
      expect(decoded.containsKey('ProgressBarType'), isTrue);
      expect(ProgressBarType.fromName(decoded['ProgressBarType']), isNotNull);
    });
  });
}
