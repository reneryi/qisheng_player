# BRIEFING — 2026-09-01T17:21:30+08:00

## Mission
全面深入调查底栏 PlayerBar 与播放详情页 NowPlayingPage 之间的封面转场与 Hero 动效机制，定位形变、闪烁、跳跃与裁切不一致问题，输出两端 1:1 对齐的重构设计方案。

## 🔒 My Identity
- Archetype: explorer
- Roles: Explorer 2 (Hero 动效子树与包围盒几何对齐勘探调研员)
- Working directory: e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2
- Original parent: 2018d570-f9e3-4340-a696-737701a7623e
- Milestone: 调研与方案设计完成

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- 一律使用中文回答
- 只在 .agents/explorer_survey_2/ 下写入报告和状态文件，不修改源代码

## Current Parent
- Conversation ID: 2018d570-f9e3-4340-a696-737701a7623e
- Updated: 2026-09-01T17:21:30+08:00

## Investigation State
- **Explored paths**:
  - `lib/component/bottom_player_bar.dart` (`_TrackCover`, `SpinningArtwork`, `_BottomBarTrackSection`, `BottomPlayerBar`)
  - `lib/page/now_playing_page/component_views.dart` (`_ImmersiveArtworkStage`, `_NowPlayingArtwork`, `VinylRecordPlayerView`)
  - `lib/page/now_playing_page/page.dart`, `large_page.dart`, `small_page.dart`
  - `lib/component/now_playing_artwork_hero.dart` (`NowPlayingArtworkRectTween`, `nowPlayingArtworkFlightShuttleBuilder`, `NowPlayingArtworkHeroFrame`)
  - `lib/entry.dart` (`NowPlayingTransitionPage`, `_buildNowPlayingRouteTransition`, `NowPlayingShellUnderlay`)
  - `lib/navigation_state.dart`, `lib/component/main_layout_frame.dart`, `lib/component/app_shell.dart`
  - `lib/library/audio_library.dart` (`cover`, `largeCover`)
  - `test/component/now_playing_artwork_hero_test.dart`, `test/page/now_playing_content_test.dart`, `test/entry_transition_test.dart`, `test/component/bottom_player_bar_test.dart`
- **Key findings**:
  - 8 项导致形变、闪烁、跳跃与裁切异常的根本原因（详见 report.md）
  - 两端 Hero 子树严重不对称（手势/3D 变换侵入 Hero 内部、FittedBox 破坏目标包围盒坐标、ImageProvider 分辨率差异与异步等待导致的单帧闪烁）
  - 设计了单核共享 `NowPlayingArtworkCard` + 分层解耦 + 单层无虚影 `flightShuttleBuilder` 重构方案
- **Unexplored areas**: None (调研完全覆盖)

## Key Decisions Made
- 确立以 `NowPlayingArtworkCard` 为单核、手势与 Transform 移出 Hero、移除 FittedBox 污染的 1:1 对齐方案。

## Artifact Index
- `e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2\report.md` — 最终调研报告
- `e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2\handoff.md` — Handoff 报告
