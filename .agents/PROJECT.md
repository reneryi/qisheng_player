# Project: qisheng_player UX & Animation Enhancement (Iteration 4)

## Architecture
- Flutter / Dart 桌面音乐播放器客户端
- 动效与转场核心层：
  - 路由转场系统 (`lib/entry.dart`)：NowPlayingTransitionPage, SlideTransitionPage, DetailTransitionPage
  - App 容器框架 (`lib/component/app_shell.dart`): Shell 页面平滑淡化切换
  - 封面 Hero 动效系统 (`lib/component/now_playing_artwork_hero.dart`): RectTween & HeroFrame
  - 播放详情页控制器 (`lib/page/now_playing_page/page.dart`): 详情页展开联动与底栏显隐
  - 设置页二级切换 (`lib/page/settings_page/page.dart`): 内部分类平滑过渡
  - 上下文菜单与二级菜单 (`lib/theme/app_component_themes.dart`, `lib/component/animated_menu_content.dart`, `lib/component/audio_context_menu.dart`, `lib/component/album_context_menu.dart`): 毛玻璃/圆角/阴影/悬停胶囊/级联展开
  - 内容详情页路由体系 (`lib/entry.dart`, 各详情页): 8% 横向平滑推入 + 视差退场 + 阻尼返回

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1 NowPlayingPage 展开/收起动效丝滑化 | 移除整页 ScaleTransition 避免 Hero 坐标跳跃，优化 RectTween 曲线，同步底栏平滑渐显 | M1 | ORIGINAL_REQUEST §R1 |
| 2 | R2 侧栏主导航与设置二级切换平滑淡化 | 移除侧栏 8px 垂直位移颠簸，重构为 Cross-Fade；设置页分类切换引入 AnimatedSwitcher 淡化 | M2 | ORIGINAL_REQUEST §R2 |
| 3 | R3 右键菜单与二级子菜单视觉与悬停重构 | 消除黑边缝隙，配置 10px 圆角、毛玻璃与柔和阴影，8px 胶囊悬停高亮，Submenu 级联进场动画 | M3 | ORIGINAL_REQUEST §R3 |
| 4 | R4 内容详情页横向平滑推入与阻尼返回 | 重构 DetailTransitionPage 为 8% 横向推入淡化 (280ms/220ms) + 次级视差景深 (-3%) | M4 | ORIGINAL_REQUEST §R4 |
| 5 | M5 全量测试、静态分析与司法审计 | 确保 `flutter analyze` 零报错，单元/集成测试全绿，通过司法完整性与防作弊审计 | M5 | ORIGINAL_REQUEST Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 0 | Survey & Architecture Mapping | 3 Explorers 深入调研 R1, R2, R3, R4 源码与成因 | none | DONE |
| 1 | M1234: 全面实施 R1, R2, R3, R4 | Worker 实施 R1 (NowPlaying 展开), R2 (侧栏/设置淡化), R3 (右键菜单/级联), R4 (详情页推入) | M0 | IN_PROGRESS |
| 2 | M5: 多维评审与对抗性验证 | Reviewers, Challengers, Forensic Auditor 独立并行验证与静态分析 | M1234 | PLANNED |
| 3 | M6: 最终门禁聚合与交付汇报 | 聚合 Gate 结果并向 Parent 发送结构化完成报告 | M5 | PLANNED |

## Code Layout
- `lib/entry.dart`: 路由构建器与全套 PageTransition (`_buildNowPlayingRouteTransition`, `_buildAppRouteTransition`, `_buildDetailRouteTransition`)
- `lib/component/app_shell.dart`: AppShell 页面切换过渡 (`_ShellPageTransition`)
- `lib/component/now_playing_artwork_hero.dart`: Hero 飞行插值与 HeroFrame
- `lib/page/now_playing_page/`: NowPlaying 播放页与底栏联动 (`page.dart`, `component_views.dart`, `top_actions.dart`)
- `lib/page/settings_page/page.dart`: 设置页分类切换动效
- `lib/theme/app_component_themes.dart`: MenuThemeData 与 MenuButtonThemeData 现代视觉定义
- `lib/component/animated_menu_content.dart`: 菜单级联展开动效
- `lib/component/audio_context_menu.dart` & `lib/component/album_context_menu.dart`: 歌曲/专辑右键菜单
- `lib/page/uni_page_components.dart`: 清洗局部菜单覆盖样式
- `test/`: 包含 entry_transition_test, app_shell_test, now_playing_artwork_hero_test 等测试套件
