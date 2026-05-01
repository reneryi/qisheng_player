# Windows 发布流程

本文档说明 `qisheng_player` 的 Windows 发布约定。当前正式版本为 `1.1.0`，发布名使用 `Qisheng Player v1.1.0`。

## 目录分工

- `build/`：Flutter、CMake 和 Rust 的自动构建输出，只用于编译。
- `dist/windows/package/`：发布脚本整合后的完整可运行目录，可用于人工检查。
- `dist/windows/artifacts/packages/`：最终发布产物目录，保存 zip 和安装器。
- `dist/windows/installer_work/`：Inno Setup 中间工作目录。
- `docs/releases/`：版本说明和 GitHub Release payload。

## 发布前检查

```powershell
flutter pub get
dart format lib test tools\test
flutter analyze
flutter test

Set-Location rust
cargo check
Set-Location ..
```

## 构建主程序

```powershell
flutter build windows --release
```

主程序输出应包含：

- `build/windows/x64/runner/Release/qisheng_player.exe`
- Flutter 运行时 DLL
- `data/` 资源目录

## 构建桌面歌词

```powershell
Set-Location third_party\desktop_lyric
flutter pub get
flutter analyze --no-fatal-infos
flutter build windows --release
Set-Location ..\..
```

## 准备 BASS 依赖

仓库根目录的 `BASS/` 需要包含运行时 DLL：

- `bass.dll`
- `bassape.dll`
- `bassdsd.dll`
- `bassflac.dll`
- `bassmidi.dll`
- `bassopus.dll`
- `basswv.dll`
- `basswasapi.dll`
- `bass_aac.dll`

这些文件用于本地构建和发布整合，但不提交到 Git。

## 生成发布包

```powershell
powershell -ExecutionPolicy Bypass -File tools/release/package_release_windows.ps1 -Version 1.1.0
```

如果桌面歌词的 `flutter build windows --release` 在当前机器上不稳定，但你已经有一份可用的
`dist/windows/package/desktop_lyric/`，可以复用现有整合目录来继续生成 zip 和安装器：

```powershell
powershell -ExecutionPolicy Bypass -File tools/release/package_release_windows.ps1 -Version 1.1.0 -ReuseExistingPackage
```

输出文件：

- `dist/windows/artifacts/packages/Qisheng-Player-v1.1.0-Windows-x64.zip`
- `dist/windows/artifacts/packages/Qisheng-Player-v1.1.0-Setup-x64.exe`

安装器需要本机安装 Inno Setup 6。如果环境未安装 Inno Setup，zip 包仍可作为便携版交付，安装器需要在具备 `ISCC.exe` 的机器上重新生成。

## GitHub 发布建议

- Tag：`v1.1.0`
- Release 标题：`Qisheng Player v1.1.0`
- Release 说明来源：`docs/releases/v1.1.0.md`
- 附件：zip 便携包和 setup 安装器。
