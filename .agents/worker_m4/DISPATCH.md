## 2026-09-01T09:22:13Z

你被指派为 Milestone 4（MainLayoutFrame 窗口边距平滑过渡动效）的实施 Worker。

工作目录：e:\PyCharmSave\qisheng_player\.agents\worker_m4
用户原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
全局项目文档：e:\PyCharmSave\qisheng_player\PROJECT.md
Explorer 3 详尽报告：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\report.md
Explorer 3 交接文档：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\handoff.md
项目根目录：e:\PyCharmSave\qisheng_player

【独占文件写入权限】：
- `lib/component/main_layout_frame.dart`
- `test/component/main_layout_frame_test.dart`

【核心实施任务】：
1. 重构 `lib/component/main_layout_frame.dart`：
   - 将静态 `Padding(padding: EdgeInsets.fromLTRB(sideInset + 4.0, topInset, sideInset + 4.0, 0))` 替换为 `AnimatedPadding(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, padding: ...)`。
   - 将底部 dock 边距静态 `Padding(padding: EdgeInsets.only(bottom: dockInset))` 替换为 `AnimatedPadding(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, padding: ...)`。
   - 将底栏 `Positioned(left: 0, right: 0, bottom: bottomInset)` 替换为 `AnimatedPositioned(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, left: 0, right: 0, bottom: bottomInset, child: ...)`。
2. 保证在窗口模式变化（最大化、全屏、普通窗口切换）时边距平滑动画插值，消除跳跃感；在用户常规拖拽拉伸窗口尺寸时保持流畅无额外开销。
3. 检查/补充 `test/component/main_layout_frame_test.dart` 中的动画过渡测试。
4. 运行 `flutter analyze` 确保 0 errors 0 warnings，运行 `flutter test test/component/main_layout_frame_test.dart` 确保全部测试通过。
5. 在工作目录下撰写详细 `handoff.md`（包含修改详情、测试命令与输出结果），并向父级发送消息汇报。

【MANDATORY INTEGRITY WARNING】：
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
