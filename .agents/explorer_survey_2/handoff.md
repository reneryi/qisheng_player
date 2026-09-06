# Handoff Report — Explorer 2 (Hero 动效子树与包围盒几何对齐勘探调研)

## 1. Observation (直接观察事实与代码定位)

### 1.1 关键代码与组件层级观察
- **底栏封面层级**（`lib/component/bottom_player_bar.dart:220-330`）：
  - 根节点为 `SizedBox(width: size, height: size)`（`size` 为 52 或 58）。
  - `Hero`（`tag: nowPlayingArtworkHeroTag`，第 319-325 行）被 `SpinningArtwork` 包裹。在播放状态下，`SpinningArtwork` 对 `Hero` 整体应用了 `AnimatedScale(scale: 1.03)`（第 350 行）。
  - `Hero` 内部节点为 `NowPlayingArtworkHeroFrame`（`lib/component/now_playing_artwork_hero.dart:67-96`），包含 `radius = 26.0` 的 `DecoratedBox`（带静态黑阴影）和 `ClipRRect(borderRadius: BorderRadius.circular(26.0))`。
  - 最内层 `artwork` 采用 `FutureBuilder` 监听 `audio.cover`（小图 `48 * dpr`，第 266 行），并在 `KeyedSubtree`（key 为 `'${audio.path}:${provider.hashCode}'`）内部又嵌套了一层 `ClipRRect(borderRadius: BorderRadius.circular(26.0))`。

- **播放详情页封面层级**（`lib/page/now_playing_page/component_views.dart:73-145, 320-658`）：
  - 祖先容器中存在 `_ImmersiveArtworkStage`（第 101 行）：`Align -> FittedBox(fit: BoxFit.scaleDown) -> Column`，将封面 `_NowPlayingArtwork` 和下方标题、元数据条、频谱条共同缩放。
  - `_NowPlayingArtwork`（第 580 行）根节点为 `SizedBox(width: widget.size, height: widget.size)`，外部包裹了弥散发光层（`ImageFiltered(blur: 32)`）与 `DecoratedBox(boxShadow: [accentGlow 32])`（第 617 行）。
  - `Hero`（`tag: nowPlayingArtworkHeroTag`，第 629-650 行）内部直接包裹了 `GestureDetector`（key: `'now-playing-artwork-drag'`）与 `Transform(_artworkTransform)`（3D 透视与拖拽旋转，第 642 行）。
  - `Transform` 内部包裹了 `NowPlayingArtworkHeroFrame`，但未传入 `radius: widget.radius`（默认回退到 `26.0`），内层 `Image` 硬编码了 `width: widget.size, height: widget.size`（如 380x380，第 508-509 行），且内层单独使用 `ClipRRect(borderRadius: BorderRadius.circular(widget.radius /* 14 或 24 */))`，并使用不同的 Key（`'${audio.path}:${provider.hashCode}:${size.round()}'`）。
  - 详情页内部仍存在 `if (showVinyl) ... VinylRecordPlayerView` 分支（第 552-577 行），在宽屏下构建 1.15:1 唱机。

- **飞行穿梭器与 Tween**（`lib/component/now_playing_artwork_hero.dart:7-65`）：
  - `NowPlayingArtworkRectTween` 在第 16-17 行通过 `offsetY = -1.0 * (travelDistance * 0.035).clamp(4.0, 18.0) * math.sin(t * math.pi)` 添加了固定的 Y 轴负偏移。
  - `nowPlayingArtworkFlightShuttleBuilder`（第 28-65 行）采用 `Stack(fit: StackFit.expand, children: [Opacity(1.0 - t, fromHero.child), Opacity(t, toHero.child)])` 叠加两棵完全不对称的 Widget 树进行交叉淡入。

---

## 2. Logic Chain (推理链条)

1. **闪烁（Flicker）的产生机制**：
   - 引用观测：底栏监听 `audio.cover`（小图，已解码在内存中），详情页监听 `audio.largeCover`（大图，异步 Future 尚未完成）；`nowPlayingArtworkFlightShuttleBuilder` 实例化 `toHero.child`。
   - 推理：在 Hero 飞行启动初期，`toHero.child` 的 `FutureBuilder` 处于等待状态并显示 `placeholder` 占位符。当飞行至中途大图解码完成后，占位符突然变为图片，产生显著的单帧闪白/闪黑现象。

2. **形变突变与残影（Ghosting & Distortion）的产生机制**：
   - 引用观测：`toHero.child` 内硬编码了 `Image(width: 380, height: 380)`；两端 `KeyedSubtree` 的 Key 格式不一致；`flightShuttleBuilder` 在 $58 \times 58$ 的飞行初始矩形中强制渲染 `toHero.child`，并在 $t=0.5$ 处同时以 50% 不透明度叠加两棵树。
   - 推理：硬编码尺寸强制在紧约束下被挤压，两个不同分辨率、不同 Key、不同裁剪半径的 Widget 树同时叠加，产生重影、模糊与比例失调。

3. **落点跳跃（Snap/Jump）的产生机制**：
   - 引用观测：`_ImmersiveArtworkStage` 中 `FittedBox(fit: BoxFit.scaleDown)` 包裹了整个 Column；`_NowPlayingStagedReveal` 在转场期间执行位移与淡入；`MainLayoutFrame` 边距在窗口缩放时变动。
   - 推理：`FittedBox` 动态缩放了子树 RenderBox，使得 Hero 在计算目标 Rect 时捕获了带缩放的全局坐标。当转场结束交付给页面时，页面子组件重绘或布局微调导致缩放因子微变，造成一帧内的物理落点瞬间位移（跳变）。

4. **圆角裁切突变的产生机制**：
   - 引用观测：底栏恒定 26px（52px 下为 50% 纯圆）；详情页目标为 24px（380px 下为圆角矩形）；`flightShuttleBuilder` 仅渐变透明度，未对 `BorderRadius` 做插值。
   - 推理：飞行过程中圆形与圆角矩形边缘撕裂重叠，落地瞬间边界硬切。

---

## 3. Caveats (注意事项与未探测区域)

1. **只读约束**：本调研严格保持只读，未对工程源码做任何实际改动。
2. **测试环境**：现有 Widget 测试（如 `test/page/now_playing_content_test.dart` 第 287 行）对 `const ValueKey('now-playing-artwork-drag')` 与 `Transform` 存在特定断言，在实施重构时需同步保证测试契约满足。
3. **网络封面延迟**：网络封面在弱网或冷启动未命中缓存时，建议严格保持单核组件的占位符平滑过渡逻辑。

---

## 4. Conclusion (最终结论与行动建议)

当前 Hero 动效的形变、闪烁与跳跃问题是由于**两端 Widget 树不对称、`flightShuttleBuilder` 粗暴的双树叠合、ImageProvider 分辨率与加载时差、`FittedBox` 破坏目标坐标系、以及手势与 Transform 侵入 Hero 内部**等综合因素导致的。

**核心行动建议**：
1. 在 `lib/component/now_playing_artwork_hero.dart` 中抽象出统一共享的 `NowPlayingArtworkCard`。
2. 严格遵循分层解耦原则：手势（`GestureDetector`）、3D 变换（`Transform`）、环境光晕（`Glow`）移至 `Hero` 外部；`Hero` 内部仅保留纯净单核卡片。
3. 在 `_ImmersiveArtworkStage` 中移除 `FittedBox`，改为自适应非缩放排版，保证包围盒坐标稳定。
4. 重构 `flightShuttleBuilder` 为单层圆角与阴影插值容器，彻底杜绝残影。
5. 彻底清除 `VinylRecordPlayerView` 黑胶唱机分支。

---

## 5. Verification Method (独立验证方法)

可通过以下命令与检查点独立验证调研结论与后续实施方案：

1. **代码检查**：
   - 检查 `lib/component/now_playing_artwork_hero.dart` 中的 `nowPlayingArtworkFlightShuttleBuilder`。
   - 检查 `lib/page/now_playing_page/component_views.dart` 第 101 行的 `FittedBox` 及第 642 行的 `Transform`。
   - 检查 `lib/component/bottom_player_bar.dart` 第 317 行的 `SpinningArtwork`。

2. **自动化测试套件执行**：
   ```powershell
   flutter test test/component/now_playing_artwork_hero_test.dart
   flutter test test/page/now_playing_content_test.dart
   flutter test test/component/bottom_player_bar_test.dart
   flutter test test/component/bottom_player_bar_widget_test.dart
   flutter test test/entry_transition_test.dart
   flutter analyze
   ```

3. **动效视觉验证**：
   - 启动应用，在播放音乐时点击底栏封面，观察向中心放大的飞行动画。
   - 观察飞行过程中是否仍有占位符闪烁、是否有双重重影、落地瞬间是否有位置/圆角跳变。
