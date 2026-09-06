# BRIEFING — 2026-09-01T17:48:00+08:00

## Mission
实施 Milestone 3：Shell 联动转场、Staged Reveal 阶段式揭示与 120fps GPU 优化。

## 🔒 My Identity
- Archetype: implementer
- Roles: implementer, qa, specialist
- Working directory: e:\PyCharmSave\qisheng_player\.agents\worker_m3
- Original parent: 2018d570-f9e3-4340-a696-737701a7623e
- Milestone: Milestone 3 (Shell Transition, Staged Reveal & 120fps Optimization)

## 🔒 Key Constraints
- 独占文件写入权限：
  - `lib/entry.dart`
  - `lib/component/now_playing_shell_underlay.dart`
  - `lib/page/now_playing_page/page.dart`
  - `lib/page/now_playing_page/component_views.dart`
  - `test/entry_transition_test.dart`
  - `test/page/now_playing_content_test.dart`
- 消除底层 AppShell 与 NowPlayingPage 之间的双重透明度竞争（将 380ms 定时器驱动与路由转场单源统一）。
- 在路由转场中为底层 AppShell 增加 `Scale: 1.0 -> 0.96` 的空间沉降推远动效（配合 `Interval(0.0, 0.48, curve: Curves.easeOutCubic)`）。
- 精细化编排 6 阶段 Staged Reveal 时间轴（Hero 封面 0.0~1.0, AppBar 0.12~0.48, 标题/艺术家 0.24~0.68, 元数据/频谱 0.30~0.80, 歌词 0.34~0.90 锁定滚动, 底栏 >=0.82）。
- 120fps 高刷性能与 GPU 缓存优化（封面 32px 高斯模糊光晕包裹独立 RepaintBoundary，歌词缩放胶囊 BackdropFilter 惰性挂载）。
- `flutter analyze` 确保 0 errors 0 warnings。
- `flutter test test/entry_transition_test.dart test/page/now_playing_content_test.dart test/e2e/` 确保 100% 测试通过。
- 严禁作弊与虚假测试，由 Forensic Auditor 独立检验。

## Current Parent
- Conversation ID: 2018d570-f9e3-4340-a696-737701a7623e
- Updated: 2026-09-01T17:48:00+08:00

## Task Summary
- **What to build**: 重构 Shell 联动转场、空间深度缩放、6 阶段 Staged Reveal 动效编排、歌词滚动锁定与 GPU 缓存优化。
- **Success criteria**: 转场单源驱动无竞争、Scale 1.0->0.96 平滑、Staged Reveal 时间轴精准、120fps 优化到位、测试与 analyze 全部 100% 通过。
- **Interface contracts**: PROJECT.md § Shell Route Transition Contract
- **Code layout**: PROJECT.md § Code Layout

## Change Tracker
- **Files modified**:
  - `lib/component/now_playing_shell_underlay.dart`: 提取并重构 NowPlayingShellUnderlay，去除 380ms 独立定时器竞争。
  - `lib/entry.dart`: 导入并导出 NowPlayingShellUnderlay，在 `_buildAppRouteTransition` 中为底层增加 `Scale: 1.0 -> 0.96` (Interval 0.0~0.48, Curves.easeOutCubic) 空间沉降动效。
  - `lib/page/now_playing_page/component_views.dart`: 对齐元数据与频谱条 Staged Reveal (0.30~0.80)；封面 32px 高斯模糊包裹 `RepaintBoundary` 启用 GPU 纹理缓存；歌词缩放指示器 `BackdropFilter` 惰性挂载；转场入场期间锁定歌词滚动位置。
  - `test/entry_transition_test.dart`: 增加底层 Scale 1.0->0.96 空间沉降过渡插值精准验证。
  - `test/page/now_playing_content_test.dart`: 增加 32px 模糊 RepaintBoundary 纹理隔离、BackdropFilter 惰性挂载生命周期、入场转场滚动锁定等单元测试用例。
- **Build status**: PASS (`flutter analyze`: 0 errors, 0 warnings; `flutter test`: 265/265 PASS).
- **Pending issues**: None.

## Quality Status
- **Build/test result**: All 265 tests passed (100%).
- **Lint status**: 0 errors, 0 warnings (clean).
- **Tests added/modified**: `test/entry_transition_test.dart`, `test/page/now_playing_content_test.dart`.

## Loaded Skills
- **Source**: C:\Users\reneryi\.gemini\config\plugins\flutter\skills\dart-run-static-analysis\SKILL.md
- **Core methodology**: dart analyze & dart fix static analysis workflow
- **Source**: C:\Users\reneryi\.gemini\config\plugins\flutter\skills\dart-add-unit-test\SKILL.md
- **Core methodology**: widget and unit testing best practices

## Key Decisions Made
1. 单源驱动统一：底层淡入淡出及缩放完全交由 GoRouter 路由树中的 `secondaryAnimation` 控制，`NowPlayingShellUnderlay` 仅充当状态保持器与指针拦截守卫，移除 380ms 竞争定时器。
2. 空间沉降设计：在 `_buildAppRouteTransition` 中对 underlay 应用 `Transform.scale(scale: 1.0 - 0.04 * factor)`，与 `Interval(0.0, 0.48, curve: Curves.easeOutCubic)` 完美对齐。
3. 歌词入场防抖：在 `_scrollToLine` 中判断 `NowPlayingRouteTransitionScope.maybeOf(context)?.value < 0.95`，入场过渡中强制使用 `Duration.zero` 无动画定位，避免速度叠加造成歌词纵向抖动。
4. 120fps GPU 优化：为 32px 高斯模糊光晕添加 `RepaintBoundary` 纹理缓存；歌词缩放胶囊指示器在未显示时完全不挂载 `BackdropFilter`。

## Artifact Index
- `.agents/worker_m3/DISPATCH.md` — 任务指派说明
- `.agents/worker_m3/BRIEFING.md` — 持续工作记忆
- `.agents/worker_m3/progress.md` — 执行进度跟踪
- `.agents/worker_m3/handoff.md` — 完工交接报告
