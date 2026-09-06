# Plan & Milestones

## Overview
本项目已圆满完成 qisheng_player 音乐播放器的三项核心交互与动效体验优化：
- R1: 歌曲列表“更多”按钮弹窗锚定偏移修复与右键上下文菜单兼容 (DONE)
- R2: 歌词预览面板双向平滑开启动画与歌曲列表平滑自适应联动 (DONE)
- R3: 播放队列抽屉高斯模糊磨砂背景（BackdropFilter）与缓动动效优化 (DONE)

## Milestones Summary

### Phase 0: Survey & Codebase Investigation (完成)
- 3 位 Explorer 完成深度代码定位与方案设计 (`explorer_r1_gen3`, `explorer_r2_gen3`, `explorer_r3_gen3`)。

### Phase 1: M1 - 歌曲列表更多按钮弹窗锚定修复 (R1) (完成)
- 在 `lib/component/audio_tile.dart` 中为“更多”按钮单独包裹 `AudioContextMenu`，实现按钮自身 Rect 精确锚定与屏幕边界防溢出，保留整行右键菜单。

### Phase 2: M2 - 歌词预览面板双向平滑动效与列表联动 (R2) (完成)
- 在 `lib/page/uni_page.dart` 中使用 `AnimationController` 时间轴驱动双向平滑动效与列表内边距连续插值，退场节点保活，彻底消除文本排版换行抖动与白边撕裂。

### Phase 3: M3 - 播放队列抽屉毛玻璃背景与缓动动效 (R3) (完成)
- 在 `lib/component/bottom_player_bar.dart` 中引入 `BackdropFilter` 自适应模糊（24.0/12.0）、半透明渐变底色、双层投影与进退场双 Cubic 缓动曲线。

### Phase 4: M4 - 评审、对抗验证、司法审计与全量集成 (完成)
- Reviewer 1 (APPROVE) & Reviewer 2 (APPROVE) 双独立审查通过。
- Challenger 1 (APPROVE) & Challenger 2 (APPROVE) 包含 20 项破坏性对抗测试全绿通过。
- Forensic Auditor (CLEAN) 司法级完整性与真实性审计通过。
- 静态分析 `dart analyze lib test` 0 警告 0 错误。
- 全量测试 `flutter test` 277/277 100% 通过。
