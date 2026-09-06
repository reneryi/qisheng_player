# BRIEFING — 2026-08-31T22:43:25+08:00

## Mission
调查任务 R2：重构歌词预览面板的双向平滑开启动画与列表联动，分析生硬跳变与布局抖动根因，设计双向平滑动画与联动方案，产出完整重构建议。

## 🔒 My Identity
- Archetype: explorer
- Roles: Teamwork explorer (Read-only investigation)
- Working directory: e:\PyCharmSave\qisheng_player\.agents\explorer_r2_gen3
- Original parent: 0722a8db-84a3-4820-89ea-98c68a74e815
- Milestone: Milestone R2 - Lyric Preview Smooth Animation & List Linkage Investigation

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- All answers and reports in Chinese
- Keep handoff self-contained with 5-Component structure

## Current Parent
- Conversation ID: 0722a8db-84a3-4820-89ea-98c68a74e815
- Updated: 2026-08-31T22:43:25+08:00

## Investigation State
- **Explored paths**:
  - `ORIGINAL_REQUEST.md`: R2 requirements and acceptance criteria
  - `lib/page/audios_page.dart`: lyric preview toggle button, state, UniPage invocation
  - `lib/page/uni_page.dart`: UniPage layout, Stack overlay, rightPaneReserved, listPadding, TweenAnimationBuilder, sideRail positioning
  - `lib/component/audio_lyric_preview_panel.dart`: AudioLyricPreviewPanel structure, artwork, title/artist, auto-scroll lyric lines
  - `lib/component/audio_tile.dart`: row layout, Expanded text with ellipsis, right padding impact
  - `lib/theme/app_theme_extensions.dart` & `lib/theme/app_theme.dart`: panelTransitionDuration (260ms), curves (easeInOutCubic / normal)
  - `test/page/audios_page_test.dart` & `test/page/uni_page_test.dart`: existing tests & assertions
- **Key findings**:
  1. Exit animation missing: `UniPage` uses `if (showRightPane)` in the `Stack`. When `showRightPane` flips to `false`, the entire `Positioned` is immediately removed from the widget tree in 0ms, so `TweenAnimationBuilder` never executes the reverse animation.
  2. List width instant jumping & text jitter: `listPadding.right` is calculated directly from the boolean `showRightPane ? widget.rightPaneWidth + 14.0 : 0.0`. It jumps by ~298px in 1 frame. The `ListView` / `AudioTile` immediately shrinks/expands, causing text ellipsis to snap and leaving a 260ms visual void during opening.
  3. Desynchronized side rail / locate button: Side rail uses separate `AnimatedPositioned`, which is not frame-synchronized with `listPadding`.
  4. Solution: Elevate animation control to `_UniPageState` using `AnimationController` + `CurvedAnimation(Curves.easeInOutCubic)` + `AnimatedBuilder`. Drive `listPadding.right`, right pane `width`, `opacity`, `translation`, and `sideRailRight` from the unified `_rightPaneAnimation.value`. Keep panel mounted during exit animation until `progress == 0.0`.
- **Unexplored areas**: None. Problem scope and code implementation details are fully mapped.

## Key Decisions Made
- Architecture: Manage right pane animation centrally in `_UniPageState` with `SingleTickerProviderStateMixin`.
- Animation Curve: Use `Curves.easeInOutCubic` with `context.motion.panelTransitionDuration` (260ms).
- Synchronization: Unified `progress` parameter controls list padding, panel clipping/width, fade/slide, and side index positioning.

## Artifact Index
- DISPATCH.md — Initial dispatch message
- progress.md — Liveness and progress heartbeat
- BRIEFING.md — Persistent working memory
- handoff.md — Final investigation handoff report
