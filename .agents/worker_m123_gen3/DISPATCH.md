## 2026-08-31T14:44:56Z
你被委派作为核心实施工程师（Worker），负责对音乐播放器进行三处核心交互与动效体验优化（M1: R1, M2: R2, M3: R3）的代码实施、测试与静态分析验证。

【必读需求与调查报告】
1. 原始需求：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
2. 全局架构与里程碑：e:\PyCharmSave\qisheng_player\.agents\PROJECT.md
3. R1 调研报告（更多按钮锚点修复）：e:\PyCharmSave\qisheng_player\.agents\explorer_r1_gen3\handoff.md
4. R2 调研报告（歌词预览双向平滑动效与列表联动）：e:\PyCharmSave\qisheng_player\.agents\explorer_r2_gen3\handoff.md
5. R3 调研报告（播放队列抽屉毛玻璃与丝滑动效）：e:\PyCharmSave\qisheng_player\.agents\explorer_r3_gen3\handoff.md

【工作目录与身份】
- 你的工作目录是：e:\PyCharmSave\qisheng_player\.agents\worker_m123_gen3
- 你的父编排器 Conversation ID 是：0722a8db-84a3-4820-89ea-98c68a74e815

【MANDATORY INTEGRITY WARNING】
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

【独占文件写入范围 (Exclusive Write Ownership)】
- `lib/component/audio_tile.dart`
- `lib/page/uni_page.dart`
- `lib/component/bottom_player_bar.dart`
- 相关测试文件（如 `test/page/audios_page_test.dart`, `test/component/audio_tile_test.dart`, `test/component/bottom_player_bar_test.dart`, `test/page/uni_page_test.dart` 等）

【具体实施任务】
1. **任务 M1 (R1: 更多按钮弹窗锚定)**：
   - 修改 `lib/component/audio_tile.dart`，将操作栏中的“更多” `IconButton` 单独用 `AudioContextMenu` 包裹，使其内部 `MenuAnchor` 以按钮自身为锚点精确对齐展开，支持防屏幕边界溢出与多级子菜单级联。
   - 保留整行外层的 `AudioContextMenu`，确保右键条目（`onSecondaryTapDown`）依然精确按鼠标光标位置弹出上下文菜单，两套触发机制互不干扰。
2. **任务 M2 (R2: 歌词预览面板双向平滑动效与列表联动)**：
   - 修改 `lib/page/uni_page.dart`，在 `_UniPageState` 引入 `SingleTickerProviderStateMixin`、`AnimationController` 与 `CurvedAnimation(Curves.easeInOutCubic)`。
   - 由单一动画时间轴统一驱动：歌词面板宽度展开/收缩、位移与透明度淡入淡出、主列表右侧预留边距 `listPadding.right`（消除 298px 瞬变引起的文字换行跳变与撕裂）、侧边字母索引轨位置等。
   - 彻底修复 `Stack` 内部通过 `if (showRightPane)` 直接卸载组件导致退场动画丢失的问题，在动画退场期间保活直至 `progress == 0`。
3. **任务 M3 (R3: 播放队列抽屉毛玻璃与丝滑动效)**：
   - 修改 `lib/component/bottom_player_bar.dart`，在 `_QueueEntryButton._openQueueDrawer` 中引入 `import 'dart:ui';`，构建自包含的高质感毛玻璃背景：`ClipRRect(borderRadius: BorderRadius.circular(24))` 包裹 `BackdropFilter(filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma))`，配合自适应明暗主题的半透明渐变底色（82%~86%）、微光高光边框与双层投影。
   - 优化展开与收起的动画缓动曲线，采用平滑自然的双向缓冲曲线（进场 `Cubic(0.16, 1.0, 0.3, 1.0)`，退场 `Cubic(0.2, 0.0, 0.0, 1.0)`，时长 320ms），消除退场急停与闪退。
4. **测试与静态分析验证**：
   - 编写或更新相关测试用例（如在 `test/page/audios_page_test.dart` 中追加歌词面板平滑退场动画测试，在相关组件测试中验证锚点和抽屉）。
   - 运行 `dart analyze` / `flutter analyze` 确保无任何语法错误或警告。
   - 运行 `flutter test` 确保受影响的所有测试全部通过。
