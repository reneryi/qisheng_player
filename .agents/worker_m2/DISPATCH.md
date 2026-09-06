## 2026-09-01T09:33:27Z
你被指派为 Milestone 2（Hero 动效子树与包围盒几何对齐）的实施 Worker。

工作目录：e:\PyCharmSave\qisheng_player\.agents\worker_m2
用户原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
全局项目文档：e:\PyCharmSave\qisheng_player\PROJECT.md
Explorer 2 详尽报告：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2\report.md
Explorer 2 交接文档：e:\PyCharmSave\qisheng_player\.agents\explorer_survey_2\handoff.md
项目根目录：e:\PyCharmSave\qisheng_player

【独占文件写入权限】：
- `lib/component/now_playing_artwork_hero.dart`
- `lib/component/bottom_player_bar.dart`
- `lib/page/now_playing_page/component_views.dart`
- `test/component/now_playing_artwork_hero_test.dart`
- `test/page/now_playing_content_test.dart`

【核心实施任务】：
1. 重构 `lib/component/now_playing_artwork_hero.dart`：
   - 抽象/完善统一单核 `NowPlayingArtworkCard`（标准 1:1 正方形卡片，统筹图片加载、占位符、圆角裁切与内层阴影）。
   - 重构 `nowPlayingArtworkFlightShuttleBuilder`：严禁使用双树 `Stack` 交叉淡入（杜绝重影与尺寸挤压），采用单层卡片在飞行途中对 `BorderRadius`（如 26px 插值到 24px）和 `BoxShadow` 进行平滑插值渲染。
   - 重构 `NowPlayingArtworkRectTween`：确保在 `Rect.lerp` 基础上叠加平滑自然的物理弧线。
2. 重构 `lib/component/bottom_player_bar.dart`：
   - 底栏 `_TrackCover` 中的 `Hero(tag: nowPlayingArtworkHeroTag)` 内部直接挂载标准的 `NowPlayingArtworkCard`，确保层级纯净。
3. 重构 `lib/page/now_playing_page/component_views.dart`：
   - 移除 `_ImmersiveArtworkStage` 中包裹 Column 的 `FittedBox(fit: BoxFit.scaleDown)`（第 101 行），避免对详情页 Hero 目标包围盒造成动态缩放污染导致落地 Snap 跳变。
   - 分层解耦 `_NowPlayingArtwork`：将 `GestureDetector(key: ValueKey('now-playing-artwork-drag'))`、`Transform` 3D 拖拽倾斜、以及外层弥散光晕（`ImageFiltered(blur: 32)` / `boxShadow`）移至 `Hero` 外部！`Hero` 内部仅包裹纯净的 `NowPlayingArtworkCard`（保持测试 key `'now-playing-artwork-drag'` 可用）。
   - 确保彻底移除任何可能遗留的黑胶唱机 `VinylRecordPlayerView` 分支。
4. 运行 `flutter analyze` 确保 0 errors 0 warnings。
5. 运行 `flutter test test/component/now_playing_artwork_hero_test.dart test/page/now_playing_content_test.dart test/component/bottom_player_bar_test.dart` 以及 E2E 测试 `flutter test test/e2e/` 确保 100% 通过。
6. 在工作目录下撰写详细 `handoff.md`（包含代码改动、测试输出与验证命令），并向父级发送消息汇报。
