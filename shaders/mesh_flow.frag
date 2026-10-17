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
// 无穷阶可导高斯流体旋涡算子 (C^∞ Divergence-Free Fluid Swirl)
// 采用连续高斯包络替代硬截断半径，既塑造出富有张力的流体旋转拉伸，又杜绝任何外圈等高线光环
// ============================================================
vec2 applyFluidSwirl(vec2 p, vec2 center, float radius, float strength) {
  vec2 delta = p - center;
  float distSq = dot(delta, delta);
  float rSq = radius * radius;
  float angle = strength * exp(-distSq / (2.0 * rSq));
  float s = sin(angle);
  float c = cos(angle);
  return center + mat2(c, s, -s, c) * delta;
}

// 自转椭球流体光斑核 (Anisotropic Rotating Fluid Light Spot)
// 赋予每个光斑独立的主次轴与自转角，在流场中呈现出如熔岩灯/Apple Music 聚光光斑般的液态形变
float ellipticalBlob(vec2 p, vec2 center, vec2 radii, float angle) {
  vec2 d = p - center;
  float c = cos(angle);
  float s = sin(angle);
  vec2 rotD = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
  vec2 q = rotD / max(radii, vec2(0.08));
  return exp(-0.5 * dot(q, q));
}

// 软膝双曲正切明度滚降 (Soft-Knee Luminance Roll-Off)
// 替代硬截断 min(L, limit)，彻底消除高亮光斑中心因平顶截断产生的马赫带亮圈
float softCapLuminance(float l, float limit) {
  float knee = limit * 0.58;
  if (l <= knee) return l;
  float span = max(limit - knee, 0.01);
  return knee + span * tanh((l - knee) / span);
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

  // 鲜明流畅的流体运动速度（每秒清晰呈现光斑旋转、拉伸与交融）
  float time = u_time * 0.78;

  vec2 p1 = vec2(u_point_1.x * aspect, u_point_1.y);
  vec2 p2 = vec2(u_point_2.x * aspect, u_point_2.y);
  vec2 p3 = vec2(u_point_3.x * aspect, u_point_3.y);
  vec2 p4 = vec2(u_point_4.x * aspect, u_point_4.y);
  vec2 p5 = vec2(u_point_5.x * aspect, u_point_5.y);

  float twistScale = clamp(u_warp_strength, 0.6, 1.6);
  float scale = max(u_blob_scale, 0.80);

  // ── 阶段 1：构建多中心游走流体漩涡与无散度波浪场 ──
  vec2 v1 = vec2(
    (0.36 + 0.22 * cos(time * 0.44)) * aspect,
    0.46 + 0.20 * sin(time * 0.36)
  );
  vec2 v2 = vec2(
    (0.64 + 0.22 * sin(time * 0.48 + 1.4)) * aspect,
    0.54 + 0.20 * cos(time * 0.40 + 0.9)
  );
  vec2 v3 = vec2(
    (0.50 + 0.24 * cos(time * 0.52 + 2.6)) * aspect,
    0.38 + 0.22 * sin(time * 0.46 + 1.8)
  );

  // 主流层 W：3 组动态呼吸高斯旋涡 + 谐波流体波浪
  vec2 wCoord = p;
  wCoord = applyFluidSwirl(wCoord, v1, 0.48, 1.60 * sin(time * 0.38 + 0.4) * twistScale);
  wCoord = applyFluidSwirl(wCoord, v2, 0.44, -1.50 * cos(time * 0.34 + 1.1) * twistScale);
  wCoord = applyFluidSwirl(wCoord, v3, 0.42, 1.30 * sin(time * 0.44 + 2.2) * twistScale);
  wCoord.x += 0.075 * sin(p.y * 3.1 + time * 0.65) * cos(p.x * 2.1 - time * 0.48) * twistScale;
  wCoord.y += 0.075 * cos(p.x * 2.7 - time * 0.58) * sin(p.y * 2.5 + time * 0.52) * twistScale;

  // 对冲伴生层 Q：反向穿插流场，产生双层彩色液体的相互包裹与渗透
  vec2 qCoord = p;
  qCoord = applyFluidSwirl(qCoord, v2, 0.46, 1.45 * cos(time * 0.36) * twistScale);
  qCoord = applyFluidSwirl(qCoord, v1, 0.44, -1.35 * sin(time * 0.40 + 0.8) * twistScale);
  qCoord.x -= 0.065 * cos(p.y * 2.7 - time * 0.52) * twistScale;
  qCoord.y += 0.065 * sin(p.x * 2.5 + time * 0.60) * twistScale;

  // ── 阶段 2：构建 7 团高辨识度、各自独立的自转流体光斑 (Fluid Light Spots) ──
  float w1 = ellipticalBlob(wCoord, p1, vec2(0.42, 0.30) * scale, time * 0.35);
  float w2 = ellipticalBlob(wCoord, p2, vec2(0.40, 0.28) * scale, -time * 0.30 + 1.1);
  float w3 = ellipticalBlob(wCoord, p3, vec2(0.38, 0.26) * scale, time * 0.42 - 0.6);
  float w4 = ellipticalBlob(qCoord, p4, vec2(0.42, 0.30) * scale, -time * 0.25 + 2.0);
  float w5 = ellipticalBlob(wCoord, p5, vec2(0.34, 0.24) * scale, time * 0.48 + 0.9);

  // 对角镜像伴生光斑 w6、w7：确保全屏四角与中心时刻有饱满鲜明的色彩光斑流转
  vec2 p6 = vec2((1.0 - u_point_2.x) * aspect, 1.0 - u_point_2.y);
  vec2 p7 = vec2((1.0 - u_point_3.x) * aspect, u_point_4.y);
  float w6 = ellipticalBlob(qCoord, p6, vec2(0.36, 0.25) * scale, time * 0.38 + 0.5) * 0.86;
  float w7 = ellipticalBlob(qCoord, p7, vec2(0.36, 0.25) * scale, -time * 0.36 + 1.7) * 0.86;

  // 适度凝聚光斑核心（指数 1.78），既让每个光斑边界清晰可辨、色彩纯粹，又杜绝阶跃亮圈
  w1 = pow(w1, 1.78);
  w2 = pow(w2, 1.78);
  w3 = pow(w3, 1.78);
  w4 = pow(w4, 1.70);
  w5 = pow(w5, 1.82);
  w6 = pow(w6, 1.78);
  w7 = pow(w7, 1.78);

  // ── 阶段 3：丝绒暗谷衬托 + 互补色深谷防脏灰合成 (Velvet Spotlight Synthesis) ──
  vec3 lab1 = srgbToOklab(u_color_1.rgb);
  vec3 lab2 = srgbToOklab(u_color_2.rgb);
  vec3 lab3 = srgbToOklab(u_color_3.rgb);
  vec3 lab4 = srgbToOklab(u_color_4.rgb);
  vec3 lab5 = srgbToOklab(u_color_5.rgb);
  vec3 base = srgbToOklab(u_base_color.rgb);

  // 深邃丝绒底幕（存在于各亮色光斑之间的间隙中，通过明暗对比衬托出立体流动的发光色斑）
  vec3 darkVelvet = mix(base, lab4, 0.45);
  darkVelvet.x = min(darkVelvet.x, 0.17);
  float wBg = 0.26 * (1.25 - clamp(u_layer_mix, 0.2, 0.8) * 0.4);

  float valleyW = w4 * 0.58 + wBg;
  float totalW = w1 + w2 + w3 + w5 + w6 + w7 + valleyW + 0.0001;

  vec3 blendLab = (
    lab1 * w1 +
    lab2 * (w2 + w6) +
    lab3 * (w3 + w7) +
    darkVelvet * valleyW +
    lab5 * w5
  ) / totalW;

  // 视觉心理物理学防灰机制：
  // 当两团互补色光斑（如暖金 + 深海蓝）在交界处相遇导致 (a, b) 色度相互抵消时，
  // 绝不保留高明度零色度的“脏灰烟雾”，而是将交界处平滑下沉为深邃丝绒暗谷，同时提振光斑核心纯度！
  float c1 = sqrt(dot(lab1.yz, lab1.yz) + 0.0004);
  float c2 = sqrt(dot(lab2.yz, lab2.yz) + 0.0004);
  float c3 = sqrt(dot(lab3.yz, lab3.yz) + 0.0004);
  float c4 = sqrt(dot(darkVelvet.yz, darkVelvet.yz) + 0.0004);
  float c5 = sqrt(dot(lab5.yz, lab5.yz) + 0.0004);

  float expectedChroma = (
    c1 * w1 +
    c2 * (w2 + w6) +
    c3 * (w3 + w7) +
    c4 * valleyW +
    c5 * w5
  ) / totalW;
  float actualChroma = sqrt(dot(blendLab.yz, blendLab.yz) + 0.0008);
  float cancellation = clamp((expectedChroma - actualChroma) / max(expectedChroma, 0.025), 0.0, 1.0);

  // 暗色模式：互补色交界处自然下沉为丝绒深谷，光斑内部饱满鲜亮
  vec3 darkOutputLab = blendLab;
  darkOutputLab.x *= (1.0 - 0.42 * cancellation);
  darkOutputLab.yz *= (1.0 + 0.30 * (1.0 - cancellation * 0.5));
  darkOutputLab = mix(base, darkOutputLab, clamp(u_blend_intensity, 0.0, 1.0));
  float maxDarkLum = min(u_luminance_limit, 0.54);
  darkOutputLab.x = softCapLuminance(darkOutputLab.x, maxDarkLum);

  // 明亮模式：清透水彩流体光斑，柔和融入哑光纸白底色
  vec3 lightVelvet = mix(base, lab4, 0.35);
  vec3 lightBlendLab = (
    lab1 * w1 +
    lab2 * (w2 + w6) +
    lab3 * (w3 + w7) +
    lightVelvet * valleyW +
    lab5 * w5
  ) / totalW;
  lightBlendLab.x = clamp(lightBlendLab.x * 0.88 + 0.10, 0.64, 0.86);
  lightBlendLab.yz *= (1.0 + 0.22 * (1.0 - cancellation * 0.5));
  float lightIntensity = clamp(u_blend_intensity * 0.64, 0.38, 0.72);
  vec3 lightOutputLab = mix(base, lightBlendLab, lightIntensity);
  lightOutputLab.x = clamp(lightOutputLab.x, 0.72, 0.92);

  float darkFactor = clamp(u_is_dark, 0.0, 1.0);
  vec3 outputLab = mix(lightOutputLab, darkOutputLab, darkFactor);

  vec3 rgb = oklabToSrgb(outputLab);
  rgb = clamp(rgb + vec3(dither(frag)), 0.0, 1.0);
  frag_color = vec4(rgb, 1.0);
}
