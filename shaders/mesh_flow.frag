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
// 产生像彩色墨水在水中旋转拉伸的螺旋流体涡纹，绝无拉丝褶皱
// ============================================================
vec2 applyVortex(vec2 p, vec2 center, float radius, float strength) {
  vec2 delta = p - center;
  float dist_sq = dot(delta, delta);
  float r_sq = radius * radius;
  // 柯西型衰减：中心旋转角速度最大，向外自然平滑递减至 0
  float angle = strength / (1.0 + dist_sq / (r_sq * 0.45));
  float s = sin(angle);
  float c = cos(angle);
  // GLSL 列优先 2D 旋转矩阵
  mat2 rot = mat2(c, s, -s, c);
  return center + rot * delta;
}

// 高保真分析型大尺度高斯势能核（带核心保真度）
float liquidBlob(vec2 p, vec2 center, float radius) {
  vec2 delta = p - center;
  float d2 = dot(delta, delta);
  float r2 = radius * radius;
  // 连续光滑高斯衰减
  return exp(-d2 / (2.0 * r2));
}

vec3 colorLab(vec4 color) {
  return srgbToOklab(color.rgb);
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
  
  // 真实流体时间流速 (8~14 秒为一个大周期，每秒清晰呈现彩色墨水旋转拉伸)
  float time = u_time * 0.65;

  // 映射 5 个核心提取色锚点到宽高比坐标空间
  vec2 p1 = vec2(u_point_1.x * aspect, u_point_1.y);
  vec2 p2 = vec2(u_point_2.x * aspect, u_point_2.y);
  vec2 p3 = vec2(u_point_3.x * aspect, u_point_3.y);
  vec2 p4 = vec2(u_point_4.x * aspect, u_point_4.y);
  vec2 p5 = vec2(u_point_5.x * aspect, u_point_5.y);

  // ── 阶段 1：构建多中心游走流体涡流场 (Multi-Vortex Coordinate Warping) ──
  // 涡流中心 1 (顺时针主漩涡 - 左下偏中): 精致局部卷起主色与次主色
  vec2 vCenter1 = vec2(
    (0.40 + 0.22 * cos(time * 0.45)) * aspect,
    0.55 + 0.20 * sin(time * 0.38)
  );
  // 涡流中心 2 (逆时针精致漩涡 - 右上方): 局部拉伸并向上卷曲强调色（如亮红/紫红）
  vec2 vCenter2 = vec2(
    (0.65 + 0.20 * sin(time * 0.50 + 1.2)) * aspect,
    0.42 + 0.22 * cos(time * 0.42 + 0.8)
  );
  // 涡流中心 3 (对冲局部微涡流 - 右下方): 引导环境色与高光对冲渗透
  vec2 vCenter3 = vec2(
    (0.50 + 0.25 * cos(time * 0.55 + 2.4)) * aspect,
    0.72 + 0.18 * sin(time * 0.48 + 1.6)
  );

  float twistScale = u_warp_strength;

  // ── 阶段 2：双层反向流体坐标场构建 (Layer A 顺流 + Layer B 逆流) ──
  // 缩小涡流影响半径至 0.35 ~ 0.45，使漩涡呈现局部精致翻滚，杜绝全屏大面积拖扯
  vec2 coordA = p;
  coordA = applyVortex(coordA, vCenter1, 0.45, 2.8 * twistScale);
  coordA = applyVortex(coordA, vCenter2, 0.38, -2.2 * twistScale);

  // Layer B: 逆时针反向穿插流动 (产生两层不同方向液体的相互渗透与包裹)
  vec2 coordB = p;
  coordB = applyVortex(coordB, vCenter2, 0.42, 2.5 * twistScale);
  coordB = applyVortex(coordB, vCenter3, 0.35, -2.0 * twistScale);

  // ── 阶段 3：打碎色彩为 7 组独立动态液态色核 (Liquid Color Blobs) ──
  // 动态飘移向量
  vec2 drift1 = vec2(cos(time * 0.55), sin(time * 0.45)) * 0.08;
  vec2 drift2 = vec2(sin(time * 0.50 + 1.4), cos(time * 0.38 + 0.9)) * 0.07;
  vec2 drift3 = vec2(cos(time * 0.42 + 2.8), sin(time * 0.52 + 0.5)) * 0.09;

  float scale = max(u_blob_scale, 0.75);

  // Layer A 色块势能 (保持各自鲜明色块，非均质化平均)
  // 色块 1: 主导色 Primary (左侧核心)
  float a1 = liquidBlob(coordA, p1 + drift1, 0.50 * scale);
  // 色块 2: 次主色 Secondary (右上/左下天蓝、青蓝)
  float a2 = liquidBlob(coordA, p2 - drift2, 0.46 * scale);
  // 色块 3: 强调色 Accent (右侧鲜艳玫红、亮红，强对冲)
  float a3 = liquidBlob(coordA, p3 + drift3, 0.48 * scale);
  // 色块 4: 柔和底色 Muted (大面积铺底)
  float a4 = liquidBlob(coordA, p4 - drift1, 0.60 * scale);
  // 色块 5: 高光点缀 Highlight (中央流光核心)
  float a5 = liquidBlob(coordA, p5 + drift2, 0.38 * scale);
  // 色块 6 (打碎伴生色): 围绕强调色顺时针卷曲的液滴
  float a6 = liquidBlob(coordA, p3 + vec2(0.20, -0.18) + drift1, 0.28 * scale) * 0.88;
  // 色块 7 (打碎伴生色): 围绕次主色逆时针扩散的液滴
  float a7 = liquidBlob(coordA, p2 + vec2(-0.18, 0.16) - drift3, 0.26 * scale) * 0.82;

  // 提升权重指数至 2.0 强化对比度，使各色块在核心区颜色更加鲜明、边界清晰
  a1 = pow(a1, 2.0);
  a2 = pow(a2, 2.0);
  a3 = pow(a3, 2.0);
  a4 = pow(a4, 1.8);
  a5 = pow(a5, 2.2);
  a6 = pow(a6, 2.0);
  a7 = pow(a7, 2.0);

  // Layer B 反向层色块势能
  float b1 = pow(liquidBlob(coordB, p1 - drift2, 0.48 * scale), 2.0);
  float b2 = pow(liquidBlob(coordB, p2 + drift3, 0.44 * scale), 2.0);
  float b3 = pow(liquidBlob(coordB, p3 - drift1, 0.50 * scale), 2.0);
  float b4 = pow(liquidBlob(coordB, p4 + drift2, 0.58 * scale), 1.8);
  float b5 = pow(liquidBlob(coordB, p5 - drift3, 0.36 * scale), 2.2);

  // ── 阶段 4：在 Oklab 均匀感知色彩空间进行高保真流体加权融合 ──
  vec3 lab1 = colorLab(u_color_1);
  vec3 lab2 = colorLab(u_color_2);
  vec3 lab3 = colorLab(u_color_3);
  vec3 lab4 = colorLab(u_color_4);
  vec3 lab5 = colorLab(u_color_5);

  float totalA = a1 + a2 + a3 + a4 + a5 + a6 + a7 + 0.0001;
  float totalB = b1 + b2 + b3 + b4 + b5 + 0.0001;

  vec3 blendA = (
    lab1 * a1 +
    lab2 * a2 +
    lab3 * a3 +
    lab4 * a4 +
    lab5 * a5 +
    lab3 * a6 + // 伴生色 6 强化强调色（如亮红）
    lab2 * a7   // 伴生色 7 强化次主色（如青蓝）
  ) / totalA;

  vec3 blendB = (
    lab1 * b1 +
    lab2 * b2 +
    lab3 * b3 +
    lab4 * b4 +
    lab5 * b5
  ) / totalB;

  // 双层反向流动混合（随着时间缓缓呼吸交替主导）
  float layerMixFactor = clamp(u_layer_mix + 0.15 * sin(time * 0.35), 0.20, 0.80);
  vec3 blended = mix(blendA, blendB, layerMixFactor);

  // ── 阶段 5：明暗模式沉浸合成（支持 0.0 ~ 1.0 连续平滑渐变融化） ──
  vec3 base = srgbToOklab(u_base_color.rgb);

  // 暗色模式：保留深邃沉浸底色，流体光斑柔和绚烂但不眩目过曝
  float darkIntensity = clamp(u_blend_intensity * 0.58, 0.35, 0.68);
  vec3 darkOutputLab = mix(base, blended, darkIntensity);
  float maxDarkLum = min(u_luminance_limit, 0.42);
  if (darkOutputLab.x > maxDarkLum) {
    float lumScale = maxDarkLum / max(darkOutputLab.x, 0.001);
    darkOutputLab.yz *= clamp(lumScale, 0.65, 1.0);
    darkOutputLab.x = maxDarkLum;
  }

  // 明亮模式：水彩晕染质感，保留饱满色度，与 135° 哑光纸白底座自然浸润且杜绝死白
  vec3 lightPastel = blended;
  lightPastel.x = clamp(lightPastel.x * 0.88 + 0.09, 0.65, 0.86);
  lightPastel.yz *= 0.82;
  float lightIntensity = clamp(u_blend_intensity * 0.58, 0.35, 0.68);
  vec3 lightOutputLab = mix(base, lightPastel, lightIntensity);
  lightOutputLab.x = clamp(lightOutputLab.x, 0.72, 0.92);

  // 依据 u_is_dark (0.0 ~ 1.0) 进行全维度 Oklab 平滑插值，彻底消除生硬跳变
  float darkFactor = clamp(u_is_dark, 0.0, 1.0);
  vec3 outputLab = mix(lightOutputLab, darkOutputLab, darkFactor);

  // 转回 sRGB 并施加 TPDF 抖动消除渐变断层
  vec3 rgb = oklabToSrgb(outputLab);
  rgb = clamp(rgb + vec3(dither(frag)), 0.0, 1.0);
  frag_color = vec4(rgb, 1.0);
}
