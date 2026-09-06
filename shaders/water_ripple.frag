#version 320 es

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_time;
uniform float u_ripple_count; // 当前活跃波源数量 (0 ~ 16)

// 16 个独立波源的核心几何与时间数据：
// .x = origin.x (0.0 ~ 1.0)
// .y = origin.y (0.0 ~ 1.0)
// .z = birth_time (seconds)
// .w = amplitude (0.0 ~ 1.0)
uniform vec4 u_ripples[16];

// 16 个独立波源的物理运动与衰减参数：
// .x = wave_speed (扩散波速)
// .y = wave_frequency (空间角波数)
// .z = damping (时间衰减阻尼)
// .w = duration (最大持续时间)
uniform vec4 u_ripple_params[16];

// 独立雨天水体光学色彩
uniform vec4 u_water_deep;
uniform vec4 u_water_shallow;
uniform vec4 u_specular_color;
uniform vec4 u_sky_color;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  float aspect = u_size.x / u_size.y;

  float total_h = 0.0;
  vec2 total_grad = vec2(0.0);
  int count = int(clamp(u_ripple_count, 0.0, 16.0));

  // 1. 物理池塘水面高度场遍历 (Pond Surface Heightfield Simulation)
  for (int i = 0; i < 16; i++) {
    if (i >= count) break;

    vec4 rData = u_ripples[i];
    vec4 rParams = u_ripple_params[i];

    float birthTime = rData.z;
    float maxDuration = rParams.w;
    float dt = u_time - birthTime;

    if (dt <= 0.0 || dt > maxDuration) continue;

    float amplitude = rData.w;
    if (amplitude <= 0.0005) continue;

    float speed = rParams.x;
    float damping = rParams.z;

    vec2 delta = vec2((uv.x - rData.x) * aspect, uv.y - rData.y);
    float dist = length(delta);
    if (dist <= 0.0001) continue;

    vec2 dir = delta / dist;

    // 当前波前扩散半径 R(t)
    float R = speed * dt;
    float dr = dist - R;

    // 真实池塘雨滴波包：高斯波包宽度随扩散略微变宽，自然容纳 2~3 圈同心起伏
    float sigma = 0.024 + R * 0.065;
    float twoSigmaSq = 2.0 * sigma * sigma;

    // 空间波包包络 (紧凑精致，前后平滑对称)
    float normDistSq = dr * dr;
    if (normDistSq < (4.5 * twoSigmaSq)) {
      float envelope = exp(-normDistSq / twoSigmaSq);
      float dEnv_dr = -2.0 * dr / twoSigmaSq * envelope;

      // 时间阻尼与几何扩散能量衰减
      float timeDecay = exp(-damping * dt) * (1.0 - dt / maxDuration);
      float geomDecay = 1.0 / sqrt(dist + 0.06);
      float decay = amplitude * timeDecay * geomDecay * 0.048;

      // 空间波形：自然的同心正弦起伏 (波峰波谷)
      float k = 52.0 / (1.0 + 1.2 * R); // 波数随扩散略微拉伸
      float phase = dr * k - dt * 3.0;
      float sinVal = sin(phase);
      float cosVal = cos(phase);

      // 高度贡献
      float h = envelope * decay * sinVal;
      total_h += h;

      // 解析空间偏导 (精确计算法线坡度)
      float dh_dr = (dEnv_dr * sinVal + envelope * k * cosVal) * decay;
      total_grad += dh_dr * vec2(dir.x * aspect, dir.y);
    }
  }

  // 2. 雨天水面大尺度柔和微澜 (池塘水波微动)
  float amb_t = u_time * 0.35;
  float amb = sin(uv.x * 2.8 + uv.y * 1.8 + amb_t) * cos(uv.x * 1.8 - uv.y * 2.5 + amb_t * 0.8) * 0.0010;
  total_h += amb;

  total_grad.x += cos(uv.x * 2.8 + uv.y * 1.8 + amb_t) * 2.8 * 0.0010;
  total_grad.y += cos(uv.x * 1.8 - uv.y * 2.5 + amb_t * 0.8) * (-2.5) * 0.0010;

  // 3. 计算真实池塘水面法线
  // 适度法线强度：既有清晰明暗立体感，又绝不过度夸张
  vec3 normal = normalize(vec3(-total_grad.x * 3.8, -total_grad.y * 3.8, 1.0));

  // 4. 雨天池塘光学渲染 (Pond Lighting & Optics)
  // 主漫射光源 (阴天天光来自左上方)
  vec3 light_dir = normalize(vec3(-0.35, -0.60, 0.70));
  vec3 view_dir  = vec3(0.0, 0.0, 1.0);

  // 池塘自然水色体系 (冷墨玄青水体，通透清澈)
  vec3 deep_pond    = vec3(0.045, 0.065, 0.088); // 幽深玄青水底
  vec3 shallow_pond = vec3(0.105, 0.150, 0.190); // 浅层水光漫射
  vec3 sky_ambient  = vec3(0.35, 0.45, 0.55);    // 阴天天光倒影
  vec3 sun_sheen    = vec3(0.85, 0.92, 0.98);    // 温润天光微泛光

  // 光学折射畸变采样 (水面凹凸扭曲深水光线)
  vec2 refr_offset = normal.xy * 0.015;
  vec2 refr_uv = uv + refr_offset;
  float depth_grad = clamp(refr_uv.x * 0.20 + refr_uv.y * 0.80, 0.0, 1.0);
  vec3 water_base = mix(deep_pond, shallow_pond, depth_grad * 0.35);

  // 真实菲涅尔反射 (Schlick's Fresnel)
  // 当法线倾斜（波峰迎光侧/背光侧）时，反射天光的比例自然增加
  float NdotV = max(dot(normal, view_dir), 0.0);
  float F0 = 0.035;
  float fresnel = F0 + (1.0 - F0) * pow(clamp(1.0 - NdotV, 0.0, 1.0), 4.2);

  // 波浪明暗立体感 (Slope Diffuse: 波峰迎光微明，波谷凹陷微深)
  float slope = dot(normal, light_dir);
  float diffuse = clamp(slope * 0.5 + 0.5, 0.0, 1.0);
  
  // 水面色彩合成：基础水深 + 坡度立体明暗 + 菲涅尔天光倒影
  vec3 surface = mix(water_base * (0.75 + diffuse * 0.35), sky_ambient, fresnel * 0.75);

  // 柔和天光高光微晕 (Pond Soft Specular - 柔和自然，杜绝生硬白圈)
  vec3 h_vec = normalize(light_dir + view_dir);
  float NdotH = max(dot(normal, h_vec), 0.0);
  float specular = pow(NdotH, 48.0) * (0.35 + length(total_grad) * 2.0);

  // 阴天池塘微暗角
  vec2 v_uv = uv - 0.5;
  float vignette = 1.0 - dot(v_uv, v_uv) * 0.28;
  vignette = clamp(vignette, 0.78, 1.0);

  vec3 final_rgb = (surface + sun_sheen * specular) * vignette;
  frag_color = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
