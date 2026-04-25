# Windows 发布流程

本文档说明当前项目的 Windows 打包目录约定，重点区分 `build/` 与 `dist/windows/`。

## 目录分工

- `build/`
  - Flutter、CMake、Rust 的自动构建输出。
  - 主要用于编译，不用于长期保存交付物。
- `dist/windows/package/`
  - 打包脚本整合后的完整发布目录。
  - 可用于人工检查交付结果是否完整。
- `dist/windows/artifacts/packages/`
  - 最终产物目录。
  - 保存 `.zip` 和安装程序 `.exe`。
- `dist/windows/installer_work/`
  - Inno Setup 的工作目录与临时脚本。
- `docs/releases/`
  - 版本发布说明、发布 payload、历史说明归档。

## 推荐流程

### 1. 日常开发

- 直接从主函数启动程序进行调试。
- 不再依赖整合目录做日常验证。

### 2. 构建主程序

```powershell
flutter pub get
flutter analyze

Set-Location rust
cargo check
Set-Location ..

flutter test tools/test/sort_smoke_test.dart
flutter build windows --release
```

### 3. 构建桌面歌词子程序

```powershell
Set-Location third_party/desktop_lyric
flutter pub get
flutter analyze --no-fatal-infos
flutter build windows --release
Set-Location ..\..
```

### 4. 准备 BASS 运行时依赖

将所需 DLL 放入仓库根目录的 `BASS/`：

- `bass.dll`
- `bassape.dll`
- `bassdsd.dll`
- `bassflac.dll`
- `bassmidi.dll`
- `bassopus.dll`
- `basswv.dll`
- `basswasapi.dll`
- `bass_aac.dll`

## 生成发布产物

```powershell
powershell -ExecutionPolicy Bypass -File tools/release/package_release_windows.ps1
```

运行完成后，重点查看：

- `dist/windows/package/`
- `dist/windows/artifacts/packages/`

## 当前约定

- `dist/windows/package/` 用于“看整合结果”。
- `dist/windows/artifacts/packages/` 用于“拿最终交付包”。
- `docs/releases/` 用于“保存版本说明和发布配置”。
- `build/` 只保留自动构建产物，不再承担发布归档职责。
