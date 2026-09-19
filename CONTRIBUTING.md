# 贡献指南

感谢关注栖声 Qisheng Player。本仓库基于 [Ferry-200/coriander_player](https://github.com/Ferry-200/coriander_player) 维护，如果问题同样适用于上游项目，也欢迎同步向上游反馈。

## 提交 Issue

请尽量包含以下信息：

- 问题描述、复现步骤、期望行为和实际行为。
- 发生问题的版本号、Windows 版本、音频格式、歌词格式和相关截图或录屏。
- 如果是崩溃或卡死，请附上控制台日志、Flutter 日志或可复现的最小曲库样例。
- 日志可通过“设置 -> 创建问题”复制，也可以直接附上终端输出。

## 提交 PR

- 尽量按功能拆分提交，避免把不相关的 UI、逻辑和文档改动混在一起。
- 行为变更请补充测试或说明验证方式。
- 涉及 Windows Runner、Rust、BASS、桌面歌词子程序或发布脚本时，请在描述中写清调用链和影响范围。
- 不要提交 `build/`、`.dart_tool/`、本地 `BASS/` DLL、个人曲库、日志或调试产物。

## 本地检查

```powershell
flutter pub get
dart format lib test tools\test
flutter analyze
flutter test

Set-Location rust
cargo check
Set-Location ..

flutter build windows --debug
```

发布前建议额外执行：

```powershell
flutter build windows --release

Set-Location third_party\desktop_lyric
flutter pub get
flutter analyze --no-fatal-infos
flutter build windows --release
Set-Location ..\..

powershell -ExecutionPolicy Bypass -File tools/release/package_release_windows.ps1 -Version 1.4.0
```

## 分支与提交建议

- 功能分支建议使用 `feature/...`，修复分支建议使用 `fix/...`。
- Commit message 建议包含模块前缀，例如：
- `feat(audios): 新增音乐页歌词预览`
- `fix(shell): 修复侧栏切页 GlobalKey 冲突`
- `chore(release): 准备 qisheng player v1.0`
- `docs(readme): 更新项目结构和发布流程`
