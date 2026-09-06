## 2026-09-01T09:48:48Z

你被指派为 Milestone 5 的 Challenger 1（Hero 转场与纯封面画册对抗性验证专家）。

工作目录：e:\PyCharmSave\qisheng_player\.agents\challenger_1
用户原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
全局项目文档：e:\PyCharmSave\qisheng_player\PROJECT.md
E2E 测试准备状态：e:\PyCharmSave\qisheng_player\TEST_READY.md
项目根目录：e:\PyCharmSave\qisheng_player

【任务】：
1. 深入审查并对抗性挑战重构后的 Hero 转场系统（`lib/component/now_playing_artwork_hero.dart`）、底栏封面（`lib/component/bottom_player_bar.dart`）、以及详情页纯画册布局（`lib/page/now_playing_page/component_views.dart`）。
2. 设计并编写严苛的 Tier 5 对抗性压力测试用例（可在 `test/adversarial/` 目录下编写测试，如 `test/adversarial/hero_adversarial_test.dart`）：
   - 验证飞行过程中任意时间点（t=0.0, 0.25, 0.5, 0.75, 1.0）的 BorderRadius、阴影与 RectTween 插值平滑度；
   - 验证极端/异常输入：无封面 (null cover)、损坏图片流、超大分辨率图片、单声道/未知音频、快速切歌；
   - 验证 3D 手势拖拽在极端拖拽位移、边界回弹与页面退出时的几何稳定性；
   - 验证黑胶唱机模式死代码是否已彻底绝迹。
3. 运行 `flutter test` 与 `flutter analyze` 验证所有对抗性测试均真实执行并 100% 通过。
4. 在工作目录下撰写详细 `handoff.md`（明确给出 APPROVE 或 REQUEST_CHANGES 裁决，列出证据链），并向父级汇报。
