# Handoff Report — Milestone 3: Shell 联动转场、Staged Reveal 阶段式揭示与 120fps GPU 优化

## 1. Observation (代码观察与测试事实)

1. **底层 Shell 与详情页透明度竞争及空间推远** (`lib/entry.dart`, `lib/component/now_playing_shell_underlay.dart`):
   - 原代码中 `NowPlayingShellUnderlay` 采用 380ms 定时器驱动 `AnimatedOpacity`，与 `_buildAppRouteTransition` 中 `secondaryAnimation` (Interval 0.0~0.48) 存在双重透明度乘法级联，导致底层过快变黑；退场时底层提前透出。
   - 原 `_buildAppRouteTransition` 缺乏纵深沉降，底层主界面为静态原尺寸淡出。
2. **6 阶段 Staged Reveal 动效编排与歌词滚动锁定** (`lib/page/now_playing_page/page.dart`, `lib/page/now_playing_page/component_views.dart`):
   - Hero 封面完整覆盖 (0.0 ~ 1.0)；
   - AppBar 顶部操作栏 (0.12 ~ 0.48)；
   - 歌曲标题 / 艺术家信息 (0.24 ~ 0.68)；
   - 元数据胶囊与频谱条原为 0.30~0.75 与 0.35~0.80，现统一对齐为 (0.30 ~ 0.80)；
   - 歌词视图 (0.34 ~ 0.90)，原代码在入场期间若触发切歌或初始滚动，`Scrollable.ensureVisible` 的动画位移会与父级 `_NowPlayingStagedReveal` 的 `SlideTransition` 叠加产生纵向抖动；
   - 底部控制栏在 `animation.value >= 0.82` 时自动唤醒。
3. **120fps 高刷性能与 GPU 缓存优化** (`lib/page/now_playing_page/component_views.dart`):
   - 封面 32px 呼吸发光层中的 `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32))` 每帧重绘消耗 GPU 光栅化资源；
   - 歌词缩放提示胶囊中的 `BackdropFilter` 在闲置状态（`_showScaleIndicator == false`）下仍常驻在绘制树中，占用 GPU 采样通道。

---

## 2. Logic Chain (推理与实施逻辑链)

1. **单源驱动统一与空间沉降 (Scale 1.0 -> 0.96)**:
   - 将 `NowPlayingShellUnderlay` 提取至独立文件 `lib/component/now_playing_shell_underlay.dart`，移除 380ms 独立慢速定时器，将其设为 `duration: Duration.zero`，仅作为状态与指针拦截守卫。
   - 在 `lib/entry.dart` 的 `_buildAppRouteTransition` 中，当 `isNowPlayingAbove == true` 时，统一计算 `underlayFactor = Interval(0.0, 0.48, curve: Curves.easeOutCubic).transform(secondaryAnimation.value)`，驱动 `underlayOpacity = 1.0 - underlayFactor` 与 `underlayScale = 1.0 - 0.04 * underlayFactor`（`Scale: 1.0 -> 0.96`），并通过 `Transform.scale` 包装，消除双重透明度竞争，实现深度推远转场。
2. **Staged Reveal 精细编排与歌词滚动入场锁定**:
   - 在 `component_views.dart` 中将 `_ImmersiveMetadataStrip` 与 `_ImmersiveSpectrumBar` 的 Staged Reveal 区间精细化对齐为 `0.30 ~ 0.80`。
   - 在 `_CenteredLyricViewState._scrollToLine` 中，通过 `NowPlayingRouteTransitionScope.maybeOf(context)` 检查入场状态，当 `routeAnimation.value < 0.95` 时，强制令 `effectiveAnimated = false` (`duration: Duration.zero`) 实行静态定位，待入场彻底完成后恢复平滑动效，彻底杜绝位移速度叠加抖动。
3. **120fps GPU 纹理缓存与 BackdropFilter 惰性挂载**:
   - 在封面 32px 高斯模糊 `ImageFiltered` 外层显式包裹 `RepaintBoundary`，使 Flutter 将高斯模糊结果固化为 GPU 纹理缓存，呼吸动效仅改变 Scale 与 Opacity，每秒节省 120 次重算。
   - 在歌词缩放胶囊中引入条件渲染 `_showScaleIndicator ? ClipRRect(...) : const SizedBox.shrink()`，闲置期彻底卸载 `BackdropFilter`，释放 GPU 采样通道。

---

## 3. Caveats (约束与注意事项)

1. **独占写入权限合规**：所有改动严格限制在指定文件（`lib/entry.dart`, `lib/component/now_playing_shell_underlay.dart`, `lib/page/now_playing_page/page.dart`, `lib/page/now_playing_page/component_views.dart`, `test/entry_transition_test.dart`, `test/page/now_playing_content_test.dart`）。
2. **向后兼容性**：保留了所有 Key（如 `now-playing-shell-underlay-opacity`, `now-playing-underlay-opacity`, `now-playing-underlay-pointer`），并新增 `now-playing-underlay-scale`，确保现有所有单元/集成测试 100% 兼容。

---

## 4. Conclusion (实施结论)

- Milestone 3 核心任务已 100% 达成。
- `flutter analyze` 检查通过，0 errors, 0 warnings。
- 全套测试（包含 `test/entry_transition_test.dart`, `test/page/now_playing_content_test.dart`, `test/e2e/all_e2e_test.dart` 及全量 Tier 1~4 E2E 套件，共 265 项测试）全部 100% 通过。

---

## 5. Verification Method (独立验证方法)

请按以下命令进行独立复核验证：

1. **静态代码分析**：
   ```powershell
   flutter analyze
   ```
   *预期输出*：`No issues found!`

2. **核心转场与页面单元测试**：
   ```powershell
   flutter test test/entry_transition_test.dart test/page/now_playing_content_test.dart
   ```
   *预期输出*：All tests passed! (17 tests passed)

3. **全套 E2E 与回归测试**：
   ```powershell
   flutter test test/entry_transition_test.dart test/page/now_playing_content_test.dart test/e2e/
   ```
   *预期输出*：All tests passed! (265 tests passed)
