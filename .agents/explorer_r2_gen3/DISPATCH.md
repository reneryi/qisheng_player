## 2026-08-31T14:41:05Z
任务 R2：重构歌词预览面板的双向平滑开启动画与列表联动。

【必读需求】
请首先完整阅读原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md

【工作目录与身份】
- 你的工作目录是：e:\PyCharmSave\qisheng_player\.agents\explorer_r2_gen3
- 你的父编排器 Conversation ID 是：0722a8db-84a3-4820-89ea-98c68a74e815

【调查目标与范围】
1. 搜索并定位歌词预览面板组件（如 LyricPreview、LyricPanel、SideLyricView 等）、其在主界面（如 MainScreen、HomeView、PlaylistDetailView 等）中的布局方式（Row、Stack 等），以及顶部/工具栏切换按钮的触发逻辑与状态管理。
2. 分析当前展开/收起时生硬跳变、收起时缺少退出动画、以及主歌曲列表区域宽度调整时突跳/文字换行抖动的根本原因。
3. 设计双向丝滑平滑过渡方案（包含宽度动画、位移/淡入淡出动画、平滑缓动曲线如 Curves.easeInOutCubic、主列表自适应宽度平滑动画等）。
4. 提供具体涉及的文件路径、类名、方法、行号范围以及完整的重构代码方案建议。

【产出要求】
- 在你的工作目录维护 progress.md。
- 调研完成后，撰写详尽的 e:\PyCharmSave\qisheng_player\.agents\explorer_r2_gen3\handoff.md。
- 使用 send_message 向父编排器报告已完成。
