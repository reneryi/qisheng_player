## 2026-09-01T09:48:48Z

你被指派为 Milestone 5 的 Challenger 2（边距动画、Shell 协同与 Staged Reveal 对抗性验证专家）。

工作目录：e:\PyCharmSave\qisheng_player\.agents\challenger_2
用户原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
全局项目文档：e:\PyCharmSave\qisheng_player\PROJECT.md
E2E 测试准备状态：e:\PyCharmSave\qisheng_player\TEST_READY.md
项目根目录：e:\PyCharmSave\qisheng_player

【任务】：
1. 深入审查并对抗性挑战重构后的 `MainLayoutFrame` 边距平滑过渡、`AppShell` / `NowPlayingShellUnderlay` 协同淡入淡出与 `Scale 0.96` 空间沉降、以及 6 阶段 Staged Reveal 动效。
2. 设计并编写严苛的 Tier 5 对抗性压力测试用例（可在 `test/adversarial/` 目录下编写测试，如 `test/adversarial/shell_and_insets_adversarial_test.dart`）：
   - 验证 `MainLayoutFrame` 在高频连续触发最大化/还原/全屏切换（Rapid Layout Mode Toggling）时的插值连续性与无溢出无死锁；
   - 验证底层 Shell 沉降动效在转场中断、快速反复进出详情页（Fast Route Push/Pop）时的状态一致性；
   - 验证 Staged Reveal 各阶段在慢速回放、反向退出、以及入场时快速切歌/滚动歌词时的平稳性（歌词入场防抖验证）；
   - 验证 120fps GPU 缓存优化（`RepaintBoundary` 隔离与 `BackdropFilter` 惰性挂载）的结构完整性。
3. 运行 `flutter test` 与 `flutter analyze` 验证所有对抗性测试均真实执行并 100% 通过。
4. 在工作目录下撰写详细 `handoff.md`（明确给出 APPROVE 或 REQUEST_CHANGES 裁决，列出证据链），并向父级汇报。

【MANDATORY INTEGRITY WARNING】：
DO NOT CHEAT. All tests must be genuine.
