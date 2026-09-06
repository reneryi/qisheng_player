# 栖声播放器 (Qisheng Player) UI 视觉风格与背景材质推倒重构设计与执行规范

> **版本**：v2.0 Architecture Redesign
> **状态**：方案已对齐，待执行
> **设计目标**：彻底解耦「背景材质」与「UI 视觉风格」，推倒粗糙毛玻璃，重构通透、高级、沉浸、丝滑的现代音乐播放器视觉与动画系统。

---

## 目录
- [一、 设计系统架构重构总览](#一-设计系统架构重构总览)
- [二、 窗口背景材质 (Window Backdrop Materials) 规范与实现](#二-窗口背景材质-window-backdrop-materials-规范与实现)
  - [2.1 原生默认背景 (Default Native Background) 调优](#21-原生默认背景-default-native-background-调优)
  - [2.2 Windows 增强型云母 (Mica Alt / Tabbed)](#22-windows-增强型云母-mica-alt--tabbed)
  - [2.3 实时背景亚克力 (Real-time Background Acrylic)](#23-实时背景亚克力-real-time-background-acrylic)
  - [2.4 弥散流彩 / 灵动流光 (Mesh Flow / Fluid Chroma)](#24-弥散流彩--灵动流光-mesh-flow--fluid-chroma)
  - [2.5 交互水波纹 (Interactive Water Ripple)](#25-交互水波纹-interactive-water-ripple)
  - [2.6 琉璃透镜 / 动态折射玻璃 (Prismatic Refraction Glass)](#26-琉璃透镜--动态折射玻璃-prismatic-refraction-glass)
- [三、 UI 视觉表面风格 (UI Surface Styles) 规范与实现](#三-ui-视觉表面风格-ui-surface-styles-规范与实现)
  - [3.1 移除原有生硬毛玻璃 (Deprecated Legacy Glass)](#31-移除原有生硬毛玻璃-deprecated-legacy-glass)
  - [3.2 纯净实体卡片 (Solid Card Surface)](#32-纯净实体卡片-solid-card-surface)
  - [3.3 无界极简悬浮 (Borderless Ambient Floating)](#33-无界极简悬浮-borderless-ambient-floating)
  - [3.4 新增液态玻璃 (Liquid Glass Surface - Apple iOS/visionOS 灵感)](#34-新增液态玻璃-liquid-glass-surface---apple-iosvisionos-灵感)
- [四、 动态取色算法升级规范 (Dynamic Color Extraction Pipeline)](#四-动态取色算法升级规范-dynamic-color-extraction-pipeline)
- [五、 全局动画与交互物理系统 (Motion & Micro-interactions)](#五-全局动画与交互物理系统-motion--micro-interactions)
- [六、 模块重构执行清单与代码审查验收标准 (Checklist & Review Criteria)](#六-模块重构执行清单与代码审查验收标准-checklist--review-criteria)

---

## 一、 设计系统架构重构总览

为解决过去 UI 视觉风格与背景材质混合时产生的“脏色、过曝、发虚、对比度不足”问题，新架构严格采用**双层解耦与自适应安全色彩管道 (Dual-Layer Decoupled Architecture with Smart Scrim Pipeline)**：

```
+-------------------------------------------------------------------------+
| Layer 3: 顶层交互微动效与文字 (Text / Icons / Micro-interactions / Vibrancy) |
+-------------------------------------------------------------------------+
                                    ▲
| Layer 2: UI 视觉表面风格 (AppSurface: 纯净卡片 / 无界悬浮 / 液态玻璃)         |
+-------------------------------------------------------------------------+
                                    ▲
| Layer 1: 智能安全自适应遮罩管道 (Smart Scrim / Auto-Contrast Clamping)     |
+-------------------------------------------------------------------------+
                                    ▲
| Layer 0: 窗口背景材质 (Backdrop: 默认对角渐变 / Mica Alt / 亚克力 / 弥散流彩 / 水波纹 / 琉璃透镜)|
+-------------------------------------------------------------------------+
```

---

## 二、 窗口背景材质 (Window Backdrop Materials) 规范与实现

### 2.1 原生默认背景 (Default Native Background) 调优
* **视觉定义**：关闭一切复杂硬件特效时的默认基础背景，追求极致护眼、极简沉静、高字体清晰度。
* **夜间模式设计**：
  * **形态**：`135°` 对角流光渐变（从左上到右下）。
  * **色彩阶梯**：
    * 左上 Top-Left: `Color(0xFF0A1324)`（深邃午夜蓝）
    * 正中 Center: `Color(0xFF0F1D32)`（微亮沉静蓝灰）
    * 右下 Bottom-Right: `Color(0xFF070D18)`（纯净玄黑）
  * **作用**：打破单一纯色的死板，赋予暗黑界面如同夜空微光的呼吸感。
* **日间模式设计**：
  * **解决痛点**：彻底告别图二中高反光、刺眼的纯白与发虚的泛黄。
  * **形态**：`135°` 哑光柔和对角渐变（Warm Matte Paper White）。
  * **色彩阶梯**：
    * 左上 Top-Left: `Color(0xFFF6F8FA)`（极淡珍珠冷白）
    * 正中 Center: `Color(0xFFF0F2F5)`（柔和哑光纸白）
    * 右下 Bottom-Right: `Color(0xFFE8EBF0)`（极浅温润米灰）
  * **前景适配**：主文本使用高对比碳素黑 `Color(0xFF1B1F24)`，副文本使用 `Color(0xFF57606A)`，边缘锐利，彻底解决发虚、刺眼问题。

---

### 2.2 Windows 增强型云母 (Mica Alt / Tabbed)
* **视觉定义**：修复当前版本（图三）中错误的完全透明穿透问题，提供 Windows 11 原生的高级深层云母质感。
* **选型决策**：经过对比标准云母与增强型云母，**选择 Mica Alt（增强型云母，DWM 标识符 `DWMSBT_TABBEDWINDOW = 4`）**。
  * *原因*：Mica Alt 具有更饱满的桌面色彩渗出与丰富的微珠光色泽，特别适合多层次的音乐播放器界面。
* **技术实现方案**：
  * **无需额外引入笨重的第三方包**，直接利用项目现有的 `windows/runner/flutter_window.cpp` 原生层：
  * 在 C++ 窗口初始化与主题响应时调用：
    ```cpp
    const int backdrop_type = DWMSBT_TABBEDWINDOW; // 4
    DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop_type, sizeof(backdrop_type));
    ```
  * Flutter 端配合：`Scaffold` 与 Window 根节点保持 `Colors.transparent`，确保 DWM 材质完整透出；内容区采用半透明极微底衬（Alpha 0.05 ~ 0.12）提升层次。

---

### 2.3 实时背景亚克力 (Real-time Background Acrylic)
* **视觉定义**：真正的全窗口实时硬件加速亚克力材质。窗口能够实时采集后方的桌面壁纸、浏览器、代码编辑器等所有正在运行的活动窗口，并进行硬件级平滑高斯模糊与实时色彩透光。
* **技术实现方案**：
  * 在 `flutter_window.cpp` 中调用：
    ```cpp
    const int backdrop_type = DWMSBT_TRANSIENTWINDOW; // 3 (Windows 11 Acrylic)
    DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop_type, sizeof(backdrop_type));
    ```
  * Flutter 侧自动注入暗色/明亮微遮罩（Scrim Alpha 0.15），防止背后窗口高亮文字干扰播放器前景文字阅读。

---

### 2.4 弥散流彩 / 灵动流光 (Mesh Flow / Fluid Chroma)
* **命名敲定**：告别名不副实的“极光”，定名为 **「弥散流彩 (Mesh Flow)」**（或 **「灵动流光」**）。
* **视觉定义**：仿照 Apple Music 沉浸式流体光斑（Mesh Gradient Backdrop），彻底告别图四、图五中的浑浊与灰暗色块。
* **明暗模式专属分层逻辑（关键细节）**：
  * **暗色模式（最佳沉浸表现）**：
    * 以深邃暗调夜空为基底，由 4~6 个提取自主色的高饱和、高对比光斑球在底层深度交织、缓慢呼吸推移，呈现最为绚烂灵动的沉浸视觉。
  * **明亮模式（柔和纸白为主体，流光为点缀）**：
    * **主体基底**：严格采用优化后的 **135° 哑光柔和对角渐变纸白（Warm Matte Paper White）**，确保整体视觉依然保持洁净、温润、大面积的白昼呼吸感。
    * **流体光斑**：光斑透明度与饱和度调至适中（Pastel Accent Blooms，Alpha ~0.20-0.30），作为背景的雅致光晕点缀，绝不反客为主；前景文本维持碳黑高对比度，兼顾高颜值与长时间阅读舒适度。
* **技术实现方案**：
  1. **5 动态色彩锚点网格（5-Color Harmonic Anchors）**：
     - 100% 优先保留 Rust Oklab 从专辑封面提取的真实颜色；中性色建立零饱和度安全通道，单色封面仅做同色系邻近微偏（$\pm 14^\circ$）明暗阶梯；
  2. **SkSL / GLSL 片段着色器 (`shaders/mesh_flow.frag`)**：
     - **大尺度 Metaball 液滴熔融势能场**：采用长尾超平滑势能 $W_i(p) = \frac{R_i^2}{\|p - P_i\|^2 + 0.42 R_i^2}$，使大液滴在空间中互相靠近时自然吸引、拉伸、粘连与融化（Metaball Fluid Coalescence）；
     - **低频平缓 S-Curve 形变**：施加大尺度柔和流动形变，杜绝任何高频噪声、等高线与大理石纹理；
     - **全画幅多波段柔和融合**：色彩在 Gamma 2.2 线性空间中加权融合，暗色模式下沉浸深邃，亮色模式下马卡龙水彩雅致流动，结合胶片微抖动彻底杜绝色带。

---

### 2.5 交互水波纹 / 雨天涟漪水面 (Interactive Rainy Ripple Surface)
* **视觉定义**：将播放器底座化作一汪清冽、干净、通透的雨天水面（雨天冷灰玄青冷墨色调），具备极佳的物理涟漪、多波碰撞相长干涉、全时自然细雨点滴与视听共振。
* **独立环境与色彩隔离特性（关键设计准则）**：
  * **绝不受动态取色与手动选色影响**：恒久保持干净清澈的雨天冷灰玄青光谱（深水区 `#0C1014`，漫射水色 `#1B252E`，冷白高光 `#E2EFF8`，阴天天光 `#506270`），杜绝任何外界高饱和色彩污染；
  * **绝不受系统日夜模式切换影响**：拥有独立自洽的雨天水光折射空间，恒定保持深邃沉静的雨水光泽，不随日间模式变成刺眼白底；
  * **前台控件与主题色 100% 联动**：按钮、控制栏、滑块等前台 UI 元素仍严格消费全局动态/手动主题色与日夜对比度适配。
* **四大水动力学波源系统**：
  1. **全时自然小雨涟漪（Ambient Rain Simulation）**：全时自然运作的泊松随机雨滴系统（间隔 1.2s~2.6s 随机滴落，全屏维持 2~4 个不同扩散周期的清脆涟漪），无需鼠标闲置即持续营造静谧雨天氛围；
  2. **鼠标点击激荡（Click Shockwave）**：点击任意区域触发高振幅、低阻尼的高能量扩散冲击波；
  3. **鼠标滑行动能微澜（Mouse Trail Waves）**：跟随光标速度向量生成细腻的跟随小波痕；
  4. **低音重击共鸣（Bass-Reactive Resonance）**：在大播放页模式下响应 BASS 音频低频能量，激荡中心扩散同心波。
* **着色器光学与碰撞物理技术实现**：
  * **色散波列与陡峭波前**：模拟水-气界面毛细重力波，波峰边缘锐利且波长随距离自然拉伸；
  * **多波碰撞相长干涉（Interference Dynamics）**：两圈或多圈水波相交时，波峰叠加产生非线性曲率增强与相撞激荡闪光（Interference Flash），波相消处平滑如镜；
  * **菲涅尔光学反射（Schlick's Fresnel Approximation）**：波前迎光面法线倾斜时反射率急剧升高，水波反射亮白天光，波谷透射深水，产生极强的立体通透度；
  * **单次遍历高阶解析偏导（GPU Extreme Performance）**：单 pass 计算 16 个波源的法线梯度与高度，0 额外采样，稳定满帧 120Hz/144Hz。

---

### 2.6 琉璃透镜 / 动态折射玻璃 (Prismatic Refraction Glass)
* **视觉定义**：默认呈现清透淡雅的冰蓝透明晶体质感；开启动态取色时随音乐呈现极淡的氛围染色。具备厚度感、凸透镜折射与动态次表面光影。
* **明暗模式专属表现（关键细节）**：
  * **暗色模式（暗调黑曜琉璃）**：玻璃基底呈现深邃透光的黑曜冰晶（Translucent Obsidian Ice），高光条纹更显冷冽犀利，折射边缘带微弱暗蓝色晕。
  * **明亮模式（晨曦高透晶体）**：玻璃基底整体明亮通透，透光度显著提升（High Translucency Clear Glass），折射高光呈现温润的白光微芒。
* **技术实现方案**：
  1. **凸透镜几何折射（Convex Lens Refraction）**：
     * 利用着色器构建中心平缓、四周边缘凸起的透镜高度场（SDF Lens Heightfield）；
     * 对采样坐标进行光线折射偏移（Refractive UV Offset: $UV_{offset} = UV + \vec{N}_{xy} \times \eta$），让窗口边缘产生真实厚玻璃将光线弯折放大的物理质感。
  2. **动态流光高光（Dynamic Caustics / Sheen）**：
     * 沿着玻璃对角线缓缓流淌柔和的冷白色流光条纹。
  3. **适度染色**：
     * 严格限制动态色彩的饱和度（Saturation: 0.12 ~ 0.22，Lightness: 暗色 0.12 / 明亮 0.90+），杜绝浓重染色破坏玻璃晶莹剔透感。

---

## 三、 UI 视觉表面风格 (UI Surface Styles) 规范与实现

### 3.1 移除原有生硬毛玻璃 (Deprecated Legacy Glass)
* **行动**：完全废弃并移除现有粗糙的全局毛玻璃样式（容易引起白边发灰、文字不可读、GPU 负担重等缺陷）。

### 3.2 纯净实体卡片 (Solid Card Surface)
* **视觉定义**：以清晰的信息层级与极高的文字可读性为核心。
* **参数规范**：
  * **暗色模式**：基底色采用 `Color.alphaBlend(scheme.primary.withOpacity(0.06), Color(0xFF141C2B))`，边框采用 `Color(0xFF2C3A52)`（0.5px 极细精细描边），阴影深度 `blur: 16px, offset: (0, 6), color: Colors.black.withOpacity(0.35)`。
  * **日间模式**：基底色采用 `Color(0xFFFFFFFF)`，边框采用 `Color(0xFFE1E4E8)`，配合柔和环境光弥散阴影。

### 3.3 无界极简悬浮 (Borderless Ambient Floating)
* **视觉定义**：彻底去除所有卡片容器的实心底色与生硬边框，所有信息直接“漂浮”在背景之上。
* **沉浸度增强规范**：
  * 默认状态：0 容器底色、0 边框、0 阴影；
  * 交互状态（Hover / Focus / Selected）：浮现呼吸微光胶囊（Ambient Glow Capsule，Alpha 0.08 ~ 0.15）并伴随 `+1.5px` 的微小 Z 轴悬浮上浮动画；
  * 智能文字阴影：底层自动为悬浮文本注入轻量微光扩散阴影（`Shadow(color: Colors.black.withOpacity(0.45), blurRadius: 4)`），确保在任何动态背景下字体永不发虚。

### 3.4 新增液态玻璃 (Liquid Glass Surface - Apple iOS/visionOS 灵感)
* **视觉定义**：参考苹果最新的 Liquid Glass 空间设计语言，呈现出如水银与液体包裹般的表面张力与微折射边缘。
* **参数与实现规范**：
  * **连续曲率平滑圆角（Squircle Curvature）**：`radius: 20px ~ 24px`；
  * **内边缘次表面发光（Inner Rim Lighting）**：卡片上边缘与左边缘带有 1.2px 的半透明白光高光（`LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0.05)])`）；
  * **表面流动微光（Specular Fluid Sheen）**：当鼠标划过卡片时，光标附近产生微弱的动态高光跟随（Radial Specular Flare）；
  * **轻量局部曲面模糊**：局部轻量模糊（Sigma: 12.0），配合淡雅底色（Alpha 0.18），视觉通透灵动。

---

## 四、 动态取色算法升级规范 (Dynamic Color Extraction Pipeline)

* **现有问题**：提取颜色偏暗、单一、数量不足，容易提取到偏灰浊的无用色。
* **升级方案**：
  1. **多调色板提取（5-Color Harmonic Palette）**：
     * 从专辑封面提取五种语义色：
       * `primaryDominant`（主导色）
       * `vibrantAccent`（高饱和明亮强调色）
       * `softAmbient`（柔和环境色）
       * `deepBackdrop`（深邃背景对比色）
       * `highlightGlow`（高光点缀色）
  2. **色彩清洗与中性色安全通道（Neutral Guard & Chroma Clamping）**：
     * **中性色绝对保护**：对纯白、纯黑、银灰、石墨等中性色/低饱和度封面，生成纯正零饱和度的黑白灰冷暖阶梯，绝不强制注入红橙饱和度；
     * **原生取色优先**：100% 优先保留 Rust 提取的原生多色；单色封面仅做同色系微偏阶梯（$\pm 14^\circ$），杜绝跳色与异色产生；
     * 在 Oklab 空间中做自然纯化，使输入给着色器的色彩通透、饱满且忠实于封面艺术基调。

---

## 五、 全局动画与交互物理系统 (Motion & Micro-interactions)

为达成 120Hz/144Hz 极度丝滑体验，制定以下全局动效规范：

| 交互场景 | 动效类型 | 曲线 / 物理参数 | 时长 (Duration) | 交互细节 |
| :--- | :--- | :--- | :--- | :--- |
| **按钮 / 卡片按压** | 弹簧微缩放 (Spring Scale) | Spring (Damping: 0.82, Stiffness: 280) | ~180ms | 按下缩放至 `0.96x`，松开回弹至 `1.0x`，伴随柔和波纹 |
| **页面路由切换** | 交叉平滑淡入滑移 (Slide Fade) | `Cubic(0.05, 0.7, 0.1, 1.0)` (Apple Emphasized) | 260ms | 上层页面从下方微滑移 16px 并淡入，下层轻微缩放 0.98x |
| **播放 / 暂停切换** | 图标形态形变 (Morphing) | `Curves.easeInOutCubic` | 200ms | 播放三角形与暂停双竖条之间的平滑矢量插值形变 |
| **歌词滚动与高亮** | 物理惯性平滑追踪 | Fluid Spring Track Curve | 350ms | 当前歌词平滑居中，字体尺寸放大 1.08x 并渐显微光，非激活行平滑景深模糊过渡 |
| **低音节拍涟漪** | 阻尼水波激荡 | Damped Sine Wave ($e^{-\gamma t}\sin(\omega t)$) | 600ms | 随 BASS 低音能量实时触发同心涟漪扩散 |

---

## 六、 模块重构执行清单与代码审查验收标准 (Checklist & Review Criteria)

### 1. 执行模块清单
- [ ] **Native C++ 层 (`windows/runner/flutter_window.cpp`)**：
  - [ ] 接入 `DWMSBT_TABBEDWINDOW` 实现 Mica Alt 增强型云母；
  - [ ] 接入 `DWMSBT_TRANSIENTWINDOW` 实现实时背景亚克力；
  - [ ] 修复窗口透明度与 ClientArea Extend 边框混合问题。
- [ ] **着色器层 (`shaders/`)**：
  - [ ] 新建/优化 `mesh_flow.frag`（弥散流彩着色器）；
  - [ ] 新建 `water_ripple.frag`（交互水波纹与低音共振着色器）；
  - [ ] 新建 `lens_glass.frag`（琉璃透镜折射与高光着色器）。
- [ ] **主题与 Token 层 (`lib/theme/` & `lib/theme_provider.dart`)**：
  - [ ] 重构 `WindowBackdropMode` 枚举（默认渐变、Mica Alt、亚克力、弥散流彩、水波纹、琉璃透镜）；
  - [ ] 重构 `UiVisualStyleMode` 枚举（移除 glass，保留 solidCard，优化 borderless，新增 liquidGlass）；
  - [ ] 升级 5 色调色板提取与 Oklab 色彩清洗算法；
  - [ ] 更新日间（哑光纸白）与夜间（对角深蓝）默认背景。
- [ ] **UI 容器层 (`lib/component/ui/app_surface.dart`)**：
  - [ ] 重写 `AppSurface`，实现全新的 `_LiquidGlassSurface`、`_SolidCardSurface` 与 `_BorderlessSurface`。
- [ ] **设置页面 (`lib/page/settings_page/theme_settings.dart`)**：
  - [ ] 刷新设置项文案与分段选择器，呈现全新的材质与风格选项。

---

### 2. 验收审查标准 (Review Criteria)
1. **视觉美感与协调性**：
   - [x] 日间模式在纯白背景下是否依然柔和温润、字体锐利不刺眼？
   - [x] 夜间模式对角渐变是否过渡平滑、无色彩阶跃断层（Banding）？
   - [x] 增强型云母 (Mica Alt) 是否能正常反射桌面壁纸色调且不再透出窗口后方的杂乱字迹？
   - [x] 亚克力背景是否能够随背后窗口的移动实时变色与硬件级模糊？
   - [x] 弥散流彩是否彻底消除浑浊灰暗感，呈现如 Apple Music 般的通透与灵动？
   - [x] 水波纹在鼠标滑动、点击以及大播放页低音节拍响起时是否有精准的物理扩散波纹？
   - [x] 琉璃透镜是否具备明显的厚度折射感与清透淡蓝微光？
   - [x] 液态玻璃 UI 是否具备高级的内高光边缘与表面张力感？
2. **性能与帧率**：
   - [x] 窗口在 120Hz/144Hz 刷新率显示器上全屏运行时，动画是否持续稳定在满帧无卡顿？
   - [x] 鼠标快速划过、切换歌曲时 GPU 占用率是否保持在合理低位？
