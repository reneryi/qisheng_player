# 更新日志

本文件记录项目的显著变更，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

## [Unreleased]

- 暂无。

## [1.7.0] - 2026-04-25

### 新增

- 新增 UI 视觉风格模式，支持在设置页切换“玻璃拟态”和“高对比极简”，并持久化 `UiVisualStyleMode`。
- 新增 UI 效果强度设置和 Windows 背景材质设置，支持在平衡、视觉、性能以及 Auto、Mica、Acrylic、关闭之间切换。
- 新增共享主框架 `MainLayoutFrame`、全局底部播放器 `BottomPlayerBar`、主题 token 扩展和 `Cp*` 兼容组件层，为后续 UI 迁移提供统一基础。
- 新增 `shadcn_flutter` 依赖和 `AppShadcnTheme` 主题桥，保留现有 Material 架构的同时支持渐进迁移。
- 新增 Now Playing 内容视图拆分、顶部操作区、媒体信息面板和幕后信息展示，支持读取并展示 `composer`、`arranger` 等元数据。
- 新增播放会话恢复，记录上次歌曲、播放队列、队列索引和播放进度，启动后可恢复到上次状态。
- 新增播放、歌词和桌面歌词控制抽象接口，便于 UI 解耦和测试注入。

### 变更

- 主界面重构为浮层侧栏、页面面板和底部浮动播放器的桌面布局，并在大屏支持侧边栏展开/收起。
- 页面标题区、设置页、文件夹页、音乐列表、专辑列表、艺术家列表、播放队列和 Now Playing 页面统一到新的视觉节奏和动效体系。
- 搜索入口移入页面头部，音乐页支持展开式内联搜索。
- 动态主题改为更克制地影响强调色和背景渐变，避免破坏整体表面层级。
- 主路由转场调整为 shared-axis 风格，底部播放器封面与 Now Playing 封面接入共享 `Hero` 转场。
- 竖向歌词滚动增加重复索引节流和 `RepaintBoundary`，减少播放过程中的不必要重绘。
- 打包流程迁移到 `dist/windows/`，整合主程序和桌面歌词子程序，输出 `Coriander-Player-v<version>-Windows-x64.zip` 与 `Coriander-Player-v<version>-Setup-x64.exe`。
- 项目文档和发布说明迁入 `docs/`，工具脚本迁入 `tools/release/`、`tools/test/`，README 同步新的项目结构和发布目录约定。

### 修复

- 修复播放器最大化后点击全屏按钮时，底部播放器音量 `Slider` 在窗口状态切换瞬间收到 0 宽约束，触发 Flutter `clampDouble` 断言并卡死的问题。
- 为底部播放器进度条与音量条增加实际绘制宽度保护，并过滤非有限数值，避免极窄布局、窗口动画或全屏切换过程中的绘制断言。
- 修复点击底部播放器进入播放详情页时，底栏封面 Hero 与详情页封面 Hero 使用相同 tag 导致 Flutter 断言并卡死的问题。
- 修复底部播放器在没有 `GoRouterState` 的测试或独立挂载场景下读取当前路由会抛 `GoError` 的问题。
- 清理代码与文档中的中文 mojibake 乱码，恢复播放器队列、独占模式、关闭按钮、桌面歌词等可见中文文案。
- 修复系统主题读取失败时可能影响启动的问题，增加明暗模式和强调色回退值。
- 修复旧偏好可能导致启动页异常、音乐页默认排序异常、历史 100% 启动音量以及静音快捷键冲突的问题，并在读取偏好时自动规范化。

### 测试

- 新增视觉风格模式、主题效果映射、主布局、侧栏、页面框架、Now Playing 内容、底部播放器和音量条宽度坍缩等测试。
- 当前版本发布前执行 `flutter analyze`、`flutter test`、`cargo check`、主程序 Windows release 构建、桌面歌词 Windows release 构建与 Windows 发布打包。
