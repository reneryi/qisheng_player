# 项目结构说明

本文档说明仓库内各目录的职责边界，目的是让源码、构建缓存、发布产物、协作笔记彼此分离，避免目录继续变乱。

## 根目录原则

- 根目录只保留“项目入口级”内容：核心源码目录、平台目录、配置文件、许可证、README、贡献说明。
- 业务源码优先放在 `lib/`、`rust/`、`windows/`、`third_party/desktop_lyric/`。
- 自动生成物不混入源码目录说明中。
- 发布产物统一进入 `dist/`，不再塞进 `build/`。

## 目录职责

### 源码相关

- `lib/`
  - Flutter 主程序源码。
  - 包含页面、组件、播放服务、主题、FFI Dart 侧桥接等。
- `rust/`
  - Rust 业务实现与 FRB 相关 Rust 代码。
  - `rust/target/` 属于编译缓存，不属于源码。
- `windows/`
  - 主程序 Windows 原生 Runner 与平台适配代码。
- `third_party/desktop_lyric/`
  - 桌面歌词子项目。
  - 这是 path 依赖，属于项目的一部分，不应与普通构建产物混淆。
- `test/`
  - Flutter/Dart 测试。
- `tools/`
  - 项目工具脚本，不放业务代码。
  - `tools/release/`：发布、打包脚本。
  - `tools/test/`：工具类或补充测试脚本。

### 文档相关

- `docs/`
  - 项目文档统一入口。
  - `docs/changelog.md`：变更日志。
  - `docs/msix_install.md`：MSIX 安装说明。
  - `docs/screenshots/`：README 引用截图。
  - `docs/releases/`：版本发布说明、发布用 JSON 描述、历史归档。

### 发布与本地运行

- `dist/windows/package/`
  - 已整合好的发布目录，可直接检查最终交付内容。
  - 用于观察最终 exe、依赖 DLL、桌面歌词子程序、资源是否齐全。
- `dist/windows/artifacts/packages/`
  - 最终输出的压缩包与安装程序。
- `dist/windows/installer_work/`
  - 安装程序生成时的中间工作目录。
- `BASS/`
  - 本地运行和打包时需要的 BASS DLL。
  - 这是本地依赖目录，不提交到 Git。

### 缓存与忽略项

- `build/`
  - Flutter / CMake / Rust 联动构建输出目录。
  - 只看作临时构建结果，不用于长期保存发布内容。
- `.dart_tool/`
  - Dart / Flutter 本地缓存。
- `notes/`
  - 本地协作笔记，例如 AI 规则、任务清单、工作日志。
  - 已被忽略，不参与开源仓库提交。

## 维护约定

- 新增项目文档时，优先放入 `docs/`，而不是继续堆在根目录。
- 新增发布脚本时，优先放入 `tools/release/`。
- 新增非业务测试脚本时，优先放入 `tools/test/`。
- 新增安装包、压缩包、整合目录时，统一放入 `dist/windows/`。
- 不再把“可运行整合目录”和“Flutter 自动构建目录”混在 `build/` 下。
