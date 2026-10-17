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

// 水体光学与动态封面色彩通道 (保持 148 floats 严格布局兼容)：
// u_water_deep.rgb    : 深水宝石基底色 (Primary / Muted)，.a = darkness (0.0 日间 ~ 1.0 夜间)
// u_water_shallow.rgb : 浅水流光漫射色 (Secondary)，      .a = bassEnergy (0.0 ~ 1.0 低频律动能量)
// u_specular_color.rgb: 焦散与高光强调色 (Accent)，       .a = 1.0
// u_sky_color.rgb     : 天光与珠光反射色 (Highlight)，    .a = 1.0
uniform vec4 u_water_deep;
uniform vec4 u_water_shallow;
uniform vec4 u_specular_color;
uniform vec4 u_sky_color;

out vec4 frag_color;

float hash12(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float dither(vec2 p) {
  float a = hash12(p);
  float b = hash12(p + vec2(19.0, 37.0));
  return (a + b - 1.0) * (0.65 / 255.0);
}

// 2D 旋转矩阵
mat2 rot2(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, s, -s, c);
}

// 真实水底双层干涉焦散光网 (Underwater Optical Caustic Filament Network)
float causticNetwork(vec2 p, float t) {
  vec2 p1 = rot2(0.42) * p * 5.2 + vec2(t * 0.18, -t * 0.14);
  vec2 p2 = rot2(-0.68) * p * 6.4 + vec2(-t * 0.15, t * 0.21);
  vec2 p3 = rot2(1.05) * p * 4.6 + vec2(sin(t * 0.22) * 0.4, cos(t * 0.19) * 0.4);

  vec2 w1 = sin(p1 + cos(p1.yx * 1.35 + t * 0.32));
  vec2 w2 = sin(p2 + cos(p2.yx * 1.25 - t * 0.28));
  vec2 w3 = cos(p3 + sin(p3.yx * 1.15 + t * 0.24));

  // 利用三角场零点锐化生成如阳光穿透水面般的纤细焦散光丝
  float ridge1 = 1.0 - abs(w1.x * w1.y);
  float ridge2 = 1.0 - abs(w2.x + w2.y) * 0.5;
  float ridge3 = 1.0 - abs(w3.x * w3.y);

  float c = pow(clamp(ridge1 * 0.55 + ridge2 * 0.45, 0.0, 1.0), 4.5) +
            pow(clamp(ridge3 * 0.60 + ridge1 * 0.40, 0.0, 1.0), 5.5) * 0.65;
  return clamp(c, 0.0, 1.4);
}

// 渲染水底多色流光画卷 (Underwater Bioluminescent & Sunlit Lagoon Canvas)
vec3 sampleUnderwaterBed(
  vec2 uv,
  float aspect,
  float t,
  vec3 deepCol,
  vec3 shallowCol,
  vec3 accentCol,
  vec3 skyCol,
  float darkness,
  float bass
) {
  vec2 p = vec2(uv.x * aspect, uv.y);

  // 三大水底流光色域锚点（随时间缓慢游走）
  vec2 c1 = vec2((0.24 + 0.14 * cos(t * 0.22)) * aspect, 0.34 + 0.14 * sin(t * 0.18));
  vec2 c2 = vec2((0.76 + 0.14 * sin(t * 0.20 + 1.4)) * aspect, 0.66 + 0.14 * cos(t * 0.24 + 0.8));
  vec2 c3 = vec2((0.52 + 0.18 * sin(t * 0.26 + 2.6)) * aspect, 0.28 + 0.16 * cos(t * 0.21 + 2.1));

  float wShallow = exp(-dot(p - c2, p - c2) / (0.62 * aspect));
  float wAccent  = exp(-dot(p - c3, p - c3) / (0.48 * aspect));
  float wPrimary = exp(-dot(p - c1, p - c1) / (0.58 * aspect));

  // 構建通透渐变水底（彻底告别单调死黑，呈现深海琉璃/晴空碧潭层次）
  float diag = clamp(uv.x * 0.42 + uv.y * 0.58, 0.0, 1.0);
  vec3 bed = mix(deepCol, shallowCol, diag * 0.52 + wShallow * 0.38);
  bed = mix(bed, deepCol * 1.18 + shallowCol * 0.22, wPrimary * 0.45);
  bed = mix(bed, accentCol, wAccent * (0.34 + bass * 0.14));

  // 叠加水底自然微焦散光网
  float ambientCaustic = causticNetwork(p, t);
  float causticStrength = mix(0.16, 0.11, darkness) * (1.0 + bass * 0.35);
  bed += mix(skyCol, accentCol, 0.45) * ambientCaustic * causticStrength;

  return bed;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / max(u_size, vec2(1.0));
  float aspect = max(u_size.x / max(u_size.y, 1.0), 0.1);

  float total_h = 0.0;
  vec2 total_grad = vec2(0.0);
  float total_curv = 0.0; // 累积波面曲率（用于真实焦散聚光环计算）
  int count = int(clamp(u_ripple_count, 0.0, 16.0));

  // ── 1. 真实表面张力-重力色散多环水波场 (Capillary-Gravity Dispersive Wave Field) ──
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
    float baseFreq = max(rParams.y, 10.0);
    float damping = rParams.z;

    vec2 delta = vec2((uv.x - rData.x) * aspect, uv.y - rData.y);
    float dist = length(delta);
    if (dist <= 0.0001) continue;

    vec2 dir = delta / dist;

    // 波前扩散半径 R(t)：初始迅速张开，随后以真实色散群速度平滑向外推进
    float R = speed * dt + 0.014 * (1.0 - exp(-dt * 8.0));
    float dr = dist - R;

    // 非对称色散波包包络：
    // 波前外侧 (dr > 0) 紧凑锐利，波前内侧 (dr < 0) 拖曳出 5~7 圈层次分明的同心子波列，
    // 同时波心中央随扩散迅速恢复平静水面 (innerCalm)
    float sigmaFront = 0.015 + R * 0.024;
    float sigmaBack  = 0.048 + R * 0.095;
    float sigma = dr >= 0.0 ? sigmaFront : sigmaBack;
    float twoSigmaSq = 2.0 * sigma * sigma;
    float normDistSq = dr * dr;

    if (normDistSq < (5.0 * twoSigmaSq)) {
      float innerCalm = smoothstep(0.0, max(0.014, R * 0.34), dist);
      float envelope = exp(-normDistSq / twoSigmaSq) * innerCalm;
      float dEnv_dr = (-2.0 * dr / twoSigmaSq) * envelope;

      // 时间阻尼与二维柱面波 1/sqrt(r) 能量守恒衰减
      float lifeRatio = clamp(dt / max(maxDuration, 0.01), 0.0, 1.0);
      float smoothFadeOut = (1.0 - lifeRatio) * (1.0 - lifeRatio * 0.65);
      float timeDecay = exp(-damping * 0.72 * dt) * smoothFadeOut;
      float geomDecay = 1.0 / sqrt(dist + 0.045);
      float decay = amplitude * timeDecay * geomDecay * 0.068;

      // 表面张力色散 (Capillary Chirp)：外圈前沿波纹更细密，内圈尾波波长略舒展
      float relPos = clamp(dr / max(sigmaBack, 0.01), -1.2, 0.8);
      float k = (baseFreq * 4.4 / (1.0 + 0.75 * R)) * (1.0 + 0.24 * relPos);
      float phase = dr * k - dt * 5.2;

      // 斯托克斯尖峰圆谷波形 (Trochoidal / Stokes Wave Profile)：
      // 波峰窄而清亮，波谷宽而圆润，彻底消除传统正弦波的塑料模糊感
      float s1 = sin(phase);
      float c1 = cos(phase);
      float s2 = sin(2.0 * phase);
      float c2 = cos(2.0 * phase);

      float wave = s1 + 0.24 * c2;
      float dWave = c1 - 0.48 * s2;
      float d2Wave = -s1 - 0.96 * c2;

      float h = envelope * decay * wave;
      total_h += h;

      // 解析空间一阶梯度（精确计算波面法线）
      float dh_dr = (dEnv_dr * wave + envelope * k * dWave) * decay;
      total_grad += dh_dr * vec2(dir.x * aspect, dir.y);

      // 解析波峰曲率代理（用于计算波峰透镜在水底投射的明亮焦散光环）
      total_curv += envelope * decay * k * d2Wave;
    }
  }

  // ── 2. 湖面清风微澜 (Dual-Octave Capillary Breeze) ──
  float breeze_t = u_time * 0.42;
  vec2 p_uv = vec2(uv.x * aspect, uv.y);
  float b1 = sin(p_uv.x * 4.2 + p_uv.y * 2.8 + breeze_t) *
             cos(p_uv.x * 2.6 - p_uv.y * 3.6 - breeze_t * 0.8);
  float b2 = sin(p_uv.x * 7.5 - p_uv.y * 5.2 + breeze_t * 1.3) * 0.45;
  float amb = (b1 + b2) * 0.00085;
  total_h += amb;

  total_grad.x += (cos(p_uv.x * 4.2 + p_uv.y * 2.8 + breeze_t) * 4.2 +
                   cos(p_uv.x * 7.5 - p_uv.y * 5.2 + breeze_t * 1.3) * 3.3) * 0.00085;
  total_grad.y += (cos(p_uv.x * 4.2 + p_uv.y * 2.8 + breeze_t) * 2.8 -
                   cos(p_uv.x * 7.5 - p_uv.y * 5.2 + breeze_t * 1.3) * 2.3) * 0.00085;

  // ── 3. 计算真实水面三维光学法线 ──
  float gradMag = length(total_grad);
  vec3 normal = normalize(vec3(-total_grad.x * 4.4, -total_grad.y * 4.4, 1.0));

  // 解码明暗模式与音频能量参数
  float darkness = clamp(u_water_deep.a, 0.0, 1.0);
  float bassEnergy = clamp(u_water_shallow.a, 0.0, 1.0);

  vec3 deepCol    = u_water_deep.rgb;
  vec3 shallowCol = u_water_shallow.rgb;
  vec3 accentCol  = u_specular_color.rgb;
  vec3 skyCol     = u_sky_color.rgb;

  // 若外部传入旧式极暗死黑基底色 (如 #0C1014)，自动提亮注入清澈蓝绿琉璃光泽，保证通透感
  float deepLum = dot(deepCol, vec3(0.2126, 0.7152, 0.0722));
  if (deepLum < 0.025 && darkness > 0.5) {
    deepCol    = max(deepCol, vec3(0.055, 0.135, 0.195));
    shallowCol = max(shallowCol, vec3(0.110, 0.275, 0.365));
    accentCol  = max(accentCol, vec3(0.380, 0.760, 0.920));
    skyCol     = max(skyCol, vec3(0.560, 0.840, 0.960));
  }

  // ── 4. 斯涅尔水面折射 + RGB 微棱镜色散 (Refraction & Chromatic Dispersion) ──
  vec2 refrOffset = normal.xy * 0.038;
  float slowT = u_time * 0.35;

  // 当涟漪经过时，水底色彩与焦散光网发生真实的透镜折射弯曲与轻微 RGB 色散
  vec3 bedR = sampleUnderwaterBed(
      clamp(uv + refrOffset * 0.88, 0.0, 1.0), aspect, slowT,
      deepCol, shallowCol, accentCol, skyCol, darkness, bassEnergy);
  vec3 bedG = sampleUnderwaterBed(
      clamp(uv + refrOffset * 1.00, 0.0, 1.0), aspect, slowT,
      deepCol, shallowCol, accentCol, skyCol, darkness, bassEnergy);
  vec3 bedB = sampleUnderwaterBed(
      clamp(uv + refrOffset * 1.12, 0.0, 1.0), aspect, slowT,
      deepCol, shallowCol, accentCol, skyCol, darkness, bassEnergy);
  vec3 refractedBed = vec3(bedR.r, bedG.g, bedB.b);

  // ── 5. 双光源立体明暗、波峰焦散聚光环与菲涅尔天光反射 ──
  vec3 lightDir1 = normalize(vec3(-0.38, -0.52, 0.76)); // 主天顶漫射光源（左上方）
  vec3 lightDir2 = normalize(vec3(0.48, 0.36, 0.80));   // 副环境反光光源（右下方）
  vec3 viewDir   = vec3(0.0, 0.0, 1.0);

  // 波面迎光/背光立体明暗对比 (Wave Slope Shading)
  float slope1 = dot(normal, lightDir1);
  float slope2 = dot(normal, lightDir2);
  float waveContrast = (slope1 - lightDir1.z) * 1.65 + (slope2 - lightDir2.z) * 0.55;

  // 波峰透镜焦散聚光环 (Ripple Caustic Focusing Ring)：
  // 真实水波的波峰如同凸透镜，会在水底投射出一圈圈随波扩散的明亮光环
  float causticRing = clamp(-total_curv * 1.45 + max(waveContrast, 0.0) * 0.85, 0.0, 1.6);
  causticRing = pow(causticRing, 1.35);

  // 菲涅尔边缘反射 (Schlick Fresnel)
  float NdotV = max(dot(normal, viewDir), 0.0);
  float F0 = 0.04;
  float fresnel = F0 + (1.0 - F0) * pow(clamp(1.0 - NdotV, 0.0, 1.0), 3.6);
  // 强化涟漪波纹斜坡上的天光与极光色反射
  float rippleFresnel = clamp(fresnel + gradMag * 0.85, 0.0, 0.88);

  // 双瓣高光微芒 (Dual-Lobe Specular Glints)：柔美宽光晕 + 清冽晶莹波峰锐高光
  vec3 halfVec1 = normalize(lightDir1 + viewDir);
  vec3 halfVec2 = normalize(lightDir2 + viewDir);
  float NdotH1 = max(dot(normal, halfVec1), 0.0);
  float NdotH2 = max(dot(normal, halfVec2), 0.0);

  float broadSheen = pow(NdotH1, 22.0) * (0.28 + gradMag * 2.4);
  float crispGlint = pow(NdotH1, 76.0) * (0.45 + gradMag * 4.2) +
                     pow(NdotH2, 48.0) * (0.20 + gradMag * 2.2);

  // 合成水体：折射水底 + 波谷深邃阴影/波峰通透提亮 + 水底焦散亮环 + 菲涅尔天光倒影
  float shadeFactor = clamp(1.0 + waveContrast * (darkness > 0.5 ? 0.52 : 0.32), 0.58, 1.48);
  vec3 waterBody = refractedBed * shadeFactor;

  // 注入波峰投射的焦散亮环（混合强调色与珠光色）
  vec3 causticColor = mix(accentCol, skyCol, 0.55);
  waterBody += causticColor * causticRing * (darkness > 0.5 ? 0.34 : 0.24);

  // 菲涅尔天光混合
  vec3 surface = mix(waterBody, skyCol, rippleFresnel * (darkness > 0.5 ? 0.46 : 0.38));

  // 叠加波峰晶莹高光
  vec3 specTint = mix(skyCol, vec3(1.0), darkness > 0.5 ? 0.48 : 0.65);
  vec3 finalRgb = surface + accentCol * broadSheen * 0.32 + specTint * crispGlint * 0.42;

  // 暗色模式下智能亮度安全护栏（确保白色/浅色 UI 文字在任何高亮波峰上依然清晰易读）
  if (darkness > 0.5) {
    float lum = dot(finalRgb, vec3(0.2126, 0.7152, 0.0722));
    if (lum > 0.56) {
      finalRgb *= 0.56 / lum;
    }
  } else {
    finalRgb = clamp(finalRgb, 0.0, 0.96);
  }

  // 自然呼吸感微暗角与防断层抖动
  vec2 vUv = uv - 0.5;
  float vignette = clamp(1.0 - dot(vUv, vUv) * (darkness > 0.5 ? 0.22 : 0.10), 0.82, 1.0);
  finalRgb = clamp(finalRgb * vignette + vec3(dither(frag)), 0.0, 1.0);

  frag_color = vec4(finalRgb, 1.0);
}
