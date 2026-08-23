#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

// 屏幕分辨率与时间
uniform vec2 u_size;
uniform float u_time;

// 5 种调和提取色 (RGBA)
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;
uniform vec4 u_color_5;

// 基础背景底色 (暗黑深蓝黑 或 日间哑光纸白)
uniform vec4 u_base_color;

// 动态锚点坐标 (归一化 0.0 ~ 1.0)
uniform vec2 u_point_1;
uniform vec2 u_point_2;
uniform vec2 u_point_3;
uniform vec2 u_point_4;
uniform vec2 u_point_5;

// 参数控制：u_is_dark (1.0 为暗色, 0.0 为亮色), u_blend_intensity (流光强度)
uniform float u_is_dark;
uniform float u_blend_intensity;

out vec4 frag_color;

// 快速 Simplex/Perlin 风格平滑哈希
float hash21(vec2 p) {
  p = fract(p * vec2(234.34, 435.345));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

// 2D 平滑值噪声
float smoothNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 分形布朗运动 (FBM)，生成丝绸流体扰动场
float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
  for (int i = 0; i < 3; i++) {
    v += smoothNoise(p) * a;
    p = rot * p * 2.02 + vec2(13.5, 4.2);
    a *= 0.5;
  }
  return v;
}

// 高斯光斑权重计算（带平滑软边界）
float getGaussianWeight(vec2 uv, vec2 center, float radius) {
  float d = distance(uv, center);
  return exp(- (d * d) / (2.0 * radius * radius));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  float aspect = u_size.x / u_size.y;
  vec2 aspect_uv = vec2(uv.x * aspect, uv.y);

  // 计算多层低频领域扭曲 (Domain Warping)，产生如丝绸般的流动感
  float t = u_time * 0.06;
  vec2 warp_1 = vec2(
    fbm(aspect_uv * 1.5 + vec2(t, -t * 0.5)),
    fbm(aspect_uv * 1.4 + vec2(-t * 0.7, t))
  ) - 0.5;

  vec2 warp_2 = vec2(
    fbm(aspect_uv * 2.0 + warp_1 * 1.2 + vec2(5.2, 1.3)),
    fbm(aspect_uv * 2.0 + warp_1 * 1.2 + vec2(1.8, 8.4))
  ) - 0.5;

  vec2 warped_uv = aspect_uv + warp_2 * 0.35;

  // 映射 5 个锚点到宽高比坐标
  vec2 p1 = vec2(u_point_1.x * aspect, u_point_1.y);
  vec2 p2 = vec2(u_point_2.x * aspect, u_point_2.y);
  vec2 p3 = vec2(u_point_3.x * aspect, u_point_3.y);
  vec2 p4 = vec2(u_point_4.x * aspect, u_point_4.y);
  vec2 p5 = vec2(u_point_5.x * aspect, u_point_5.y);

  // 计算各个色球的高斯热力权重
  float radius = 0.65;
  float w1 = getGaussianWeight(warped_uv, p1, radius);
  float w2 = getGaussianWeight(warped_uv, p2, radius);
  float w3 = getGaussianWeight(warped_uv, p3, radius);
  float w4 = getGaussianWeight(warped_uv, p4, radius);
  float w5 = getGaussianWeight(warped_uv, p5, radius);

  float total_weight = w1 + w2 + w3 + w4 + w5 + 0.001;

  // 在感知线性空间做颜色混合
  vec4 fluid_color = (
    u_color_1 * w1 +
    u_color_2 * w2 +
    u_color_3 * w3 +
    u_color_4 * w4 +
    u_color_5 * w5
  ) / total_weight;

  // 根据明暗模式做自适应分层合成
  vec4 final_color;
  if (u_is_dark > 0.5) {
    // 暗色模式：深色对角渐变打底，流体光斑深度交融
    float fluid_alpha = clamp(total_weight * 0.75 * u_blend_intensity, 0.0, 0.95);
    final_color = mix(u_base_color, fluid_color, fluid_alpha);
  } else {
    // 明亮模式：哑光纸白为主体，流体光斑作为柔和粉彩雅致点缀 (Pastel Ambient Tint)
    float fluid_alpha = clamp(total_weight * 0.32 * u_blend_intensity, 0.0, 0.45);
    final_color = mix(u_base_color, fluid_color, fluid_alpha);
  }

  frag_color = final_color;
}
