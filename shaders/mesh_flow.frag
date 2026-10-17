#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

// Keep the first uniform block compatible with the existing Dart painter.
uniform vec2 u_size;
uniform float u_time;
uniform vec4 u_color_1;
uniform vec4 u_color_2;
uniform vec4 u_color_3;
uniform vec4 u_color_4;
uniform vec4 u_color_5;
uniform vec4 u_base_color;
uniform vec2 u_point_1;
uniform vec2 u_point_2;
uniform vec2 u_point_3;
uniform vec2 u_point_4;
uniform vec2 u_point_5;
uniform float u_is_dark;
uniform float u_blend_intensity;

// Performance-aware controls appended after the established uniform block.
uniform float u_warp_strength;
uniform float u_blob_scale;
uniform float u_layer_mix;
uniform float u_luminance_limit;

out vec4 frag_color;

vec3 srgbToLinear(vec3 c) {
  return mix(c / 12.92, pow((max(c, 0.0) + 0.055) / 1.055, vec3(2.4)),
      step(vec3(0.04045), c));
}

vec3 linearToSrgb(vec3 c) {
  return mix(c * 12.92,
      1.055 * pow(max(c, 0.0), vec3(1.0 / 2.4)) - 0.055,
      step(vec3(0.0031308), c));
}

vec3 linearToOklab(vec3 rgb) {
  float l = 0.4122214708 * rgb.r + 0.5363325363 * rgb.g +
      0.0514459929 * rgb.b;
  float m = 0.2119034982 * rgb.r + 0.6806995451 * rgb.g +
      0.1073969566 * rgb.b;
  float s = 0.0883024619 * rgb.r + 0.2817188376 * rgb.g +
      0.6299787005 * rgb.b;
  vec3 lmsRoot = pow(max(vec3(l, m, s), vec3(0.0)), vec3(1.0 / 3.0));
  return vec3(
      0.2104542553 * lmsRoot.x + 0.7936177850 * lmsRoot.y -
          0.0040720468 * lmsRoot.z,
      1.9779984951 * lmsRoot.x - 2.4285922050 * lmsRoot.y +
          0.4505937099 * lmsRoot.z,
      0.0259040371 * lmsRoot.x + 0.7827717662 * lmsRoot.y -
          0.8086757660 * lmsRoot.z);
}

vec3 oklabToLinear(vec3 lab) {
  float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
  float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
  float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
  vec3 lms = vec3(l * l * l, m * m * m, s * s * s);
  return vec3(
      4.0767416621 * lms.x - 3.3077115913 * lms.y +
          0.2309699292 * lms.z,
      -1.2684380046 * lms.x + 2.6097574011 * lms.y -
          0.3413193965 * lms.z,
      -0.0041960863 * lms.x - 0.7034186147 * lms.y +
          1.7076147010 * lms.z);
}

vec3 srgbToOklab(vec3 rgb) {
  return linearToOklab(srgbToLinear(clamp(rgb, 0.0, 1.0)));
}

vec3 oklabToSrgb(vec3 lab) {
  return clamp(linearToSrgb(oklabToLinear(lab)), 0.0, 1.0);
}

float hash12(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ============================================================
// 柯西衰减涡流旋转算子 (不可压缩流体涡旋场 Divergence-Free Swirl)
// ============================================================
vec2 applyVortex(vec2 p, vec2 center, float radius, float strength) {
  vec2 delta = p - center;
  float dist_sq = dot(delta, delta);
  float r_sq = radius * radius;
  float angle = strength / (1.0 + dist_sq / (r_sq * 0.45));
  float s = sin(angle);
  float c = cos(angle);
  mat2 rot = mat2(c, s, -s, c);
  return center + rot * delta;
}

// 高保真分析型大尺度高斯势能核
float liquidBlob(vec2 p, vec2 center, float radius) {
  vec2 delta = p - center;
  float d2 = dot(delta, delta);
  float r2 = radius * radius;
  return exp(-d2 / (2.0 * r2));
}

vec3 colorLab(vec4 color) {
  return srgbToOklab(color.rgb);
}

// Oklch 色度守恒与互补色桥接合成：
// 彻底解决红+青、蓝+橙等互补色在 Oklab 笛卡尔空间线性平均时 (a, b) 正负抵消退化为灰绿/暗褐泥色的问题
vec3 preserveChromaMix(vec3 mixedLab, float targetChroma, vec2 fallbackDir) {
  float actualChroma = length(mixedLab.yz);
  if (targetChroma <= 0.008) {
    return mixedLab;
  }
  vec2 dir = actualChroma > 0.006
      ? (mixedLab.yz / actualChroma)
      : normalize(fallbackDir + vec2(0.0001, -0.0001));
  // 当两股互补色流交汇导致笛卡尔色度下降时，补偿 74% 的感知色度，使交界处呈现通透宝石过渡色而非脏灰
  float restoredChroma = mix(actualChroma, targetChroma, 0.74);
  return vec3(mixedLab.x, dir * restoredChroma);
}

float dither(vec2 p) {
  float first = hash12(p);
  float second = hash12(p + vec2(17.0, 29.0));
  return (first + second - 1.0) * (0.65 / 255.0);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / u_size;
  float aspect = max(u_size.x / max(u_size.y, 1.0), 0.1);
  vec2 p = vec2(uv.x * aspect, uv.y);

  float time = u_time * 0.62;

  vec2 p1 = vec2(u_point_1.x * aspect, u_point_1.y);
  vec2 p2 = vec2(u_point_2.x * aspect, u_point_2.y);
  vec2 p3 = vec2(u_point_3.x * aspect, u_point_3.y);
  vec2 p4 = vec2(u_point_4.x * aspect, u_point_4.y);
  vec2 p5 = vec2(u_point_5.x * aspect, u_point_5.y);

  // ── 阶段 1：构建多中心游走流体涡流场 (Multi-Vortex Coordinate Warping) ──
  vec2 vCenter1 = vec2(
    (0.38 + 0.22 * cos(time * 0.45)) * aspect,
    0.52 + 0.20 * sin(time * 0.38)
  );
  vec2 vCenter2 = vec2(
    (0.66 + 0.20 * sin(time * 0.50 + 1.2)) * aspect,
    0.40 + 0.22 * cos(time * 0.42 + 0.8)
  );
  vec2 vCenter3 = vec2(
    (0.50 + 0.24 * cos(time * 0.55 + 2.4)) * aspect,
    0.72 + 0.18 * sin(time * 0.48 + 1.6)
  );

  float twistScale = u_warp_strength;

  // ── 阶段 2：双层反向流体坐标场构建 ──
  vec2 coordA = p;
  coordA = applyVortex(coordA, vCenter1, 0.46, 2.6 * twistScale);
  coordA = applyVortex(coordA, vCenter2, 0.38, -2.1 * twistScale);

  vec2 coordB = p;
  coordB = applyVortex(coordB, vCenter2, 0.42, 2.3 * twistScale);
  coordB = applyVortex(coordB, vCenter3, 0.36, -1.9 * twistScale);

  // ── 阶段 3：7 组独立动态液态色核 (Liquid Color Blobs) ──
  vec2 drift1 = vec2(cos(time * 0.55), sin(time * 0.45)) * 0.08;
  vec2 drift2 = vec2(sin(time * 0.50 + 1.4), cos(time * 0.38 + 0.9)) * 0.07;
  vec2 drift3 = vec2(cos(time * 0.42 + 2.8), sin(time * 0.52 + 0.5)) * 0.09;

  float scale = max(u_blob_scale, 0.75);

  float a1 = liquidBlob(coordA, p1 + drift1, 0.52 * scale);
  float a2 = liquidBlob(coordA, p2 - drift2, 0.48 * scale);
  float a3 = liquidBlob(coordA, p3 + drift3, 0.48 * scale);
  float a4 = liquidBlob(coordA, p4 - drift1, 0.58 * scale);
  float a5 = liquidBlob(coordA, p5 + drift2, 0.40 * scale);
  float a6 = liquidBlob(coordA, p3 + vec2(0.18, -0.16) + drift1, 0.30 * scale) * 0.90;
  float a7 = liquidBlob(coordA, p2 + vec2(-0.18, 0.16) - drift3, 0.28 * scale) * 0.86;

  // 强化各色块核心区域的主导权（指数 2.4），避免所有颜色在全屏均质化混成一团
  a1 = pow(a1, 2.4);
  a2 = pow(a2, 2.4);
  a3 = pow(a3, 2.4);
  a4 = pow(a4, 1.9);
  a5 = pow(a5, 2.5);
  a6 = pow(a6, 2.3);
  a7 = pow(a7, 2.3);

  float b1 = pow(liquidBlob(coordB, p1 - drift2, 0.48 * scale), 2.4);
  float b2 = pow(liquidBlob(coordB, p2 + drift3, 0.46 * scale), 2.4);
  float b3 = pow(liquidBlob(coordB, p3 - drift1, 0.50 * scale), 2.4);
  float b4 = pow(liquidBlob(coordB, p4 + drift2, 0.56 * scale), 1.9);
  float b5 = pow(liquidBlob(coordB, p5 - drift3, 0.38 * scale), 2.5);

  // ── 阶段 4：在 Oklab/Oklch 空间进行色度守恒流体融合 ──
  vec3 lab1 = colorLab(u_color_1);
  vec3 lab2 = colorLab(u_color_2);
  vec3 lab3 = colorLab(u_color_3);
  vec3 lab4 = colorLab(u_color_4);
  vec3 lab5 = colorLab(u_color_5);

  float c1 = length(lab1.yz);
  float c2 = length(lab2.yz);
  float c3 = length(lab3.yz);
  float c4 = length(lab4.yz);
  float c5 = length(lab5.yz);

  float totalA = a1 + a2 + a3 + a4 + a5 + a6 + a7 + 0.0001;
  float totalB = b1 + b2 + b3 + b4 + b5 + 0.0001;

  vec3 blendA = (
    lab1 * a1 +
    lab2 * a2 +
    lab3 * a3 +
    lab4 * a4 +
    lab5 * a5 +
    lab3 * a6 +
    lab2 * a7
  ) / totalA;
  float targetChromaA = (
    c1 * a1 + c2 * a2 + c3 * (a3 + a6) + c4 * a4 + c5 * a5 + c2 * a7
  ) / totalA;

  vec3 blendB = (
    lab1 * b1 +
    lab2 * b2 +
    lab3 * b3 +
    lab4 * b4 +
    lab5 * b5
  ) / totalB;
  float targetChromaB = (
    c1 * b1 + c2 * b2 + c3 * b3 + c4 * b4 + c5 * b5
  ) / totalB;

  // 当互补色交汇时利用正交色桥方向保留纯净色度
  vec2 bridgeDir = vec2(-lab1.z + lab3.y, lab1.y + lab3.z);
  blendA = preserveChromaMix(blendA, targetChromaA, bridgeDir);
  blendB = preserveChromaMix(blendB, targetChromaB, -bridgeDir);

  float layerMixFactor = clamp(u_layer_mix * 0.72 + 0.16 * sin(time * 0.35), 0.18, 0.68);
  vec3 blended = mix(blendA, blendB, layerMixFactor);
  float targetChroma = mix(targetChromaA, targetChromaB, layerMixFactor);
  blended = preserveChromaMix(blended, targetChroma, bridgeDir);

  // ── 阶段 5：明暗模式沉浸合成 ──
  vec3 base = srgbToOklab(u_base_color.rgb);

  // 暗色模式：保留深邃丝绒暗谷，同时让流彩主色带通透鲜明
  float blobEnergy = mix(totalA, totalB, layerMixFactor);
  float fluidEnergy = smoothstep(0.18, 1.75, blobEnergy);
  float darkIntensity = mix(0.42, 0.90, fluidEnergy) * clamp(u_blend_intensity, 0.0, 1.0);
  vec3 darkOutputLab = mix(base, blended, darkIntensity);
  darkOutputLab = preserveChromaMix(
    darkOutputLab,
    mix(length(base.yz), length(blended.yz), darkIntensity),
    bridgeDir
  );
  float maxDarkLum = min(u_luminance_limit, 0.54);
  darkOutputLab.x = min(darkOutputLab.x, maxDarkLum);

  // 明亮模式：水彩晕染质感，保留饱满色度，与 135° 哑光纸白底座自然浸润
  vec3 lightPastel = blended;
  lightPastel.x = clamp(lightPastel.x * 0.88 + 0.09, 0.65, 0.86);
  lightPastel.yz *= 0.94;
  float lightIntensity = clamp(u_blend_intensity * 0.60, 0.36, 0.70);
  vec3 lightOutputLab = mix(base, lightPastel, lightIntensity);
  lightOutputLab.x = clamp(lightOutputLab.x, 0.72, 0.92);

  float darkFactor = clamp(u_is_dark, 0.0, 1.0);
  vec3 outputLab = mix(lightOutputLab, darkOutputLab, darkFactor);

  vec3 rgb = oklabToSrgb(outputLab);
  rgb = clamp(rgb + vec3(dither(frag)), 0.0, 1.0);
  frag_color = vec4(rgb, 1.0);
}
