import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const int audioSpectrumBinCount = 64;

/// 实时声学物理特征向量（由 64 频段对数 FFT 频谱解算，驱动着色器与微动量交互）
@immutable
class AcousticFeatures {
  const AcousticFeatures({
    this.subBassEnergy = 0.0,
    this.midHarmonicEnergy = 0.0,
    this.highBrilliance = 0.0,
    this.spectralCentroid = 0.0,
    this.rmsEnergy = 0.0,
  });

  static const AcousticFeatures zero = AcousticFeatures();

  /// Sub-Bass 低频瞬态能量 (20~120Hz，前 4 个频段)，用于驱动鼓点脉冲与水波/流体扩散
  final double subBassEnergy;

  /// 中频谐波饱满度 (人声与主乐器基频区)
  final double midHarmonicEnergy;

  /// 高频空气感与泛音亮度 (擦片、泛音瞬态)
  final double highBrilliance;

  /// 归一化频谱质心 (0.0 低沉温暖 ~ 1.0 明亮清冽)，用于控制光学折射色散与噪波细腻度
  final double spectralCentroid;

  /// 全频段均方根响度能量 (0.0 ~ 1.0)
  final double rmsEnergy;

  bool get isActive => rmsEnergy > 0.005 || subBassEnergy > 0.005;

  static AcousticFeatures lerp(
    AcousticFeatures a,
    AcousticFeatures b,
    double t,
  ) {
    final p = t.clamp(0.0, 1.0).toDouble();
    return AcousticFeatures(
      subBassEnergy:
          a.subBassEnergy + (b.subBassEnergy - a.subBassEnergy) * p,
      midHarmonicEnergy:
          a.midHarmonicEnergy + (b.midHarmonicEnergy - a.midHarmonicEnergy) * p,
      highBrilliance:
          a.highBrilliance + (b.highBrilliance - a.highBrilliance) * p,
      spectralCentroid:
          a.spectralCentroid + (b.spectralCentroid - a.spectralCentroid) * p,
      rmsEnergy: a.rmsEnergy + (b.rmsEnergy - a.rmsEnergy) * p,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcousticFeatures &&
          (subBassEnergy - other.subBassEnergy).abs() < 1e-4 &&
          (midHarmonicEnergy - other.midHarmonicEnergy).abs() < 1e-4 &&
          (highBrilliance - other.highBrilliance).abs() < 1e-4 &&
          (spectralCentroid - other.spectralCentroid).abs() < 1e-4 &&
          (rmsEnergy - other.rmsEnergy).abs() < 1e-4;

  @override
  int get hashCode => Object.hash(
        (subBassEnergy * 1000).round(),
        (midHarmonicEnergy * 1000).round(),
        (highBrilliance * 1000).round(),
        (spectralCentroid * 1000).round(),
        (rmsEnergy * 1000).round(),
      );
}

/// 从对数频谱提取声学物理特征（Sub-Bass、中频、高频、频谱质心、RMS）
AcousticFeatures computeAcousticFeatures(List<double> spectrum) {
  if (spectrum.isEmpty) return AcousticFeatures.zero;

  final len = spectrum.length;
  final bassEnd = math.min(len, 4);
  final midEnd = math.min(len, 24);

  var bassSum = 0.0;
  var midSum = 0.0;
  var highSum = 0.0;
  var weightedIndexSum = 0.0;
  var magnitudeSum = 0.0;
  var squareSum = 0.0;

  for (var i = 0; i < len; i++) {
    final raw = spectrum[i];
    final v = raw.isFinite ? raw.clamp(0.0, 1.0).toDouble() : 0.0;
    if (i < bassEnd) {
      bassSum += v;
    } else if (i < midEnd) {
      midSum += v;
    } else {
      highSum += v;
    }
    weightedIndexSum += v * i;
    magnitudeSum += v;
    squareSum += v * v;
  }

  if (magnitudeSum <= 0.0001) return AcousticFeatures.zero;

  final subBass = (bassSum / math.max(1, bassEnd)).clamp(0.0, 1.0).toDouble();
  final midCount = math.max(1, midEnd - bassEnd);
  final midHarmonic =
      (len > bassEnd ? midSum / midCount : subBass).clamp(0.0, 1.0).toDouble();
  final highCount = math.max(1, len - midEnd);
  final highBrilliance =
      (len > midEnd ? highSum / highCount : 0.0).clamp(0.0, 1.0).toDouble();
  final centroid = len > 1
      ? (weightedIndexSum / (magnitudeSum * (len - 1)))
          .clamp(0.0, 1.0)
          .toDouble()
      : 0.0;
  final rms = math.sqrt(squareSum / len).clamp(0.0, 1.0).toDouble();

  return AcousticFeatures(
    subBassEnergy: subBass,
    midHarmonicEnergy: midHarmonic,
    highBrilliance: highBrilliance,
    spectralCentroid: centroid,
    rmsEnergy: rms,
  );
}

/// Converts native FFT magnitudes into log-spaced, display-ready bands.
List<double> shapeFftSpectrum(
  List<double> fft, {
  int bins = audioSpectrumBinCount,
}) {
  final targetBins = bins.clamp(1, audioSpectrumBinCount).toInt();
  if (fft.length < 4) return const <double>[];

  const minIndex = 2.0;
  final maxIndex = (fft.length - 1).toDouble();
  final logMin = math.log(minIndex);
  final logSpan = math.log(maxIndex) - logMin;
  final output = List<double>.filled(targetBins, 0.0);

  for (var band = 0; band < targetBins; band++) {
    final startRatio = band / targetBins;
    final endRatio = (band + 1) / targetBins;
    final start = math
        .exp(logMin + logSpan * startRatio)
        .floor()
        .clamp(1, fft.length - 1)
        .toInt();
    final end = math
        .exp(logMin + logSpan * endRatio)
        .ceil()
        .clamp(start + 1, fft.length)
        .toInt();

    var peak = 0.0;
    for (var index = start; index < end; index++) {
      final value = fft[index];
      if (value.isFinite) peak = math.max(peak, value);
    }

    final magnitude = math.max(0.0, peak);
    final shaped = math.log(1 + magnitude * 140) / math.log(141);
    output[band] = shaped < 0.015 ? 0.0 : shaped.clamp(0.0, 1.0).toDouble();
  }

  if (output.every((value) => value < 0.003)) {
    return const <double>[];
  }
  return List<double>.unmodifiable(output);
}

/// Applies attack/release smoothing without making silence jump to zero.
List<double> smoothAudioSpectrum({
  required List<double> previous,
  required List<double> next,
  required bool active,
  int binCount = audioSpectrumBinCount,
  double attack = 0.45,
  double decay = 0.86,
}) {
  final targetBins = binCount.clamp(1, audioSpectrumBinCount).toInt();
  final output = List<double>.filled(targetBins, 0.0);
  final attackWeight = attack.clamp(0.0, 1.0).toDouble();
  final decayWeight = decay.clamp(0.0, 1.0).toDouble();

  if (previous.isEmpty && next.isEmpty) return const <double>[];

  for (var index = 0; index < targetBins; index++) {
    final oldValue = _spectrumValueAt(previous, index, targetBins);
    if (!active || next.isEmpty) {
      output[index] = oldValue * decayWeight;
      continue;
    }

    final rawValue = _spectrumValueAt(next, index, targetBins);
    output[index] = rawValue > oldValue
        ? oldValue + (rawValue - oldValue) * attackWeight
        : math.max(rawValue, oldValue * decayWeight);
  }

  if (output.every((value) => value < 0.003)) {
    return const <double>[];
  }
  return List<double>.unmodifiable(output);
}

double _spectrumValueAt(List<double> values, int index, int targetLength) {
  if (values.isEmpty) return 0.0;
  if (values.length == 1 || targetLength <= 1) {
    return _normalizedSpectrumValue(values.first);
  }

  final sourcePosition = index * (values.length - 1) / (targetLength - 1);
  final left = sourcePosition.floor();
  final right = sourcePosition.ceil();
  final t = sourcePosition - left;
  final leftValue = _normalizedSpectrumValue(values[left]);
  final rightValue = _normalizedSpectrumValue(values[right]);
  return leftValue + (rightValue - leftValue) * t;
}

double _normalizedSpectrumValue(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(0.0, 1.0).toDouble();
}

class AudioSpectrumNotifier extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<List<double>> {
  AudioSpectrumNotifier({required this.sample});

  final List<double> Function() sample;
  Timer? _timer;
  List<double> _value = const <double>[];
  bool _drainToSilence = false;
  bool _appVisible = true;
  bool _observingLifecycle = false;

  @override
  List<double> get value => _value;

  AcousticFeatures get acousticFeatures => computeAcousticFeatures(_value);

  @override
  void addListener(VoidCallback listener) {
    final hadListeners = hasListeners;
    super.addListener(listener);
    if (!hadListeners) _startSampling();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stopSampling();
  }

  void _startSampling() {
    if (!_appVisible) return;
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _sampleOnce(),
    );
  }

  void _stopSampling({bool removeLifecycleObserver = true}) {
    _timer?.cancel();
    _timer = null;
    _drainToSilence = false;
    _value = const <double>[];
    if (removeLifecycleObserver && _observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextVisible =
        state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
    if (_appVisible == nextVisible) return;
    _appVisible = nextVisible;
    if (_appVisible && hasListeners) {
      _startSampling();
    } else if (!_appVisible) {
      _stopSampling(removeLifecycleObserver: false);
    }
  }

  void decayToSilence() {
    if (_value.isEmpty) return;
    if (!hasListeners) {
      _value = const <double>[];
      return;
    }
    _drainToSilence = true;
  }

  /// Immediately clears the current frame for callers that explicitly need a
  /// hard reset; playback transitions use [decayToSilence] instead.
  void clear() {
    _drainToSilence = false;
    if (_value.isEmpty) return;
    _value = const <double>[];
    notifyListeners();
  }

  void _sampleOnce() {
    final active = sample;
    List<double> next;
    try {
      next = _drainToSilence ? const <double>[] : active();
    } catch (_) {
      next = const <double>[];
    }

    final nextValue = smoothAudioSpectrum(
      previous: _value,
      next: next,
      active: next.isNotEmpty,
    );
    if (_drainToSilence && nextValue.isEmpty) {
      _drainToSilence = false;
    }
    if (listEquals(_value, nextValue)) return;
    _value = nextValue;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopSampling();
    super.dispose();
  }
}
