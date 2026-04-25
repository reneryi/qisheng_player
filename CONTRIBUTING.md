# 贡献指南

感谢你关注 Coriander Player（Fork 维护版）！

> 本仓库为 [Ferry-200/coriander_player](https://github.com/Ferry-200/coriander_player) 的 Fork 分支。如果你的反馈适用于上游原版，建议优先向上游提交。

## 提交 Issue

1. 请写清楚**复现步骤、期望行为、实际行为**。
2. 建议附上截图/录屏、日志、音频样本信息（格式、编码、标签情况）。
3. 若是回归问题，请注明可复现版本与首次出现版本。
4. 日志获取方式：设置 → 创建问题 → 复制底部输入框中的文字。

## 提交 PR

1. 尽量按功能拆分提交，避免把不相关改动混在一起。
2. 对行为变更请补充验证方式（命令、测试点、结果）。
3. 涉及 Windows Runner、Rust、Flutter 多层联动时，请在描述里写清调用链。

## 本地检查（最低要求）

```bash
# 获取依赖
flutter pub get

# Dart 静态分析
flutter analyze

# Rust 编译检查
cd rust
cargo check
cd ..

# 排序逻辑单元测试
flutter test tools/test/sort_smoke_test.dart

# Windows Release 构建
flutter build windows --release
```

## 分支与提交建议

- 功能分支命名：`feature/...` 或 `fix/...`
- Commit message 建议包含模块前缀：
  - `feat(player): 新增播放次数统计`
  - `fix(desktop_lyric): 修复位置记忆失效`
  - `chore(ci): 补齐 DTS 插件下载`
  - `refactor(library): 统一去重逻辑`
