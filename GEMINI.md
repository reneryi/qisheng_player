# 歧声播放器 (Qisheng Player) 工程与设计规范

本规范记录歧声播放器的视觉风格、图标设计、微动量交互与工程稳健性规范，适用于全应用所有界面的开发与演进。

---

## 一、 图标设计与全局视觉规范 (Iconography & Visual Styling)

### 1. 饱满圆润的实心符号质感 (Rounded & Solid Aesthetic)
* **符号选型**：优先选用 Material Symbols 的 **Rounded** 变体（如 `Symbols.play_arrow_rounded`、`Symbols.skip_next_rounded`、`Symbols.skip_previous_rounded`、`Symbols.shuffle_rounded`、`Symbols.repeat_rounded`、`Symbols.palette_rounded` 等），杜绝单薄、锋利的生硬线框。
* **全局主题 Token（AppTheme.build）**：
  在 `AppTheme.build` 中，统一注入全局日夜间图标主题：
  ```dart
  iconTheme: IconThemeData(
    color: colorScheme.onSurface,
    fill: 1.0,
    weight: 600,
    grade: 0.25,
    opticalSize: 24,
  ),
  primaryIconTheme: IconThemeData(
    color: accents.onAccent,
    fill: 1.0,
    weight: 600,
    grade: 0.25,
    opticalSize: 24,
  ),
  ```
  保证全应用所有未显式指定的图标自动继承扎实、高权重、实心的视觉张力。

### 2. 主播放控键视觉层级 (Primary Play Button)
* **斜向光感渐变**：采用 `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight)`，高光端自然过渡至主体色。
* **微高光半透明内描边**：配置 `Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8)`，强化玻璃与金属交融的微立体边缘。
* **双层动态弥散光晕**：悬停与播放态下动态调整 `accents.accentGlow` 的扩散半径与模糊半径，搭配自然环境暗部投影。

### 3. 模式激活指示机制 (Active Mode Indicators)
* **微发光底环**：激活时呈现半透明强调色圆环底色（`accents.accent` 低 alpha）。
* **呼吸高亮指示点**：底部微发光点必须由 `AnimatedOpacity` 与 `AnimatedScale` 驱动，切换时呈现呼吸般的优雅浮现与收拢，**禁止通过 `if (selected)` 生硬增删节点导致瞬间闪烁**。

---

## 二、 交互动效与物理微动量规范 (Micro-Interactions & Kinetics)

### 1. 核心播放控键无 Tooltip 准则 (No-Tooltip Policy for Core Controls)
* **核心控键免遮挡**：底栏 5 个高频核心播放控制键（**随机播放、上一首、主播放/暂停、下一首、循环模式**）**严格禁止包裹 `Tooltip` 或 `ModernTooltip`**！
* 杜绝鼠标移上时弹出文本气泡遮挡音频进度条、曲名或干扰视线。状态提示仅依靠图标变化与底部呼吸指示点传达。

### 2. 平滑悬停物理插值 (Smooth Hover Scaling)
* **严禁单帧阶跃**：不得在 `Transform.scale` 中直接使用单帧三元表达式（如 `_hovered ? 1.045 : 1.0`）。
* **独立控制器驱动**：必须配备独立的 `_hoverController`（`160ms~180ms`，缓动曲线 `Curves.easeOutCubic`），呈现细腻平滑的呼吸缩放与复位。

### 3. 双控制器解耦与矩阵合成 (Decoupled Motion Synthesis)
* 使用 `Listenable.merge([_pressController, _hoverController])` 合成变换矩阵：
  ```dart
  final pressScale = _pressScaleAnimation.value;
  final hoverScale = _hoverScaleAnimation.value;
  final combinedScale = pressScale * hoverScale;
  ```
  实现“悬停放大”与“点击下压回弹”两个独立物理过程的丝滑解耦与无缝叠加。

### 4. 方向微动量反馈 (Directional Kinetic Feedback)
* **上一首**：点击按下时触发向左微冲量（`-2.5px`），释放带微弹簧回弹。
* **下一首**：点击按下时触发向右微冲量（`+2.5px`），释放带微弹簧回弹。
* **随机播放**：点击瞬间触发 `-90°`（`-0.25 * 2 * math.pi`）旋转弹簧动量，松手弹性复位。
* **循环模式**：点击触发向上微弹移（`-2.0px`），并在模式切换（单曲循环/列表循环）时，利用 `AnimatedSwitcher` + `SlideTransition` 实现垂直滑块弹性翻滚过渡。

---

## 三、 工程健壮性与热重载防护规范 (Hot Reload Resilience & Lifecycle Safety)

### 1. 杜绝裸露 `late final AnimationController`
* 在 StatefulWidget 中引入新的控制器字段时，严禁使用不可变的 `late final AnimationController`。
* **原因**：在 Flutter 调试模式下触发热重载（Hot Reload / reassemble）时，内存中已存在的 State 实例**不会重新执行 `initState()`**，导致访问未赋值字段直接抛出 `LateInitializationError` 致命崩溃。

### 2. 防御式惰性初始化与自愈范式 (Lazy & Safe Init Pattern)
对于包含控制器或动画的 State 组件，统一采用如下自愈初始化范式：
```dart
AnimationController? _pressController;
AnimationController? _hoverController;

@override
void initState() {
  super.initState();
  _initAnimations();
}

@override
void reassemble() {
  super.reassemble();
  _initAnimations();
}

void _initAnimations() {
  _pressController ??= AnimationController(...);
  _hoverController ??= AnimationController(...);
}

@override
void dispose() {
  _pressController?.dispose();
  _hoverController?.dispose();
  super.dispose();
}
```
在 `build()` 以及手势入口函数开头调用 `_initAnimations()`，确保无论是首次挂载、热重载、热重启还是异步重组，动画状态均具备 100% 稳定性。
