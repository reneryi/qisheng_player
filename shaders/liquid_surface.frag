#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time;
uniform vec4 u_primary;
uniform vec4 u_secondary;
uniform vec4 u_accent;
uniform vec4 u_primary_core;
uniform vec4 u_secondary_core;
uniform vec4 u_accent_core;
uniform vec2 u_center_1;
uniform vec2 u_center_2;
uniform vec2 u_center_3;
uniform vec2 u_opacity;
uniform float u_seed;

out vec4 frag_color;

float hash21(vec2 point) {
  point = fract(point * vec2(123.34, 456.21));
  point += dot(point, point + 45.32 + u_seed);
  return fract(point.x * point.y);
}

float value_noise(vec2 point) {
  vec2 cell = floor(point);
  vec2 local = fract(point);
  local = local * local * (3.0 - 2.0 * local);
  float a = hash21(cell);
  float b = hash21(cell + vec2(1.0, 0.0));
  float c = hash21(cell + vec2(0.0, 1.0));
  float d = hash21(cell + vec2(1.0, 1.0));
  return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 point) {
  float value = 0.0;
  float amplitude = 0.5;
  mat2 rotation = mat2(0.80, -0.60, 0.60, 0.80);
  for (int octave = 0; octave < 4; octave++) {
    value += value_noise(point) * amplitude;
    point = rotation * point * 2.03 + vec2(17.1, 9.2);
    amplitude *= 0.5;
  }
  return value;
}

vec2 domain_warp(vec2 point, float seed) {
  float time = u_time * 0.055;
  float x = fbm(point * 2.2 + vec2(seed * 7.1, time));
  float y = fbm(point * 2.0 + vec2(-time, seed * 9.7));
  vec2 first = vec2(x, y) - 0.5;
  float second = fbm(point * 3.6 + first * 1.8 + seed * 13.0);
  return first * 0.72 + vec2(second - 0.5) * 0.28;
}

vec2 field_strength(vec2 uv, vec2 center, float seed, vec2 radii) {
  vec2 delta = uv - center;
  delta.x *= u_size.x / max(u_size.y, 1.0);
  float angle = seed * 4.3 + sin(u_time * 0.031 + seed) * 0.34;
  mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
  delta = rotation * delta;
  vec2 warp = domain_warp(uv + center * 1.7, seed);
  vec2 deformed = delta / radii + warp * vec2(0.46, 0.34);
  float distance_to_dye = length(deformed);
  float edge_noise = fbm(uv * 5.1 + seed * 21.0 + u_time * 0.018);
  distance_to_dye += (edge_noise - 0.5) * 0.30;
  float outer = 1.0 - smoothstep(0.55, 1.18, distance_to_dye);
  float core = 1.0 - smoothstep(0.14, 0.58, distance_to_dye);
  return vec2(outer, core);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  vec2 dye_1 = field_strength(uv, u_center_1, 0.17, vec2(0.62, 0.50));
  vec2 dye_2 = field_strength(uv, u_center_2, 0.53, vec2(0.56, 0.54));
  vec2 dye_3 = field_strength(uv, u_center_3, 0.89, vec2(0.68, 0.46));

  vec3 base = mix(mix(u_primary.rgb, u_secondary.rgb, 0.24), u_accent.rgb, 0.10);
  vec3 outer_weights = vec3(dye_1.x, dye_2.x * 0.96, dye_3.x * 0.82);
  float outer_total = max(dot(outer_weights, vec3(1.0)), 0.0001);
  vec3 outer_color = (
    u_primary.rgb * outer_weights.x +
    u_secondary.rgb * outer_weights.y +
    u_accent.rgb * outer_weights.z
  ) / outer_total;
  float outer_amount = clamp(max(max(outer_weights.x, outer_weights.y), outer_weights.z) * u_opacity.x, 0.0, 0.72);
  vec3 color = mix(base, outer_color, outer_amount);

  vec3 core_weights = vec3(dye_1.y, dye_2.y * 0.96, dye_3.y * 0.62);
  float core_total = max(dot(core_weights, vec3(1.0)), 0.0001);
  vec3 core_color = (
    u_primary_core.rgb * core_weights.x +
    u_secondary_core.rgb * core_weights.y +
    u_accent_core.rgb * core_weights.z
  ) / core_total;
  float core_amount = clamp(max(max(core_weights.x, core_weights.y), core_weights.z) * u_opacity.y, 0.0, 0.64);
  color = mix(color, core_color, core_amount);

  frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
