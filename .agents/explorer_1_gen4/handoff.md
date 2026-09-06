# Handoff Report — R1 & R2 动效与转场系统调研

## 1. Observation

### 1.1 R1 播放详情页 (NowPlayingPage) 展开与收起
- **入口与触发**：
  - `lib/component/bottom_player_bar.dart:151-161`：`_BottomBarTrackSection` 点击调用 `openNowPlayingRoute(context)`。
  - `lib/page/now_playing_page/page.dart:361-365`：`_NowPlayingBackBtn` 点击调用 `AppNavigationState.instance.closeNowPlaying(context)`。
- **路由转场定义**：
  - `lib/entry.dart:304-331`：`NowPlayingTransitionPage` 设定 `transitionDuration = 320ms`，`reverseTransitionDuration = 260ms`，`opaque: false`。
  - `lib/entry.dart:141-166`：`_buildNowPlayingRouteTransition` 中同时包裹了 `FadeTransition` 与 `ScaleTransition(scale: Tween<double>(begin: 0.985, end: 1.0))`。
- **Hero 共享元素与轨迹**：
  - `lib/component/now_playing_artwork_hero.dart:7-26`：`NowPlayingArtworkRectTween` 中定义了抛物线向上位移 `offsetY = -1.0 * (travelDistance * 0.06).clamp(12.0, 40.0) * arcProgress`。
  - `lib/component/now_playing_artwork_hero.dart:43-73`：`NowPlayingArtworkHeroFrame` 默认圆角硬编码为 `nowPlayingArtworkHeroRadius = 26.0`。
  - `lib/page/now_playing_page/component_views.dart:520`：`_NowPlayingArtwork` 中实例化 `NowPlayingArtworkHeroFrame` 时未传入 `radius: widget.radius`（默认 26.0），而内部图片剪裁使用了 `widget.radius`（14/24）。
- **底栏控件断层显隐**：
  - `lib/page/now_playing_page/page.dart:198, 226-238`：`_AutoHideBottomPlayerBar` 只有在 `_routeAnimation.value >= 0.82` 时才将 `_visible` 设为 `true` 并执行 `AnimatedSlide(offset: Offset(0, 0.24))` 和 `AnimatedOpacity`。
- **底层 Shell 遮罩淡出**：
  - `lib/entry.dart:96-114`：`_buildAppRouteTransition` 监听 `secondaryAnimation` 计算 `underlayOpacity`（`Interval(0.0, 0.48)`）。
  - `lib/entry.dart:234-243`：`NowPlayingShellUnderlay` 监听 `nowPlayingPageActive` 触发 `AnimatedOpacity`。

### 1.2 R2 侧栏主导航与设置二级标签切换
- **侧栏主导航页面切换**：
  - `lib/component/side_nav.dart:77-86`：`onDestinationSelected` 调用 `context.go(desPath)`。
  - `lib/component/app_shell.dart:287-323`：`_ShellPageTransition` 在每次切换路由时通过 `TweenAnimationBuilder` 施加了 `offsetY = (1.0 - progress) * 8.0`（8px 垂直位移）和 `scale = 0.99 + 0.01 * progress`。
  - `lib/entry.dart:77-128`：`SlideTransitionPage` 的 `_buildAppRouteTransition` 对进场页面施加 `SlideTransition(begin: Offset(0, 0.02))`，对退场页面施加 `Transform.translate(offset: Offset(0, 8.0 * outgoingProgress))`。
- **设置页二级标签切换**：
  - `lib/page/settings_page/page.dart:41-49, 148-154`：`_selectCategory` 触发 `setState(() => _selectedCategory = category)`，右侧直接重绘 `ListView(children: _buildCategoryContent(_selectedCategory))` 并 `jumpTo(0)`，无任何过渡动画。

---

## 2. Logic Chain

1. **R1 动效顿挫与跳跃成因**：
   - 由 `lib/entry.dart:161` 可知，`_buildNowPlayingRouteTransition` 给整页施加了 `ScaleTransition`；Flutter Hero 飞行是基于 Overlay 全局绝对坐标系计算起止 Rect。当目标 Hero 所属页面发生动态中心缩放时，目标组件在飞行期间的场景坐标发生漂移，飞行完毕瞬间由于坐标对齐释放而发生微跳变（Snap）。
   - 由 `now_playing_artwork_hero.dart:17` 可知，`NowPlayingArtworkRectTween` 附加了非线性的向上拱起抛物线，破坏了桌面端平滑减速入场的物理手感。
   - 由 `page.dart:198` 可知，播放页内底栏在进场进度达到 0.82 之前处于完全隐藏状态，导致底层底栏先淡出消失，随后在 0.82 处底栏突然从底部滑入弹跳，产生视觉断层。

2. **R2 侧栏与设置页颠簸感成因**：
   - 由 `app_shell.dart:308` 与 `entry.dart:79, 121` 可知，在侧栏主导航切换时，两套垂直位移逻辑（AppShell 的 8px Y 位移与 entry.dart 的 2% Y 位移 + 8px 下沉位移）同时作用在页面容器上，导致了极为强烈的上下颠簸位移感。
   - 由 `settings_page/page.dart:148-154` 可知，设置分类切换直接替换 Widget 子树且无过渡组件，导致视图突兀瞬变。

---

## 3. Caveats

- **测试套件约束**：`test/entry_transition_test.dart` 和 `test/component/now_playing_artwork_hero_test.dart` 中包含对部分动画持续时间（260ms / 320ms）与 RectTween 的端点断言，重构时需保持参数兼容或适度同步测试用例。
- **未涉及 R3 与 R4 范畴**：本报告专注于 R1（NowPlayingPage 展开收起）与 R2（侧栏与设置页切换），未包含 R3（右键菜单磨砂与悬停）和 R4（详情页平滑横向推入）的详细分析。

---

## 4. Conclusion

1. **R1 解决方案**：
   - 移除 `_buildNowPlayingRouteTransition` 的 `ScaleTransition`，采用纯净流畅的 `FadeTransition`（320ms / 260ms，`Curves.easeOutCubic`）；
   - 优化 `NowPlayingArtworkRectTween` 为自然平滑的直线/微自然缓动过渡，修复 `NowPlayingArtworkHeroFrame` 的圆角同步问题；
   - 移除 `_AutoHideBottomPlayerBar` 的 0.82 硬阶跃，改为与 `NowPlayingRouteTransitionScope` 平滑渐显联动。
2. **R2 解决方案**：
   - 彻底移除 `_ShellPageTransition` 与 `_buildAppRouteTransition` 中的所有 Y 轴位移与缩放，改为纯粹的平滑交叉淡化（Cross-Fade / Fade Through）；
   - 在 `SettingsPage` 的内容区域引入 `AnimatedSwitcher` + `FadeTransition`，实现优雅轻盈的二级标签切换。

---

## 5. Verification Method

- **代码与测试验证**：
  - 运行静态检查：`flutter analyze` 或 `dart analyze`。
  - 运行过渡与路由相关测试：
    - `flutter test test/entry_transition_test.dart`
    - `flutter test test/component/app_shell_test.dart`
    - `flutter test test/component/now_playing_artwork_hero_test.dart`
    - `flutter test test/component/side_nav_test.dart`
- **交互验证**：
  - 点击底部播放栏左侧歌曲信息区，验证 NowPlayingPage 展开与收起过程中，封面飞行平滑对齐无跳跃，底栏无突兀消失或弹跳，背景与歌词渐显协调；
  - 切换侧边栏各项（音乐、艺术家、专辑、文件夹、歌单、设置），验证主界面原地平滑淡化，无任何上下颠簸位移；
  - 在设置页内切换分类标签（外观、播放、系统、关于），验证内容区域原地平滑溶解淡化。
