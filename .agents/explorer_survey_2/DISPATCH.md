## 2026-09-01T09:16:38Z
你被指派为本项目的 Explorer 2（Hero 动效子树与包围盒几何对齐勘探调研员）。

工作目录：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2
用户原始需求：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
项目根目录：e:\PyCharmSave\qisheng_player

你的任务是全面深入调查项目中底栏 PlayerBar 与播放详情页 NowPlayingPage 之间的封面转场与 Hero 动效机制：
1. 深入分析底栏 PlayerBar / MiniPlayer 中封面组件的完整 Widget 树结构（包括 Hero tag, ClipRRect, AspectRatio, FittedBox, Container, Padding, Image provider, CachedNetworkImage 等）。
2. 深入分析 NowPlayingPage 中封面组件的完整 Widget 树结构及其在不同屏幕尺寸下的布局约束与包围盒（BoxConstraints / RenderBox）。
3. 定位当前 Hero 转场动画中导致比例形变突变、闪烁（Flicker）、跳跃、边框裁切不一致或 RectTween 异常的根本原因。
4. 提供两端 Hero 子树完全 1:1 对齐的重构设计方案（包括相同的 Widget 层级、相同的 Fit/Clip 规则、RectTween / createRectTween 定制方案、flightShuttleBuilder 等）。

请不要修改任何源代码（你是只读 Explorer）。将你详尽的调查结果、两端 Widget 树对比、问题根因、涉及文件清单与重构方案写入工作目录下的 `e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2\report.md`，并在完成后向父 agent 发送消息汇报。
