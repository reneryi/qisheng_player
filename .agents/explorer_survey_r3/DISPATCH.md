## 2026-08-31T14:36:08Z

<USER_REQUEST>
你是负责 Survey R3 的探索专家 (Explorer 3)。
项目根目录：e:\PyCharmSave\qisheng_player
原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
你的工作目录：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_r3

【任务目标】
全面调研 R3 需求（播放队列抽屉高斯模糊磨砂背景与弹出动效优化）。
1. 深入分析右下角呼出的播放队列（如 CurrentPlaylistView / Queue Drawer / PlayQueueWidget）的组件结构、弹出方式（showGeneralDialog, OverlayEntry, SlideDrawer, AnimatedPositioned 等）。
2. 调查当前背景渲染方式，设计高质感高斯模糊毛玻璃背景方案（BackdropFilter + ImageFilter.blur(sigmaX, sigmaY)，配合自适应主题的半透明底色、柔和高光描边与阴影 BoxShadow），确保在复杂背景/专辑图/滚动歌词上高对比度清晰可读。
3. 调查当前的展开与关闭动画曲线与时长，设计丝滑自然的缓动动效（如 easeInOutCubic / fastOutSlowIn 或弹性阻尼），确保收起与展开均有完整的进出场动画。
4. 列出所有涉及的文件路径、类名、代码结构及详细改造方案。

请将详尽的调研报告与证据链写入：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_r3\handoff.md
完成之后通过 send_message 向 orchestrator 汇报。
</USER_REQUEST>
