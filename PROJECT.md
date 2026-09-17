# Project: 栖声播放器“音乐编辑”全体系重构与现代化升级

## Architecture
本项目对栖声播放器（Qisheng Player）的“音乐编辑”（Music Edit）体系进行全链路重构，彻底解决底层标签持久化受阻、播放器界面无即时热更新、多源在线搜索封面/歌词缺失、单曲/专辑/艺术家视觉边界混淆、以及表单界面单栏堆叠与前置复选框反人性等历史包袱。

系统核心架构与分层设计：
1. **Online Metadata & Visual Assets Layer (`lib/music_matcher.dart`, `lib/library/artwork_store.dart`)**:
   - 升级在线检索接口：网易云采用云搜索协议 (`searchPc`) / 详情接口直出高清 `al.picUrl`；酷狗提取 `trans_param.union_cover` 宏替换生成 800px 高清图；QQ 音乐过滤空 mid 杜绝 404 伪链接。
   - 网络图片防盗链加固：所有网络图片请求显式附加 `User-Agent: QishengPlayer/${AppSettings.version}`，彻底根除网易云 CDN 对 Dart 原生 UA 的 403 Forbidden 拦截。
   - 视觉资产边界规范（R4）：严格划分“单曲内嵌封面”（物理文件 / `cover_cache`）、“专辑封面”（`entity_artwork`）、“艺术家头像”三者存储与生命周期，解耦单曲搜索采纳与全局画册的粗暴绑定。
2. **Physical Persistence & Concurrency Layer (`rust/src/api/metadata_editor.rs`, `lib/library/audio_edit_service.dart`, `lib/play_service/playback_service.dart`)**:
   - Rust 事务引擎加固：消除对 ID3v1 的强行断言误杀；针对 M4A 二进制 atom (`trkn`, `disk`) 提供数值安全比对；放宽 VBR MP3 时长估算漂移门限；扩展白名单支持 `.aac` 等主流格式。
   - Windows 文件占用与并发锁协同：`PlaybackService.withMetadataFileReleased` 规范化路径比较（统一正反斜杠与大小写）；Rust `replace_file` 引入 15 次带指数退避的 Win32 Error 32 (`ERROR_SHARING_VIOLATION`) 重试循环。
   - 物理文件持久化保障：支持 MP3 (ID3v2)、FLAC (Vorbis Comment)、M4A/AAC (MP4 Ilst)、OGG 及 CUE 虚拟分轨的元数据（标题/歌手/专辑/专辑艺术家/音轨/碟号/歌词/内嵌封面图片）高可靠写入。
3. **Global Instant Hot-Sync Layer (`lib/play_service/playback_service.dart`, `lib/library/audio_library.dart`, `lib/component/bottom_player_bar.dart`, `lib/component/now_playing_artwork_hero.dart`, `lib/page/playlist_detail_page.dart`)**:
   - 解决 Provider Selector 抑制重绘：`PlaybackService` 维护 `nowPlayingRevision` 并作为 Selector 联合监听依赖，或生成不可变 Audio 镜像，打破指针全等短路。
   - 静态封面与图像缓存实时驱逐：保存成功后主动清理 `NowPlayingArtworkCard._syncCoverCache` 与 `PaintingBinding.instance.imageCache`，实现底栏、详情页封面即刻刷新。
   - 歌单与列表联动：歌单详情页（`PlaylistDetailPage`）及曲库视图统一订阅 `AudioLibrary.revision`，实现无感热同步。
4. **Dual-Pane Modern Dialog UI/UX Layer (`lib/component/audio_edit_dialog.dart`, `lib/component/ui/modern_dialog.dart`)**:
   - 废除单栏 1200px 纵向深滚与前置 Checkbox 设计，基于 `ModernDialogFrame` 打造 980px 双栏现代弹窗：
     - **左栏（48%）**：140x140 高清封面卡片预览/本地选取替换/清除 + 纯净无勾选框核心元数据网格表单（标题、艺术家、专辑、专辑艺术家、音轨、碟号、年份、流派）。
     - **右栏（52%）**：智能搜索框 + 平台多源过滤 Chip + 候选结果卡片（带来源 Logo、匹配度、“★ 一键智能采纳”按钮）+ 实时歌词工坊（微调/时间轴预览/导出/内嵌写入）。
   - 完备状态机：加载骨架、原值比对 `isDirty` 纯函数标记、保存中进度遮罩、异常降级气泡提示。

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Netease High-Res Cover & CloudSearch | 网易云检索切换至 `searchPc` / `song/detail` 接口，直接获取有效 `al.picUrl` 高清封面 | M1 | Survey Explorer 3 |
| 2 | Kugou Cover Extraction & Whitelist | 酷狗检索从 `trans_param.union_cover` 提取并替换 800px 高清图，解除 `ArtworkStore` 短路限制 | M1 | Survey Explorer 3 |
| 3 | QQ Music Empty Mid 404 Prevention | QQ 音乐校验 `mid` 非空，杜绝生成 404 伪链接及 7 天拉黑惩罚 | M1 | Survey Explorer 3 |
| 4 | CDN User-Agent 403 Remediation | 网络请求统一附加 `User-Agent: QishengPlayer/${version}`，彻底解决网易云 CDN 403 阻断 | M1 | Survey Explorer 3 |
| 5 | Visual Asset Boundary Decoupling | 单曲内嵌封面、专辑封面、艺术家头像三者物理与逻辑边界解耦，杜绝单曲采纳污染全局专辑画册 | M1 | Survey Explorer 3 |
| 6 | Rust Metadata ID3v1 Assertion Fix | 移除 `metadata_editor.rs` 中 ID3v1 丢失误判逻辑，保障现实世界 MP3 事务写入成功 | M2 | Survey Explorer 2 |
| 7 | M4A Track/Disc Binary Atom Support | 修复 M4A 中 `trkn`/`disk` 二进制 atom 回读验证失败的问题，支持安全数值校验 | M2 | Survey Explorer 2 |
| 8 | AAC Whitelist & VBR Drift Tolerance | 扩展格式白名单支持 `.aac`，放宽 VBR MP3 嵌入大图时的微小估算时长容差 | M2 | Survey Explorer 2 |
| 9 | Win32 Error 32 Backoff & Path Norm | 规范化 `withMetadataFileReleased` 路径比较，Rust `replace_file` 引入 15 次带指数退避的重试 | M2 | Survey Explorer 2 |
| 10 | Global Hot-Sync & Pointer Equality Fix | 解决 Provider Selector 指针全等抑制重绘缺陷，驱逐静态封面缓存与 Flutter 图像缓存 | M2 | Survey Explorer 2 |
| 11 | Playlist & Tile Revision Subscription | `PlaylistDetailPage` 与曲目项接入 `AudioLibrary.revision`，保存成功后立即热刷新 | M2 | Survey Explorer 2 |
| 12 | Dual-Pane ModernDialogFrame Layout | 基于 `ModernDialogFrame` 实现 980px 宽双栏经典现代弹窗布局，彻底废除单栏深滚 | M3 | Survey Explorer 1 |
| 13 | Elimination of Strange Checkboxes | 彻底移除各字段前置复选框，采用纯净表单与自动脏数据（`isDirty`）算法 | M3 | Survey Explorer 1 |
| 14 | Left Pane Cover Management & Grid Form | 左栏集成 140x140 高清封面预览/选取/清除，以及紧凑美观的核心元数据网格表单 | M3 | Survey Explorer 1 |
| 15 | Right Pane Online Search & Match Cards | 右栏实现多源智能搜索、来源过滤 Chip、高质感候选匹配卡片与一键智能采纳按钮 | M3 | Survey Explorer 1 |
| 16 | Right Pane Lyric Workshop & Preview | 右栏集成实时歌词预览与微调编辑区，支持格式化导出与内嵌写入切换 | M3 | Survey Explorer 1 |
| 17 | Robust Dialog Lifecycle & State Machine | 完善 loading 骨架、saving 进度遮罩、修改放弃确认与无网/超时错误降级提示 | M3 | Survey Explorer 1 |
| 18 | Comprehensive E2E Testing & Verification | 全面通过 `flutter test` 关联测试，开展网络降级、物理写入与热更新端到端验证 | M4 | Project Orchestrator |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Online Search Upgrade & Visual Asset Decoupling | 升级网易云、酷狗、QQ音乐在线检索；解决 CDN 403 与 404；规范单曲、专辑、艺术家视觉资产边界 | none | PLANNED |
| M2 | Physical Metadata Persistence & Global Hot-Sync | Rust 事务断言修复；M4A/MP3/AAC 格式与内嵌封面写入；Win32 文件锁协同；曲库、底栏与歌单即时热更新 | none | PLANNED |
| M3 | Dual-Pane Music Edit Dialog UI/UX Redesign | 980px 双栏现代弹窗重构；彻底消除前置复选框；左栏封面+网格表单；右栏多源搜索卡片+歌词工坊；状态机流转 | M1, M2 | PLANNED |
| M4 | Comprehensive Integration & E2E Verification | 全量 `flutter test` 测试集；网络异常与无网降级验证；标签物理持久化与即时热更新端到端质检验收 | M1, M2, M3 | PLANNED |

## Interface Contracts
### Online Search Result Contract (`lib/music_matcher.dart`)
- **Cover URL Rule**:
  - Netease: `searchPc` -> `song["al"]["picUrl"]` (必须携带 `http://` 或 `https://`，不得为 null/empty)
  - Kugou: `trans_param["union_cover"]` -> 宏替换 `{size}` 为 `800`
  - QQ: `mid.trim().isNotEmpty ? "https://y.qq.com/music/photo_new/T002R800x800M000${mid}.jpg" : null`
- **HTTP Client User-Agent**: `QishengPlayer/${AppSettings.version}`（对所有封面下载与图片网络加载生效）
- **Visual Asset Boundary**:
  - 单曲候选封面：仅写入 `AudioEditDraft.coverBytes` 或 `coverUrl`，不得默认调用 `ArtworkStore.associate(album)` 覆盖专辑画册。

### Metadata Persistence & Hot-Sync Contract (`lib/library/audio_edit_service.dart`, `rust/src/api/metadata_editor.rs`)
- **Rust Transaction Verification**:
  - 仅验证目标字段改动是否生效；忽略因 ID3v1 缺失造成的旧 tag 数量差异。
  - 数值字段（TrackNumber, DiscNumber）统一转为整数比较，支持二进制 atom 与字符串表示双向对齐。
- **Concurrency & Lock Contract**:
  - `PlaybackService.withMetadataFileReleased(path, action)`：规范化路径比较 `p.canonicalize(path).toLowerCase()`，确保命中正在播放文件时安全释放句柄。
  - Commit 阶段让出 25ms 线程切片；Rust `replace_file` 执行 15 次重试（每次间隔 20ms * 1.5^n）。
- **Global Sync Notification**:
  - 保存成功后：
    1. `AudioLibrary.instance.updateAudio(updatedAudio)` 并触发 `revision++`。
    2. `PlaybackService.instance.refreshNowPlaying(forceNewInstance: true)` 并递增 `nowPlayingRevision`。
    3. `NowPlayingArtworkCard.evictCache(audio.path)`。
    4. `PaintingBinding.instance.imageCache.evict(FileImage(File(coverPath)))`。

### Dual-Pane Dialog Contract (`lib/component/audio_edit_dialog.dart`)
- **Dialog Dimensions**: 宽度固定为 980px，高度自适应 `math.min(740, screenHeight - 108)`。
- **Layout Division**:
  - Left Pane (`0.46`~`0.48` Flex)：封面管理（140x140 正方形带圆角阴影）+ 网格表单（无复选框）。
  - Right Pane (`0.52`~`0.54` Flex)：搜索栏 + 平台源过滤器 + 匹配候选列表 + 歌词微调与预览卡片。
- **Action Buttons**: 取消（Esc / 点击遮罩）、一键智能采纳、保存更改（Cmd/Ctrl+S）。

## Code Layout
- `lib/music_matcher.dart`: [MODIFIED - searchPc, Kugou union_cover, QQ mid check]
- `lib/library/artwork_store.dart`: [MODIFIED - User-Agent header, Kugou unblock, decoupled single vs album association]
- `rust/src/api/metadata_editor.rs`: [MODIFIED - relaxed ID3v1 assertion, M4A binary atom, AAC whitelist, Win32 retry]
- `rust/src/api/tag_reader.rs`: [MODIFIED - replace_file backoff retry]
- `lib/library/audio_edit_service.dart`: [MODIFIED - clean draft mapping, cache eviction, hot-sync trigger]
- `lib/play_service/playback_service.dart`: [MODIFIED - path normalization, nowPlayingRevision, instant state refresh]
- `lib/component/now_playing_artwork_hero.dart`: [MODIFIED - evict static _syncCoverCache]
- `lib/component/audio_edit_dialog.dart`: [REFACTORED - dual-pane modern dialog without checkboxes]
- `lib/component/audio_edit/`: [NEW SUBCOMPONENTS if needed: left_pane, right_pane, lyric_workshop]
- `lib/page/playlist_detail_page.dart`: [MODIFIED - revision listener]
- `test/component/audio_edit_dialog_test.dart`: [UPDATED - dual-pane assertions, remove checkbox expectation]
- `test/library/music_matcher_test.dart`: [UPDATED & EXPANDED]
- `test/library/audio_edit_service_test.dart`: [NEW/UPDATED - persistence & hot-sync verification]
