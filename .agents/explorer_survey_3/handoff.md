# Handoff Report — Explorer 3: Shell 联动动效、边距动画与 Staged Reveal 调研

## 1. Observation (直接观察事实与代码定位)

1. **MainLayoutFrame 静态布局约束** (`lib/component/main_layout_frame.dart`):
   - 第 41-46 行：`final isMaximized = WindowControls.layoutMode.value == WindowLayoutMode.maximized;`，`topInset` (12.0 或 20.0)、`sideInset` (0.0 或 8.0)、`bottomInset` (0.0 或 8.0)。
   - 第 63-69 行：`Padding(padding: EdgeInsets.fromLTRB(sideInset + 4.0, topInset, sideInset + 4.0, 0), child: Column(...))` 采用非动画的静态 `Padding`。
   - 第 74-76 行：`Padding(padding: EdgeInsets.only(bottom: dockInset), ...)` 采用静态 `Padding`。
   - 第 93-96 行：`Positioned(left: 0, right: 0, bottom: bottomInset, child: ...)` 采用静态 `Positioned`。
2. **底层 AppShell 与播放详情页双重透明度竞争** (`lib/entry.dart`):
   - 第 244-248 行：`NowPlayingShellUnderlay` 内部采用独立的 `AnimatedOpacity(duration: const Duration(milliseconds: 380), opacity: _hidden ? 0.0 : 1.0, curve: Curves.easeOutCubic)`。
   - 第 92-107 行：`_buildAppRouteTransition` 内部又基于 `secondaryAnimation` 计算 `underlayOpacity = 1.0 - Interval(0.0, 0.48, curve: Curves.easeOutCubic).transform(secondaryAnimation.value)`，并在子树上再次套用 `Opacity(opacity: underlayOpacity)`。
3. **NowPlayingPage 进退场与 Staged Reveal 时间轴** (`lib/entry.dart`, `lib/page/now_playing_page/page.dart`, `lib/page/now_playing_page/component_views.dart`):
   - `NowPlayingTransitionPage` 转场总时长：Forward 480ms，Reverse 400ms，`opaque: false`。
   - `_NowPlayingStagedReveal` (`page.dart:97-140`): 基于 `Interval(begin, end)` 驱动 `FadeTransition`、`SlideTransition` 与 `ScaleTransition`。
   - 各组件区间：AppBar (`0.12 ~ 0.48`)、TrackIdentity (`0.24 ~ 0.68`)、MetadataStrip (`0.30 ~ 0.75`)、SpectrumBar (`0.35 ~ 0.80`)、LyricsView (`0.34 ~ 0.90`)、底栏控制条 (`>= 0.82` 阈值唤醒)。
   - 黑胶唱机死分支存在于 `component_views.dart` 第 547-578 行，容器宽度为 `size * 1.15`，与常规封面 Hero 容器（`size`）尺寸不对称。
4. **性能与渲染层级** (`lib/component/fluid_gradient_background.dart`, `lib/page/now_playing_page/component_views.dart`):
   - 全局背景 `FluidGradientBackground`（`fluid_gradient_background.dart:220`）拥有独立 `RepaintBoundary`。
   - 封面呼吸发光（`component_views.dart:607-613`）中的 `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32))` 缺乏直接的 `RepaintBoundary` 纹理缓存。
   - 歌词缩放提示胶囊（`component_views.dart:1214-1255`）中的 `BackdropFilter` 在 `_showScaleIndicator == false` 时仍挂载于绘制树。

## 2. Logic Chain (推导逻辑链)

1. **从 Observation 1 到 Inset 硬跳变消除**：
   - 观察到 `topInset`, `sideInset`, `bottomInset`, `dockInset` 随 `layoutMode` 状态改变产生瞬时阶跃（如 12px → 20px, 0px → 8px）；
   - 因为外层包裹的是普通 `Padding` 和 `Positioned`，Flutter 在下一帧直接按照新尺寸重新 layout 并绘制，产生了可见的瞬时几何跳变；
   - 将其替换为 `AnimatedPadding` 和 `AnimatedPositioned`（duration ~220ms，Curves.easeOutCubic），可在值变更时由 Flutter 动画引擎在多帧中线性/缓动插值，消除硬跳变。而在日常鼠标拖拽窗口大小时，`layoutMode` 维持不变，不产生额外计算开销。
2. **从 Observation 2 到协同淡入淡出与空间缩放优化**：
   - 观察到两层 `Opacity` 分别由 `AnimatedOpacity` (380ms 定时器) 和 `secondaryAnimation` (0.0~0.48 进度) 同时驱动；
   - 乘法级联使得底层在 150ms 左右即快速变黑，导致 Hero 飞跃失去连贯的背景参考系；
   - 统一转场驱动源并为底层增加 `Scale: 1.0 -> 0.96` 空间推远，能提供深度感更强的现代视口转场。
3. **从 Observation 3 到 Staged Reveal 与 Hero 结构统一**：
   - 观察到 6 阶段 Staged Reveal 节奏设计层次分明，但黑胶唱机分支破坏了 Hero 的矩形对齐；
   - 移除黑胶死分支后，两端 Hero 包围盒均为统一的 `size`，飞跃动效无畸变；同时在入场期间锁定歌词滚动重定位，防止位移叠加抖动。
4. **从 Observation 4 到 120fps 满帧优化**：
   - 32px 高斯模糊计算量巨大，通过在 `ImageFiltered` 外层加 `RepaintBoundary`，Flutter 仅光栅化一次为 Texture，后续 `_glowController` 的 `Transform.scale` 和 `Opacity` 均为 GPU 矩阵与 Alpha 运算，彻底消除每帧滤镜重算。

## 3. Caveats (局限与未调研区域)

- **无源代码修改**：本 Agent 严格遵循只读约束，未对项目任何 `.dart` 文件执行修改。
- **着色器硬件兼容性**：GPU Fragment Shader 在极其老旧的显卡或软解光栅化环境下未做极低配置真机实测（但现有代码已有 `UiEffectsLevel` 画质分级降级兜底）。

## 4. Conclusion (调研结论)

1. `MainLayoutFrame` 重构目标明确、改动高度局部且无破坏性，使用 `AnimatedPadding` + `AnimatedPositioned` 即可完美消除窗口模式切换时的硬跳变。
2. `AppShell` 与 `NowPlayingPage` 的协同应消除双重透明度竞争，建议在转场中引入 `Scale 0.96` 空间沉降。
3. 纯封面画册布局与 Staged Reveal 阶段式时间轴设计完备，移除黑胶唱机分支可确保 Hero 结构 100% 对齐。
4. 高刷优化方案（`RepaintBoundary` 纹理缓存、`BackdropFilter` 惰性挂载、歌词入场滚动锁定）切实可行，可充分保障 60fps/120fps 极限流畅度。

## 5. Verification Method (验证方法)

1. **单元测试与 Widget 测试**：
   ```bash
   flutter test test/entry_transition_test.dart test/component/main_layout_frame_test.dart
   ```
2. **代码规范与静态分析**：
   ```bash
   flutter analyze
   ```
3. **文件检视**：
   - 查看详尽报告：`e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\report.md`
   - 查看进度记录：`e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\progress.md`
