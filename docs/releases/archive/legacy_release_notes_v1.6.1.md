## 📦 下载

下载 `Coriander-Player-v1.6.1-Windows-x64.zip`，解压后运行 `coriander_player.exe` 即可使用。

> ⚠️ 首次运行前请确保已安装 [Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)。

## ✨ 版本亮点

本版本主要修复在线封面获取、音乐标签编辑和鼠标侧键快捷键三个功能的问题。

### 修复
- 在线封面自动获取：各音乐 API 独立容错，单个 API 故障不影响搜索结果
- 标签编辑后 UI 不刷新：保存标签/歌词/封面后立即更新播放界面
- 鼠标侧键快捷键无法识别：改用应用内事件捕获

### 改进
- 标签编辑直接写入音乐文件元数据（支持 MP3/FLAC/OGG/M4A 等格式）
- 在线封面同时写入音乐文件封面标签
- 标签修改同步更新 index.json，重启后不丢失

完整改动日志请见 [CHANGELOG.md](https://github.com/reneryi/coriander_player/blob/main/CHANGELOG.md)。
