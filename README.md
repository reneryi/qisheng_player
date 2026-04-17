# Coriander Player（Fork 版）

[![Windows CI](https://github.com/reneryi/coriander_player/actions/workflows/windows_ci.yml/badge.svg)](https://github.com/reneryi/coriander_player/actions/workflows/windows_ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

![音乐页](软件截图/音乐页.png)

> 基于 [Ferry-200/coriander_player](https://github.com/Ferry-200/coriander_player) 的维护分支，专注于 **稳定性修复** 与 **功能增强**。

## ✨ Fork 版改动亮点

### 🛠 稳定性修复（阶段一）
- 修复播放过程中控件显示暂停/播放状态不一致的问题
- 修复桌面歌词开启后不立即显示当前歌词的问题
- 修复多文件夹扫描导致歌曲重复显示的问题
- 修复搜索功能对歌手和专辑关联性不足的问题
- 修复独占模式偶发不生效的问题
- 修复歌曲标签乱码与内置字体不显示常用字的问题
- 修复歌单持久化丢失（重启后歌单为空）的问题
- 修复最大化后关闭再打开不保持最大化状态的问题

### 🚀 功能扩展（阶段二）
- **窗口与托盘**：关闭窗口最小化到托盘，托盘菜单支持播放控制
- **任务栏控件**：鼠标悬停任务栏时显示上/下一首、播放/暂停缩略图按钮
- **播放列表**：支持拖拽重排与自定义播放顺序
- **歌曲播放次数**：记录并展示播放次数，支持按播放次数排序
- **专辑碟号识别**：多碟专辑按碟号 + 音轨号排列
- **歌词翻译开关**：可在播放页/桌面歌词中控制是否显示翻译
- **首字母快速定位**：音乐详情页右侧 A-Z 索引，支持中文拼音首字母
- **音乐定位按钮**：播放界面一键定位到当前播放歌曲在列表中位置
- **当前播放高亮**：音乐详情页内高亮显示正在播放的歌曲
- **播放页添加到歌单**：支持创建新歌单并添加当前歌曲
- **长歌名滚动**：歌曲名过长时自动滚动显示
- **音量均衡**：基于 ReplayGain 的自动音量补偿
- **CUE 文件支持**：解析 CUE 分轨、封面、歌词裁剪
- **桌面歌词增强**：字体选择、RGB 颜色、位置/颜色/锁定等设置记忆
- **多选增强**：Shift 范围选择，批量添加到歌单、批量删除
- **快捷键系统**：可自定义快捷键，支持鼠标侧键，后台可用范围控制
- **背景自定义**：支持自定义播放器背景图片
- **控件自动隐藏**：播放页无操作 5 秒后自动隐藏进度条和按钮
- **在线封面获取**：自动为无封面的歌曲在线获取封面
- **音乐标签编辑**：右键菜单在线搜索后编辑内嵌封面、歌词、Tag
- **WAV 元数据**：完善 WAV 格式的元数据读取
- **DTS 格式支持**：新增对 DTS 音频格式的播放支持
- **m3u 导入**：导入播放列表文件，自动生成对应歌单
- **多选入口优化**：多选功能从右上角直接进入，无需右键菜单
- **文件夹管理**：设置中的文件夹管理移至专属页面，支持扫描音乐库

完整改动日志请见 [CHANGELOG.md](CHANGELOG.md)。

## 📥 下载安装

### 直接下载
前往 [Releases](https://github.com/reneryi/coriander_player/releases) 下载最新版本。

### MSIX 安装
如使用 MSIX 包安装，请参阅 [MSIX 安装指南](MSIX_install.md)。

## 🎵 支持的音频格式

| 格式 | 播放 | 内嵌歌词 |
|------|:----:|:--------:|
| MP3 / MP2 / MP1 | ✅ | ✅ |
| FLAC | ✅ | ✅ |
| WAV / WAVE | ✅ | ✅* |
| OGG | ✅ | ✅ |
| AAC / ADTS | ✅ | ✅ |
| M4A | ✅ | ✅ |
| AIFF / AIF / AIFC | ✅ | ✅ |
| OPUS | ✅ | ✅ |
| APE | ✅ | — |
| WV / WVC | ✅ | — |
| DSD (DSF / DFF) | ✅ | — |
| AC3 | ✅ | — |
| ASF / WMA | ✅ | — |
| MPC | ✅ | — |
| MIDI | ✅ | — |
| AMR / 3GA | ✅ | — |
| DTS | ✅ | — |

> \* WAV 内嵌歌词需标签使用 UTF-8 编码。  
> 其他格式支持同目录 LRC 文件（UTF-8 / UTF-16 编码）或在线歌词匹配。

## ⌨️ 默认快捷键

| 功能 | 快捷键 |
|------|--------|
| 播放 / 暂停 | `空格` |
| 上一首 | `←` |
| 下一首 | `→` |
| 音量增 | `↑` |
| 音量减 | `↓` |
| 静音 | `Alt + M` |
| 显示/隐藏桌面歌词 | `Ctrl + M` |
| 显示/隐藏主界面 | `Ctrl + H` |
| 返回上一页 | `Esc` |
| 退出程序 | `Ctrl + Q` |

> 所有快捷键均可在设置中自定义，支持鼠标侧键。  
> 后台（窗口失焦）时仅部分快捷键可用：上/下一首、音量加/减、静音、显示/隐藏主界面。

## 🔧 开发环境

| 工具 | 版本 |
|------|------|
| Flutter | 3.41.6 (stable) |
| Dart SDK | >=3.1.4 <4.0.0 |
| Rust | stable |
| 目标平台 | Windows 10/11 x64 |

## 📁 项目结构

```
coriander_player/
├── lib/                        # Flutter 主程序
│   ├── main.dart               # 启动入口
│   ├── play_service/           # 播放服务
│   ├── library/                # 媒体库
│   ├── lyric/                  # 歌词解析
│   └── src/rust/               # Rust FFI 桥接
├── rust/                       # Rust 实现（标签读取等）
├── windows/runner/             # Windows 原生层（托盘、任务栏控件等）
├── third_party/desktop_lyric/  # 桌面歌词组件（内置 path 依赖）
├── BASS/                       # BASS 音频引擎动态库（运行时需要）
└── tools/                      # 构建与测试工具
```

## 🏗️ 本地构建（Windows）

```bash
# 1. 获取依赖
flutter pub get

# 2. 代码质量检查
flutter analyze
cd rust && cargo check && cd ..
flutter test tools/sort_smoke_test.dart

# 3. 构建主程序
flutter build windows --release

# 4. 构建桌面歌词
cd third_party/desktop_lyric
flutter pub get
flutter analyze --no-fatal-infos
flutter build windows --release
cd ../..
```

### BASS 运行时依赖

将以下 64 位 DLL 放入发布目录的 `BASS/` 文件夹中：

`bass.dll` · `bassape.dll` · `bassdsd.dll` · `bassflac.dll` · `bassmidi.dll` · `bassopus.dll` · `basswv.dll` · `basswasapi.dll` · `bass_aac.dll`

## 🔄 CI / CD

GitHub Actions 工作流 ([`.github/workflows/windows_ci.yml`](.github/workflows/windows_ci.yml)) 覆盖：

- **主工程**：`flutter pub get` → `flutter analyze` → `cargo check` → `flutter test` → `flutter build windows --release`
- **桌面歌词**：`flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter build windows --release`
- **BASS 依赖**：自动下载并归档（含 `bass_aac.dll`）

## 🤝 贡献

欢迎提交 Issue 和 PR！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 📸 软件截图

<details>
<summary>展开查看更多截图</summary>

![音乐页](软件截图/音乐页.png)
![艺术家页](软件截图/艺术家页.png)
![艺术家详情页](软件截图/艺术家详情页.png)
![专辑详情页](软件截图/专辑详情页.png)
![主题选择器](软件截图/主题选择器.png)
![夜间模式](软件截图/夜间模式.png)
![正在播放：LRC歌词](软件截图/正在播放（LRC歌词）.png)
![正在播放：逐字歌词](软件截图/正在播放（逐字歌词）.png)
![正在播放：间奏动画](软件截图/正在播放（间奏动画）.png)
![正在播放：居中对齐](软件截图/正在播放（居中对齐）.png)
![桌面歌词](软件截图/桌面歌词.png)
![桌面歌词：操作栏](软件截图/桌面歌词（操作栏）.png)
![桌面歌词：个性化设置](软件截图/桌面歌词（个性化设置）.png)
![桌面歌词：夜间模式](软件截图/桌面歌词（夜间模式）.png)

</details>

## 🙏 致谢

- [Ferry-200/coriander_player](https://github.com/Ferry-200/coriander_player) — 原始项目
- [desktop_lyric](https://github.com/Ferry-200/desktop_lyric) — 桌面歌词组件原始仓库
- [music_api](https://github.com/yhsj0919/music_api.git) — 歌曲匹配与歌词获取
- [Lofty](https://crates.io/crates/lofty) — 歌曲标签读取
- [BASS](https://www.un4seen.com/bass.html) — 音频播放引擎
- [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge) — Flutter 与 Rust 桥接
- [Silicon7921](https://github.com/Silicon7921) — 应用图标设计

## 📄 许可证

本项目基于 [GPL-3.0](LICENSE) 协议开源。
