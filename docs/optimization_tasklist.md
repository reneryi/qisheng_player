# 栖声播放器优化任务清单

> 本文档基于对 qisheng_player v1.2.10 的全面代码审查，整理出可落地的优化任务。
> 每个任务包含：背景、问题位置、当前代码、实施方案、验证方式、风险与依赖。
> 按优先级分批，建议按顺序执行，每批完成后跑 `flutter analyze` + `flutter test` + `cargo check` + `cargo test`。

---

## 目录

- [方向一：清理死代码 / 未完成功能](#方向一清理死代码--未完成功能)
- [方向二：性能优化](#方向二性能优化)
- [方向三：修复功能性缺陷](#方向三修复功能性缺陷)
- [方向四：提升在线匹配精度](#方向四提升在线匹配精度)
- [实施顺序建议](#实施顺序建议)
- [验证清单](#验证清单)

---

## 方向一：清理死代码 / 未完成功能

### 任务 1.1 移除 studio 模式整条死代码链路

- [x] 完成

**背景**：
`NowPlayingStyleMode.studio`（专业式）模式有完整的枚举、偏好字段、设置控件和约 500 行的 `_StudioDashboardView` 实现，但整条链路从未被调用，用户保存的 `styleMode: studio` 偏好完全无效。

**问题位置与证据**：
| 文件 | 行号 | 问题 |
|---|---|---|
| `lib/page/now_playing_page/content_view.dart` | 3-22 | `NowPlayingContentView` 定义后从未被任何地方调用，且 build 方法忽略 `styleMode` 参数，总是返回 `_ImmersiveModeView` |
| `lib/page/now_playing_page/small_page.dart` | 8 | `_NowPlayingPage_Small` 直接返回 `_ImmersiveModeView`，绕过 styleMode |
| `lib/page/now_playing_page/large_page.dart` | 8 | `_NowPlayingPage_Large` 同上 |
| `lib/page/now_playing_page/component_views.dart` | 174-696 | `_StudioDashboardView`/`_DashboardHeader`/`_StudioMetadataStrip`/`_StudioInformationPanel`/`_StudioQueuePanel`/`_CreditEntryRow`/`_PanelHeader`/`_EmptyPanelState`/`_MetadataBadge` 约 500 行从未被调用 |
| `lib/app_preference.dart` | 40-50 | `NowPlayingStyleMode` 枚举 |
| `lib/app_preference.dart` | 54 | `NowPlayingPagePreference.styleMode` 字段 |
| `lib/app_preference.dart` | 439 | `styleMode` 持久化逻辑 |
| `lib/page/settings_page/theme_settings.dart` | 477-519 | `NowPlayingStyleModeControl` 设置项未被 `settings_page/page.dart` 引用 |

**当前代码**（`content_view.dart`）：
```dart
class NowPlayingContentView extends StatelessWidget {
  const NowPlayingContentView({
    super.key,
    required this.compact,
    required this.styleMode,
  });
  final bool compact;
  final NowPlayingStyleMode styleMode;

  @override
  Widget build(BuildContext context) {
    return compact
        ? const _ImmersiveModeView(compact: true)
        : const _ImmersiveModeView(compact: false);  // styleMode 被忽略
  }
}
```

**实施方案**：
1. 删除 `lib/page/now_playing_page/content_view.dart` 整个文件（或在 `page.dart` 中移除 `part 'content_view.dart';`）。
2. 删除 `component_views.dart` 中 174-696 行的 `_StudioDashboardView` 系列代码。
3. 删除 `app_preference.dart` 中 `NowPlayingStyleMode` 枚举（40-50 行）和 `NowPlayingPagePreference.styleMode` 字段（54 行）。
4. 修改 `NowPlayingPagePreference.fromMap`（78-89 行）：移除 `styleMode` 读取逻辑，但保留向后兼容（旧配置中的 `styleMode` 字段静默忽略，不报错）。
5. 修改 `NowPlayingPagePreference.toMap`（69-76 行）：移除 `styleMode` 序列化。
6. 删除 `theme_settings.dart` 中 `NowPlayingStyleModeControl`（477-519 行）。
7. 用 grep 全局搜索 `NowPlayingStyleMode`、`styleMode`、`studio`、`_StudioDashboardView`、`NowPlayingContentView`，确保无残留引用。

**验证方式**：
- `flutter analyze` 通过
- `flutter test test/page/now_playing_content_test.dart test/page/detail_page_style_test.dart test/app_preference_test.dart` 通过
- 手动启动应用，进入 Now Playing 页面，确认沉浸式视图正常

**风险**：低。全部为删除未引用代码。需注意 `app_preference_test.dart` 中可能有 `styleMode` 相关断言，需同步更新。

---

### 任务 1.2 移除 `MiniNowPlaying` 死代码

- [x] 完成

**背景**：
`MiniNowPlaying` 组件完整实现 227 行，但从未被任何地方调用。

**问题位置**：
- `lib/component/mini_now_playing.dart` 整文件（227 行）

**实施方案**：
1. 删除 `lib/component/mini_now_playing.dart` 文件。
2. grep 搜索 `MiniNowPlaying`、`mini_now_playing`，移除所有 import 引用。

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过

**风险**：低。

---

### 任务 1.3 移除 NowPlaying 页面重复的菜单/桌面歌词按钮

- [x] 完成

**背景**：
`page.dart` 中的 `_NowPlayingMoreAction`（385-572 行）和 `_DesktopLyricSwitch`（574-612 行）与 `top_actions.dart` 中的 `NowPlayingMoreMenuAction`（3-223 行）和 `NowPlayingDesktopLyricAction`（225-263 行）功能几乎完全重复。

**问题位置**：
- `lib/page/now_playing_page/page.dart` 385-612 行
- `lib/page/now_playing_page/top_actions.dart` 3-263 行（公开版本，保留）

**实施方案**：
1. 删除 `page.dart` 中的 `_NowPlayingMoreAction`（385-572 行）和 `_DesktopLyricSwitch`（574-612 行）。
2. 检查 `_NowPlayingAppBar`（page.dart:345 附近）中对上述组件的引用，改为使用 `top_actions.dart` 的公开版本 `NowPlayingMoreMenuAction` 和 `NowPlayingDesktopLyricAction`。
3. grep 搜索 `_NowPlayingMoreAction`、`_DesktopLyricSwitch` 确认无残留。

**验证方式**：
- `flutter analyze` 通过
- `flutter test test/page/now_playing_content_test.dart test/page/now_playing_overlay_context_test.dart` 通过
- 手动进入 Now Playing 页面，点击右上角菜单和桌面歌词按钮，确认功能正常

**风险**：中。需仔细对比两套实现的差异（可能有细微行为不同），确保切换后行为一致。

---

### 任务 1.4 修复 `create_issue` 指向错误仓库

- [x] 完成

**背景**：
设置页"创建 Issue"功能指向上游 fork 源项目 `Ferry-200/coriander_player`，用户反馈的 issue 会发到上游仓库而非 `reneryi/qisheng_player`。

**问题位置**：
- `lib/page/settings_page/create_issue.dart:61`

**当前代码**：
```dart
final slug = RepositorySlug("Ferry-200", "coriander_player");
```

**实施方案**：
```dart
final slug = RepositorySlug(AppSettings.releaseRepoOwner, AppSettings.releaseRepoName);
```
`AppSettings.releaseRepoOwner` = `"reneryi"`，`AppSettings.releaseRepoName` = `"qisheng_player"`（见 `app_settings.dart:106-107`）。

**验证方式**：
- `flutter analyze` 通过
- 手动点击设置页"创建 Issue"，确认跳转到 `https://github.com/reneryi/qisheng_player/issues`

**风险**：极低。

---

### 任务 1.5 清理 `startPage` 矛盾逻辑

- [x] 完成

**背景**：
`app_preference.dart:403-405` 强制 `startPage = 0`，但字段仍被保存和读取，`entry.dart:584` 的 `_startLocation` 也使用它——逻辑矛盾，`startPage` 实际恒为 0。

**问题位置**：
- `lib/app_preference.dart:345`（保存 `startPage`）
- `lib/app_preference.dart:403-405`（强制设为 0）
- `lib/entry.dart:584`（`_startLocation` 使用 `startPage`）

**实施方案**：
选项 A（推荐，彻底移除）：
1. 移除 `AppPreference.startPage` 字段定义。
2. 移除 `toMap` 中 `startPage` 序列化。
3. 移除 `fromMap` 中 `startPage` 读取和 `needNormalizeStartPage` 逻辑（403-405 行、457-461 行中的相关分支）。
4. 修改 `entry.dart:584` 的 `_startLocation`，直接返回音乐页路由常量。

选项 B（保留字段但清理逻辑）：保留字段，移除强制设 0 的注释和代码，让 `startPage` 真正可配。

推荐选项 A，因为当前无 UI 设置启动页，字段无意义。

**验证方式**：
- `flutter analyze` 通过
- `flutter test test/app_preference_test.dart` 通过（需更新相关断言）

**风险**：低。

---

## 方向二：性能优化

### 任务 2.1 修复 `_SpinningArtwork` Ticker 永不停止

- [x] 完成

**背景**：
`_SpinningArtwork` 的 `_ticker.start()` 在 initState 启动后永不停止，即使暂停且角度已回正到 0 度，Ticker 仍在每帧调用 `_onTick`，造成持续 CPU/GPU 开销。

**问题位置**：
- `lib/component/bottom_player_bar.dart:344-405`

**当前代码**（关键部分）：
```dart
@override
void initState() {
  super.initState();
  _ticker = createTicker(_onTick);
  _ticker.start();  // 永不停止
}
```
```dart
// _onTick 中暂停+回正完成分支（388-402 行）：
} else {
  // 速度完全降为 0 后，计算最近的下一个 0 度位置
  final double fullRotations = (_angle / (2.0 * math.pi)).ceilToDouble();
  _alignStartAngle = _angle;
  _alignEndAngle = fullRotations * 2.0 * math.pi;
  if ((_alignEndAngle - _alignStartAngle).abs() < 0.01) {
    _angle = _alignEndAngle;
  } else {
    _isAligning = true;
    _alignProgress = 0.0;
  }
  setState(() {});
  // ← 此处应在回正完成后停止 Ticker
}
```

**实施方案**：
1. 在 `_onTick` 的暂停+回正完成分支中，当 `_speed == 0` 且回正动画完成（`_isAligning == false`）且 `_angle == _alignEndAngle` 时，调用 `_ticker.stop()` 并 `setState` 一次最终状态。
2. 重写 `didUpdateWidget` 检测 `widget.spinning` 变化：
   - 从 false → true（恢复播放）：`_ticker.start()` + 重置 `_lastElapsed = Duration.zero`。
   - 从 true → false（暂停）：保持 Ticker 运行（让阻尼减速和回正动画继续），无需额外操作。
3. 确保 initState 中 `_ticker.start()` 保留。

**修改后逻辑**：
```dart
} else {
  final double fullRotations = (_angle / (2.0 * math.pi)).ceilToDouble();
  _alignStartAngle = _angle;
  _alignEndAngle = fullRotations * 2.0 * math.pi;
  if ((_alignEndAngle - _alignStartAngle).abs() < 0.01) {
    _angle = _alignEndAngle;
    _ticker.stop();  // 完全静止，停止 Ticker
    setState(() {});
  } else {
    _isAligning = true;
    _alignProgress = 0.0;
    setState(() {});
  }
}
```
```dart
@override
void didUpdateWidget(covariant _SpinningArtwork oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.spinning && !oldWidget.spinning) {
    // 恢复播放，确保 Ticker 运行
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }
}
```

**验证方式**：
- 新增 widget 测试：验证暂停回正完成后 Ticker 停止、恢复播放时 Ticker 重启
- `flutter test test/component/bottom_player_bar_widget_test.dart` 通过
- 手动测试：播放→暂停→等待回正完成→观察 CPU 占用是否下降

**风险**：中。需确保所有状态转换路径都正确启停 Ticker，避免封面"卡住不转"。

---

### 任务 2.2 优化歌词逐行高斯模糊

- [x] 完成

**背景**：
每个非当前歌词行都用 `ImageFiltered(blur)` 模糊，长歌词列表滚动时 GPU 开销大。`TweenAnimationBuilder<double>` 包裹让模糊值变化时触发整行重绘。

**问题位置**：
- `lib/page/now_playing_page/component/lyric_view_tile.dart:68-77`
- `lib/page/now_playing_page/component/component_views.dart:1457`

**实施方案**：
方案 A（推荐，性能优先）：
1. 移除非当前行的 `ImageFiltered` 模糊层，改为纯 `Opacity` 区分：
   - 当前行：opacity 1.0，无模糊
   - 已播放行：opacity 0.32，无模糊
   - 未播放行：opacity 0.22，无模糊
2. 保留 `TweenAnimationBuilder<double>` 但只动画 opacity 而非 blur sigma。
3. 在设置页新增"歌词景深模糊"开关（默认关闭），仅 `UiEffectsLevel.visual` 且开关开启时才用模糊。

方案 B（折中）：仅对当前行 ±3 行应用模糊，远处行用纯 opacity。

**验证方式**：
- `flutter test test/page/now_playing_content_test.dart` 通过
- 手动测试长歌词列表滚动流畅度（特别是 visual 档）
- 在性能面板观察 GPU 占用

**风险**：中。涉及视觉降级，需确认视觉效果可接受。建议保留开关让用户选择。

---

### 任务 2.3 封面图片共享解码

- [x] 完成

**背景**：
`getPictureFromPath` 三种尺寸（cover/mediumCover/largeCover）各自独立调用 `getOriginalPictureFromPath` 读取原始字节并 `image::load_from_memory` 解码，原始字节被读取和解码三次。

**问题位置**：
- `rust/src/api/tag_reader.rs:1275-1307`（`getPictureFromPath`）
- `lib/library/audio_library.dart:408-460`（`Audio.cover`/`mediumCover`/`largeCover`）

**实施方案**：
1. 在 Rust 端新增函数 `get_picture_sizes_from_path(path: String) -> Option<Vec<u8>>`（返回包含三种尺寸的合并字节，或返回结构体）。内部只读一次原始字节、解码一次 `DynamicImage`，然后缩放到三种尺寸并序列化。
   ```rust
   pub fn get_picture_sizes_from_path(path: String) -> Option<(Option<Vec<u8>>, Option<Vec<u8>>, Option<Vec<u8>>)> {
       let original = get_original_picture_from_path(path.clone())?;
       let img = image::load_from_memory(&original).ok()?;
       let small = resize_to(&img, 160);
       let medium = resize_to(&img, 320);
       let large = resize_to(&img, 600);
       Some((small, medium, large))
   }
   ```
2. 在 `lib/src/rust/api/tag_reader.dart` 重新生成绑定（`flutter_rust_bridge_codegen`）。
3. 修改 `Audio` 类的封面加载逻辑：`cover`/`mediumCover`/`largeCover` 共享一次 Rust 调用，分别取对应尺寸。
4. 保留原 `getPictureFromPath` 作为兼容（或移除，视调用情况）。

**验证方式**：
- `cargo check` + `cargo test` 通过
- `flutter analyze` 通过
- `flutter test test/library/audio_library_test.dart` 通过
- 手动测试封面显示正常

**风险**：中高。涉及 Rust/Dart 接口变更，需重新生成 `frb_generated.dart`。建议在分支上操作。

---

### 任务 2.4 `initFromIndex` 改异步 + 合并重建

- [x] 完成

**背景**：
`initFromIndex` 用 `readAsStringSync()` 同步阻塞读取整个 index.json，大库时（万首级别 JSON 几十 MB）会卡 UI 线程。`_rebuildCollections()` 被调用两次（中间穿插 override 应用），第一次构建结果被丢弃。

**问题位置**：
- `lib/library/audio_library.dart:53-83`

**当前代码**：
```dart
static Future<void> initFromIndex() async {
  final indexStr = File(indexPath).readAsStringSync();  // 同步阻塞！
  final Map indexJson = json.decode(indexStr);
  ...
  _instance = AudioLibrary._(folders);
  instance._rebuildCollections();
  await AudioMetadataOverrideStore.instance.read();
  AudioMetadataOverrideStore.instance.applyToLibrary(instance);
  instance._rebuildCollections();  // 第二次重建
  notifyChanged();
}
```

**实施方案**：
```dart
static Future<void> initFromIndex() async {
  final indexStr = await File(indexPath).readAsString();  // 异步
  final Map indexJson = json.decode(indexStr);
  ...
  _instance = AudioLibrary._(folders);
  await AudioMetadataOverrideStore.instance.read();
  AudioMetadataOverrideStore.instance.applyToLibrary(instance);
  instance._rebuildCollections();  // 只重建一次
  notifyChanged();
}
```
注意：`applyToLibrary` 需要在 `_rebuildCollections` 之前调用（它修改 Audio 对象字段），需确认 `applyToLibrary` 不依赖集合已构建。

**验证方式**：
- `flutter analyze` 通过
- `flutter test test/library/audio_library_test.dart` 通过
- 手动测试大库启动速度

**风险**：中。需确认 `applyToLibrary` 在集合构建前调用不影响逻辑。

---

### 任务 2.5 `PlayCountStore` debounce 写盘

- [x] 完成

**背景**：
`increaseByPath` 每次播放都 `await save()` 序列化整个 Map 写盘。万首播放记录时每次播放写几 MB JSON。

**问题位置**：
- `lib/library/play_count_store.dart:55-58`

**当前代码**：
```dart
Future<void> increaseByPath(String path) async {
  _counts[path] = (_counts[path] ?? 0) + 1;
  await save();  // 每次播放全量写盘
}
```

**实施方案**：
```dart
Timer? _saveDebounce;

Future<void> increaseByPath(String path) async {
  _counts[path] = (_counts[path] ?? 0).clamp(0, 1 << 30) + 1;
  _scheduleSave();
}

void _scheduleSave() {
  _saveDebounce?.cancel();
  _saveDebounce = Timer(const Duration(milliseconds: 500), () {
    unawaited(save());
  });
}
```
参考 `playlist.dart:14-20` 的 `scheduleSavePlaylists` 模式。
确保应用退出时 flush 一次（在 `PlayService.close()` 或 `WindowControls` 退出逻辑中调用 `save()`）。

**验证方式**：
- `flutter analyze` 通过
- 新增测试：验证多次播放只触发一次 save
- 手动测试播放计数正常累积

**风险**：低。需确保退出前 flush，避免丢失最近 500ms 内的计数。

---

### 任务 2.6 `FluidGradientBackground` 统一用 Rust 取色

- [x] 完成

**背景**：
`FluidGradientBackground` 用 Dart `PaletteGenerator.fromImageProvider`（maximumColorCount: 8）在主 isolate 解码封面取色，每次切歌阻塞。而 `ThemeProvider._extractAlbumPalette` 已用 Rust `extractDominantColors`（更快且有 128 条 LRU 缓存）——两套取色重复实现。

**问题位置**：
- `lib/component/fluid_gradient_background.dart:87-90`（Dart PaletteGenerator）
- `lib/theme_provider.dart:297-327`（Rust 版本，保留）

**实施方案**：
1. 移除 `fluid_gradient_background.dart` 中的 `PaletteGenerator.fromImageProvider` 调用。
2. 改为监听 `ThemeProvider.instance` 的调色板变化（`ThemeProvider` 已在切歌时提取并缓存 `AlbumPalette`）。
3. `FluidGradientBackground` 通过 `ListenableBuilder` 或 `AnimatedBuilder` 订阅 `ThemeProvider`，读取当前 `AlbumPalette` 作为流体颜色来源。
4. 移除 `_updateColorsForAudio` 中 `scheduleMicrotask` 的 build 副作用（`fluid_gradient_background.dart:134-138`）。

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过
- 手动测试切歌时背景色流转正常

**风险**：中。需确保 `ThemeProvider` 在无动态主题时仍有合理默认色。

---

### 任务 2.7 `WindowControlls` debounce 保存

- [x] 完成

**背景**：
每次 maximize/unmaximize/restore/fullscreen 都 `saveSettings()`，连续操作频繁写文件。

**问题位置**：
- `lib/component/title_bar.dart:426,432,438,445,452`

**实施方案**：
1. 在 `AppSettings` 中新增 `Timer? _saveDebounce` 和 `scheduleSaveSettings()` 方法（500ms debounce）。
2. `title_bar.dart` 中所有 `AppSettings.instance.saveSettings()` 改为 `AppSettings.instance.scheduleSaveSettings()`。
3. 确保应用退出前 flush（`WindowControls` 退出逻辑中调用 `saveSettings()`）。

**验证方式**：
- `flutter analyze` 通过
- 手动测试窗口状态变化后设置正确保存

**风险**：低。

---

### 任务 2.8 修复 `_LiquidGradientPainter.shouldRepaint`

- [x] 完成

**背景**：
`_LiquidPalette` 是 `@immutable` 但未实现 `==`/`hashCode`，导致 `shouldRepaint` 每次判不等，非动画模式下也每帧重绘。

**问题位置**：
- `lib/component/fluid_gradient_background.dart:429-433`

**实施方案**：
为 `_LiquidPalette` 实现 `operator==` 和 `hashCode`：
```dart
@immutable
class _LiquidPalette {
  final List<Color> colors;
  const _LiquidPalette(this.colors);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LiquidPalette && _listEquals(colors, other.colors);

  @override
  int get hashCode => Object.hashAll(colors);
}
```

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过

**风险**：极低。

---

## 方向三：修复功能性缺陷

### 任务 3.1 CUE 文件支持 GBK 编码

- [x] 完成

**背景**：
`fs::read_to_string(cue_path)` 只能读 UTF-8，而中文 CUE 文件大量使用 GBK/GB2312，会直接报错返回空数组，导致整张 CUE 专辑无法识别。**这是重大缺陷**。

**问题位置**：
- `rust/src/api/tag_reader.rs:491`

**当前代码**：
```rust
pub fn read_from_cue_path(cue_path: String) -> Vec<Audio> {
    let Ok(cue_content) = fs::read_to_string(&cue_path) else {
        return vec![];  // GBK 编码直接失败
    };
    ...
}
```

**实施方案**：
1. 在 `rust/Cargo.toml` 添加依赖：`encoding_rs = "0.8"`
2. 修改 `read_from_cue_path`：
```rust
pub fn read_from_cue_path(cue_path: String) -> Vec<Audio> {
    let Ok(bytes) = fs::read(&cue_path) else {
        return vec![];
    };
    // 先尝试 UTF-8，失败则降级到 GBK
    let cue_content = match String::from_utf8(bytes.clone()) {
        Ok(s) => s,
        Err(_) => encoding_rs::GBK.decode(&bytes).0.into_owned(),
    };
    ...
}
```
3. 也可进一步尝试 GB18030（GBK 超集）或 Shift_JIS（日文 CUE）：
```rust
let cue_content = String::from_utf8(bytes.clone())
    .unwrap_or_else(|_| encoding_rs::GB18030.decode(&bytes).0.into_owned());
```

**验证方式**：
- `cargo check` 通过
- 新增 Rust 测试：包含 GBK 编码的中文 CUE 文件解析（可在 `rust/tests/` 下添加）
- `flutter test` 通过
- 手动测试：用 GBK 编码的 CUE 文件扫描

**风险**：低。添加依赖 `encoding_rs` 是纯 Rust 实现无副作用。

---

### 任务 3.2 修复 BASS 递归初始化无终止条件

- [x] 完成

**背景**：
`setSource`、`_bassWasapiInit`、`_start_wasapiExclusive`、`_startDevice` 遇到 `BASS_ERROR_INIT`/`ALREADY` 时递归调用自身，无终止条件。若底层状态持续异常会栈溢出。

**问题位置**：
- `lib/src/bass/bass_player.dart:419-423`（`setSource`）
- `lib/src/bass/bass_player.dart:494-497,512-515`（`_bassWasapiInit`）
- `lib/src/bass/bass_player.dart:537-540`（`_start_wasapiExclusive`）
- `lib/src/bass/bass_player.dart:244-248`（`_startDevice`）

**当前代码**（示例）：
```dart
case BASS.BASS_ERROR_INIT:
  _bassInit();
  _bassWasapiInit();  // 递归，无终止
  break;
```

**实施方案**：
为每个递归调用添加重试次数限制：
```dart
void _bassWasapiInit({int retries = 0}) {
  ...
  case BASS.BASS_ERROR_INIT:
    if (retries >= 2) {
      throw FormatException("BASS_WASAPI init failed after $retries retries");
    }
    _bassInit();
    _bassWasapiInit(retries: retries + 1);
    break;
  case BASS.BASS_ERROR_ALREADY:
    if (retries >= 2) {
      throw FormatException("BASS_WASAPI already initialized after $retries retries");
    }
    _bassWasapi.BASS_WASAPI_Free();
    _bassWasapiInit(retries: retries + 1);
    break;
}
```
同样模式应用到 `setSource`、`_start_wasapiExclusive`、`_startDevice`。

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过
- 手动测试独占模式切换

**风险**：低。正常情况只递归一次，限制为 2 次不影响正常流程。

---

### 任务 3.3 修复 `volumeDsp` getter 内存泄漏

- [x] 完成

**背景**：
`volumeDsp` getter 每次 `ffi.malloc.allocate<ffi.Float>` 后未 `free`，造成内存泄漏。虽单次 4 字节，但频繁调用会累积。

**问题位置**：
- `lib/src/bass/bass_player.dart:120-126`

**当前代码**：
```dart
double get volumeDsp {
  final volDsp = ffi.malloc.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>);
  _bass.BASS_ChannelGetAttribute(_fstream!, BASS.BASS_ATTRIB_VOLDSP, volDsp);
  return volDsp.value;  // ← volDsp 未 free！
}
```

**实施方案**：
```dart
double get volumeDsp {
  final volDsp = ffi.malloc.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>);
  try {
    _bass.BASS_ChannelGetAttribute(_fstream!, BASS.BASS_ATTRIB_VOLDSP, volDsp);
    return volDsp.value;
  } finally {
    ffi.malloc.free(volDsp);
  }
}
```
全局搜索其他类似的 `ffi.malloc.allocate` 未配对 `free` 的地方，一并修复。

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过

**风险**：极低。

---

### 任务 3.4 JSON 写入改为原子操作

- [x] 完成

**背景**：
所有 Store 的 `save()` 直接 `writeAsString`，写一半崩溃会损坏 JSON，导致用户数据丢失。

**问题位置**：
- `lib/library/audio_metadata_override_store.dart` 的 `save()`
- `lib/library/online_cover_store.dart` 的 `save()`
- `lib/library/play_count_store.dart` 的 `save()`
- `lib/app_settings.dart` 的 `saveSettings()`（358 行）
- `lib/library/playlist.dart` 的保存逻辑
- `lib/app_preference.dart` 的 `save()`

**实施方案**：
1. 在 `lib/utils.dart` 新增工具函数：
```dart
Future<void> atomicWriteString(String path, String content) async {
  final tmpPath = '$path.tmp';
  final file = await File(tmpPath).create(recursive: true);
  file.writeAsStringSync(content);
  await file.rename(path);  // 原子操作
}
```
2. 所有 `output.writeAsStringSync(settingsStr)` 替换为 `await atomicWriteString(settingsPath, settingsStr)`。
3. 对于同步写入场景（如 `saveSettings`），提供同步版本 `atomicWriteStringSync`。

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过
- 新增测试：模拟写入中断后文件完整性

**风险**：低。rename 在同一文件系统是原子的。

---

### 任务 3.5 修复 index.json 并发写竞态

- [x] 完成

**背景**：
`main.dart:112` 后台运行 `updateIndex` 写 index.json，同时 `audio_tile.dart:537` 的 `_updateIndexJson` 在 Dart 端也写 index.json，可能交错执行导致写覆盖。

**问题位置**：
- `lib/main.dart:112`（后台 `updateIndex`）
- `lib/page/audios_page.dart` 或 `audio_tile.dart:537`（`_updateIndexJson`）

**实施方案**：
选项 A（推荐，彻底统一）：
1. 移除 `audio_tile.dart` 中的 `_updateIndexJson` 方法。
2. 元数据编辑后，通过 Rust 端新增 API `update_audio_metadata_in_index(indexPath, audioPath, newMetadata)` 更新 index.json，统一由 Rust 端管理。
3. 确保启动时 `_runStartupIndexUpdateSilently` 完成后才允许编辑（或 Rust 端内部加锁）。

选项 B（加互斥锁）：
1. 在 Dart 端引入全局 `Completer<void>` 互斥锁保护 index.json 写入。
2. `_updateIndexJson` 和 `_runStartupIndexUpdateSilently` 都获取锁后再写。

推荐选项 A，因为 Rust 端已有 `updateIndex` 基础设施，统一管理更可靠。

**验证方式**：
- `flutter analyze` 通过
- `flutter test` 通过
- 手动测试：启动时立即编辑元数据，确认无数据丢失

**风险**：中。选项 A 涉及 Rust/Dart 接口变更。

---

### 任务 3.6 修复 `OnlineCoverStore` 无 per-path 去重

- [x] 完成

**背景**：
`getCover` 中 `uniSearch` 是昂贵的网络操作，多个 widget 同时请求同一 audio 封面时会重复搜索。

**问题位置**：
- `lib/library/online_cover_store.dart:68-94`

**实施方案**：
```dart
final Map<String, Future<String?>> _inflightSearches = {};

Future<String?> getCover(Audio audio) async {
  await read();
  final cached = _cachedPathMap[audio.path];
  if (cached != null) return cached;
  if (_failedAudioPaths.contains(audio.path)) return null;

  // 去重：复用进行中的搜索
  if (_inflightSearches.containsKey(audio.path)) {
    return _inflightSearches[audio.path]!;
  }

  final future = _searchAndCacheCover(audio);
  _inflightSearches[audio.path] = future;
  try {
    return await future;
  } finally {
    _inflightSearches.remove(audio.path);
  }
}

Future<String?> _searchAndCacheCover(Audio audio) async {
  // 原 getCover 中的搜索+下载+缓存逻辑
}
```

**验证方式**：
- `flutter analyze` 通过
- 新增测试：并发调用 getCover 同一 audio 只触发一次搜索
- 手动测试快速滚动列表，封面加载正常

**风险**：低。

---

### 任务 3.7 修复静音恢复不一致

- [x] 完成

**背景**：
`_VolumeControl` 点击图标静音恢复固定为 0.5，而 `HotkeysHelper._toggleMute` 用 `_lastNonZeroVolume` 记忆——两个入口行为不一致。

**问题位置**：
- `lib/component/bottom_player_bar.dart:1210-1213`

**实施方案**：
1. 在 `_VolumeControl` 中维护 `_lastNonZeroVolume` 字段（初始化为 0.5）。
2. 音量变化时若 > 0 则记录到 `_lastNonZeroVolume`。
3. 点击图标：`current <= 0 ? _lastNonZeroVolume : 0.0`。
4. 与 `HotkeysHelper._toggleMute` 行为统一。

**验证方式**：
- `flutter test test/component/bottom_player_bar_widget_test.dart` 通过
- 手动测试：调高音量→静音→恢复，确认恢复到原音量而非 0.5

**风险**：低。

---

### 任务 3.8 修复 `useExclusiveMode` 失败回滚不完整

- [x] 完成

**背景**：
`useExclusiveMode` catch 块只回滚 `wasapiExclusive` 标志，但不重新 `setSource` 恢复 prev state 的流，状态可能不一致。

**问题位置**：
- `lib/src/bass/bass_player.dart:368-393`

**实施方案**：
在 catch 块中，回滚 `wasapiExclusive` 后重新加载当前流：
```dart
} catch (err) {
  wasapiExclusive = prevState;
  // 重新加载当前流以恢复 prevState 的播放状态
  if (_currentPath != null) {
    try {
      await setSource(_currentPath!);  // 重新加载
      // 可选：恢复之前的播放位置和状态
    } catch (e) {
      LOGGER.e("[useExclusiveMode rollback] $e");
    }
  }
  return false;
}
```

**验证方式**：
- `flutter analyze` 通过
- 手动测试：独占模式切换失败后，播放状态恢复正常

**风险**：中。需确保回滚后播放位置/状态正确恢复。

---

## 方向四：提升在线匹配精度

### 任务 4.1 重构 `_computeScore` 匹配算法

- [x] 完成

**背景**：
`_computeScore` 是逐字符前缀匹配，只比较到较短字符串长度。`"Hello"` vs `"Hello World Hello World"` 得满分但明显是不同歌曲。无归一化（大小写/空格/标点）、无编辑距离、顺序敏感（`"ABC"` vs `"BAC"` 得 0 分）。

**问题位置**：
- `lib/music_matcher.dart:14-34`

**当前代码**：
```dart
double _computeScore(Audio audio, String title, String artists, String album) {
  int maxScore = audio.title.length + audio.artist.length + audio.album.length;
  int score = 0;
  int minTitleLength = min(audio.title.length, title.length);
  for (int i = 0; i < minTitleLength; ++i) {
    if (audio.title[i] == title[i]) score += 1;
  }
  // artist、album 同上
  return score / maxScore;
}
```

**实施方案**：
1. 在 `lib/utils.dart` 新增工具函数：
```dart
/// 归一化字符串：转小写、去首尾空格、去标点、去常见后缀
String normalizeForMatch(String input) {
  var s = input.toLowerCase().trim();
  // 去除括号后缀如 "(Live)"、"- Remix"
  s = s.replaceAll(RegExp(r'\s*[\(（\[【].*?[\)）\]】\s*$'), '');
  s = s.replaceAll(RegExp(r'\s*[-－]\s*(remix|live|version|demo|edit).*$'), '');
  // 去除标点
  s = s.replaceAll(RegExp(r'[^\w\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af\s]'), '');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 归一化编辑距离相似度 [0, 1]
double normalizedSimilarity(String a, String b) {
  final na = normalizeForMatch(a);
  final nb = normalizeForMatch(b);
  if (na.isEmpty && nb.isEmpty) return 1.0;
  if (na.isEmpty || nb.isEmpty) return 0.0;
  final dist = _levenshtein(na, nb);
  return 1.0 - dist / max(na.length, nb.length);
}

int _levenshtein(String a, String b) {
  // 标准编辑距离实现
}
```
2. 重写 `_computeScore`：
```dart
double _computeScore(Audio audio, String title, String artists, String album) {
  final titleSim = normalizedSimilarity(audio.title, title);
  final artistSim = normalizedSimilarity(audio.artist, artists);
  final albumSim = normalizedSimilarity(audio.album, album);
  // 加权：title 0.5, artist 0.3, album 0.2
  return titleSim * 0.5 + artistSim * 0.3 + albumSim * 0.2;
}
```

**验证方式**：
- 新增测试：`test/library/music_matcher_test.dart`，覆盖同名异曲、大小写、标点、后缀、顺序无关等场景
- `flutter test` 通过
- 手动测试：对一些之前匹配错误的歌曲重新匹配

**风险**：中。需确保归一化不误伤正常曲名（特别是中日韩字符）。

---

### 任务 4.2 `uniSearch` 三 API 并行查询

- [x] 完成

**背景**：
三个 API（酷狗/网易/QQ）顺序 await，匹配慢。应并行查询。

**问题位置**：
- `lib/music_matcher.dart:143-205`

**实施方案**：
```dart
Future<List<SongSearchResult>> uniSearch(Audio audio) async {
  final query = '${audio.title} ${audio.artist}';

  final results = await Future.wait([
    _searchKugou(query, audio).catchError((e, s) => <SongSearchResult>[]),
    _searchNetease(query, audio).catchError((e, s) => <SongSearchResult>[]),
    _searchQQ(query, audio).catchError((e, s) => <SongSearchResult>[]),
  ]);

  final all = [...results[0], ...results[1], ...results[2]];
  all.sort((a, b) => b.score.compareTo(a.score));
  return all;
}

Future<List<SongSearchResult>> _searchKugou(String query, Audio audio) async {
  final Map answer = (await KuGou.searchSong(keyword: query)).data;
  final List? list = answer["data"]?["info"];
  if (list == null) return [];
  return list.take(5).map((item) => SongSearchResult.fromKugouSearchResult(item, audio)).toList();
}

// _searchNetease、_searchQQ 同理
```

**验证方式**：
- 新增测试验证并行查询
- 手动测试匹配速度提升

**风险**：低。`Future.wait` + `catchError` 保证单个失败不影响整体。

---

### 任务 4.3 改进查询关键词

- [x] 完成

**背景**：
`uniSearch` 只用 `audio.title` 查询，容易匹配同名异曲。

**问题位置**：
- `lib/music_matcher.dart:144`

**实施方案**：
```dart
final query = '${audio.title} ${audio.artist}'.trim();
// 如果 artist 是 "未知艺术家"，只用 title
final actualQuery = audio.artist == '未知艺术家' ? audio.title : query;
```
注意：部分 API 对长 query 支持不好，可适当截断（如限制 50 字符）。

**验证方式**：
- 手动测试同名不同歌手的歌曲匹配精度

**风险**：低。

---

### 任务 4.4 `getMostMatchedLyric` 增加匹配阈值

- [x] 完成

**背景**：
直接取第一个结果，不做相似度阈值判断，可能匹配到错误歌曲。

**问题位置**：
- `lib/music_matcher.dart:274-287`

**实施方案**：
```dart
Future<Lyric?> getMostMatchedLyric(Audio audio) async {
  final unisearchResult = await uniSearch(audio);
  if (unisearchResult.isEmpty) return null;

  final mostMatch = unisearchResult.first;
  if (mostMatch.score < 0.6) {
    LOGGER.i("[getMostMatchedLyric] 低于阈值: ${audio.title} -> ${mostMatch.title} (${mostMatch.score})");
    return null;  // 让 LyricService 回退到本地歌词
  }

  return switch (mostMatch.source) { ... };
}
```

**验证方式**：
- 手动测试：对一些生僻歌曲，确认不会错误匹配而是回退本地

**风险**：低。阈值 0.6 可后续根据反馈调整。

---

### 任务 4.5 `_failedAudioPaths` 持久化带 TTL

- [x] 完成

**背景**：
失败集合是内存集合，重启后丢失——每次启动对失败封面重新搜索，可能产生大量无效请求。

**问题位置**：
- `lib/library/online_cover_store.dart`（`_failedAudioPaths` 字段）

**实施方案**：
1. 将失败记录改为 `Map<String, int>`（path → 失败时间戳）。
2. 持久化到 `cover_cache_failed.json`。
3. `read()` 时过滤超过 7 天的记录（TTL）。
4. `getCover` 中检查失败时间戳，7 天内不再搜索。
```dart
Map<String, int> _failedAudioPaths = {};  // path -> 失败时间戳

Future<void> read() async {
  if (_loaded) return;
  _loaded = true;
  try {
    final str = await File(_failedPath).readAsString();
    final map = json.decode(str) as Map;
    final now = DateTime.now().millisecondsSinceEpoch;
    _failedAudioPaths = map.map((k, v) => MapEntry(k.toString(), (v as int)))
      ..removeWhere((k, ts) => now - ts > 7 * 24 * 3600 * 1000);  // 7 天 TTL
  } catch (_) {}
}

void _markFailed(String path) {
  _failedAudioPaths[path] = DateTime.now().millisecondsSinceEpoch;
  _scheduleSaveFailed();
}
```

**验证方式**：
- 新增测试验证 TTL 过期
- 手动测试：启动时不再对近期失败封面重复搜索

**风险**：低。

---

## 实施顺序建议

建议按以下批次执行，降低相互依赖风险：

### 第一批：低风险高收益（建议立即执行）
- [x] 任务 1.4 修复 create_issue 指向错误仓库
- [x] 任务 3.3 修复 volumeDsp 内存泄漏
- [x] 任务 3.7 修复静音恢复不一致
- [x] 任务 2.7 WindowControlls debounce 保存
- [x] 任务 2.8 修复 _LiquidGradientPainter.shouldRepaint

### 第二批：死代码清理
- [x] 任务 1.1 移除 studio 模式死代码
- [x] 任务 1.2 移除 MiniNowPlaying
- [x] 任务 1.3 移除重复菜单/桌面歌词按钮
- [x] 任务 1.5 清理 startPage 矛盾逻辑

### 第三批：性能优化（无接口变更）
- [x] 任务 2.1 修复 _SpinningArtwork Ticker
- [x] 任务 2.4 initFromIndex 改异步+合并重建
- [x] 任务 2.5 PlayCountStore debounce 写盘
- [x] 任务 2.6 FluidGradientBackground 统一取色

### 第四批：功能性修复
- [x] 任务 3.1 CUE 文件支持 GBK 编码
- [x] 任务 3.2 修复 BASS 递归初始化
- [x] 任务 3.4 JSON 原子写入
- [x] 任务 3.5 修复 index.json 并发写竞态
- [x] 任务 3.6 修复 OnlineCoverStore 去重
- [x] 任务 3.8 修复 useExclusiveMode 回滚

### 第五批：在线匹配精度
- [x] 任务 4.1 重构 _computeScore
- [x] 任务 4.2 uniSearch 并行查询
- [x] 任务 4.3 改进查询关键词
- [x] 任务 4.4 增加匹配阈值
- [x] 任务 4.5 _failedAudioPaths 持久化

### 第六批：高复杂度性能优化（建议在分支操作）
- [x] 任务 2.2 优化歌词逐行模糊
- [x] 任务 2.3 封面图片共享解码

---

## 验证清单

每批任务完成后，执行以下验证：

### Dart 端验证
```powershell
dart format lib/ test/
flutter analyze
flutter test
```

### Rust 端验证
```powershell
Set-Location rust
cargo check
cargo test
Set-Location ..
```

### 构建验证
```powershell
flutter build windows --debug
flutter build windows --release
```

### 专项测试（按涉及模块选择）
```powershell
# 死代码清理后
flutter test test/page/now_playing_content_test.dart test/page/detail_page_style_test.dart test/app_preference_test.dart

# 性能优化后
flutter test test/component/bottom_player_bar_widget_test.dart test/library/audio_library_test.dart

# 功能修复后
flutter test test/play_service/lyric_service_test.dart test/component/bottom_player_bar_test.dart

# 匹配精度后
flutter test test/library/music_matcher_test.dart  # 新增
```

### 手动回归测试清单
- [x] 启动应用，扫描音乐库正常
- [x] 播放/暂停/切歌/拖动进度条正常
- [x] 进入 Now Playing 页面，沉浸式视图正常
- [x] 歌词显示与滚动正常
- [x] 桌面歌词开关正常
- [x] 独占模式切换正常
- [x] 设置页各项可正常修改并保存
- [x] 快捷键响应正常
- [x] 编辑元数据后保存正常
- [x] 重启后偏好恢复正常

---

## 备注

- 涉及 Rust/Dart 接口变更的任务（2.3、3.5）需运行 `flutter_rust_bridge_codegen` 重新生成绑定。
- 涉及视觉降级的任务（2.2）建议保留设置开关。
- 每个任务建议单独 commit，commit message 参考仓库现有风格（见 WORKLOG.md）。
- 完成后更新 `docs/changelog.md` 和 `pubspec.yaml` 版本号。
