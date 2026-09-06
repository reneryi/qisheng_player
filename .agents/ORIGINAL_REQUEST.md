# Original User Request

## 2026-09-01T15:34:06Z

This is a single self-contained fix; keep it small and focused.

优化 Windows 桌面端音乐播放器（qisheng_player）的窗口动画与全屏/最大化过渡效果，彻底解决当前窗口最大化、还原及全屏时生硬瞬切、缺失系统原生平滑动画的问题，达到接近 Windows 11 文件资源管理器（File Explorer）的原生 DWM 丝滑缩放动画与全屏体验。

Working directory: e:\PyCharmSave\qisheng_player
Integrity mode: demo

## Requirements

### R1. Win32 窗口原生 DWM 动画与边框体系重构
- 根除当前代码中导致 DWM 硬件加速动画失效的 GDI 区域裁剪机制（如 `SetWindowRgn` / `CreateRoundRectRgn`），全面依托 Windows 11 原生 DWM 圆角与阴影体系（`DWMWA_WINDOW_CORNER_PREFERENCE`、`DwmExtendFrameIntoClientArea`）。
- 规范 `WS_OVERLAPPEDWINDOW` 样式与 `WM_NCCALCSIZE`、`WM_NCHITTEST` 消息处理链路，保留系统级 `WS_CAPTION` / `WS_THICKFRAME` 标志，使 DWM 能正确识别并触发系统原生最大化/还原动画（包含 Windows 11 Snap Layouts 贴靠布局支持与 `HTMAXBUTTON` 命中测试）。

### R2. 最大化与多显示器边缘自适应（Anti-Overflow & Smooth Transition）
- 在无边框客户区拓展模式下，精确处理最大化时的 `WM_NCCALCSIZE` 边框裁切逻辑，防止窗口最大化时超出当前屏幕可视工作区（Work Area）向相邻显示器或任务栏溢出 8px。
- 确保窗口在 最大化 ↔ 还原（Maximize / Restore）状态切换时，触发平滑的 DWM 插值过渡，动画过程流畅无重绘闪烁与白边。

### R3. 全屏（Fullscreen）平滑过渡与沉浸式体验
- 优化全屏进出逻辑（Fullscreen Enter/Exit），避免使用破坏窗口状态树的粗暴尺寸切换。
- 正确保存与恢复 `WINDOWPLACEMENT`，实现全屏与窗口化状态间平滑无缝切换，保证全屏覆盖整个物理屏幕（包括任务栏），退出时精准恢复上一状态（普通窗口或最大化状态）且动画平稳。

### R4. Flutter 与 Native 交互及 UI 布局自适应优化
- 梳理 Dart 层（`window_controls.dart` / `title_bar.dart`）与 Win32 原生层（`flutter_window.cpp`）的交互通道，消除 `window_manager` 插件与底层自绘无边框逻辑的冲突。
- 保证动画进行期间及完成后，Flutter 内部布局监听（`WindowLayoutMode` / `shellGap`）响应精准且无抖动。

## Acceptance Criteria

### DWM 动画与视觉效果
- [ ] 窗口在点击最大化/双击标题栏最大化时，展现与 Windows 11 文件管理器一致的原生 DWM 平滑放大展开动画。
- [ ] 窗口在从最大化点击还原/双击标题栏还原/拖拽还原时，展现原生 DWM 平滑收缩还原动画。
- [ ] 彻底移除 `SetWindowRgn` 强制裁剪，圆角平滑且保留 Windows 11 原生投影与 Snap Layouts（鼠标悬停最大化按钮展示贴靠布局菜单）。

### 边界与全屏行为
- [ ] 最大化时窗口铺满当前屏幕可用工作区，不遮挡任务栏，且在多屏幕环境下边缘不溢出到副屏。
- [ ] 全屏模式下正确覆盖全屏（遮盖任务栏），退出全屏后能正确恢复至进入全屏前的状态（若进入前是最大化则恢复最大化，若进入前是普通窗口则恢复原窗口尺寸与位置）。
- [ ] 动画过程中无明显的黑屏、闪烁、重绘断裂或白边。

## Verification Resources
- 视频对比基准：`C:\Users\reneryi\Videos\屏幕录制\屏幕录制 2026-09-01 231900.mp4`（现状） vs `C:\Users\reneryi\Videos\屏幕录制\屏幕录制 2026-09-01 231935.mp4`（目标文件管理器动画）。
- 启动与构建验证：`flutter build windows` 或使用运行实例验证最大化、还原、全屏及 Snap Layouts 贴靠行为。
