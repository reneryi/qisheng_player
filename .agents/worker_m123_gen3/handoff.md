# Handoff Report: 音乐播放器三处核心交互与动效体验优化 (M1, M2, M3) 实施交付

## 1. Observation (观察事实与现场取证)

### 1.1 涉及文件与修改清单
- **核心代码文件**：
  1. `lib/component/audio_tile.dart`（第 310~365 行）：将操作栏中的“更多” `IconButton` 单独用 `AudioContextMenu` 包裹，使内部 `MenuAnchor` 以按钮自身为锚点对齐展开，同时保留外层整行的右键上下文菜单。
  2. `lib/page/uni_page.dart`（第 525~1080 行）：在 `_UniPageState` 混入 `SingleTickerProviderStateMixin`，引入 `AnimationController` 与 `CurvedAnimation(Curves.easeInOutCubic)`。统一驱动面板宽度、透明度/位移、主列表右侧内边距 `listPadding.right` 以及侧边字母轨 `sideRailRight`；在退场期间将面板节点保活直至 `progress == 0`。
  3. `lib/component/bottom_player_bar.dart`（第 1 行与第 1250~1350 行）：引入 `import 'dart:ui';`，在 `_openQueueDrawer` 中使用 `ClipRRect(borderRadius: BorderRadius.circular(24))` 包裹 `BackdropFilter(filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma))`，配合自适应明暗半透明渐变底色与双层投影；将弹窗过渡优化为 `transitionDuration: const Duration(milliseconds: 320)`，进场曲线 `Cubic(0.16, 1.0, 0.3, 1.0)` 与退场曲线 `Cubic(0.2, 0.0, 0.0, 1.0)`。
- **测试套件文件**：
  1. `test/component/audio_tile_test.dart`（新建）：验证更多按钮弹窗在按钮附近展开（X > 700），以及右键点击在光标位置弹出且互不干扰。
  2. `test/page/audios_page_test.dart`（新增用例）：验证歌词预览面板在关闭时执行平滑退场动画（100ms 期间依然保活淡出，完全结束后卸载）。
  3. `test/component/bottom_player_bar_widget_test.dart`（新增用例）：验证播放队列抽屉呼出时包含 `BackdropFilter` 毛玻璃且平滑关闭。

### 1.2 静态分析与全量测试验证结果
- **静态分析**：
  ```bash
  dart analyze lib test
  ```
  输出：`Analyzing lib, test... No issues found!`（0 警告、0 错误）。
- **全量测试套件**：
  ```bash
  flutter test
  ```
  输出：`00:27 +257: All tests passed!`（全部 257 个测试用例 100% 通过）。

---

## 2. Logic Chain (推理与逻辑链)

1. **M1 (R1: 更多按钮锚点对齐)**：
   - 原代码中外层整行使用单个 `AudioContextMenu`，当用户点击右侧“更多”按钮时调用 `controller.open()`，由于未传局部坐标，`MenuAnchor` 默认以整行条目左下角为锚点展开，导致菜单跳至行首左侧。
   - 方案在内部更多按钮上单独包裹专用 `AudioContextMenu`，`MenuAnchor` 锚定在 36×36 的按钮自身包围盒上，原生支持下侧/上侧及右侧屏幕边缘防溢出和子菜单级联；整行外层依然监听 `onSecondaryTapDown` 并传递 `details.localPosition`，确保两种触发机制职责单一且互不干扰。

2. **M2 (R2: 歌词预览面板双向平滑动效与列表联动)**：
   - 原代码中 `Stack` 内部使用 `if (showRightPane)` 直接判断，导致关闭时节点在第 0 帧被直接移除，退场动画完全丢失；同时 `listPadding.right` 直接布尔增减 298px，导致列表视口宽度在 1 帧内剧烈突变引发文字换行撕裂。
   - 方案通过在 `_UniPageState` 建立统一的 `AnimationController` 时间轴，驱动 `isRightPaneActive = hasRightPane && (widget.showRightPane || rightPaneProgress > 0.0001)` 保活退场动画；同时 `listPadding.right = sideRailReserved + (widget.rightPaneWidth + rightPaneGap) * rightPaneProgress` 与 `sideRailRight` 逐帧平滑插值，实现 100% 帧同步与零文本抖动。

3. **M3 (R3: 播放队列抽屉毛玻璃与丝滑动效)**：
   - 原代码依赖全局主题的 `CpSurface`，在 solid 策略下不会渲染 `BackdropFilter`，导致抽屉在全屏高亮大字歌词上方呼出时文字穿透干扰；退场采用 `easeInCubic` 导致末端急停闪退。
   - 方案在抽屉内构建自包含的 `ClipRRect` + `BackdropFilter`，根据设备性能自适应高斯模糊半径（标准 24.0 / 性能模式 12.0），配合半透明渐变底色与双层立体投影；采用进场 `Cubic(0.16, 1.0, 0.3, 1.0)` 与退场 `Cubic(0.2, 0.0, 0.0, 1.0)`，时长 320ms，实现丝滑流畅的物理缓冲。

---

## 3. Caveats (注意事项与边界条件)

1. **测试环境下的 Ticker 调度**：
   - `BottomPlayerBar` 包含正在播放的封面旋转与频谱进度条 Ticker。在编写针对底栏的 Widget 测试时，应使用定时步进的 `tester.pump(duration)` 而非无休止等待的 `pumpAndSettle()`，避免因活跃 Ticker 触发超时。
2. **多选模式与手势隔离**：
   - 多选模式下 `AudioTile` 的多选框已正常显示且右键拦截已就绪，专用 `AudioContextMenu` 未改变原有事件消费优先级。

---

## 4. Conclusion (交付结论)

已圆满完成 M1（R1: 更多按钮锚点对齐）、M2（R2: 歌词预览双向平滑动效与列表联动）、M3（R3: 播放队列抽屉毛玻璃与丝滑动效）的三处核心交互与动效体验优化。代码结构规范，静态分析零警告，全量 257 项测试全部绿灯通过。

---

## 5. Verification Method (独立验证方法)

可执行以下命令进行独立复核验证：
```bash
# 1. 静态代码分析
dart analyze lib test

# 2. 针对性组件与页面测试
flutter test test/component/audio_tile_test.dart test/page/audios_page_test.dart test/component/bottom_player_bar_widget_test.dart

# 3. 全量测试套件
flutter test
```
全部命令均应返回退出码 0 且无任何报错。
