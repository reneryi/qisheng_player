# Handoff Report — Explorer 1 (黑胶唱机模式移除与纯封面画册布局勘探)

## 1. Observation
1. **黑胶唱机实现与依赖组件**：
   - lib/component/ui/vinyl_record_player_view.dart: 包含 VinylRecordPlayerView (392行)，内部定义了 _VinylRecordPlayerViewState (TickerProviderStateMixin, 旋转控制器 20s _spinController，唱针控制器 800ms _tonearmController)、_VinylDiscBody、_VinylGroovePainter、_TonearmWidget 与 _TonearmPainter。
   - lib/app_settings.dart:166-167: 声明了 ool showVinylRecord = false;，并在第 368 行 _instance.showVinylRecord = settingsMap[ShowVinylRecord] ?? true; 及第 403 行 ShowVinylRecord: showVinylRecord, 进行了序列化。
   - lib/page/settings_page/theme_settings.dart:271-283: 实现了 ShowVinylRecordSwitch 组件（文案为“显示黑胶唱盘” / “在大尺寸播放页中显示旋转唱盘与唱针。”）。
   - lib/page/settings_page/page.dart:269: 在“播放页沉浸模块化”分类下挂载了 ShowVinylRecordSwitch()。
   - lib/page/now_playing_page/page.dart:19: 引用了 import 'package:qisheng_player/component/ui/vinyl_record_player_view.dart';。
   - lib/page/now_playing_page/component_views.dart:547-578: 在 _NowPlayingArtwork 中通过 inal showVinyl = AppSettings.instance.showVinylRecord && widget.large; 分支渲染 SizedBox(width: widget.size * 1.15, height: widget.size, child: Hero(... child: Center(child: VinylRecordPlayerView(...))))。
2. **Hero 动画形变与突变观察**：
   - 底栏 BottomPlayerBar 的 _TrackCover 为正方形（1:1 比例，58x58 或 52x52），Hero 标签为 
owPlayingArtworkHeroTag。
   - 详情页黑胶模式下的 Hero 容器宽度为 widget.size * 1.15，高度为 widget.size（1.15:1 比例），且内部为圆形唱片加右上角外突唱针。
   - 纯封面画册模式下的 Hero 容器为 widget.size x widget.size（1:1 比例），内部为 NowPlayingArtworkHeroFrame -> RepaintBoundary -> AnimatedSwitcher -> KeyedSubtree -> ClipRRect -> Image。
3. **死分支与测试观察**：
   - lib/page/now_playing_page/page.dart:47-62: 定义了 NowPlayingViewMode 与 NOW_PLAYING_VIEW_MODE，仅在第 170 行被赋值，没有任何 UI 渲染组件读取或监听。
   - 	est/ 目录下经全局 grep 扫描，0 处涉及 VinylRecordPlayerView 或 showVinylRecord；现有 11+ 个播放页组件与布局测试（	est/page/now_playing_content_test.dart 等）全部工作在纯封面画册模式下。

## 2. Logic Chain
1. 基于 Observation 1，黑胶唱机模式在业务层仅有 4 处关键点：配置项（AppSettings）、设置项开关（ShowVinylRecordSwitch）、页面渲染分支（_NowPlayingArtwork 中的 if (showVinyl)）以及被引入的单独文件（inyl_record_player_view.dart）。因此移除该模式的影响范围高度局部化，不存在与其他深层模块（音频引擎、播放队列、歌词解析等）的隐式耦合。
2. 基于 Observation 2，Hero 转场时发生的比例变形、拉伸和唱针硬切，直接由黑胶模式下的 1.15:1 非正方形包围盒及异构子树导致。当彻底移除黑胶模式后，底栏与详情页两端均统一采用 1:1 正方形纯封面，Hero 动画可以通过 NowPlayingArtworkRectTween 和 NowPlayingArtworkHeroFrame 实现完美物理与几何对齐。
3. 基于 Observation 3，代码库中不存在黑胶相关测试用例，且现有测试均在纯画册模式下验证。移除黑胶代码不会引发测试回归，反而能净化死分支与冗余状态。

## 3. Caveats
- NowPlayingViewMode 是一个历史遗留的独立枚举，在 lib/app_preference.dart 中被序列化，但实际已无任何 UI 影响。建议在本次黑胶移除中保持 AppPreference 的兼容性，避免影响用户旧的偏好设置加载。
- 用户本地可能已有存量的 settings.json（其中包含 ShowVinylRecord 键），在移除 showVinylRecord 时，AppSettings.readFromJson 只需忽略该键即可，无需特殊迁移处理。

## 4. Conclusion
1. 黑胶唱机模式可以安全且彻底地从项目中剔除。
2. 需要修改/删除的全部文件清单为 6 处（1 个待删除源码文件，5 处代码修改点）：
   - 删除：lib/component/ui/vinyl_record_player_view.dart
   - 修改：lib/app_settings.dart、lib/page/settings_page/theme_settings.dart、lib/page/settings_page/page.dart、lib/page/now_playing_page/page.dart、lib/page/now_playing_page/component_views.dart。
3. 纯封面画册模式具备完善的 3D 弹簧物理微交互、超慢背景呼吸发光与响应式排版，移除黑胶后 NowPlayingPage 的结构将显著简化，Hero 飞跃动画将实现无缝平滑过渡。

## 5. Verification Method
1. 检查文件与引用清理：
   - 验证 lib/component/ui/vinyl_record_player_view.dart 是否已彻底删除。
   - 运行全局 grep 确保 VinylRecordPlayerView、showVinylRecord、ShowVinylRecordSwitch 关键词在 lib/ 下 0 匹配。
2. 运行工程静态分析：
   - 执行 lutter analyze，确保 0 errors, 0 warnings。
3. 运行测试套件：
   - 执行 lutter test test/page/now_playing_content_test.dart
   - 执行 lutter test test/page/now_playing_overlay_context_test.dart
   - 执行 lutter test test/component/now_playing_artwork_hero_test.dart
   - 执行 lutter test test/component/bottom_player_bar_widget_test.dart
   - 执行全量 lutter test，确保所有测试用例 100% 通过。
