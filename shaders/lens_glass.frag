#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time;

// 动态取色注入的氛围染色 (低饱和度)
uniform vec4 u_tint_color;

// 参数控制
uniform float u_is_dark;              // 1.0 暗色黑曜琉璃, 0.0 明亮高透冰晶
uniform float u_refraction_strength;  // 折射强度

out vec4 frag_color;

// 凸透镜高度场模型（中心平缓，四周边缘向上凸起弧度）
float getLensHeight(vec2 uv) {
  vec2 d = abs(uv - 0.5) * 2.0;
  float edge_dist = max(d.x, d.y);
  // 四周边缘平滑隆起形成凸透镜边缘
  return smoothstep(0.65, 1.0, edge_dist);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  float aspect = u_size.x / u_size.y;

  // 1. 计算凸透镜表面法线
  float eps = 0.004;
  float h_center = getLensHeight(uv);
  float h_right  = getLensHeight(uv + vec2(eps, 0.0));
  float h_down   = getLensHeight(uv + vec2(0.0, eps));

  vec2 normal_2d = vec2(h_right - h_center, h_down - h_center) / eps;
  vec3 normal = normalize(vec3(normal_2d * u_refraction_strength * 2.0, 1.0));

  // 2. 玻璃基础底色与明暗分层
  vec4 glass_base;
  if (u_is_dark > 0.5) {
    // 暗色模式：暗调深空黑曜冰晶 (Translucent Obsidian Glass)
    glass_base = mix(
      vec4(0.04, 0.07, 0.12, 1.0),
      u_tint_color,
      0.18
    );
  } else {
    // 明亮模式：高透晨曦冰晶琉璃 (High Translucency Clear Glass)
    glass_base = mix(
      vec4(0.94, 0.96, 0.98, 1.0),
      u_tint_color,
      0.14
    );
  }

  // 3. 对角线动态流光高光 (Dynamic Caustic Sheen)
  float sheen_pos = fract(u_time * 0.04);
  float diag = (uv.x + uv.y * 0.8) * 0.5;
  float dist_to_sheen = abs(diag - sheen_pos);
  float sheen_band = (1.0 - smoothstep(0.0, 0.22, dist_to_sheen)) * 0.25;

  // 4. 边缘菲涅尔高光与折射光晕 (Fresnel Rim Lighting)
  vec3 view_dir = vec3(0.0, 0.0, 1.0);
  float fresnel = pow(1.0 - max(dot(normal, view_dir), 0.0), 3.0);

  vec4 highlight_color = (u_is_dark > 0.5)
      ? vec4(0.65, 0.82, 1.0, 1.0)
      : vec4(1.0, 1.0, 1.0, 1.0);

  vec4 final_color = glass_base +
                     highlight_color * (fresnel * 0.35 + sheen_band);

  frag_color = clamp(final_color, 0.0, 1.0);
}
