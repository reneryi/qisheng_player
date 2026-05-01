# WORKLOG

本文件记录重要实现、验证结果与后续注意事项。

## 2026-05-01 - qisheng_player v1.1.0 发布整合

### 背景

- 需要整理本轮 UI、桌面歌词、启动扫描和发布链路修复，并将正式版本提升到 `1.1.0`。
- 仓库已迁移到 `https://github.com/reneryi/qisheng_player`，更新检查与发布配置需要同步。

### 实现

- 精简顶栏、列表和索引栏视觉层级，统一圆角并优化歌词与页面切换动画。
- 修复桌面歌词在 Debug、Release 和安装目录中的查找路径，发布包与 CI 主产物均包含 `desktop_lyric` bundle。
- 启动索引更新改为后台静默执行，文件夹页手动扫描仍保留进度动画。
- 新增启动检查 GitHub Release 的更新提示；暂不做播放器内自动替换安装包，提示界面提供 GitHub 下载入口。
- 更新 `docs/changelog.md`、`docs/releases/v1.1.0.md`、`docs/releases/v1.1.0.json` 和发布流程文档。

### 验证

- 发布前执行格式化、静态分析、测试、Windows Release 构建、打包脚本与 GitHub Release 上传。

## 2026-04-29 - qisheng_player v1.0 整合

### 背景

- 用户选择“栖声”方案后，需要将播放器名称、图标、文档、更新日志和发布流程整理为 `qisheng_player v1.0`。
- 同时继续排查播放器内剩余中文乱码，避免发布版本中出现“文件夀”“专辀”“歌區”“版本＀”等可见错误。

### 实现

- 将应用版本统一为 `1.0.0`，发布名使用 `Qisheng Player v1.0`。
- 修复侧栏、文件夹页、专辑页、歌单菜单、设置页、更新检查和歌词来源页中的残留乱码。
- 重写 `README.md`、`CONTRIBUTING.md`、`docs/changelog.md`、`docs/project_structure.md`、`docs/release_workflow.md` 和 `docs/msix_install.md`。
- 新增 `docs/releases/v1.0.0.md` 与 `docs/releases/v1.0.0.json`，作为 GitHub Release 说明与附件清单。

### 验证

- 本轮发布前会重新执行格式化、静态分析、关键测试、Windows Release 构建和发布包脚本。

## 2026-04-28 - 主界面卡顿与导航交互修复

### 背景

- 用户反馈主界面在当前默认效果设置下存在明显卡顿，同时左上角前进/后退按钮无法点击。
- 另外在展开或收起侧栏时，Flutter 持续抛出 `RenderFlex overflowed by 2.0 pixels on the right`，错误定位到 `side_nav.dart` 的收起态菜单项。

### 实现

- 将 `AppNavigationState` 改为 `ChangeNotifier`，让 shell 内历史状态变化可以主动通知顶栏按钮重建。
- 将顶栏的 `NavBackBtn` 和 `NavForwardBtn` 改为监听 `AppNavigationState.instance`，修复历史已存在但按钮仍保持禁用态的问题。
- 修正侧栏收起态图标的安全尺寸：缩小 `_MetalNavIcon` 的外围 glow 容器，避免在 `48px` 宽约束下出现 `2px` 横向溢出。
- 对默认 `balanced` 效果档做减负：背景流体动画改为静态，降低混色强度与模糊半径，减少持续 repaint 带来的掉帧。
- 将底部 `LiquidAudioVisualizer` 限制为仅在 `UiEffectsLevel.visual` 下启用，避免默认使用时频谱波形持续重绘。
- 下调 `balanced` 档的玻璃模糊和阴影深度，使默认主界面更偏向稳定和流畅，而不是追求最强视觉效果。

### 验证

- `dart format` 已执行。
- `flutter analyze` 通过。
- `flutter test test\navigation_state_test.dart test\component\side_nav_test.dart test\component\main_layout_frame_test.dart test\theme\app_theme_effects_test.dart test\component\bottom_player_bar_widget_test.dart` 通过。
- `flutter test` 通过，当前 60 项测试全部成功。

### 注意事项

- 当前默认体验已经把高成本的动态背景和底栏频谱从 `balanced` 档移出；如果后续仍有卡顿，下一步应优先排查 Windows 调试模式下的 `BackdropFilter` 堆叠成本。
- 底栏音频可视化现在仅在 `visual` 档启用，属于有意的体验取舍，不再保证默认模式下始终可见。

## 2026-04-27 - 主界面对齐概念图改版

### 背景

- 用户要求主播放器主界面对齐参考概念图，重点是夜间模式的深藏青玻璃质感、动态青色强调色、侧栏悬浮胶囊、铺满式主内容区和贯穿式底部播放栏。
- 同时要求保留项目现有功能语义，只调整布局、视觉层级和控制区按钮编排，不把概念图中不属于项目的功能直接照搬进来。

### 实现

- 重调夜间主题基底与动态取色混合策略：主背景从偏暖雾面过渡到更深的藏青/墨蓝层次，玻璃染色锚点改为更接近 cyan/teal 的高对比强调色。
- 调整主框架 token：减小 `shellGap`、放宽 `shellContentMaxWidth`、抬高底栏高度，让页面内容更贴近窗口边缘，减少此前左右明显留空。
- 顶栏改造为概念图式结构：移除播放器名称，加入返回/前进导航簇，保留歌词主显示区并包装成浅层药丸输入区风格。
- 为 shell 内页面补上独立前进/后退历史，侧栏切页改为 `context.go(...)`，让顶部前进按钮在播放器主界面里真实可用，而不是静态占位。
- 侧栏重做为更窄的悬浮胶囊：压缩展开/收起宽度，强化选中态的动态强调色与柔光，收起控制项改为仅显示箭头图标，不再显示“收起侧栏/展开侧栏”文字。
- 页面头部取消整块玻璃大框，标题、搜索和动作按钮直接悬浮在主内容区顶端，更接近概念图的无包裹式排布。
- 右侧 A-Z 锚点条改为更细长的玻璃索引柱，定位按钮保持功能但视觉统一到新的浮层样式。
- 底部播放栏重排控制逻辑：拆分“随机播放”和“顺序/单曲循环”为两个独立按钮，保留独占模式与队列功能，音量区改为概念图式胶囊滑杆。
- 将桌面歌词入口从原播放模式按钮位接管到底栏右侧，同时移除播放详情页顶部的重复桌面歌词按钮，避免同一功能多入口堆叠。

### 验证

- `dart format` 已执行。
- `flutter analyze` 通过。
- `flutter test test\navigation_state_test.dart test\component\side_nav_test.dart test\component\bottom_player_bar_test.dart test\component\expandable_search_action_test.dart test\component\main_layout_frame_test.dart` 通过。
- `flutter test` 通过。

### 注意事项

- 顶栏“前进”历史当前基于 shell 内部页面切换历史，不会覆盖详情页/弹层自己的返回逻辑；后续若引入更复杂的多级导航，需要继续统一历史来源。
- 这次主要完成播放器主界面的布局和控制区改版，音乐行卡片、专辑/艺术家等内容项仍保持现有结构，只做了适配性视觉收敛。

## 2026-04-27 - 玻璃拟态播放器 UI 升级

### 背景

- 用户希望播放器界面全面转向 Glassmorphism：使用高斯模糊与半透明表面替代生硬色块。
- 同时希望背景具备淡紫、柔金和 misty blue 的慢速弥散光效果，并让侧边栏、底部播放栏和技术信息展示更精致。

### 实现

- 将 `AppSurface` 与 `CpSurface` 的主要表面统一升级为半透明毛玻璃效果，保留 `UiEffectsLevel` 的性能降级策略。
- 重调 `LiquidGradientBackground` 和动态主题背景生成逻辑，使主背景转为淡紫、柔金、misty blue 与专辑色彩融合的慢速弥散光。
- 将页面标题区、窗口控制区、Now Playing 专业面板和队列面板迁移到更轻的玻璃表面。
- 精修侧边栏：降低条栏分割感，新增玫瑰金/香槟金/银色金属图标描边感，选中项保留兼容测试的 active indicator 并加入光晕。
- 精修底部播放栏：提高通透度，播放、上一首、下一首按钮改为圆润金银金属质感，中央播放按钮加入柔和弥散光环。
- 将播放进度条和音量条的强调色调整为柔金色，封面占位也同步为金属玻璃感。
- 降低 Now Playing 专业面板中 FLAC、kHz、kbps 等技术信息的视觉重量，元数据徽标在悬停时增强可读性。
- 修复玻璃播放栏 padding 调整后中央控制区在 Windows 调试运行中底部溢出 2px 的问题：中央区间距改为根据可用高度自适应压缩。
- 调整字体 fallback，优先使用 Segoe UI Variable 与 Microsoft YaHei UI，并移除标题负字距以保持中英文排版更稳。

### 验证

- `dart format` 已执行。
- `flutter analyze` 通过。
- `flutter test test\component\bottom_player_bar_widget_test.dart` 通过。
- `flutter test` 通过，当前 58 项测试全部成功。

### 注意事项

- `AppSurface` 和 `CpSurface` 当前会在非 performance 模式下尽量使用 BackdropFilter；后续若在低端设备上发现 GPU 压力，可继续按 `UiEffectsLevel` 做更细粒度降级。
- 本次继续保留 `side-nav-active-indicator` 测试 key，避免视觉改造破坏既有侧栏回归测试。

## 2026-04-26 - 偏好恢复、排序兼容与索引层乱码修复

### 背景

- 继续按优先级处理可明确落地的维护项。
- 发现 `NowPlayingStyleMode.fromString` 固定返回 `immersive`，会导致正在播放页面模式无法从配置恢复到 `studio`。
- 发现 `SortOrder.decending` 枚举拼写错误会继续写入配置，后续维护成本较高。
- 需要把音乐元数据乱码修复从 Dart 显示兜底进一步下沉到 Rust 索引读取阶段，减少新索引写入乱码的机会。

### 实现

- 修复 `NowPlayingStyleMode.fromString`，按枚举名称恢复 `immersive` / `studio`，未知值返回 `null` 并走默认值。
- 新增 `test/app_preference_test.dart`，覆盖 Now Playing 页面模式恢复、偏好读取和旧排序配置兼容。
- 将 `SortOrder.decending` 更正为 `SortOrder.descending`，并在 `SortOrder.fromString` 中兼容读取旧配置值 `decending`。
- 将 UTF-8 mojibake 修复逻辑补到 `rust/src/api/tag_reader.rs` 的 `sanitize_metadata_text`，让索引生成阶段也能清理常见乱码。
- 扩展 Dart 和 Rust 的可读字符评分范围，纳入假名、韩文音节和兼容韩文字母，避免日文/韩文乱码无法修复。
- 补充多语言元数据测试，覆盖中文、日文、韩文、繁体中文和 emoji 场景。

### 验证

- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter test test\library\audio_library_test.dart` 通过。
- `cargo test` 通过。
- `cargo check` 通过。
- `flutter build windows --debug` 通过。
- `git diff --check` 通过；仅有 Git LF/CRLF 规范化提示。

### 注意事项

- `decending` 只保留在旧配置读取兼容逻辑中，新的保存值会写入 `descending`。
- Rust 索引层修复和 Dart 显示层修复会同时存在：前者减少新索引乱码，后者兜底历史索引和播放列表中已有数据。

## 2026-04-26 - 音乐库页面顶栏动作排版优化

### 背景

- 用户反馈音乐、文件夹、歌单、艺术家和专辑页顶栏按钮排版不统一：主操作与排序/视图按钮分成两行，部分页面按钮未贴近右边缘。
- 目标是让标题、搜索和页面动作的视觉层级更清晰，并保持现有页面共用结构。

### 实现

- 扩展 `PageScaffold`，新增 `titleAction` 插槽，用于把音乐页搜索按钮放在“音乐”标题右侧。
- 调整宽屏顶栏布局：主操作与次级动作合并成同一行动作区，并让动作区贴近顶栏右边缘。
- 调整窄屏顶栏布局：主操作与次级动作同样合并为水平滚动动作行，避免上下两组按钮割裂。
- `AudiosPage` 将搜索入口从 `primaryAction` 移到 `titleAction`，使搜索按钮与标题同一行，随机播放、排序、升降序、视图切换和多选按钮保留在右侧动作行。
- 顺手修复通用定位按钮 tooltip 的乱码，恢复为 `定位当前音乐`。

### 验证

- `flutter analyze` 通过。
- `flutter test test\page\page_scaffold_test.dart test\component\expandable_search_action_test.dart test\page\folders_page_test.dart` 通过。

## 2026-04-26 - 播放器界面中文化与乱码兜底增强

### 背景

- 用户反馈播放器界面仍有乱码，并且部分可见名称仍显示英文。
- 需要在不扩大 UI 重构范围的前提下，优先修正可见文案和音乐元数据乱码兜底。

### 实现

- 将播放器控制区、Now Playing 顶栏、歌词占位、专业面板、侧栏副标题、设置页和扫描/欢迎页中的残留英文可见文案改为中文。
- 将 CUE 默认分轨名从 `Track 01` 改为 `音轨 01`。
- 将音乐元数据中的 `UNKNOWN` 兜底显示改为 `未知艺术家`、`未知专辑`、`未知格式`。
- 增强 `Audio` 元数据清洗逻辑，支持修复常见 UTF-8 被误按 Latin-1 / Windows-1252 解码导致的中文、日文 mojibake，并清除替代字符、BOM、控制字符和 `锟斤拷`。
- 补充音频元数据单元测试，覆盖 `UNKNOWN` 中文兜底、中文 mojibake 修复和包含 C1 控制字符的日文 mojibake 修复。

### 验证

- `flutter analyze` 通过。
- `flutter test test\library\audio_library_test.dart test\component\bottom_player_bar_widget_test.dart test\component\horizontal_lyric_view_test.dart` 通过。
- `cargo check` 通过。

### 注意事项

- 当前仍保留 `CUE`、`M3U`、`RGB`、`ReplayGain`、`Windows`、`UI` 等协议、格式、品牌或技术术语，不作为英文界面问题处理。
- 乱码修复是显示层和索引读取后的兜底修复；若源音乐标签本身写入错误，仍建议通过现有编辑标签功能保存正确元数据。

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
