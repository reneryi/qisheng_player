#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

// 保持前 9 个 float 槽位与历史调用完全兼容：
// [0..1] u_size
// [2]    u_time
// [3..6] u_tint_color
// [7]    u_is_dark
// [8]    u_refraction_strength
uniform vec2 u_size;
uniform float u_time;
uniform vec4 u_tint_color;
uniform float u_is_dark;
uniform float u_refraction_strength;

// 扩展光学与声学物理驱动通道 (Slots 9..13)：
// [9]      u_corner_radius (px)
// [10]     u_bass_energy (0.0 ~ 1.0 Sub-bass 瞬态能量)
// [11]     u_spectral_centroid (0.0 ~ 1.0 频谱质心/色散张力)
// [12..13] u_pointer_uv (0.0 ~ 1.0 归一化鼠标悬停焦点)
uniform float u_corner_radius;
uniform float u_bass_energy;
uniform float u_spectral_centroid;
uniform vec2 u_pointer_uv;

out vec4 frag_color;

// 圆角矩形有向距离场 (Signed Distance Field for Rounded Box)
float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// 解析 SDF 梯度法线 (用于边缘凸透镜折射与棱镜色散计算)
vec2 sdfNormal(vec2 p, vec2 b, float r) {
  const float eps = 1.0;
  float dx = sdRoundedBox(p + vec2(eps, 0.0), b, r) -
             sdRoundedBox(p - vec2(eps, 0.0), b, r);
  float dy = sdRoundedBox(p + vec2(0.0, eps), b, r) -
             sdRoundedBox(p - vec2(0.0, eps), b, r);
  float len = max(length(vec2(dx, dy)), 0.0001);
  return vec2(dx, dy) / len;
}

// 晶体内部次表面焦散光丝网络
float crystalCausticField(vec2 uv, float t, float centroidShift) {
  vec2 p = uv * vec2(2.6, 1.8);
  float w1 = sin(p.x * 3.2 + p.y * 2.1 + t * 0.24);
  float w2 = cos(p.x * 2.4 - p.y * 3.5 - t * 0.19 + centroidShift * 1.6);
  float ridge = 1.0 - abs(w1 * w2);
  return pow(clamp(ridge, 0.0, 1.0), 3.6);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 safeSize = max(u_size, vec2(1.0));
  vec2 uv = frag / safeSize;
  vec2 centered = (uv - 0.5) * 2.0;

  float darkFactor = clamp(u_is_dark, 0.0, 1.0);
  float refrStrength = clamp(u_refraction_strength, 0.0, 2.0);
  float bass = clamp(u_bass_energy, 0.0, 1.0);
  float centroidVal = clamp(u_spectral_centroid, 0.0, 1.0);
  float radiusPx = u_corner_radius > 0.5 ? u_corner_radius : 22.0;

  // 1. 计算 SDF 几何边界与边缘曲率区域
  vec2 halfSize = safeSize * 0.5;
  vec2 localPos = frag - halfSize;
  float r = min(radiusPx, min(halfSize.x, halfSize.y) - 0.5);
  float d = sdRoundedBox(localPos, halfSize, max(r, 1.0));
  vec2 edgeNormal = sdfNormal(localPos, halfSize, max(r, 1.0));

  // 距离边缘的归一化光学透镜带 (0.0 在内部中心，1.0 在晶体倒角边缘)
  float bevelWidth = clamp(min(safeSize.x, safeSize.y) * 0.22, 10.0, 36.0);
  float edgeBand = smoothstep(-bevelWidth, 0.0, d);
  float rimLine = smoothstep(-2.4, 0.0, d) * (1.0 - smoothstep(0.0, 1.2, d));

  // 2. 纯净透光晶体基底 (50%~60% 通透玻璃底色，搭载 10%~14% 极浅淡动态封面染色)
  float darkAlpha  = 0.58;
  float lightAlpha = 0.50;
  float baseAlpha  = mix(lightAlpha, darkAlpha, darkFactor);

  vec3 darkCore = vec3(0.042, 0.058, 0.080);
  vec3 darkBase = mix(darkCore, u_tint_color.rgb, 0.13 + bass * 0.04);

  vec3 lightCore = vec3(0.958, 0.970, 0.988);
  vec3 lightBase = mix(lightCore, u_tint_color.rgb, 0.085 + bass * 0.025);

  vec3 glassBase = mix(lightBase, darkBase, darkFactor);

  // 3. 边缘斯涅尔透镜折射 + RGB 棱镜色散 (Chromatic Aberration)
  // 边缘曲率越大、高频质心越高，RGB 三通道的折射角微小偏移越明显，形成真实亚克力镇纸边缘的彩虹微芒
  float dispersion = (0.014 + centroidVal * 0.018 + bass * 0.010) *
                     (0.5 + refrStrength * 0.5) * edgeBand;
  vec2 refrUvR = uv + edgeNormal * dispersion * 0.85;
  vec2 refrUvG = uv + edgeNormal * dispersion * 1.00;
  vec2 refrUvB = uv + edgeNormal * dispersion * 1.18;

  float causticR = crystalCausticField(refrUvR, u_time, centroidVal * 0.8);
  float causticG = crystalCausticField(refrUvG, u_time, centroidVal * 1.0);
  float causticB = crystalCausticField(refrUvB, u_time, centroidVal * 1.2);
  vec3 dispersionCaustic = vec3(causticR, causticG, causticB);

  // 棱镜边缘色散微彩 (Red-Cyan-Violet subtle spectral fringe along bevel)
  vec3 spectralFringe = vec3(
    max(0.0, edgeNormal.x) * 0.9 + max(0.0, -edgeNormal.y) * 0.4,
    abs(edgeNormal.x * edgeNormal.y) * 0.8,
    max(0.0, -edgeNormal.x) * 0.9 + max(0.0, edgeNormal.y) * 0.5
  );
  vec3 prismEdgeTint = mix(u_tint_color.rgb, spectralFringe, 0.45) *
                       edgeBand * (darkFactor > 0.5 ? 0.065 : 0.042) *
                       (0.75 + refrStrength * 0.45);

  // 4. 顶部环境天光温润微晕 + 菲涅尔边缘高光 (Fresnel Rim Specular)
  float topGlaze = smoothstep(0.8, -0.65, centered.y) *
                   (darkFactor > 0.5 ? 0.040 : 0.024);
  vec2 lightDir = normalize(vec2(-0.45, -0.75));
  float rimAlignment = max(0.0, dot(edgeNormal, lightDir));
  float fresnelRim = (edgeBand * 0.35 + rimLine * 0.85) *
                     (0.35 + 0.65 * rimAlignment) *
                     (darkFactor > 0.5 ? 0.14 : 0.18);

  // 5. 鼠标指针局部聚光折射微晕 (Pointer Interactive Spotlight)
  float pointerGlow = 0.0;
  if (u_pointer_uv.x > 0.001 || u_pointer_uv.y > 0.001) {
    vec2 aspectDelta = (uv - u_pointer_uv) *
                       vec2(safeSize.x / max(safeSize.y, 1.0), 1.0);
    float distSq = dot(aspectDelta, aspectDelta);
    pointerGlow = exp(-distSq / 0.18) * (darkFactor > 0.5 ? 0.055 : 0.038);
  }

  // 6. 声学低频呼吸与次表面流光合成
  float lusterStrength = (darkFactor > 0.5 ? 0.032 : 0.018) * (1.0 + bass * 0.55);
  vec3 subsurfaceLuster = u_tint_color.rgb * dispersionCaustic * lusterStrength;
  float subtleSheen = (centered.x * 0.2 - centered.y * 0.3) *
                      (darkFactor > 0.5 ? 0.012 : 0.008);

  // 7. 极细微高频防断层抖动 (Dither)
  float n = fract(sin(dot(frag, vec2(12.9898, 78.233))) * 43758.5453);
  float dither = (n - 0.5) * (0.4 / 255.0);

  vec3 finalRgb = glassBase +
                  vec3(topGlaze + fresnelRim + pointerGlow + subtleSheen) +
                  subsurfaceLuster +
                  prismEdgeTint +
                  vec3(dither);
  float finalAlpha = clamp(
    baseAlpha + topGlaze * 0.22 + edgeBand * 0.06 + rimLine * 0.10,
    0.0,
    0.82
  );

  frag_color = vec4(clamp(finalRgb, 0.0, 1.0), finalAlpha);
}
