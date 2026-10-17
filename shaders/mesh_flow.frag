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
// Apple Music 级大尺度柔焦有机流场扭曲算子 (Ultra-Smooth Silk Domain Warp)
// 采用大半径 (0.80~0.95)、低扭角 (< 0.65 rad) 与低频谐波流场，
// 让巨型高斯色云呈现丝绸般缓慢舒展的液态光晕，彻底杜绝尖锐漩涡钩子与撕裂感
// ============================================================
vec2 gentleSwirl(vec2 p, vec2 center, float radius, float strength) {
  vec2 delta = p - center;
  float distSq = dot(delta, delta);
  float rSq = radius * radius;
  float angle = strength * exp(-distSq / (2.0 * rSq));
  float s = sin(angle);
  float c = cos(angle);
  return center + mat2(c, s, -s, c) * delta;
}

vec2 organicSilkWarp(vec2 p, float aspect, float t, float strength) {
  vec2 c1 = vec2((0.36 + 0.18 * cos(t * 0.32)) * aspect, 0.44 + 0.16 * sin(t * 0.28));
  vec2 c2 = vec2((0.66 + 0.18 * sin(t * 0.30 + 1.6)) * aspect, 0.58 + 0.16 * cos(t * 0.26 + 0.9));

  vec2 q = gentleSwirl(p, c1, 0.86, 0.52 * strength);
  q = gentleSwirl(q, c2, 0.82, -0.46 * strength);

  // 低频无散度有机谐波呼吸（模拟流体光斑边沿的自然漫溢）
  vec2 wave = vec2(
    sin(q.y * 2.1 + t * 0.42) * cos(q.x * 1.6 - t * 0.34),
    cos(q.x * 2.0 - t * 0.38) * sin(q.y * 1.7 + t * 0.31)
  );
  return q + wave * (0.048 * strength);
}

// Apple Music 巨型柔焦椭球流体光斑核 (Anisotropic Rotating Gaussian Light Cloud)
// 每个光斑具备独立的长短轴呼吸比与缓慢自转角，相互交叠时产生如流体透镜般的柔滑融化感
float fluidLightCloud(vec2 p, vec2 center, vec2 radii, float angle) {
  vec2 d = p - center;
  float c = cos(angle);
  float s = sin(angle);
  vec2 rotD = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
  vec2 q = rotD / max(radii, vec2(0.10));
  float r2 = dot(q, q);
  return pow(exp(-0.5 * r2), 1.28);
}

float dither(vec2 p) {
  float first = hash12(p);
  float second = hash12(p + vec2(17.0, 29.0));
  return (first + second - 1.0) * (0.65 / 255.0);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / max(u_size, vec2(1.0));
  float aspect = max(u_size.x / max(u_size.y, 1.0), 0.1);
  vec2 p = vec2(uv.x * aspect, uv.y);

  // Apple Music 标志性的静谧呼吸流速（约 20~28 秒完成一次完整流转）
  float time = u_time * 0.32;

  vec2 p1 = vec2(u_point_1.x * aspect, u_point_1.y);
  vec2 p2 = vec2(u_point_2.x * aspect, u_point_2.y);
  vec2 p3 = vec2(u_point_3.x * aspect, u_point_3.y);
  vec2 p4 = vec2(u_point_4.x * aspect, u_point_4.y);
  vec2 p5 = vec2(u_point_5.x * aspect, u_point_5.y);

  float warpAmt = clamp(u_warp_strength, 0.5, 1.6);
  float scale = max(u_blob_scale, 0.80);

  // ── 阶段 1：构建双层丝绸般平滑的有机流场坐标 (无穷阶可导 C^∞，绝无撕裂或折痕) ──
  vec2 coordA = organicSilkWarp(p, aspect, time, warpAmt * 0.85);
  vec2 coordB = organicSilkWarp(p, aspect, -time * 0.82 + 2.4, warpAmt * 0.75);

  // ── 阶段 2：生成 6 团缓慢自转与呼吸的巨型椭球流体光斑 (Apple Music Fluid Light Clouds) ──
  // 呼吸因子：让各光斑在漫游中呈现自然的扩张与收缩
  float breathe1 = 1.0 + 0.10 * sin(time * 0.55);
  float breathe2 = 1.0 + 0.10 * cos(time * 0.48 + 1.3);
  float breathe3 = 1.0 + 0.12 * sin(time * 0.62 + 2.5);

  // Layer A：主光斑层（大半径柔焦浸润，覆盖全屏并保留自然明暗纵深）
  float a1 = fluidLightCloud(
    coordA,
    p1,
    vec2(0.76, 0.56) * scale * breathe1,
    time * 0.22 + 0.3
  );
  float a2 = fluidLightCloud(
    coordA,
    p2,
    vec2(0.74, 0.54) * scale * breathe2,
    -time * 0.20 + 1.1
  );
  float a3 = fluidLightCloud(
    coordA,
    p3,
    vec2(0.68, 0.48) * scale * breathe3,
    time * 0.26 - 0.5
  );
  float a4 = fluidLightCloud(
    coordA,
    p4,
    vec2(0.82, 0.62) * scale,
    -time * 0.16 + 0.8
  );
  float a5 = fluidLightCloud(
    coordA,
    p5,
    vec2(0.62, 0.46) * scale * breathe1,
    time * 0.28 + 1.9
  );
  // 第 6 团伴生极光云：连接强调色与次主色的斜向柔光带，赋予画面如极光漫染般的丝滑张力
  vec2 bridgeCenter = mix(p2, p3, 0.5 + 0.18 * sin(time * 0.40));
  float a6 = fluidLightCloud(
    coordA,
    bridgeCenter,
    vec2(0.70, 0.42) * scale * breathe2,
    -0.35 + 0.20 * cos(time * 0.24)
  ) * 0.78;

  // Layer B：深层伴生呼吸光云（形成前后景流体视差与柔和穿插）
  float b1 = fluidLightCloud(coordB, p1, vec2(0.70, 0.54) * scale, -time * 0.18);
  float b2 = fluidLightCloud(coordB, p2, vec2(0.68, 0.52) * scale, time * 0.19 + 0.7);
  float b3 = fluidLightCloud(coordB, p3, vec2(0.64, 0.46) * scale, -time * 0.22 + 1.4);
  float b4 = fluidLightCloud(coordB, p4, vec2(0.78, 0.58) * scale, time * 0.15 + 2.1);
  float b5 = fluidLightCloud(coordB, p5, vec2(0.58, 0.44) * scale, -time * 0.24 + 0.4);

  // ── 阶段 3：连续无奇点 Oklab + 光学混合 (彻底根除零色度等高线断崖与硬边色带) ──
  vec3 rgb1 = clamp(u_color_1.rgb, 0.0, 1.0);
  vec3 rgb2 = clamp(u_color_2.rgb, 0.0, 1.0);
  vec3 rgb3 = clamp(u_color_3.rgb, 0.0, 1.0);
  vec3 rgb4 = clamp(u_color_4.rgb, 0.0, 1.0);
  vec3 rgb5 = clamp(u_color_5.rgb, 0.0, 1.0);

  vec3 lab1 = srgbToOklab(rgb1);
  vec3 lab2 = srgbToOklab(rgb2);
  vec3 lab3 = srgbToOklab(rgb3);
  vec3 lab4 = srgbToOklab(rgb4);
  vec3 lab5 = srgbToOklab(rgb5);

  float totalA = a1 + a2 + a3 + a4 + a5 + a6 + 0.0001;
  float totalB = b1 + b2 + b3 + b4 + b5 + 0.0001;

  vec3 labBridge = mix(lab2, lab3, 0.5);
  vec3 rgbBridge = mix(rgb2, rgb3, 0.5);

  vec3 blendLabA = (
    lab1 * a1 +
    lab2 * a2 +
    lab3 * a3 +
    lab4 * a4 +
    lab5 * a5 +
    labBridge * a6
  ) / totalA;

  vec3 blendRgbA = (
    rgb1 * a1 +
    rgb2 * a2 +
    rgb3 * a3 +
    rgb4 * a4 +
    rgb5 * a5 +
    rgbBridge * a6
  ) / totalA;

  vec3 blendLabB = (
    lab1 * b1 +
    lab2 * b2 +
    lab3 * b3 +
    lab4 * b4 +
    lab5 * b5
  ) / totalB;

  vec3 blendRgbB = (
    rgb1 * b1 +
    rgb2 * b2 +
    rgb3 * b3 +
    rgb4 * b4 +
    rgb5 * b5
  ) / totalB;

  float layerMixFactor = clamp(u_layer_mix * 0.65 + 0.14 * sin(time * 0.36), 0.20, 0.62);
  vec3 mixedLab = mix(blendLabA, blendLabB, layerMixFactor);
  vec3 mixedRgb = mix(blendRgbA, blendRgbB, layerMixFactor);

  // 混合 Oklab 感知均匀插值与 sRGB 舞台灯光叠加，使跨色相交界区既丝滑无痕又温润通透
  vec3 opticalLab = srgbToOklab(mixedRgb);
  vec3 blended = mix(mixedLab, opticalLab, 0.34);

  // 连续可导色度保真增益（直接对 (a, b) 向量乘平滑标量 1.0~1.22，在零点处完全连续，绝不产生任何硬边）
  float meanChroma = (
    length(lab1.yz) * a1 +
    length(lab2.yz) * a2 +
    length(lab3.yz) * a3 +
    length(lab4.yz) * a4 +
    length(lab5.yz) * a5 +
    length(labBridge.yz) * a6
  ) / totalA;
  float curChroma = length(blended.yz);
  float chromaLoss = clamp((meanChroma - curChroma) / max(meanChroma, 0.035), 0.0, 1.0);
  blended.yz *= 1.0 + 0.24 * chromaLoss;

  // ── 阶段 4：明暗模式沉浸式光影合成 ──
  vec3 base = srgbToOklab(u_base_color.rgb);

  // 暗色模式：营造 Apple Music 般“深邃丝绒底幕 + 悬浮呼吸流体光云”的立体层次
  float blobEnergy = mix(totalA, totalB, layerMixFactor);
  float fluidGlow = smoothstep(0.22, 1.85, blobEnergy);
  float darkIntensity = mix(0.46, 0.90, fluidGlow) * clamp(u_blend_intensity, 0.0, 1.0);
  vec3 darkOutputLab = mix(base, blended, darkIntensity);
  float maxDarkLum = min(u_luminance_limit, 0.54);
  darkOutputLab.x = min(darkOutputLab.x, maxDarkLum);

  // 明亮模式：高明度水彩流体光晕，通透温润
  vec3 lightPastel = blended;
  lightPastel.x = clamp(lightPastel.x * 0.88 + 0.09, 0.65, 0.86);
  lightPastel.yz *= 0.93;
  float lightIntensity = clamp(u_blend_intensity * 0.60, 0.36, 0.68);
  vec3 lightOutputLab = mix(base, lightPastel, lightIntensity);
  lightOutputLab.x = clamp(lightOutputLab.x, 0.72, 0.92);

  float darkFactor = clamp(u_is_dark, 0.0, 1.0);
  vec3 outputLab = mix(lightOutputLab, darkOutputLab, darkFactor);

  vec3 rgb = oklabToSrgb(outputLab);
  rgb = clamp(rgb + vec3(dither(frag)), 0.0, 1.0);
  frag_color = vec4(rgb, 1.0);
}
