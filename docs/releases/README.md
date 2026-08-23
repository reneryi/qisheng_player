# 版本发布说明

本目录只保存已经创建或准备创建的版本发布材料。当前未发布的开发过程、临时规划和实现记录不写入发布说明。

## 文件规范

- `v<version>.md`：面向用户阅读的版本发布说明。
- `v<version>.json`：对应版本的 GitHub Release payload，使用 `body_path` 引用同名 Markdown。
- `archive/legacy-v<version>.*`：历史版本线的发布材料。
- `archive/prerelease-v<version>.*`：预发布版本线的发布材料。

Markdown 与 JSON 必须成对存在，版本号、发布状态和文件名保持一致。历史发布材料保留原始 `tag_name`，仅通过归档目录和文件名前缀区分其版本线。

## 当前正式版本线

- [v1.3.2.md](v1.3.2.md) / [v1.3.2.json](v1.3.2.json)
- [v1.3.1.md](v1.3.1.md) / [v1.3.1.json](v1.3.1.json)
- [v1.3.0.md](v1.3.0.md) / [v1.3.0.json](v1.3.0.json)
- [v1.2.10.md](v1.2.10.md) / [v1.2.10.json](v1.2.10.json)
- [v1.2.9.md](v1.2.9.md) / [v1.2.9.json](v1.2.9.json)
- [v1.2.8.md](v1.2.8.md) / [v1.2.8.json](v1.2.8.json)
- [v1.2.7.md](v1.2.7.md) / [v1.2.7.json](v1.2.7.json)
- [v1.2.6.md](v1.2.6.md) / [v1.2.6.json](v1.2.6.json)
- [v1.2.5.md](v1.2.5.md) / [v1.2.5.json](v1.2.5.json)
- [v1.2.4.md](v1.2.4.md) / [v1.2.4.json](v1.2.4.json)
- [v1.2.3.md](v1.2.3.md) / [v1.2.3.json](v1.2.3.json)
- [v1.2.2.md](v1.2.2.md) / [v1.2.2.json](v1.2.2.json)
- [v1.2.1.md](v1.2.1.md) / [v1.2.1.json](v1.2.1.json)
- [v1.2.0.md](v1.2.0.md) / [v1.2.0.json](v1.2.0.json)
- [v1.1.0.md](v1.1.0.md) / [v1.1.0.json](v1.1.0.json)
- [v1.0.0.md](v1.0.0.md) / [v1.0.0.json](v1.0.0.json)

## 历史版本线

- [legacy-v1.6.2.md](archive/legacy-v1.6.2.md) / [legacy-v1.6.2.json](archive/legacy-v1.6.2.json)：旧版本线。
- [legacy-v1.6.1.md](archive/legacy-v1.6.1.md) / [legacy-v1.6.1.json](archive/legacy-v1.6.1.json)：旧版本线。
- [prerelease-v1.7.0.md](archive/prerelease-v1.7.0.md) / [prerelease-v1.7.0.json](archive/prerelease-v1.7.0.json)：预发布版本线。
- [prerelease-v1.7.1.md](archive/prerelease-v1.7.1.md) / [prerelease-v1.7.1.json](archive/prerelease-v1.7.1.json)：预发布版本线。
