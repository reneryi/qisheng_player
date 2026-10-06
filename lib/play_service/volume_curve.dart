import 'dart:math' as math;

/// 将用户感知音量 [0.0, 1.0] 映射为底层物理线性振幅 [0.0, 1.0]。
///
/// 采用工业标准的三次多项式立方感知曲线 (Cubic Auditory Perceptual Curve: a = p^3)，
/// 与人耳响度的 Stevens 幂律及对数分贝规律高度契合：
/// - p = 0.00 -> a = 0.000 (-∞ dB, 静音)
/// - p = 0.10 -> a = 0.001 (-60.0 dB, 极弱背景音)
/// - p = 0.20 -> a = 0.008 (-41.9 dB, 耳机低音量轻柔舒适区)
/// - p = 0.30 -> a = 0.027 (-31.4 dB, 耳机常规听音区)
/// - p = 0.50 -> a = 0.125 (-18.0 dB, 适中音量)
/// - p = 1.00 -> a = 1.000 (0.0 dB, 满幅原始母带)
double perceptualVolumeToAmplitude(double perceptualVolume) {
  if (perceptualVolume <= 0.0) return 0.0;
  if (perceptualVolume >= 1.0) return 1.0;
  final clamped = perceptualVolume.clamp(0.0, 1.0);
  return clamped * clamped * clamped;
}

/// 将底层物理线性振幅 [0.0, 1.0] 反向映射为感知音量 [0.0, 1.0]。
///
/// 用于旧版本偏好设置平滑迁移或逆向换算：p = a^(1/3)。
double amplitudeToPerceptualVolume(double amplitude) {
  if (amplitude <= 0.0) return 0.0;
  if (amplitude >= 1.0) return 1.0;
  final clamped = amplitude.clamp(0.0, 1.0);
  return math.pow(clamped, 1.0 / 3.0).toDouble().clamp(0.0, 1.0);
}
