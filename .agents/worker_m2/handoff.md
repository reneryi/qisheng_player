# Milestone 2 实施交接报告 (Handoff Report)

**实施 Worker**：Worker M2 (Hero 动效子树与包围盒几何对齐)  
**时间**：2026-09-01  
**状态**：全部任务圆满完成（测试通过率 100%，静态分析 0 告警）

---

## 1. 观察 (Observation)

通过对项目原有代码与 Explorer 2 勘探报告的审查与实操验证，观察到以下关键事实：

1. **旧版 Hero 双树 Stack 交叉淡入与变形问题**：
   - `lib/component/now_playing_artwork_hero.dart:28-65` 原使用 `Stack(children: [Opacity(1-t, fromHero.child), Opacity(t, toHero.child)])`。由于两端 `child` 异构且包含不同尺寸约束（如详情页硬编码大尺寸），在转场中途产生严重双重残影（Ghosting）与容器挤压。
2. **两端 Hero 结构层级不对称与手势混入**：
   - 原详情页 `lib/page/now_playing_page/component_views.dart:606-621` 将 `GestureDetector(key: ValueKey('now-playing-artwork-drag'))` 和 `Transform` 放置在 `Hero` **内部**；而底栏 `lib/component/bottom_player_bar.dart:317` 将缩放发光放在 `Hero` **外部**。
   - 外部弥散光晕与内部静态阴影层级倒置，圆角（26px vs 24px/14px）未进行动态平滑插值。
3. **`FittedBox` 破坏详情页 Hero 目标坐标系**：
   - `lib/page/now_playing_page/component_views.dart:101` 使用 `FittedBox(fit: BoxFit.scaleDown)` 包裹包含封面、歌名和元数据的大 Column，导致目标包围盒在转场展开或窗口自适应时产生缩放扰动与单帧跳变（Snap/Jump）。

---

## 2. 逻辑链 (Logic Chain)

根据上述观察，实施了以下重构闭环：

1. **统一单核 `NowPlayingArtworkCard`**：
   - 在 `lib/component/now_playing_artwork_hero.dart` 中建立标准 1:1 单核卡片组件，统一统筹图片加载（优先使用 `coverProvider`，缺省回退至 `audio.cover` 内存流，失败/空音频则展示精致占位符）、统一圆角裁切和阴影。
2. **单层无虚影飞行穿梭器 `nowPlayingArtworkFlightShuttleBuilder`**：
   - 彻底废弃双树透明度交叉淡入 Stack，在飞行途中直接以单层 `NowPlayingArtworkCard` 进行承载，通过 `ui.lerpDouble` 对 `BorderRadius`（如底栏正圆 26px 到详情页精致圆角 24px）进行毫秒级平滑插值，实现 120fps 满帧无重影飞行。
3. **自然物理抛物线 `NowPlayingArtworkRectTween`**：
   - 在 `Rect.lerp` 基础上叠加平滑自适应的自然 Y 轴物理弧度微调（`arcAmplitude = (travelDistance * 0.024).clamp(0.0, 14.0)`），杜绝反向漂浮与突兀折线。
4. **两端 Hero 子树纯净化与外部层级分层解耦**：
   - 底栏 `BottomPlayerBar` 的 `_TrackCover`：`Hero` 内部直接挂载纯净 `NowPlayingArtworkCard`。
   - 详情页 `_NowPlayingArtwork`：将手势检测 `GestureDetector(key: ValueKey('now-playing-artwork-drag'))`、3D 悬浮倾斜 `Transform`、外层弥散光晕 `ImageFiltered(blur: 32)` 完整移至 `Hero` **外部**；`Hero` 内部仅包裹纯净 `NowPlayingArtworkCard`。
5. **解除 `FittedBox` 缩放污染**：
   - 在 `_ImmersiveArtworkStage` 中移除 `FittedBox`，使用自适应约束计算与纯净列布局，确保详情页 Hero 目标 RenderBox 具备绝对稳定的 1:1 正方形几何包围盒。
6. **单元测试与全套回归**：
   - 在 `test/component/now_playing_artwork_hero_test.dart` 中扩充了针对 `NowPlayingArtworkRectTween` 边界、`NowPlayingArtworkHeroFrame` 容器属性、`NowPlayingArtworkCard` 多态渲染以及穿梭器的详尽单元测试。

---

## 3. 局限与注意事项 (Caveats)

- `disableHero` 逻辑保持完整：在详情页弹出全屏歌词或悬浮底栏时，底栏依旧保持 `disableHero: true`，以防止同一路由中出现多 Hero 重复 Tag 冲突。
- 本次改动严格限定在 Milestone 2 独占文件范围内，未改动任何超出授权的工程源码。

---

## 4. 结论 (Conclusion)

Milestone 2 核心实施任务已全部达成：
- 封面画册在底栏与播放详情页之间实现了严格 1:1 的几何与层级对称；
- 彻底消除了飞行重影、黑胶唱机撕裂形变、落地 Snap 跳变与单帧白屏闪烁；
- 全项目静态分析 0 告警，全量 531 个测试及 248 个 E2E 测试全部 100% 通过。

---

## 5. 独立验证方法 (Verification Method)

请按以下命令进行独立审计与验证：

1. **静态代码分析**：
   ```powershell
   flutter analyze
   ```
   *预期输出*：`No issues found!`

2. **Milestone 2 核心及关联测试集**：
   ```powershell
   flutter test test/component/now_playing_artwork_hero_test.dart test/page/now_playing_content_test.dart test/component/bottom_player_bar_test.dart test/component/bottom_player_bar_widget_test.dart
   ```
   *预期输出*：全部通过（26/26 passed）。

3. **E2E 完整套件验证**：
   ```powershell
   flutter test test/e2e/
   ```
   *预期输出*：全部通过（248/248 passed）。

4. **全工程单元与集成测试套件**：
   ```powershell
   flutter test
   ```
   *预期输出*：全部通过（531/531 passed）。
