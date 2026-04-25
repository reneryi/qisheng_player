# WORKLOG

本文件记录重要实现、验证结果与后续注意事项。

## 2026-04-25 - UI 丝滑化第一轮与播放详情页卡死修复

### 背景

- 参考 Spotube 的 Flutter/shadcn 简洁风格，对 Coriander Player 做第一轮全应用 UI 与动效优化。
- 实测发现点击底部播放器进入播放详情页时卡死，控制台报错：`There are multiple heroes that share the same tag within a subtree`。

### 实现

- 引入 `shadcn_flutter` 依赖，并新增 `AppShadcnTheme` 作为 shadcn 主题桥，保留现有 Material/GoRouter/Provider 架构。
- 新增 `Cp*` 兼容组件层：`CpSurface`、`CpMotionPressable`、`CpAnimatedSwitcher`、`CpButton`、`CpIconButton`、`CpListTile`，用于统一 hover、press、surface、切换动效。
- 将主应用路由转场调整为 shared-axis 风格，普通页面与 Now Playing 页面使用不同节奏的转场时长。
- 将 `AppShell` 主内容面板与 `BottomPlayerBar` 底部浮层迁移到轻量 `CpSurface`，降低玻璃、描边和强阴影存在感。
- 将歌曲、专辑、艺术家列表项迁移到 `CpMotionPressable`，统一悬停、按压、选中和正在播放状态反馈。
- 为底部播放器封面到 Now Playing 封面加入 `Hero(tag: 'now-playing-artwork')` 转场。
- 修复 Hero 重复 tag：当当前路由已经是 Now Playing 时，底部播放器封面不再注册 `Hero`，只渲染普通封面，避免同一路由子树内出现重复 Hero。
- 新增 `isNowPlayingRoute` 安全判断，兼容没有 `GoRouterState` 的测试/独立挂载场景。
- 对竖向歌词滚动增加重复索引节流和 `RepaintBoundary`，减少播放过程中不必要的整块重绘。

### 验证

- `flutter analyze` 通过。
- `flutter test` 通过，当前 32 项测试全部成功。
- 专项覆盖：`bottom_player_bar_widget_test`、`now_playing_content_test`、`now_playing_overlay_context_test`。

### 注意事项

- 当前 `CpButton` / `CpIconButton` 使用 Material 兼容实现，避免独立 widget test 缺少 shadcn Theme；shadcn 主要作为主题桥与后续迁移基座。
- 后续如果继续扩大 Hero/shared element 转场，必须保证每个 route subtree 内同一 tag 只出现一次。
- 底栏部分可见文案临时使用英文 ASCII，以避免当前仓库部分文件编码乱码继续破坏 Dart 字符串；后续建议统一修复仓库文本编码后再恢复中文文案。

## 2026-04-25 - 乱码清理与播放器文案恢复

### 背景

- 用户实测发现 `WORKLOG.md`、`docs/changelog.md` 以及播放器界面中仍存在中文乱码。
- 前序修复中部分 PowerShell 行替换导致 Dart 字符串和 Widget 结构出现断裂，需要先恢复可解析状态。

### 实现

- 修复 `BottomPlayerBar` 中独占模式按钮、播放队列弹窗、关闭按钮和队列入口的中文文案。
- 修复 `NowPlayingPage` 中桌面歌词 tooltip 与滚动文本清理注释的乱码。
- 修复 `AppTheme` 中播放器 token 断裂和主题注释乱码。
- 修复 `UniPage` 通用页面容器注释乱码。
- 重写 `docs/changelog.md`，将不可读历史乱码整理为干净中文摘要，并保留本次 UI 丝滑化与 Hero 修复记录。
- 保留 `audio_library.dart` 与 `tag_reader.rs` 中用于识别损坏文本的 `锟斤拷` / 替代字符检测逻辑。

### 注意事项

- 后续写入中文文档或源码时统一使用 UTF-8，避免 PowerShell 默认编码再次制造 mojibake。
- 若继续做全项目编码清理，需区分“真实乱码”和“用于检测乱码的测试/清理逻辑”。

## 2026-04-25 - 播放器全屏切换 Slider 卡死修复

### 背景

- 用户实测发现播放器最大化后点击全屏按钮会卡死。
- Flutter 报错指向 `BottomPlayerBar` 的音量 `Slider`：窗口状态切换过程中 RenderSlider 收到 `BoxConstraints(w=0.0)`，在 paint 阶段触发 `dart:ui/math.dart` 的 `clampDouble` 断言。

### 实现

- 新增 `canPaintSliderAtWidth`，统一判断 Slider 的实际可绘制宽度，宽度小于安全阈值时直接渲染空节点。
- 给底部播放器音量条增加 `LayoutBuilder` 宽度保护，避免 `AnimatedContainer` 宽度坍缩到 0 时仍绘制 Slider。
- 给底部播放器进度条增加同样的宽度保护，避免极窄窗口或布局动画下出现同类断言。
- 对播放进度、时长、音量值增加 finite 检查，避免 NaN/Infinity 进入 Slider。

### 验证

- 新增 `canPaintSliderAtWidth` 单元测试。
- 新增 `BottomPlayerBar survives volume slider width collapse` widget 回归测试，覆盖宽布局切换到 dense 布局时音量 Slider 收缩过程。
