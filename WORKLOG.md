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

## 2026-04-25 - Apple Music 风格 UI 计划阶段 1-6 完成

### 背景

- 根据 `docs/apple_music_ui_plan.md` 继续推进 Apple Music 风格 UI 更新计划，覆盖专辑色彩、流体背景、列表动效、歌词动效、全局音频可视化和专辑 Hero 转场。
- 当前目标是在保持 Flutter + Rust + BASS 架构稳定的前提下，完成计划内剩余视觉与播放体验改造。

### 实现

- 阶段 1：新增 Rust 专辑封面主色调提取 API，Dart 侧接入 `AlbumPalette` 与 `ThemeProvider` 调色板缓存，并加入快速切歌 request id 防串色保护。
- 阶段 2：新增 `LiquidGradientBackground`，主布局背景从静态渐变升级为可按 `UiEffectsLevel` 降级的流体渐变；用户自定义背景图存在时只作为 tint/scrim。
- 阶段 3：扩展 `CpMotionPressable` 的 hover/press/shadow/glow 参数，并接入歌曲、专辑、艺术家列表项；封面绘制使用 `RepaintBoundary` 隔离。
- 阶段 4：增强 Now Playing 竖向、横向和沉浸歌词动效，当前行增加字号、字重、透明度和 glow；快速切歌时清理旧滚动状态与延迟任务。
- 阶段 5：扩展 BASS FFI `BASS_ChannelGetData` 与 FFT 常量，在 `BassPlayer` 暴露 `sampleFft()`；`PlaybackService` 以 30fps 平滑输出 `audioSpectrum`，底部播放器背景接入 `LiquidAudioVisualizer`。
- 阶段 6：新增专辑封面共享元素转场，使用独立 `album-artwork:*` tag；通过 `AppNavigationState` 限制同一次转场只有被点击的源封面启用，避免重复 Hero tag。

### 验证

- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter test tools\test\sort_smoke_test.dart` 通过。
- `cargo check` 通过。
- `flutter build windows --debug` 通过。
- `flutter build windows --release` 通过。
- `git diff --check` 通过；仅有 Git LF/CRLF 提示。

### 注意事项

- WASAPI 独占模式下暂不启用 FFT 采样，避免读取 decoding channel 时影响播放进度。
- 专辑 Hero 只在 `AlbumsPage` 的 `AlbumTile(enableHero: true)` 启用，其他复用场景默认不参与共享元素转场。
- 后续若增加设置页可视化开关，应复用 `PlaybackController.audioSpectrum`，不要让 UI 直接访问 BASS stream handle。

## 2026-04-25 - 1.7.1 预发布整合

### 实现

- 将应用版本从 `1.7.0` 更新到 `1.7.1`，同步 `pubspec.yaml` 和 `AppSettings.version`。
- 将本轮 Apple Music 风格 UI 阶段 1-6 内容整理为 `docs/changelog.md` 的 `1.7.1` 预发布条目。
- 新增 `docs/releases/v1.7.1.md` 和 `docs/releases/v1.7.1.json`，并在发布说明中加入与 `1.7.0` 预发布的差异对比。
- 更新 `docs/releases/README.md`，把 `v1.7.1` 发布说明和 release payload 纳入当前发布文件列表。

### 验证

- `docs/releases/v1.7.1.json` 可被 `ConvertFrom-Json` 正常解析，`prerelease` 为 `true`。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter test tools\test\sort_smoke_test.dart` 通过。
- `cargo check` 通过。
- `flutter build windows --debug` 通过。
- `flutter build windows --release` 通过。
