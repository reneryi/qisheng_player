# Apple Music 风格 UI 更新计划

本文档记录 Coriander Player 在 1.7.0 预发布版本之后的 UI 更新路线。目标是沿着 Apple Music 式的沉浸视觉、流体背景、动态歌词和全局音频可视化方向迭代，同时保持现有 Flutter + Rust + BASS 架构的稳定性。

## 目标

- 用专辑封面色彩驱动全局氛围色、玻璃层和播放页背景。
- 将主背景从静态渐变升级为柔和流体背景。
- 提升歌曲、专辑、艺术家列表的 hover、press 和选中反馈。
- 将 Now Playing 歌词升级为更有层级的动态排版。
- 在全局底部播放器加入低干扰、柔和的实时音频可视化。
- 保持桌面端滚动、切歌、路由跳转和播放控制稳定。

## 当前基础

1.7.0 已经完成以下基础建设：

- `ThemeProvider` 已支持封面驱动的动态主题色。
- `MainLayoutFrame` 已统一主窗口背景、标题栏、页面面板和底部播放器布局。
- `BottomPlayerBar` 已成为全局底部播放器。
- `CpSurface`、`CpMotionPressable`、`CpButton`、`CpIconButton` 已作为兼容组件层。
- `AppTheme`、`app_theme_extensions.dart` 已抽象颜色、表面、动效和播放器 token。
- Rust / flutter_rust_bridge 已存在，适合承接封面色彩提取等 CPU 密集任务。
- BASS FFI 已存在，适合后续扩展 FFT 频域数据读取。

## 总体策略

- 先做色彩地基，再做视觉表现。
- 先局部增强，再全局替换。
- 先使用 `CustomPainter` 和 Flutter 原生能力实现流体背景，暂不直接引入复杂 shader。
- 所有高频动画必须使用 `RepaintBoundary` 隔离重绘。
- 所有封面色彩计算必须异步执行并缓存，不能阻塞 UI 线程。
- BASS FFT 可视化单独作为高风险阶段处理，不和主题背景改造混在同一提交。

## 阶段 1：Rust 主色调提取

### 目标

替换当前 `ThemeProvider` 中基于 `PaletteGenerator` 的单色提取逻辑，改为 Rust 侧从封面图片中提取 4-6 个稳定色值，为流体背景、歌词 glow 和底部栏氛围色打基础。

### 涉及文件

- `rust/Cargo.toml`
- `rust/src/api/album_palette.rs`
- `lib/src/rust/api/album_palette.dart`
- `lib/theme_provider.dart`
- `lib/library/audio_library.dart`
- `flutter_rust_bridge.yaml`

### 实施细节

- 新增 Rust API：`extract_dominant_colors(image_bytes: Vec<u8>, max_colors: u8) -> anyhow::Result<Vec<u32>>`。
- 输入优先使用封面图片原始字节，不使用 UI 层的 `ImageProvider`。
- Rust 侧使用已有 `image` crate 解码图片。
- 解码后统一下采样到 `64x64`，降低像素数量和计算成本。
- 色彩提取先实现轻量 Median Cut 或 K-Means；第一版优先简单、稳定、可测。
- 返回 RGB int，Dart 侧转换为 `Color(0xFF000000 | rgb)`。
- 新增 Dart 侧 `AlbumPalette` 模型，至少包含 `primary`、`secondary`、`accent`、`muted`。
- `ThemeProvider` 新增 `_paletteCache`，缓存 key 使用 `audio.path`、`audio.modified` 和 `audio.mediaPath` 组合。
- 快速切歌时使用递增 request id，避免上一首异步结果覆盖当前歌曲主题。
- 封面不存在、字节读取失败、Rust 提取失败时回退到当前 `defaultTheme` 和 `_fallbackDominantColor()`。

### 不做事项

- 不在 `album_tile.dart`、`artist_tile.dart`、`audio_tile.dart` 渲染时动态提取色彩。
- 不在音乐库扫描时批量提取全库封面。
- 不把调色板写入已有 `index.json`，除非后续确认有持久化需求。
- 不在此阶段引入 shader 或 FFT 可视化。

### 验证

- `flutter_rust_bridge_codegen` 成功生成绑定。
- `cargo check` 通过。
- `flutter analyze` 通过。
- 新增 Rust 或 Dart 测试覆盖无效图片、空图片、单色图片、多色图片。
- 手动验证切歌后主题色稳定更新，快速切歌不会出现颜色串歌。

## 阶段 2：流体渐变背景

### 目标

把 `MainLayoutFrame` 当前静态 `LinearGradient` 升级为 Apple Music 风格的柔和动态背景。

### 涉及文件

- `lib/component/main_layout_frame.dart`
- `lib/component/ui/liquid_gradient_background.dart`
- `lib/theme_provider.dart`
- `lib/theme/app_theme_extensions.dart`

### 实施细节

- 新增 `LiquidGradientBackground` 组件。
- 第一版用 `CustomPainter` 绘制多个缓慢移动的径向渐变光斑。
- 使用 `AnimationController` 或 `Ticker` 提供缓慢时间参数。
- 背景整体包裹 `RepaintBoundary`。
- `UiEffectsLevel.performance` 下禁用动态流动，仅显示静态渐变。
- `UiEffectsLevel.balanced` 下使用低速、低透明度流动。
- `UiEffectsLevel.visual` 下增强 glow、模糊和颜色混合。
- 保留用户自定义背景图逻辑，并定义优先级：自定义背景图存在时，专辑流体背景只作为 tint / scrim，不覆盖用户图片。

### 验证

- 切歌时背景颜色平滑过渡。
- 页面切换不闪烁。
- 性能模式下动画停止。
- `flutter analyze` 和相关 widget test 通过。

## 阶段 3：列表与卡片动效

### 目标

提升桌面端鼠标操作质感，让歌曲、专辑、艺术家列表拥有轻微 Z 轴浮起感。

### 涉及文件

- `lib/component/cp/cp_components.dart`
- `lib/component/album_tile.dart`
- `lib/component/artist_tile.dart`
- `lib/component/audio_tile.dart`
- `lib/page/uni_page.dart`

### 实施细节

- 扩展 `CpMotionPressable`，增加可配置 hover scale、press scale、hover shadow 和 selected glow。
- hover scale 建议控制在 `1.015-1.035`，避免列表抖动。
- press scale 建议控制在 `0.985-0.995`。
- 阴影和 glow 使用 `AppSurfaceTokens` 或新增 token 控制。
- 封面图单独包裹 `RepaintBoundary`。
- 大列表中不使用 `BackdropFilter`，避免滚动性能下降。
- 对当前播放项、选中项、hover 项定义清晰优先级。

### 验证

- 列表快速滚动不卡顿。
- hover / selected 状态在亮暗模式下可读。
- 现有 tile 和页面测试不回退。
- 新增 `CpMotionPressable` hover / press 状态测试。

## 阶段 4：Now Playing 歌词动效

### 目标

将歌词从普通滚动文本升级为更接近 Apple Music 的动态排版体验。

### 涉及文件

- `lib/page/now_playing_page/component/vertical_lyric_view.dart`
- `lib/component/horizontal_lyric_view.dart`
- `lib/page/now_playing_page/component_views.dart`
- `lib/theme/app_theme_extensions.dart`

### 实施细节

- 当前行增加字号、字重、不透明度和轻微 glow。
- 非当前行降低透明度，已播放行和未播放行可使用不同衰减。
- 第一版不做真实 blur，避免文字发糊和 GPU 压力过高。
- 滚动曲线使用主题 motion token 或 `Curves.easeOutCubic`，避免线性跳动。
- 歌词区域包裹 `RepaintBoundary`。
- 快速切歌时清理旧滚动目标和动画状态。
- 保留无歌词、纯音乐、翻译歌词、桌面歌词开关等现有场景。

### 验证

- 歌词索引越界测试通过。
- 快速切歌不抛异常。
- 无歌词页面正常。
- Now Playing 相关 widget test 通过。

## 阶段 5：全局 FFT 音频可视化

### 目标

在 `BottomPlayerBar` 中加入低干扰、柔和的实时音频可视化。视觉上偏流体线条和呼吸波形，不做传统高对比柱状图。

### 涉及文件

- `lib/src/bass/bass.dart`
- `lib/src/bass/bass_player.dart`
- `lib/play_service/playback_service.dart`
- `lib/component/bottom_player_bar.dart`
- `lib/component/audio_visualizer/liquid_audio_visualizer.dart`

### 实施细节

- BASS FFI wrapper 新增 `BASS_ChannelGetData`。
- 新增 `BASS_DATA_FFT256` 或 `BASS_DATA_FFT512` 常量。
- `BassPlayer` 暴露 FFT 采样接口，不直接让 UI 访问 `_fstream`。
- 播放中采样，暂停时停止采样或做平滑衰减。
- 第一版采样频率控制在 `30fps`，稳定后再考虑 `60fps`。
- FFT 数据做时间平滑：`smoothed = old * 0.8 + raw * 0.2`。
- 视觉使用 `CustomPainter` 绘制柔和贝塞尔波形。
- `LiquidAudioVisualizer` 必须包裹 `RepaintBoundary`。
- 可视化层放在 `BottomPlayerBar` 背景，不影响按钮、进度条、音量条 hit test。
- 设置页后续可增加关闭开关，给低性能机器降级。

### 验证

- 播放中波形有响应。
- 暂停后波形衰减或静止。
- 底栏按钮和 Slider 不跟随 FFT 高频重绘。
- `flutter build windows --debug` 和 `flutter build windows --release` 通过。

## 阶段 6：Hero 与页面连续性

### 目标

补充专辑封面从列表到详情页的共享元素转场，增强页面之间的空间连续性。

### 涉及文件

- `lib/component/album_tile.dart`
- `lib/page/album_detail_page.dart`
- `lib/page/now_playing_page/page.dart`
- `lib/navigation_state.dart`

### 实施细节

- 先只做专辑列表到专辑详情，不同时扩展到歌曲和艺术家。
- Hero tag 使用稳定唯一值，例如 `album-artwork:${album.name}:${album.works.first.path}`。
- 不复用 Now Playing 的 `now-playing-artwork` tag。
- 当前路由树内同一个 tag 只允许出现一次。
- 没有封面时不启用 Hero。
- 对快速点击多个专辑的场景做防抖或安全判断。

### 验证

- 专辑页进入和返回动画正常。
- 快速点击多个专辑不触发重复 Hero tag。
- Now Playing 现有 Hero 修复不回退。

## 风险与约束

- Flutter 桌面端高频动画容易扩大 repaint 范围，必须用 `RepaintBoundary` 隔离。
- Rust 色彩提取需要重新生成 FRB 绑定，生成文件变更较多，应该单独提交。
- BASS FFT 涉及播放 handle 生命周期，必须处理未播放、暂停、切歌、停止、释放资源等场景。
- Apple Music 风格不能过度发光，否则会影响文字可读性。
- 自定义背景图片和专辑色彩背景必须明确优先级，避免用户设置失效。
- 任何新增动画都必须遵守 `UiEffectsLevel` 降级策略。

## 推荐提交拆分

- `feat: add Rust album palette extraction`
- `feat: add liquid album background`
- `feat: enhance tile hover motion`
- `feat: refine now playing lyrics motion`
- `feat: add global audio visualizer`
- `feat: add album artwork hero transition`

## 验证命令

```powershell
flutter pub get
flutter analyze
flutter test
flutter test tools/test/sort_smoke_test.dart

Set-Location rust
cargo check
Set-Location ..

flutter build windows --debug
flutter build windows --release
```

## 推荐优先级

1. Rust 主色调提取。
2. `ThemeProvider` 调色板缓存。
3. `LiquidGradientBackground`。
4. Tile hover 动效。
5. 歌词动效。
6. BASS FFT 全局可视化。
7. Album Hero 转场。

## 实施记录

### 2026-04-25

- 阶段 1 已完成：Rust 主色调提取、原始封面字节读取、Dart `AlbumPalette`、`ThemeProvider` 调色板缓存和快速切歌防串色保护已接入。
- 阶段 2 已完成：`LiquidGradientBackground` 已接入主布局，支持性能/平衡/视觉效果等级降级，并保留用户自定义背景图优先级。
- 阶段 3 已完成：`CpMotionPressable` 已扩展 hover、press、shadow、selected glow 能力，歌曲/专辑/艺术家列表项已接入。
- 阶段 4 已完成：Now Playing 竖向、横向和沉浸歌词动效已增强，快速切歌时会清理旧滚动和延迟任务。
- 阶段 5 已完成：BASS FFT 采样、`PlaybackController.audioSpectrum`、频谱平滑和底部播放器 `LiquidAudioVisualizer` 已接入；WASAPI 独占模式下暂不采样。
- 阶段 6 已完成：专辑列表到专辑详情页的封面 Hero 转场已接入，使用独立 `album-artwork:*` tag，并通过导航状态避免重复 Hero tag。
- 验证已完成：`flutter analyze`、`flutter test`、`flutter test tools\test\sort_smoke_test.dart`、`cargo check`、`flutter build windows --debug`、`flutter build windows --release`、`git diff --check` 均通过。
