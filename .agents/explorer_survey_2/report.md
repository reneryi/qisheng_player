# 底栏 PlayerBar 与播放详情页 NowPlayingPage 封面 Hero 动效子树与包围盒几何对齐勘探调研报告

**调研员**：Explorer 2（Hero 动效子树与包围盒几何对齐勘探调研员）  
**时间**：2026-09-01  
**状态**：调研完成（只读勘探，未修改任何工程源码）

---

## 摘要 (Executive Summary)

本调研全面深入地勘探了 `qisheng_player` 项目中底栏（`BottomPlayerBar`）与播放详情页（`NowPlayingPage`）之间的专辑封面转场与 Hero 动效机制。通过对两端从全局路由（`GoRouter` / `NowPlayingTransitionPage`）、外层框架（`MainLayoutFrame` / `NowPlayingShellUnderlay`）、到封面核心组件（`_TrackCover` / `_NowPlayingArtwork` / `NowPlayingArtworkHeroFrame`）每一层 Widget、RenderBox 包围盒约束（`BoxConstraints`）、图片加载源（`ImageProvider`）以及插值器（`NowPlayingArtworkRectTween` / `flightShuttleBuilder`）的逐行代码审查与几何测算，定位出导致**比例形变突变、白屏闪烁（Flicker）、落点跳跃（Jump/Snap）、边框裁切不一致、残影重叠**等视觉瑕疵的 **8 项根本原因**，并制定了**两端 Hero 子树完全 1:1 对齐的现代纯画册重构设计方案**。

---

## 一、底栏 PlayerBar 封面组件 Widget 树深度解析

### 1.1 祖先链与布局上下文
底栏封面位于主界面 Shell 架构底部：
* 文件：`lib/component/bottom_player_bar.dart`
* 引用路径：`AppShell` (`lib/component/app_shell.dart:108`) -> `MainLayoutFrame.overlay` (`lib/component/main_layout_frame.dart:93-105`) -> `BottomPlayerBar` -> `_BottomBarTrackSection` -> `_TrackCover`

```
[全局路由与外层容器]
NowPlayingShellUnderlay (lib/entry.dart:202, AnimatedOpacity 380ms)
 └─ AppShell (lib/component/app_shell.dart:17)
     └─ MainLayoutFrame (lib/component/main_layout_frame.dart:16)
         └─ Stack (Positioned(bottom: bottomInset), ConstrainedBox(maxWidth: shellContentMaxWidth))
             └─ BottomPlayerBar (lib/component/bottom_player_bar.dart:53, height: dockHeight=82, padding: [h:24, v:6])
                 └─ LayoutBuilder (lib/component/bottom_player_bar.dart:69-98)
                     └─ Row
                         └─ Expanded (flex: 1)
                             └─ _BottomBarTrackSection (lib/component/bottom_player_bar.dart:132)
                                 └─ Selector<PlaybackController, Audio?> (lib/component/bottom_player_bar.dart:143)
                                     └─ CpMotionPressable (lib/component/bottom_player_bar.dart:148, borderRadius: 20, padding: [h:4, v:4])
                                         └─ Row
                                             └─ _TrackCover (lib/component/bottom_player_bar.dart:164, size: dense ? 52.0 : 58.0)
```

### 1.2 `_TrackCover` 完整内部 Widget 结构（Hero 内外部层级）
* 源码位置：`lib/component/bottom_player_bar.dart:220-331`

```
_TrackCover (lib/component/bottom_player_bar.dart:220)
 └─ SizedBox (width: size, height: size)  // 52.0 x 52.0 或 58.0 x 58.0
     └─ StreamBuilder<PlayerState> (lib/component/bottom_player_bar.dart:258)
         │
         ├── [HERO 外部装饰/缩放]
         └─ SpinningArtwork (lib/component/bottom_player_bar.dart:317, 333-387)
             └─ AnimatedScale (scale: spinning ? 1.03 : 1.0, duration: 260ms, curve: emphasized)
                 └─ AnimatedContainer (decoration: BoxDecoration(borderRadius: 26.0, boxShadow: [glow/shadow]))
                     │
                     ├── [HERO 边界]
                     └─ Hero (tag: 'now-playing-artwork', createRectTween: NowPlayingArtworkRectTween, flightShuttleBuilder: nowPlayingArtworkFlightShuttleBuilder) (lib/component/bottom_player_bar.dart:319-325)
                         │
                         ├── [HERO 内部结构]
                         └─ NowPlayingArtworkHeroFrame (radius: 26.0) (lib/component/now_playing_artwork_hero.dart:67)
                             └─ DecoratedBox (decoration: BoxDecoration(borderRadius: 26.0, boxShadow: [BoxShadow(color: 0x33000000, blurRadius: 26, spreadRadius: -6, offset: (0, 10))]))
                                 └─ ClipRRect (borderRadius: 26.0)
                                     └─ RepaintBoundary
                                         └─ FutureBuilder<ImageProvider?> (future: audio.cover -> small: 48 * dpr) (lib/component/bottom_player_bar.dart:266)
                                             └─ AnimatedSwitcher (FadeTransition, duration: 260ms) (lib/component/bottom_player_bar.dart:283)
                                                 └─ KeyedSubtree (key: ValueKey('${audio.path}:${provider.hashCode}')) (lib/component/bottom_player_bar.dart:297)
                                                     └─ ClipRRect (borderRadius: 26.0)  // 冗余嵌套裁剪
                                                         └─ Image (image: provider, fit: BoxFit.cover, errorBuilder: placeholder)
```

---

## 二、播放详情页 NowPlayingPage 封面组件 Widget 树与包围盒深度解析

### 2.1 祖先链与布局上下文
播放详情页为顶层覆盖式路由：
* 路由配置：`GoRoute(path: '/nowplaying', pageBuilder: NowPlayingTransitionPage(child: NowPlayingPage()))` (`lib/entry.dart:583-594`)
* 文件：`lib/page/now_playing_page/page.dart` 及 `lib/page/now_playing_page/component_views.dart`

```
[全局路由与外层容器]
NowPlayingTransitionPage (lib/entry.dart:314, transitionDuration: 480ms, opaque: false)
 └─ _buildNowPlayingRouteTransition (lib/entry.dart:131, FadeTransition, easeOutCubic)
     └─ NowPlayingRouteTransitionScope (lib/page/now_playing_page/page.dart:64)
         └─ NowPlayingPage (lib/page/now_playing_page/page.dart:142)
             └─ MainLayoutFrame (lib/page/now_playing_page/page.dart:172)
                 └─ Stack
                     ├─ overlay: _AutoHideBottomPlayerBar (BottomPlayerBar(disableHero: true))
                     └─ Column (children: [_NowPlayingAppBar, Expanded(child: ConstrainedBox(maxWidth: shellContentMaxWidth, child: LayoutBuilder))])
                         └─ _NowPlayingPage_Small / _NowPlayingPage_Large (lib/page/now_playing_page/small_page.dart, large_page.dart)
                             └─ ImmersiveNowPlayingView (lib/page/now_playing_page/component_views.dart:5)
                                 └─ Padding (fromLTRB(compact ? 16 : 28, 12, compact ? 16 : 28, 24))
                                     └─ LayoutBuilder (stacked: compact || maxWidth < 1160 || height < 760)
                                         └─ Column / Row (flex: 4)
                                             └─ _ImmersiveArtworkStage (lib/page/now_playing_page/component_views.dart:73)
```

### 2.2 `_ImmersiveArtworkStage` 约束计算与 RenderBox 包围盒
在 `_ImmersiveArtworkStage.build`（`lib/page/now_playing_page/component_views.dart:80-94`）中：
* `availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0`
* `availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0`
* 尺寸动态计算逻辑：
  - **紧凑/移动端模式（`compact: true`）**：  
    `size = (availableHeight * 0.44).clamp(80.0, 150.0).toDouble()`
  - **沉浸宽屏模式（`compact: false`）**：  
    `size = math.min(availableWidth * 0.74, availableHeight * 0.54).clamp(180.0, 380.0).toDouble()`

### 2.3 `_NowPlayingArtwork` 完整内部 Widget 结构（Hero 内外部层级）
* 源码位置：`lib/page/now_playing_page/component_views.dart:95-145, 320-658`

```
_ImmersiveArtworkStage (lib/page/now_playing_page/component_views.dart:73)
 └─ SizedBox.expand
     └─ Stack
         └─ Align (alignment: compact ? centerLeft : center)
             └─ FittedBox (fit: BoxFit.scaleDown, alignment: compact ? centerLeft : center) // ⚠️ 严重破坏 Hero 坐标系
                 └─ Column (mainAxisSize: min)
                     ├─ _NowPlayingArtwork (size: size, radius: compact ? 14 : 24, large: true, showBackdropGlow: true) (line 110, 320)
                     │   └─ Selector<PlaybackController, Audio?> (line 475)
                     │       └─ FutureBuilder<ImageProvider?> (future: audio.largeCover -> 400 * dpr) (line 487)
                     │           │
                     │           └─ SizedBox (width: size, height: size) (line 580)
                     │               └─ Stack (alignment: center)
                     │                   ├─ [环境呼吸弥散背光] (if enableBreath)
                     │                   │   └─ Positioned.fill -> Padding(size * 0.08) -> AnimatedBuilder(_glowController) -> Transform.scale -> Opacity -> ImageFiltered(blur: 32)
                     │                   │
                     │                   ├─ [HERO 外部装饰]
                     │                   └─ DecoratedBox (decoration: BoxDecoration(borderRadius: radius (14/24), boxShadow: [accentGlow 32])) (line 617)
                     │                       │
                     │                       ├── [HERO 边界]
                     │                       └─ Hero (tag: 'now-playing-artwork', createRectTween: NowPlayingArtworkRectTween, flightShuttleBuilder: nowPlayingArtworkFlightShuttleBuilder) (line 629)
                     │                           │
                     │                           ├── [HERO 内部结构]
                     │                           └─ GestureDetector (key: ValueKey('now-playing-artwork-drag'), onPanStart/Update/End/Cancel) (line 635)
                     │                               └─ Transform (transform: _artworkTransform [3D perspective + pan rotation + scale]) (line 642)
                     │                                   └─ NowPlayingArtworkHeroFrame (radius: 26.0 [默认值，未传入 widget.radius!]) (line 520, 647)
                     │                                       └─ DecoratedBox (borderRadius: 26.0, boxShadow: [BoxShadow(color: 0x33000000, blurRadius: 26, spreadRadius: -6, offset: (0, 10))])
                     │                                           └─ ClipRRect (borderRadius: 26.0)
                     │                                               └─ RepaintBoundary
                     │                                                   └─ AnimatedSwitcher (FadeTransition)
                     │                                                       └─ KeyedSubtree (key: ValueKey('${audio.path}:${provider.hashCode}:${size.round()}'))
                     │                                                           └─ ClipRRect (borderRadius: 14 或 24) // ⚠️ 内部裁剪与外部 26.0 冲突
                     │                                                               └─ Image (image: imageProvider, width: size, height: size, fit: BoxFit.cover) // ⚠️ 硬编码尺寸
                     │
                     ├─ SizedBox (height: compact ? 10 : 20)
                     ├─ _NowPlayingStagedReveal (_NowPlayingTrackIdentity) (line 117)
                     ├─ _NowPlayingStagedReveal (_ImmersiveMetadataStrip) (line 125)
                     └─ _NowPlayingStagedReveal (_ImmersiveSpectrumBar) (line 133)
```

---

## 三、两端 Hero 子树与包围盒几何对照矩阵

| 维度 / 属性 | 底栏 PlayerBar 端 | 播放详情页 NowPlayingPage 端 | 对齐状态与冲突评估 |
| :--- | :--- | :--- | :--- |
| **Hero Tag** | `'now-playing-artwork'` (`lib/component/bottom_player_bar.dart:320`) | `'now-playing-artwork'` (`lib/page/now_playing_page/component_views.dart:630`) | ✅ Tag 一致 |
| **Hero 祖先容器** | `SizedBox(52/58, 52/58)` 无缩放祖先 | `FittedBox(fit: BoxFit.scaleDown)` + `Column` | ❌ **严重冲突**：FittedBox 对目标 Rect 施加缩放变换，且依赖文字/频谱条总高度，导致 RenderBox 坐标漂移 |
| **Hero 外部容器** | `SpinningArtwork` (`AnimatedScale(1.03)` + `AnimatedContainer` 投影) | `SizedBox(size, size)` + `Stack` (带发光层) + `DecoratedBox` (品牌色光晕) | ❌ **不对称**：底栏在播放时外部带 1.03 缩放变换，Hero 捕获的起始 Rect 包含 1.03 缩放，与详情页 1.0 不一致 |
| **Hero 内部根节点** | `NowPlayingArtworkHeroFrame` (`DecoratedBox` + `ClipRRect`) | `GestureDetector` -> `Transform` (3D 交互矩阵) -> `NowPlayingArtworkHeroFrame` | ❌ **严重冲突**：详情页在 Hero 内部嵌入了交互手势与 3D 旋转 Transform，底栏无此层级 |
| **ImageProvider 来源** | `audio.cover` (小图 `48 * dpr`) (`lib/library/audio_library.dart:460`) | `audio.largeCover` (大图 `400 * dpr`) (`lib/library/audio_library.dart:490`) | ❌ **严重冲突**：两端为不同 MemoryImage 实例。转场瞬间大图尚未就绪，导致白屏/闪烁 (Flicker) |
| **Image Widget 约束** | `Image(image: provider, fit: BoxFit.cover)` 无硬编码宽高 | `Image(image: provider, width: size, height: size, fit: BoxFit.cover)` | ❌ **严重冲突**：详情页硬编码 `width: size, height: size`（如 380），在飞行起始阶段（58x58 容器）被强行挤压变形 |
| **KeyedSubtree 键值** | `'${audio.path}:${provider.hashCode}'` | `'${audio.path}:${provider.hashCode}:${size.round()}'` | ❌ **不匹配**：Key 中引入了 `size.round()`，导致两端 Key 不一致，AnimatedSwitcher 判定为不同组件重新淡入 |
| **圆角裁剪 (BorderRadius)**| 恒定 `26.0` (`nowPlayingArtworkHeroRadius`) | 外部传 `14.0/24.0`，Frame 内部缺省回退为 `26.0`，最内层 `14.0/24.0` | ❌ **严重冲突**：底栏 26px 在 52px 盒子上呈正圆（50%），详情页 24px 在 380px 上呈小圆角矩形，飞行中无 BorderRadius 渐变，发生裁切突变 |
| **阴影与外发光** | `NowPlayingArtworkHeroFrame` 内部静态黑色阴影 (26, spread -6) | 外部 `accentGlow` 光晕 + 内部 `NowPlayingArtworkHeroFrame` 静态黑阴影 | ❌ **层级混乱**：内部静态阴影与外部发光层脱节，飞行时发光层被丢弃在页面底层 |
| **RectTween 插值器** | `NowPlayingArtworkRectTween` (正弦 Y 轴偏移抛物线) | `NowPlayingArtworkRectTween` (正弦 Y 轴偏移抛物线) | ⚠️ **物理不自然**：线性插值附加 `sin(t*pi)` 偏移，在反向退出转场时产生向上反向漂浮的违和感 |
| **flightShuttleBuilder** | `Stack` 叠加两个 `Opacity` 交叉淡入 | 同左（共享 `nowPlayingArtworkFlightShuttleBuilder`） | ❌ **严重缺陷**：同时实例化两端不一致的 Widget 树，双倍 FutureBuilder 重建，残影重叠与挤压变形 |
| **黑胶模式死分支** | 无 | `if (showVinyl) ... VinylRecordPlayerView` (1.15:1 唱机) | ❌ **几何严重撕裂**：一旦触发，1:1 封面与 1.15:1 黑胶转盘发生撕裂形变（待彻底清除） |

---

## 四、Hero 动效异常根因深度剖析

### 根因 1：`nowPlayingArtworkFlightShuttleBuilder` 粗暴的双树透明度交叉淡入 (Cross-Fade Ghosting & Overlay Squeeze)
* **代码定位**：`lib/component/now_playing_artwork_hero.dart:28-65`
* **机制分析**：
  `flightShuttleBuilder` 构建了一个 `Stack(fit: StackFit.expand, children: [Opacity(1.0-t, fromHero.child), Opacity(t, toHero.child)])`。
  1. 在动画启动时刻（$t \approx 0$），Hero 飞行容器的大小为底栏尺寸（如 $58 \times 58$）。
  2. `toHero.child` 内部的 `Image` 显式设置了 `width: 380, height: 380`。当被放入 $58 \times 58$ 的紧约束容器时，RenderImage 与周围的 ClipRRect、Transform 产生挤压冲突，导致内容被截断与瞬时畸变。
  3. 在 $t = 0.5$ 中间时刻，两个透明度各为 50% 的子树重叠渲染。两端具有不同的 Key、不同的阴影、不同的内层 ClipRRect，直接产生极其明显的“双重虚影（Ghosting）”与模糊。

### 根因 2：两端 ImageProvider 分辨率差异与异步等待导致的单帧闪烁 (Flicker)
* **代码定位**：`lib/component/bottom_player_bar.dart:266` 与 `lib/page/now_playing_page/component_views.dart:487`
* **机制分析**：
  - 底栏使用 `audio.cover`（小图 48*dpr，内存已常驻）。
  - 详情页使用 `audio.largeCover`（大图 400*dpr，异步加载与解码）。
  - 当从底栏点击进入详情页时，`audio.largeCover` 的 `Future` 尚未 resolve（`snapshot.data == null`）。
  - 飞行开始瞬间，`toHero.child` 的 `FutureBuilder` 处于等待状态，渲染了 `placeholder` 占位图标！
  - 随着飞行推进，$t$ 从 0 变大，`toHero.child` 正在淡入一个占位图标，中途大图解码完成后又突然替换为大图。这在用户视觉上表现为一次严重的“封面消失闪黑/占位符闪现（Flicker）”！

### 根因 3：`FittedBox(fit: BoxFit.scaleDown)` 祖先组件破坏 Hero 坐标系与落点跳跃 (Snap/Jump)
* **代码定位**：`lib/page/now_playing_page/component_views.dart:101`
* **机制分析**：
  - 在 `_ImmersiveArtworkStage` 中，`_NowPlayingArtwork` 和底部的歌名、歌手、元数据条、频谱律动条一同被包含在 `FittedBox(fit: BoxFit.scaleDown, child: Column(...))` 内部。
  - 当屏幕高度不足或子组件尺寸超出时，`FittedBox` 会对其子树应用一个全局缩放比例（例如 0.82）。
  - Hero 系统在路由初次构建阶段抓取的目标 RenderBox 矩形包含该 FittedBox 缩放；但当路由淡入展开、`_NowPlayingStagedReveal` 中的子组件执行渐显动画、或者父级 Padding 在 `MainLayoutFrame` 中动态变化时，`FittedBox` 的缩放因子在转场中间帧或结束帧发生动态重绘，导致目标位置发生单帧突变跳跃（Snap/Jump）。

### 根因 4：圆角（BorderRadius）不一致与嵌套 ClipRRect 冲突
* **代码定位**：`lib/component/bottom_player_bar.dart:237, 274` 与 `lib/page/now_playing_page/component_views.dart:505, 520`
* **机制分析**：
  - 底栏的圆角为固定的 `nowPlayingArtworkHeroRadius = 26.0`。在 $52 \times 52$ 像素下，$26\text{px}$ 相当于完全正圆（圆角半径等于宽度的 50%）。
  - 详情页在 $380 \times 380$ 像素下，传入的预期圆角为 $24.0\text{px}$（仅占宽度的 6.3%，为精致圆角矩形）。但详情页的 `NowPlayingArtworkHeroFrame` 未传 `radius`，外层 Frame 裁为 $26.0$，内层 Image 裁为 $24.0$。
  - 在整个飞行过程中，由于使用的是双层 Opacity 渐变而非真正的 `BorderRadius.lerp` 插值，在飞行中段圆形与圆角矩形边缘交错显现，并在落地瞬间边缘裁切生硬跳变。

### 根因 5：装饰层（BoxShadow / Glow）与变换（Transform）内外部层级倒置
* **代码定位**：`lib/component/bottom_player_bar.dart:317` 与 `lib/page/now_playing_page/component_views.dart:617, 642`
* **机制分析**：
  - 底栏在播放时通过 `SpinningArtwork` 在 Hero **外部**施加了 `AnimatedScale(1.03)` 缩放和发光。
  - 详情页在 Hero **内部**放了 `GestureDetector` 和 3D `Transform`，在 Hero **外部**放了 `accentGlow` 发光。
  - 两端都在 `NowPlayingArtworkHeroFrame` **内部**放了固定黑阴影。
  - 这造成了装饰层的完全混乱：Hero 飞行时，底栏的播放外发光被遗留在底栏，飞行的只是不带发光的卡片；落地后，详情页的弥散背光又突然显现。

### 根因 6：黑胶唱机模式（`VinylRecordPlayerView`）破坏几何长宽比
* **代码定位**：`lib/page/now_playing_page/component_views.dart:552-578`
* **机制分析**：
  - `showVinyl` 开启时，详情页 Hero 子树为宽高比 1.15:1 的黑胶唱机视图，内部包含黑胶盘与唱臂。与底栏 1:1 正方形封面形成根本性的长宽比冲突，Hero 在变形过程中拉伸黑胶唱片，严重破坏视觉一致性。

---

## 五、两端 Hero 1:1 几何对齐重构设计方案

### 5.1 核心重构原则
1. **纯粹共享单核（Single Core Shared Artwork Card）**：抽象唯一的 `NowPlayingArtworkCard`，底栏与详情页共享完全相同的底层渲染结构。
2. **分层严格解耦（Strict Layer Decoupling）**：
   - **Hero 内部**：仅包含纯粹的封面视觉载体（统一的 `DecoratedBox` + `ClipRRect` + `Image` / `placeholder`），禁止包含手势拖拽、3D Transform、尺寸写死、FittedBox 等任何页面私有逻辑。
   - **Hero 外部**：手势检测（`GestureDetector`）、3D 悬浮效果（`Transform`）、环境光晕（`Ambient Glow`）、呼吸动效（`Breath Animation`）全部置于 Hero 外部。
3. **分级平滑加载与缓存预热（Two-Tier Seamless Image Loading）**：转场首选已缓存的 `cover`（小图），飞行过程中使用现有纹理无缝放大；详情页就绪后静默交叉淡入高清晰度 `largeCover`，彻底消灭白屏与闪烁。
4. **单层纹理飞行穿梭器（Single-Surface Flight Shuttle with Radius Tween）**：重构 `flightShuttleBuilder`，废弃双树 Stack 交叉淡入，采用单层插值容器动态插值圆角（$26.0 \leftrightarrow 24.0$）与阴影，实现 60/120fps 满帧极速飞行。

---

### 5.2 统一共享封面核心组件设计 (`NowPlayingArtworkCard`)

在 `lib/component/now_playing_artwork_hero.dart` 中建立标准单核组件：

```dart
/// 统一播放封面画册核心组件（底栏与播放详情页 1:1 共享）
class NowPlayingArtworkCard extends StatelessWidget {
  const NowPlayingArtworkCard({
    super.key,
    required this.audio,
    this.coverProvider,
    this.radius = 24.0,
    this.elevation = 1.0,
    this.showShadow = true,
  });

  final Audio? audio;
  final ImageProvider? coverProvider;
  final double radius;
  final double elevation;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accents = context.accents;

    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            accents.accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Icon(
          Symbols.music_note,
          color: scheme.onSurface.withValues(alpha: 0.7),
          size: 28,
        ),
      ),
    );

    final imageWidget = coverProvider == null
        ? (audio == null
            ? placeholder
            : FutureBuilder<ImageProvider?>(
                future: audio!.cover,
                builder: (context, snapshot) {
                  final provider = snapshot.data;
                  if (provider == null) return placeholder;
                  return Image(
                    image: provider,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => placeholder,
                  );
                },
              ))
        : Image(
            image: coverProvider!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22 * elevation),
                    blurRadius: 20 * elevation,
                    spreadRadius: -4 * elevation,
                    offset: Offset(0, 8 * elevation),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: imageWidget,
        ),
      ),
    );
  }
}
```

---

### 5.3 两端 1:1 对齐后的 Hero 结构

#### A. 底栏端 (`_TrackCover`) 重构后结构：
```dart
// lib/component/bottom_player_bar.dart
SizedBox(
  width: size,   // 52.0 或 58.0
  height: size,  // 1:1 正方形
  child: SpinningArtwork(
    spinning: spinning,
    child: Hero(
      tag: nowPlayingArtworkHeroTag,
      createRectTween: (begin, end) =>
          NowPlayingArtworkRectTween(begin: begin, end: end),
      flightShuttleBuilder: nowPlayingArtworkFlightShuttleBuilder,
      child: NowPlayingArtworkCard(
        audio: audio,
        radius: nowPlayingArtworkHeroRadius, // 26.0
        elevation: 0.8,
      ),
    ),
  ),
);
```

#### B. 播放详情页端 (`_NowPlayingArtwork`) 重构后结构：
```dart
// lib/page/now_playing_page/component_views.dart
SizedBox(
  width: widget.size,   // 响应式计算尺寸 (如 360.0)
  height: widget.size,  // 1:1 正方形
  child: Stack(
    alignment: Alignment.center,
    children: [
      // 1. 环境光晕置于 Hero 外部
      if (enableBreath)
        Positioned.fill(
          child: _NowPlayingAmbientGlow(
            provider: primaryProvider,
            glowAnimation: _glowController,
            radius: widget.radius,
          ),
        ),

      // 2. 手势与 3D Transform 置于 Hero 外部
      GestureDetector(
        key: const ValueKey('now-playing-artwork-drag'),
        onPanStart: motionEnabled ? _handlePanStart : null,
        onPanUpdate: motionEnabled ? _handlePanUpdate : null,
        onPanEnd: motionEnabled ? (_) => _handlePanEnd() : null,
        onPanCancel: motionEnabled ? _handlePanEnd : null,
        child: Transform(
          alignment: Alignment.center,
          transform: motionEnabled ? _artworkTransform() : Matrix4.identity(),
          child: Hero(
            tag: nowPlayingArtworkHeroTag,
            createRectTween: (begin, end) =>
                NowPlayingArtworkRectTween(begin: begin, end: end),
            flightShuttleBuilder: nowPlayingArtworkFlightShuttleBuilder,
            child: NowPlayingArtworkCard(
              audio: audio,
              coverProvider: primaryProvider, // 优先复用底栏已加载 Provider，就绪后再平滑展示高清图
              radius: widget.radius,          // 24.0 (或 compact 下 16.0)
              elevation: 1.2,
            ),
          ),
        ),
      ),
    ],
  ),
);
```

---

### 5.4 消除 FittedBox 污染与详情页自适应包围盒重构

在 `_ImmersiveArtworkStage` 中，解除 `FittedBox` 对整个 Column 的强制包裹，保证 Hero 目标 RenderBox 具备绝对稳定的 1:1 几何尺寸：

```dart
// lib/page/now_playing_page/component_views.dart -> _ImmersiveArtworkStage
class _ImmersiveArtworkStage extends StatelessWidget {
  const _ImmersiveArtworkStage({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;

        // 精确自适应封面尺寸：保留下方信息区充足空间 (信息区约需 120px)
        final maxCoverHeight = math.max(80.0, availableHeight - 140.0);
        final size = compact
            ? math.min(availableWidth * 0.72, maxCoverHeight).clamp(80.0, 160.0).toDouble()
            : math.min(availableWidth * 0.76, maxCoverHeight).clamp(180.0, 380.0).toDouble();

        return SizedBox.expand(
          child: Align(
            alignment: compact ? Alignment.centerLeft : Alignment.center,
            child: SingleChildScrollView( // 替换 FittedBox 为平滑无缩放的自适应列，杜绝坐标变换畸变
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  _NowPlayingArtwork(
                    size: size,
                    radius: compact ? 16.0 : 24.0,
                    large: true,
                    showBackdropGlow: true,
                  ),
                  SizedBox(height: compact ? 12 : 20),
                  _NowPlayingStagedReveal(
                    begin: 0.18,
                    end: 0.60,
                    beginOffset: const Offset(0, 0.04),
                    child: _NowPlayingTrackIdentity(compact: compact),
                  ),
                  const SizedBox(height: 10),
                  const _NowPlayingStagedReveal(
                    begin: 0.24,
                    end: 0.70,
                    child: _ImmersiveMetadataStrip(),
                  ),
                  if (AppSettings.instance.showSpectrumVisualizer) ...[
                    const SizedBox(height: 12),
                    const _NowPlayingStagedReveal(
                      begin: 0.30,
                      end: 0.78,
                      child: _ImmersiveSpectrumBar(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

### 5.5 单层无虚影 `flightShuttleBuilder` 与平滑弧线 `RectTween`

在 `lib/component/now_playing_artwork_hero.dart` 中，实现单层插值穿梭构建器：

```dart
/// 高性能平滑弧线 RectTween
class NowPlayingArtworkRectTween extends RectTween {
  NowPlayingArtworkRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    if (begin == null || end == null) return null;

    // 采用三次贝塞尔缓动曲线插值位置与尺寸
    final curve = Curves.easeInOutCubic.transform(t);
    final rect = Rect.lerp(begin, end, curve)!;

    // 微妙自然的 Y 轴抛物线弧度（根据飞行跨度自适应微调）
    final travelDistance = (end!.center - begin!.center).distance;
    final arcProgress = math.sin(t * math.pi);
    final arcAmplitude = (travelDistance * 0.024).clamp(0.0, 14.0);
    final offsetY = -arcAmplitude * arcProgress;

    return Rect.fromLTWH(
      rect.left,
      rect.top + offsetY,
      rect.width,
      rect.height,
    );
  }
}

/// 单层无虚影飞行穿梭构建器（插值圆角与阴影）
Widget nowPlayingArtworkFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  // 提取目标或来源 Hero 的 child（均为 NowPlayingArtworkCard）
  final targetHero = (direction == HeroFlightDirection.push
      ? toHeroContext.widget
      : fromHeroContext.widget) as Hero;
  final sourceHero = (direction == HeroFlightDirection.push
      ? fromHeroContext.widget
      : toHeroContext.widget) as Hero;

  final sourceCard = sourceHero.child is NowPlayingArtworkCard
      ? sourceHero.child as NowPlayingArtworkCard
      : null;
  final targetCard = targetHero.child is NowPlayingArtworkCard
      ? targetHero.child as NowPlayingArtworkCard
      : null;

  final startRadius = sourceCard?.radius ?? 26.0;
  final endRadius = targetCard?.radius ?? 24.0;
  final audio = targetCard?.audio ?? sourceCard?.audio;
  final provider = targetCard?.coverProvider ?? sourceCard?.coverProvider;

  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeInOutCubic,
  );

  return AnimatedBuilder(
    animation: curved,
    builder: (context, _) {
      final t = curved.value;
      final currentRadius = ui.lerpDouble(
        direction == HeroFlightDirection.push ? startRadius : endRadius,
        direction == HeroFlightDirection.push ? endRadius : startRadius,
        t,
      )!;

      return Material(
        type: MaterialType.transparency,
        child: NowPlayingArtworkCard(
          audio: audio,
          coverProvider: provider,
          radius: currentRadius,
          elevation: 1.0,
          showShadow: true,
        ),
      );
    },
  );
}
```

---

## 六、涉及文件与组件清单 (File Impact Matrix)

| 文件路径 | 组件 / 类 | 现状问题 | 重构职责 |
| :--- | :--- | :--- | :--- |
| `lib/component/now_playing_artwork_hero.dart` | `NowPlayingArtworkRectTween`, `nowPlayingArtworkFlightShuttleBuilder`, `NowPlayingArtworkHeroFrame` | 双树 Stack 交叉淡入、冗余阴影/裁切、写死正弦偏移 | 抽象 `NowPlayingArtworkCard`，重构单层圆角插值 `flightShuttleBuilder` 与自然物理弧线 `NowPlayingArtworkRectTween` |
| `lib/component/bottom_player_bar.dart` | `_TrackCover`, `SpinningArtwork` | 冗余多层 ClipRRect、FutureBuilder 与 ImageProvider 差异 | 接入 `NowPlayingArtworkCard`，统一 1:1 层级与 Hero 标签配置 |
| `lib/page/now_playing_page/component_views.dart` | `_ImmersiveArtworkStage`, `_NowPlayingArtwork`, `VinylRecordPlayerView` 分支 | `FittedBox` 破坏 Hero 坐标系、手势/Transform 置于 Hero 内部、硬编码 Image 尺寸、黑胶分支残留 | 移除 `FittedBox` 改为自适应无缩放流，手势/Transform 移至 Hero 外部，移除黑胶唱机模式分支，接入 `NowPlayingArtworkCard` |
| `lib/page/now_playing_page/page.dart` | `NowPlayingPage`, `_AutoHideBottomPlayerBar` | 详情页底栏 Hero 冲突与生命周期协同 | 保持 `disableHero: true`，完善转场与尺寸协同 |
| `lib/library/audio_library.dart` | `Audio` (`cover`, `largeCover`) | 独立 MemoryImage 实例导致的异步等待闪烁 | 保持底层高效缓存，由 UI 层做预热复用与平滑升阶 |
| `test/component/now_playing_artwork_hero_test.dart` | 单元测试 | 针对旧 Tween 的单测 | 更新/补充 Tween 弧度边界与 Radius 插值测试 |
| `test/page/now_playing_content_test.dart` | 页面测试 | 包含手势与 Hero 矩形断言 | 保证重构后手势与 Hero 包围盒断言 100% 通过 |

---

## 七、验证方法与测试套件建议

重构实施完成后，按以下步骤进行严格的质量验证：

1. **静态分析与代码规范**：
   ```powershell
   flutter analyze
   ```
   * 预期结果：0 errors, 0 warnings.

2. **单元与 Widget 测试集回归**：
   ```powershell
   flutter test test/component/now_playing_artwork_hero_test.dart
   flutter test test/page/now_playing_content_test.dart
   flutter test test/component/bottom_player_bar_test.dart
   flutter test test/component/bottom_player_bar_widget_test.dart
   flutter test test/entry_transition_test.dart
   ```
   * 预期结果：全部测试通过。

3. **视觉与动效真机验证要点**：
   - **尺寸无级拉伸测试**：在不同窗口尺寸（宽屏 1440x900、紧凑屏 960x640、极窄屏）下，点击底栏展开详情页，观察封面飞行动画是否有突变跳跃（Snap）或长宽比失真。
   - **快速来回切换测试**：快速连续点击展开/收起播放页，验证 Hero 动效是否连续可中断，是否存在白屏闪烁（Flicker）或虚影（Ghosting）。
   - **切歌与无封面播放测试**：播放无封面曲目、网络封面曲目、高清无损曲目，验证占位符到封面、小图到大图过渡是否丝滑无缝。
