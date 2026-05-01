# 项目结构说明

本文档说明栖声播放器仓库内主要目录的职责边界，方便后续维护、测试和发布。

## 根目录约定

- 根目录只保留项目入口级文件、平台目录、源码目录、配置文件、许可证和基础文档。
- 业务源码集中放在 `lib/`、`rust/`、`windows/` 和 `third_party/desktop_lyric/`。
- 发布产物统一进入 `dist/`，自动构建缓存保留在 `build/`。
- 本地依赖、个人笔记、调试输出和曲库数据不提交到 Git。

## 源码目录

- `lib/`：Flutter 主程序源码，包含页面、组件、主题、曲库、播放服务和 Dart 侧桥接逻辑。
- `lib/component/`：底部播放器、侧栏、标题栏、歌词预览、封面和通用 UI 组件。
- `lib/library/`：音频索引、元数据、歌单、封面缓存、播放次数和覆盖信息。
- `lib/page/`：音乐、艺术家、专辑、文件夹、歌单、设置、详情页和 Now Playing 页面。
- `lib/play_service/`：播放控制、歌词、桌面歌词和播放会话服务。
- `lib/src/bass/`：BASS 播放器桥接与底层播放能力封装。
- `rust/`：Rust 原生能力，主要用于标签读取、元数据清洗和系统能力补充。
- `rust_builder/`：`flutter_rust_bridge` 生成与桥接包。
- `windows/`：Windows Runner、资源、窗口控制和原生平台集成。
- `third_party/desktop_lyric/`：桌面歌词子程序，是当前项目的 path 依赖。

## 测试与工具

- `test/`：Flutter Widget、服务、主题、导航和回归测试。
- `tools/test/`：工具类或补充测试脚本。
- `tools/release/`：Windows 发布与打包脚本。

## 文档与发布

- `docs/changelog.md`：版本更新日志。
- `docs/release_workflow.md`：Windows 发布流程。
- `docs/msix_install.md`：历史 MSIX 安装说明。
- `docs/releases/`：版本发布说明和 GitHub Release payload。
- `docs/screenshots/`：README 或发布说明可引用的截图。
- `WORKLOG.md`：重要实现、验证结果与后续注意事项记录。

## 本地目录

- `BASS/`：本地运行与打包需要的 BASS DLL，不提交到 Git。
- `build/`：Flutter、CMake 和 Rust 自动构建输出，不作为长期发布归档。
- `dist/windows/package/`：发布脚本整合后的完整可运行目录。
- `dist/windows/artifacts/packages/`：最终 zip 和安装器输出目录。
- `.dart_tool/`：Dart / Flutter 本地缓存。
- `notes/`：本地协作笔记，不参与开源仓库提交。
