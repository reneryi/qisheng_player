# Project: 桌面歌词弹窗视觉重构、伪影消除、无滚动条紧凑布局与尺寸防截断 (Desktop Lyric Polish & Fix)

## Architecture
- **Win32 & DWM 原生窗口透明与合成层 (`third_party/desktop_lyric/windows/runner/flutter_window.cpp`, `main.dart`)**:
  - 在 Win32 `FlutterWindow::OnCreate()` 中设置 `DwmSetWindowAttribute`：
    - `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED`: 禁用 DWM 非客户区原生阴影；
    - `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE (0xFFFFFFFE)`: 消除 Windows 11 原生外边框描边；
    - `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_DONOTROUND (1)`: 禁用系统 DWM 强制外框圆角；
  - `main.dart` 启动时显式调用 `windowManager.setHasShadow(false)`，消除 `window_manager` 插件附加的透明扩展边缘；
  - 弹窗路由 `showDialog` 显式设置 `barrierColor: Colors.transparent`，彻底根除全屏半透明 `ModalBarrier` 黑底遮罩。
- **弹窗视觉风格深度对齐体系 (`third_party/desktop_lyric/lib/component/modern_lyric_dialog_frame.dart`, `font_selector_dialog.dart`)**:
  - 引入与主播放器 100% 一致的 `Color.alphaBlend` 动态主题混色体系：
    - 暗色卡片基座: `Color.alphaBlend(primary.withValues(alpha: 0.08), const Color(0xFF131822).withValues(alpha: 0.82))`；
    - 亮色卡片基座: `Color.alphaBlend(primary.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.88))`；
    - 次级容器与搜索框底色: `Color.alphaBlend(primary.withValues(alpha: 0.06), const Color(0xFF1E2533).withValues(alpha: 0.45))`；
  - 阴影收敛设计：控制 `blurRadius: 20`、`spreadRadius: -2`，配合卡片 `margin: horizontal 24, vertical 20`，杜绝阴影外溢至窗口边缘产生 1px 截断黑线；
  - 字体选择器四层结构复刻：44x44 图标徽标、紧凑搜索框、跟随主播放器字体 / 系统默认字体置顶项、项目字体库分组与系统已有字体分组、字重规格胶囊徽标与二级规格折叠菜单。
- **单屏紧凑无滚动条色彩编辑面板 (`third_party/desktop_lyric/lib/component/desktop_lyric_color_dialog.dart`)**:
  - 660x510 紧凑双列布局，总内容高度 366px，拥有 >100px 纵向安全余量，彻底消除滚动条：
    - 左列: 歌词实时渲染预览 Banner (88px) + 跟随主播放器主题色快捷卡片 (48px) + 9 款质感预设配色 Chip 网格 (78px)；
    - 右列: ColorWheelPicker 微调色轮 (直径 185px) + 带前置色标的十六进制 Hex 输入框 (46px)；
    - 底部: 取消 / 确定操作按钮 (50px)。
- **精准自适应窗口尺寸恢复与防截断机制 (`third_party/desktop_lyric/lib/component/foreground.dart`, `desktop_lyric_body.dart`)**:
  - 消除 `resizeWithForegroundSize()` 中的 10px 固定开销亏空：精确计算边距 12px + 边框 2px + 前景内边距 16px + 操作栏 48px + 间距 8px = **86px 实际固定物理开销**；
  - 引入离屏测算器 `calculateRequiredLyricWindowHeight()`：采用 `TextPainter` 计算主歌词与副歌词所需高度，为副歌词强制预留空间，设置 **142.0px 绝对安全基线**；
  - 弹窗退出时，同时钳制恢复尺寸与屏幕可用工作区安全位置，杜绝反复打开退出造成的逐次收缩截断。
- **独立编译构建与自动化验证流水线 (`desktop_lyric.exe`)**:
  - 重新编译 `third_party/desktop_lyric` 生成 Release/Debug `desktop_lyric.exe`；
  - 同步部署至主播放器候选路径：
    1. `build/windows/x64/runner/Debug/desktop_lyric/desktop_lyric.exe`
    2. `build/windows/x64/runner/Release/desktop_lyric/desktop_lyric.exe`
    3. `dist/windows/package/desktop_lyric/desktop_lyric.exe`
  - 运行全量 82+ 项自动化测试套件与 `flutter analyze` 静态分析。

## Feature Inventory
| # | Feature | Description | Milestone | Source | Status |
|---|---------|-------------|-----------|--------|:------:|
| 1 | R2: Win32 DWM 原生属性抑制与无边框设置 | 禁用非客户区阴影，清除 Windows 11 外边框与强制圆角，setHasShadow(false) | M1 | ORIGINAL_REQUEST §R2 | DONE |
| 2 | R2: 消除全屏半透明 ModalBarrier 遮罩黑底 | showDialog 显式配置 barrierColor: Colors.transparent | M1 | ORIGINAL_REQUEST §R2 | DONE |
| 3 | R2: 阴影扩散收敛与窗口边距安全适配 | 约束 BoxShadow blurRadius，确保外围完全透明无 1px 硬裁切黑线 | M1 | ORIGINAL_REQUEST §R2 | DONE |
| 4 | R1: 弹窗动态主题混色体系 (Color.alphaBlend) | 基座、搜索框、预览框、Chip卡片跟随主播放器主题色产生流光毛玻璃质感 | M2 | ORIGINAL_REQUEST §R1 | DONE |
| 5 | R1: 字体选择弹窗复刻设置页标准结构 | 44x44 图标徽标、紧凑搜索框、置顶默认项、项目/系统分组、字重规格徽标与折叠菜单 | M2 | ORIGINAL_REQUEST §R1 | DONE |
| 6 | R3: 单屏紧凑无滚动条颜色设置面板 | 660x510 双列布局，实时大样预览、跟随主题卡片、9 预设 Chip、185px 色轮、Hex 输入框 | M2 | ORIGINAL_REQUEST §R3 | DONE |
| 7 | R4: 修正桌面歌词固定物理开销与 142px 安全基线 | 修正 86px 固定布局物理开销，消除 10px 算式亏空，设置 142px 尺寸安全下限 | M3 | ORIGINAL_REQUEST §R4 | DONE |
| 8 | R4: 离屏副歌词预留与弹窗退出双重钳制恢复 | 引入 calculateRequiredLyricWindowHeight 与安全屏幕坐标恢复，彻底杜绝下半部截断 | M3 | ORIGINAL_REQUEST §R4 | DONE |
| 9 | R5: desktop_lyric.exe 独立编译与全路径同步 | 重新编译生成 Release/Debug desktop_lyric.exe 并分发同步至播放器运行路径 | M4 | ORIGINAL_REQUEST §R5 | DONE |
| 10 | R5: 全量自动化测试套件与静态代码分析验证 | 桌面歌词 50 项单测 + 主程序 32 项关联单测 100% PASS，flutter analyze 0 issues | M4 | ORIGINAL_REQUEST §R5 | DONE |
| 11 | 全维多角度门禁审查与司法级诚信审计 | 2 Reviewers + 2 Challengers + 1 Forensic Auditor 门禁终审，严禁假实现 | M5 | Acceptance Criteria | DONE |

## Code Layout
### M1 Exclusive Files (Transparency & Artifact Elimination)
- `third_party/desktop_lyric/windows/runner/flutter_window.cpp`
- `third_party/desktop_lyric/lib/main.dart`
- `third_party/desktop_lyric/lib/component/modern_lyric_dialog_frame.dart`

### M2 Exclusive Files (Visual Styling & Compact Layout)
- `third_party/desktop_lyric/lib/component/font_selector_dialog.dart`
- `third_party/desktop_lyric/lib/component/desktop_lyric_color_dialog.dart`

### M3 Exclusive Files (Window Sizing & Truncation Recovery)
- `third_party/desktop_lyric/lib/component/foreground.dart`
- `third_party/desktop_lyric/lib/component/desktop_lyric_body.dart`

### M4 Exclusive Files & Scripts (Build & Sync Pipeline)
- `third_party/desktop_lyric/` build artifacts & sync destinations:
  - `build/windows/x64/runner/Debug/desktop_lyric/desktop_lyric.exe`
  - `build/windows/x64/runner/Release/desktop_lyric/desktop_lyric.exe`
  - `dist/windows/package/desktop_lyric/desktop_lyric.exe`
- Test files:
  - `third_party/desktop_lyric/test/`
  - `test/component/desktop_lyric_font_isolation_test.dart`
  - `test/play_service/desktop_lyric_service_test.dart`

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 0 | M0: 专项技术全景勘测 | 3 名 Explorer 深入排查 R1~R5 根因与实现路径，完成像素级与代码级论证 | none | DONE |
| 1 | M1: 消除外围浅黑矩形边框与背景伪影 | R2 (Win32 DWM 原生属性抑制、setHasShadow(false)、barrierColor: transparent、阴影收敛) | M0 | DONE |
| 2 | M2: 弹窗视觉风格深度对齐与紧凑无滚动条布局 | R1, R3 (Color.alphaBlend 动态混色、字体选择器标准四层结构、660x510 无滚动条双列色彩面板) | M0 | DONE |
| 3 | M3: 弹窗退出尺寸精准自适应恢复与防截断 | R4 (86px 固定开销修正、142px 尺寸安全基线、离屏副歌词高度计算、安全坐标双重钳制恢复) | M0 | DONE |
| 4 | M4: 独立编译构建与全量自动化测试验证 | R5 (desktop_lyric.exe Release 编译、全路径同步分发、全量测试套件、flutter analyze 0 issues) | M1, M2, M3 | DONE |
| 5 | M5: 多维门禁验收、实证挑战与司法级诚信审计 | 2 Reviewers + 2 Challengers + 1 Forensic Auditor 终审验收 | M4 | DONE |

## Gate Verdict
- Gate Iteration 1: **PASS**
  - reviewer_1_gen16: **APPROVE** (R1 & R2 verified 100%)
  - reviewer_2_gen16: **APPROVE** (R3, R4, R5 verified 100%)
  - challenger_1_gen16: **APPROVE** (120-cycle rapid toggle, 0px decay, no truncation)
  - challenger_2_gen16: **APPROVE** (32 screen/DPI modes 100% no scrollbars, 60+ font switches isolated)
  - auditor_gen16: **CLEAN** (Forensic audit clean, valid 64-bit PE binary 91648 bytes, timestamp matching build time)
