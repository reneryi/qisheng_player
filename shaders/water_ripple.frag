#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time;

// 鼠标交互输入
uniform vec2 u_mouse_pos;       // 归一化鼠标位置 (0.0 ~ 1.0)
uniform float u_mouse_speed;     // 鼠标移动速度
uniform vec2 u_click_pos;        // 最近一次点击位置
uniform float u_click_time;      // 点击经过时间（秒）

// 音频低音共振能量 (0.0 ~ 1.0)
uniform float u_bass_energy;

// 水体底色与高光色
uniform vec4 u_water_deep;
uniform vec4 u_water_shallow;
uniform vec4 u_specular_color;

out vec4 frag_color;

// 2D 简单正弦水波函数
float getWaveHeight(vec2 uv, float aspect) {
  float height = 0.0;

  // 1. 鼠标滑行轨迹微澜
  vec2 mouse_delta = vec2((uv.x - u_mouse_pos.x) * aspect, uv.y - u_mouse_pos.y);
  float dist_to_mouse = length(mouse_delta);
  if (dist_to_mouse < 0.35 && u_mouse_speed > 0.01) {
    float trail_wave = sin(dist_to_mouse * 42.0 - u_time * 8.0);
    float trail_fade = (1.0 - smoothstep(0.0, 0.35, dist_to_mouse)) * clamp(u_mouse_speed * 1.5, 0.0, 1.0);
    height += trail_wave * trail_fade * 0.04;
  }

  // 2. 鼠标点击激荡扩散波（带阻尼衰减的正弦冲击波）
  if (u_click_time >= 0.0 && u_click_time < 3.0) {
    vec2 click_delta = vec2((uv.x - u_click_pos.x) * aspect, uv.y - u_click_pos.y);
    float dist_to_click = length(click_delta);
    float wave_front = u_click_time * 0.45; // 水波向外扩散速度
    float wave_dist = abs(dist_to_click - wave_front);
    if (wave_dist < 0.15) {
      float click_wave = sin(wave_dist * 50.0 - u_click_time * 12.0);
      float click_damping = exp(-u_click_time * 1.8) * (1.0 - smoothstep(0.0, 0.15, wave_dist));
      height += click_wave * click_damping * 0.08;
    }
  }

  // 3. 低音重击共振同心涟漪（从画面中心扩散）
  if (u_bass_energy > 0.05) {
    vec2 center_delta = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
    float dist_to_center = length(center_delta);
    float bass_wave = sin(dist_to_center * 32.0 - u_time * 6.0);
    float bass_fade = (1.0 - smoothstep(0.0, 0.8, dist_to_center)) * u_bass_energy;
    height += bass_wave * bass_fade * 0.035;
  }

  // 4. 水面微风环境微澜（低频平缓基础波动）
  float ambient_wave = sin(uv.x * 12.0 + u_time * 1.2) * cos(uv.y * 10.0 + u_time * 1.5) * 0.012;
  height += ambient_wave;

  return height;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  float aspect = u_size.x / u_size.y;

  // 使用有限差分法计算水面法线 (Normal Estimation via Finite Difference)
  float eps = 0.003;
  float h_center = getWaveHeight(uv, aspect);
  float h_right  = getWaveHeight(uv + vec2(eps, 0.0), aspect);
  float h_down   = getWaveHeight(uv + vec2(0.0, eps), aspect);

  vec3 normal = normalize(vec3(
    (h_center - h_right) / eps * 2.5,
    (h_center - h_down) / eps * 2.5,
    1.0
  ));

  // 光照模型：主光源方向与视线方向
  vec3 light_dir = normalize(vec3(-0.4, -0.6, 0.7));
  vec3 view_dir = vec3(0.0, 0.0, 1.0);

  // 漫反射与半球环境光
  float diffuse = max(dot(normal, light_dir), 0.0);
  vec4 water_color = mix(u_water_deep, u_water_shallow, clamp(h_center * 8.0 + 0.35 + diffuse * 0.25, 0.0, 1.0));

  // 菲涅尔高光镜面反射 (Blinn-Phong Specular)
  vec3 half_vector = normalize(light_dir + view_dir);
  float spec_angle = max(dot(normal, half_vector), 0.0);
  float specular = pow(spec_angle, 36.0) * 1.2;

  vec4 final_color = water_color + u_specular_color * specular;
  frag_color = clamp(final_color, 0.0, 1.0);
}
