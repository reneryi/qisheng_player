## 2026-09-01T09:39:44Z
你被指派为 Milestone 3（Shell 联动转场、Staged Reveal 阶段式揭示与 120fps GPU 优化）的实施 Worker。

工作目录：e:\PyCharmSave\qisheng_player\.agents\worker_m3
用户原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
全局项目文档：e:\PyCharmSave\qisheng_player\PROJECT.md
Explorer 3 详尽报告：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\report.md
Explorer 3 交接文档：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\handoff.md
项目根目录：e:\PyCharmSave\qisheng_player

【独占文件写入权限】：
- `lib/entry.dart`
- `lib/component/now_playing_shell_underlay.dart`
- `lib/page/now_playing_page/page.dart`
- `lib/page/now_playing_page/component_views.dart`
- `test/entry_transition_test.dart`
- `test/page/now_playing_content_test.dart`

【核心实施任务】：
1. 重构 `lib/entry.dart` 与 `lib/component/now_playing_shell_underlay.dart`：
   - 消除底层 AppShell 与 NowPlayingPage 之间的双重透明度竞争（将 380ms 定时器驱动与路由转场单源统一）。
   - 在路由转场中为底层 AppShell 增加 `Scale: 1.0 -> 0.96` 的空间沉降推远动效（配合 `Interval(0.0, 0.48, curve: Curves.easeOutCubic)`），带来极具深度感的现代视口转场。
2. 精细化编排 `lib/page/now_playing_page/page.dart` 与 `lib/page/now_playing_page/component_views.dart` 的 6 阶段 Staged Reveal 时间轴：
   - Hero 封面 (0.0 ~ 1.0)
   - AppBar 顶部操作栏 (0.12 ~ 0.48)
   - 歌曲标题 / 艺术家信息 (0.24 ~ 0.68)
   - 元数据胶囊 / 频谱条 (0.30 ~ 0.80)
   - 歌词视图 (0.34 ~ 0.90)，入场期间锁定歌词滚动位置避免位移叠加抖动
   - 底部控制栏 (>= 0.82)
3. 120fps 高刷性能与 GPU 缓存优化：
   - 在封面外层弥散高斯模糊光晕（32px blur）外层添加独立的 `RepaintBoundary`，使 GPU 光栅化为 Texture 缓存，避免每帧重复重算昂贵的高斯模糊。
   - 歌词缩放指示胶囊中的 `BackdropFilter` 实行惰性挂载，闲置时从绘制树卸载。
4. 运行 `flutter analyze` 确保 0 errors 0 warnings。
5. 运行 `flutter test test/entry_transition_test.dart test/page/now_playing_content_test.dart test/e2e/` 确保 100% 测试通过。
6. 在工作目录下撰写详细 `handoff.md`（包含代码改动、测试输出与验证命令），并向父级发送消息汇报。
