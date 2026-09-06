#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time;

// 动态取色注入的氛围主色 (低饱和度优雅极浅淡微染色 10%~14%)
uniform vec4 u_tint_color;

// 参数控制
uniform float u_is_dark;              // 1.0 暗色黑曜冰晶, 0.0 明亮晨曦水晶 (支持 0~1 连续平滑插值)
uniform float u_refraction_strength;  // 折射强度

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec2 centered = (uv - 0.5) * 2.0;
  float darkFactor = clamp(u_is_dark, 0.0, 1.0);

  // 1. 纯净均匀的 50%~60% 半透明透光基底 (彻底去除四周生硬边框与突兀暗角，浑然一体)
  float darkAlpha  = 0.58; // 暗色模式透明度约 58% (透光清晰，文字锐利)
  float lightAlpha = 0.50; // 日间模式透明度约 50% (通透自然，黑色文字高对比度)
  float baseAlpha  = mix(lightAlpha, darkAlpha, darkFactor);

  // 2. 极浅淡纯净晶体有色玻璃基底 (10%~12% 极弱微染色，绝不发脏发灰)
  // 暗色黑曜晶体底色
  vec3 darkCore = vec3(0.040, 0.055, 0.075);
  vec3 darkBase = mix(darkCore, u_tint_color.rgb, 0.12);

  // 明亮晨曦水晶底色
  vec3 lightCore = vec3(0.955, 0.968, 0.985);
  vec3 lightBase = mix(lightCore, u_tint_color.rgb, 0.08);

  vec3 glassBase = mix(lightBase, darkBase, darkFactor);

  // 3. 顶部环境天光温润微晕 (Top Ambient Glaze - 赋予玻璃微弧面物理厚度，无生硬边界)
  float topGlaze = smoothstep(0.8, -0.6, centered.y) * (darkFactor > 0.5 ? 0.035 : 0.020);

  // 4. 次表面慢速光通量微波 (Subsurface Caustic Luster - 赋予玻璃内部晶莹深邃质感)
  float wave = sin((uv.x * 2.0 + uv.y * 1.5) + u_time * 0.12) * 0.5 + 0.5;
  vec3 subsurfaceLuster = u_tint_color.rgb * wave * (darkFactor > 0.5 ? 0.030 : 0.015);

  // 5. 极其平缓的全局微光倾角 (左上至右下自然透光)
  float subtleSheen = (centered.x * 0.2 - centered.y * 0.3) * (darkFactor > 0.5 ? 0.012 : 0.008);

  // 6. 极细微高频随机抖动 (Dither - 消除 8-bit 色阶断层，赋予微晶质感)
  float n = fract(sin(dot(uv * u_size, vec2(12.9898, 78.233))) * 43758.5453);
  float dither = (n - 0.5) * (0.4 / 255.0);

  vec3 finalRgb = glassBase + vec3(topGlaze) + subsurfaceLuster + vec3(subtleSheen) + dither;
  float finalAlpha = clamp(baseAlpha + topGlaze * 0.2, 0.0, 0.75);

  frag_color = vec4(clamp(finalRgb, 0.0, 1.0), finalAlpha);
}
