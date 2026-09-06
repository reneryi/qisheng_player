# Project: Qisheng Player Transition & Layout Refactor

## Architecture
本项目对 Qisheng Player 的播放详情页（NowPlayingPage）、底栏播放条（BottomPlayerBar）、窗口外框布局（MainLayoutFrame）与全局 Shell 转场协同系统进行现代化重构。

系统核心分层与数据流：
1. **Window Frame Layer (`lib/component/main_layout_frame.dart`)**:
   - 负责响应窗口最大化、全屏与还原状态，通过平滑动画插值（`AnimatedPadding`, `AnimatedPositioned`，220ms `Curves.easeOutCubic`）驱动 `topInset`, `sideInset`, `bottomInset`, `dockInset`，杜绝硬跳变。
2. **Shell & Transition Coordination Layer (`lib/entry.dart`, `lib/component/now_playing_shell_underlay.dart`)**:
   - 单一驱动源协调底层主界面与 NowPlayingPage 的转场透明度与空间沉降（`Scale: 1.0 -> 0.96`），消除双重定时器透明度竞争。
3. **Hero Motion & Cover Art Layer (`lib/component/now_playing_artwork_hero.dart`, `lib/component/bottom_player_bar.dart`, `lib/page/now_playing_page/component_views.dart`)**:
   - 彻底移除黑胶唱机模式（`VinylRecordPlayerView`），统一标准化 1:1 纯画册封面卡片（`NowPlayingArtworkCard`）。
   - 实现底栏与详情页 Hero 子树完全对称，重构单层圆角与阴影插值的 `nowPlayingArtworkFlightShuttleBuilder` 与自然物理弧线 `NowPlayingArtworkRectTween`。
   - 分层解耦：手势监听、3D 拖拽变换、弥散光晕置于 Hero 外层，确保 Hero 飞行包围盒纯净无失真。
4. **Staged Reveal & High-FPS Render Layer (`lib/page/now_playing_page/page.dart`, `lib/page/now_playing_page/component_views.dart`)**:
   - 协调 6 阶段 Staged Reveal 动效（Hero 封面 0.0~1.0 -> AppBar 0.12~0.48 -> 标题/艺术家 0.24~0.68 -> 元数据/频谱 0.30~0.80 -> 歌词 0.34~0.90 -> 控制栏 >=0.82）。
   - 入场期锁定歌词滚动位置，光晕层与频谱条添加 `RepaintBoundary` 启用 GPU Texture 缓存，保障 60/120fps 满帧运行。

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Vinyl Code Clean Removal | 彻底删除 `lib/component/ui/vinyl_record_player_view.dart` 源码文件 | M1 | Survey Explorer 1 |
| 2 | Vinyl Settings & Pref Clean | 从 `AppSettings`、`ThemeSettings`、`SettingsPage` 清除 `showVinylRecord` 字段与 UI 开关 | M1 | Survey Explorer 1 |
| 3 | Pure Cover Layout Standardization | 在 `NowPlayingPage` 清除黑胶唱机分支，标准化纯画册正方形布局与自适应流 | M1 | Survey Explorer 1 |
| 4 | Hero Subtree Alignment & Decoupling | 抽象统一 `NowPlayingArtworkCard`，将 3D 手势、光晕剥离至 Hero 外部，保证两端 1:1 对齐 | M2 | Survey Explorer 2 |
| 5 | Flight Shuttle & Tween Geometry Refactor | 重构 `flightShuttleBuilder`（单层圆角/阴影插值）与 `NowPlayingArtworkRectTween`，消除闪烁、重影、跳跃与畸变 | M2 | Survey Explorer 2 |
| 6 | Coordinate Stability (No FittedBox) | 移除 `_ImmersiveArtworkStage` 中 `FittedBox` 对 Hero 目标包围盒的缩放污染 | M2 | Survey Explorer 2 |
| 7 | Shell Transition & Scale Push-back | 消除底层双重透明度竞争，实现转场单源驱动与底层 `Scale: 1.0 -> 0.96` 空间沉降动效 | M3 | Survey Explorer 3 |
| 8 | Staged Reveal Timeline Choreography | 精细化编排 6 阶段入场/退场时间轴，入场期间锁定歌词滚动避免抖动 | M3 | Survey Explorer 3 |
| 9 | 120fps GPU Texture Caching & Optimization | 弥散高斯模糊光晕外层增加 `RepaintBoundary`，惰性卸载闲置 `BackdropFilter` | M3 | Survey Explorer 3 |
| 10 | MainLayoutFrame Animated Insets | 将 `topInset`, `sideInset`, `bottomInset`, `dockInset` 封装为 `AnimatedPadding` / `AnimatedPositioned`，消除最大化/全屏硬跳变 | M4 | Survey Explorer 3 |
| 11 | Comprehensive E2E Verification & Tier 5 Hardening | 100% 通过 E2E 自动化测试，执行对抗性覆盖强化与静态分析 0 报错验证 | M5 | Project Orchestrator |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Vinyl Removal & Pure Cover Layout | 彻底删除 `vinyl_record_player_view.dart`，清理 `AppSettings` 与设置页开关，净化 `NowPlayingPage` 布局 | none | DONE |
| M2 | Hero Geometry & Subtree Alignment | 抽象统一 `NowPlayingArtworkCard`，剥离外部装饰与手势，重构 `flightShuttleBuilder` 与 `NowPlayingArtworkRectTween`，移除 `FittedBox` 坐标失真 | M1 | DONE |
| M3 | Shell Transition, Staged Reveal & 120fps Optimization | 统一转场透明度单驱动源，增加空间沉降推远，编排 6 阶段 Staged Reveal 时间轴，添加光晕 `RepaintBoundary` GPU 缓存 | M2 | DONE |
| M4 | MainLayoutFrame Insets Smooth Animation | 重构 `MainLayoutFrame`，使用 `AnimatedPadding` 与 `AnimatedPositioned` 平滑窗口边距变化 | none | DONE |
| M5 | Final E2E Test Pass & Adversarial Hardening | 验证 100% 通过 E2E 测试套件，开展 Tier 5 对抗性覆盖与静态分析 0 error/0 warning 终验 | M1, M2, M3, M4 | DONE |

## Interface Contracts
### NowPlayingArtworkHero Contract (`lib/component/now_playing_artwork_hero.dart`)
- **Hero Tag**: `const String nowPlayingArtworkHeroTag = 'now_playing_artwork_hero_tag';`
- **Widget**: `NowPlayingArtworkCard` (统一承载封面图片加载、淡入占位符、圆角裁切与内边框阴影)
- **Flight Builder**: `nowPlayingArtworkFlightShuttleBuilder` 仅对单层卡片的 `BorderRadius` 和 `BoxShadow` 进行平滑插值，杜绝双树 `Stack` 交叉淡入。
- **Tween**: `NowPlayingArtworkRectTween` 叠加平滑自然的物理抛物线微调（`arcAmplitude <= 14.0`），起终点包围盒宽高比恒定为 1:1。

### MainLayoutFrame Inset Animation Contract (`lib/component/main_layout_frame.dart`)
- **Animation Duration**: `const Duration(milliseconds: 220)`
- **Animation Curve**: `Curves.easeOutCubic`
- **Widgets**:
  - 内容区边距：`AnimatedPadding(padding: EdgeInsets.fromLTRB(sideInset + 4.0, topInset, sideInset + 4.0, 0))`
  - 底部 Dock 边距：`AnimatedPadding(padding: EdgeInsets.only(bottom: dockInset))`
  - 底栏绝对定位：`AnimatedPositioned(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, left: 0, right: 0, bottom: bottomInset)`

### Shell Route Transition Contract (`lib/entry.dart`)
- **Duration**: Forward 480ms, Reverse 400ms.
- **Underlay Transition**:
  - Opacity: `Interval(0.0, 0.48, curve: Curves.easeOutCubic)`
  - Scale: `Scale: 1.0 -> 0.96` 空间沉降（配合 `Interval(0.0, 0.48, curve: Curves.easeOutCubic)`）

## Code Layout
- `lib/component/ui/vinyl_record_player_view.dart`: [DELETED]
- `lib/app_settings.dart`: [MODIFIED - showVinylRecord removed]
- `lib/page/settings_page/theme_settings.dart`: [MODIFIED - ShowVinylRecordSwitch removed]
- `lib/page/settings_page/page.dart`: [MODIFIED - switch mount removed]
- `lib/component/now_playing_artwork_hero.dart`: [MODIFIED - unified NowPlayingArtworkCard, refactored shuttle & tween]
- `lib/component/bottom_player_bar.dart`: [MODIFIED - mounted NowPlayingArtworkCard in bottom bar Hero]
- `lib/page/now_playing_page/page.dart`: [MODIFIED - vinyl import removed, optimized staged reveal timeline]
- `lib/page/now_playing_page/component_views.dart`: [MODIFIED - vinyl branch removed, decoupled gestures/glow, RepaintBoundary caching]
- `lib/entry.dart`: [MODIFIED - unified underlay opacity & scale 0.96 transition]
- `lib/component/now_playing_shell_underlay.dart`: [MODIFIED - eliminated duplicate timer]
- `lib/component/main_layout_frame.dart`: [MODIFIED - AnimatedPadding & AnimatedPositioned]
- `test/`: [EXTENDED with 124 E2E master tests, 39 Tier 5 adversarial tests, all 535 tests passing]
