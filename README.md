# 🎵 栖声 Qisheng Player

<div align="center">
  <img src="app_icon.ico" alt="Logo" width="128" height="128" />
</div>

<div align="center">
  <strong>一款专为 Windows 10/11 打造的现代化、高颜值本地音乐播放器</strong>
</div>
<br>

<div align="center">

[![Windows CI](https://github.com/reneryi/coriander_player/actions/workflows/windows_ci.yml/badge.svg)](https://github.com/reneryi/coriander_player/actions/workflows/windows_ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Rust-Native-000000?logo=rust)](https://www.rust-lang.org/)

</div>

栖声 (Qisheng Player) 是一款基于 **Flutter**、**Rust** 与 **BASS** 音频库构建的本地音乐播放器。项目源自 [Ferry-200/coriander_player](https://github.com/Ferry-200/coriander_player)，当前分支已全面升级为 `qisheng_player v1.0.0`，重点优化了本地曲库管理、歌词显示、播放队列、桌面歌词以及提供了沉浸式的播放器界面。

---

## ✨ 主要特性 (Features)

### 🎶 极致的本地曲库管理
- **多文件夹支持**：支持多路径扫描与智能索引缓存，海量音乐秒级加载。
- **快速定位**：内置 A-Z / 拼音索引，支持全局搜索、多维度排序（按专辑、艺术家、添加时间等）。
- **灵活视图**：无缝切换列表与网格视图，提供沉浸式的浏览体验。

### 🎧 专业级播放体验
- **全格式支持**：MP3, FLAC, WAV, APE, OGG, AAC, OPUS, DSD 等主流与无损格式全兼容。
- **高级音频控制**：支持 ReplayGain 音量均衡、CUE 分轨读取。
- **播放队列机制**：支持随机、顺序、单曲循环模式，支持拖拽重排与精细的播放次数统计。

### 📝 完善的歌词与资料系统
- **动态歌词**：支持本地歌词（LRC/UTF-8/UTF-16）、在线匹配、逐字歌词特效与外语翻译切换。
- **多端显示**：内置桌面歌词与音乐页右侧歌词预览。
- **元数据管理**：提供详细的艺术家、专辑、文件夹和歌单页面，支持右键菜单快速编辑 ID3 标签、封面和内嵌歌词。

### 🎨 现代化的视觉与交互
- **玻璃拟态 UI**：全应用统一的毛玻璃视觉风格，支持 Windows 11 背景材质回退。
- **智能取色**：界面主色调根据当前播放专辑封面动态变化。
- **优雅动效**：可折叠的侧边栏、页面之间的平滑淡入淡出。
- **沉浸模式**：提供专属的沉浸式 / 专业 Now Playing 页面。

### ⚙️ 深度系统集成
- **全局快捷键**：支持自定义应用内与全局后台快捷键。
- **硬件适配**：支持鼠标侧键控制、系统托盘（System Tray）、任务栏缩略图控制（Thumbnail Toolbar）、窗口自由拖拽与缩放。

## 📂 支持格式详细列表

| 格式分类 | 支持格式 | 播放支持 | 内嵌歌词读取 |
| --- | --- | :---: | :---: |
| **常见格式** | MP3 / MP2 / MP1 | ✅ 支持 | ✅ 支持 |
| **无损音频** | FLAC / WAV / WAVE | ✅ 支持 | ✅ 支持 |
| **其他主流** | OGG / AAC / ADTS / M4A / OPUS | ✅ 支持 | ✅ 支持 |
| **苹果格式** | AIFF / AIF / AIFC | ✅ 支持 | ✅ 支持 |
| **高阶/特殊** | APE / WV / WVC | ✅ 支持 | ⚠️ 视标签而定 |
| **更多格式** | DSD / AC3 / WMA / MPC / MIDI / AMR / 3GA / DTS | ✅ 支持 | ⚠️ 视标签而定 |

*注：同目录的 `.lrc` 文件、TXT 歌词文件以及在线歌词匹配功能可作为内嵌歌词的有效补充。*

## ⌨️ 默认快捷键 (Shortcuts)

| 动作分类 | 功能 | 快捷键 |
| --- | --- | --- |
| **播放控制** | 播放 / 暂停 | `Space` (空格键) |
| | 上一首 / 下一首 | `Left` / `Right` (左右方向键) |
| **音量控制** | 音量加 / 音量减 | `Up` / `Down` (上下方向键) |
| | 静音开关 | `Alt + M` |
| **界面交互** | 显示 / 隐藏桌面歌词 | `Ctrl + M` |
| | 显示 / 隐藏主界面 | `Ctrl + H` |
| | 返回上一页 | `Esc` |
| | 退出程序 | `Ctrl + Q` |

> 💡 **提示**: 所有快捷键均可在「设置」中自由修改，部分操作支持后台全局响应。

## 项目结构

```text
qisheng_player/
├─ lib/                         Flutter 主程序、页面、组件、主题和服务
│  ├─ component/                 通用组件与播放器 UI
│  ├─ library/                   曲库、歌单、封面、播放次数和元数据
│  ├─ page/                      音乐、艺术家、专辑、文件夹、歌单、设置等页面
│  ├─ play_service/              播放、歌词与桌面歌词服务
│  └─ src/bass/                  BASS 播放桥接
├─ rust/                         Rust 元数据读取与原生能力
├─ rust_builder/                 flutter_rust_bridge 生成/桥接包
├─ windows/                      Windows Runner、资源和窗口集成
├─ third_party/desktop_lyric/    桌面歌词子程序
├─ test/                         Widget、服务和回归测试
├─ tools/release/                Windows 发布打包脚本
├─ tools/test/                   工具类测试
├─ docs/                         更新日志、结构说明和发布流程
├─ assets/                       栖声品牌图标资源
└─ BASS/                         本地运行依赖 DLL，不提交到 Git
```

更详细的目录说明见 [docs/project_structure.md](docs/project_structure.md)。

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test

Set-Location rust
cargo check
Set-Location ..

flutter build windows --debug
```

## Windows 发布

先构建主程序和桌面歌词：

```powershell
flutter build windows --release

Set-Location third_party\desktop_lyric
flutter pub get
flutter build windows --release
Set-Location ..\..
```

再生成发布包：

```powershell
powershell -ExecutionPolicy Bypass -File tools/release/package_release_windows.ps1 -Version 1.0.0
```

发布产物输出到 `dist/windows/artifacts/packages/`：

- `Qisheng-Player-v1.0.0-Windows-x64.zip`
- `Qisheng-Player-v1.0.0-Setup-x64.exe`

生成安装器需要本机安装 Inno Setup 6。完整流程见 [docs/release_workflow.md](docs/release_workflow.md)。

## 文档

- [更新日志](docs/changelog.md)
- [项目结构](docs/project_structure.md)
- [Windows 发布流程](docs/release_workflow.md)
- [贡献指南](CONTRIBUTING.md)

## License

本项目基于 GPL-3.0 许可证发布。请同时遵守 BASS 与相关第三方依赖的授权要求。
