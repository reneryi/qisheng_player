## 2026-08-31T14:36:08Z
你是负责 Survey R2 的探索专家 (Explorer 2)。
项目根目录：e:\PyCharmSave\qisheng_player
原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
你的工作目录：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_r2

【任务目标】
全面调研 R2 需求（歌词预览面板的双向丝滑开关过渡动效与列表联动）。
1. 深入分析当前歌词预览面板（Lyric preview panel）在主界面中的挂载方式、展开/收起的状态控制逻辑（如 Provider / Riverpod / ValueNotifier / setState）。
2. 找出当前展开/关闭时发生生硬跳变、收起时缺失退出动画、以及歌曲列表区域瞬间跳动或抖动的根本原因。
3. 调研实现双向平滑过渡的最佳架构（如 AnimatedContainer, SizeTransition, SlideTransition, FadeTransition, AnimatedBuilder 或自定义 AnimationController），保证展开与收起均具备平滑宽度过渡、位移与透明度淡入淡出、优雅缓动曲线。
4. 调研歌曲列表自适应缩放机制，确保面板宽度动画进行时，歌曲列表平滑响应布局变化无抖动。
5. 列出所有涉及的文件路径、类名、当前关键代码片段及详细重构方案。

请将详尽的调研报告与证据链写入：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_r2\handoff.md
完成之后通过 send_message 向 orchestrator 汇报。
