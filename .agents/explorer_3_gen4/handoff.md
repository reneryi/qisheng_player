# Handoff Report — R4: 各类内容详情页进出场转场动效升级调研

## 1. Observation

1. **当前转场实现缺陷**：
   - 在 `lib/entry.dart:168-189` 中，`_buildDetailRouteTransition` 当前仅实现了 `FadeTransition` 与微量 `ScaleTransition(scale: 0.985 -> 1.0)`，没有任何横向位移推入逻辑：
     ```dart
     Widget _buildDetailRouteTransition(
       BuildContext context,
       Animation<double> animation,
       Animation<double> secondaryAnimation,
       Widget child,
     ) {
       final curvedAnim = CurvedAnimation(
         parent: animation,
         curve: Curves.easeOutCubic,
         reverseCurve: Curves.easeInCubic,
       );

       return FadeTransition(
         opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim),
         child: ScaleTransition(
           scale: Tween<double>(begin: 0.985, end: 1.0).animate(curvedAnim),
           child: child,
         ),
       );
     }
     ```
   - `_buildDetailRouteTransition` 中未对 `secondaryAnimation` 做任何处理，导致多层详情嵌套（如专辑详情 -> 艺术家详情）时，底层页面无任何视差位移或淡化退场。
   - `_buildAppRouteTransition`（`lib/entry.dart:116-128`）在 `secondaryAnimation` 触发时执行的是垂直下沉位移（`Offset(0, 8.0 * outgoingProgress)`），与详情页进场的横向运动逻辑不协调。

2. **详情页面与路由分布**：
   - 艺术家详情页：`ArtistDetailPage`（`lib/page/artist_detail_page.dart`），路由 `/artists/detail`
   - 专辑详情页：`AlbumDetailPage`（`lib/page/album_detail_page.dart`），路由 `/albums/detail`
   - 歌曲详情页：`AudioDetailPage`（`lib/page/audio_detail_page.dart`），路由 `/audios/detail`
   - 文件夹详情页：`FolderDetailPage`（`lib/page/folder_detail_page.dart`），路由 `/folders/detail`
   - 歌单详情页：`PlaylistDetailPage`（`lib/page/playlist_detail_page.dart`），路由 `/playlists/detail`
   - 搜索结果页：`SearchResultPage`（`lib/page/search_page/search_result_page.dart`），路由 `/search/result`
   - 设置问题反馈页：`SettingsIssuePage`（`lib/page/settings_page/create_issue.dart`），路由 `/settings/issue`

3. **导航触发与返回机制**：
   - 导航全部基于 `GoRouter` 的 `context.push` / `context.pushReplacement`，并通过 `app_paths.dart` 中的统一常量定义。
   - 返回逻辑通过 `TitleBar` 中的 `NavBackBtn`（`lib/component/title_bar.dart:315-336`）以及全局快捷键/鼠标侧键（`lib/hotkeys_helper.dart:112-116`）调用 `AppNavigationState.instance.navigateBack(context)`，最终驱动 `context.pop()` 触发路由逆向过渡。
   - 静态分析基线：当前代码执行 `flutter analyze` 结果为 0 issues。

---

## 2. Logic Chain

1. **推论一（横向推入 + 淡入淡出是桌面端最佳表现形式）**：
   - 由 Observation 1 可知当前详情页缺乏横向进入位移，导致从主列表进入下一层级时视觉层级扁平。
   - 桌面端（大屏/宽屏）若使用移动端式的 100% 满屏大滑块容易造成眩晕与割裂；
   - 因此采用 **0.08 (8%)** 的细腻横向微位移推入，配合 `Interval(0.0, 0.85)` 的快速淡入与 `Curves.easeOutCubic` 缓动，既提供了明确的层级进入暗示，又保持了桌面端界面的沉静与高级感。

2. **推论二（多级嵌套与底层退场需要 Secondary 协同）**：
   - 由 Observation 1 与 2 可知，用户可能从专辑详情页直接点击艺术家进入艺术家详情页（多级嵌套）。
   - 为避免两个页面重叠冲突，`_buildDetailRouteTransition` 必须响应 `secondaryAnimation`：当上层有新页面推入时，底层页面向左微退移 `-0.03 (-3%)` 并适度降至 `0.88` 不透明度，构建精致的 Z 轴视差景深。

3. **推论三（返回阻尼与 Hero 兼容性）**：
   - 由 Observation 3 可知返回时通过 `context.pop()` 逆向播放转场。
   - 将进场时间设为 `280ms`（`Curves.easeOutCubic`），退场时间设为 `220ms`（`Curves.easeInCubic`），退场手感更加干脆利落。
   - 8% 的微位移不会对 `ArtistTile`/`AlbumTile` 的 Hero 封面飞跃轨迹产生过大偏折，能与 Hero 共享元素动画无缝融合。

---

## 3. Caveats

1. **设置主页面二级标签切换**：设置页内部的侧边 Tab 切换由 R2 负责平滑淡化，不在 R4 详情页路由范围；但设置页打开的独立子页面 `SettingsIssuePage`（`/settings/issue`）纳入统一的 `DetailTransitionPage` 管理。
2. **NowPlayingPage 沉浸全屏播放页**：播放页具备独立的 `NowPlayingTransitionPage` 与封面 Hero 融合转场，不受详情页转场修改影响。
3. **No other caveats**。

---

## 4. Conclusion

1. 详情页转场重构方案完全可行，所有详情页均已收敛至 `GoRouter` 与 `DetailTransitionPage`。
2. 实施方案只需修改 `lib/entry.dart` 中的 `DetailTransitionPage`、`_buildDetailRouteTransition` 与相关路由配置，代码变动集中且完全向后兼容。
3. 该方案完美实现了“横向平滑推入淡化 + 阻尼感返回 + 二级视差景深”，全面提升桌面端各详情页交互质感。

---

## 5. Verification Method

1. **静态代码分析**：
   ```powershell
   flutter analyze
   ```
   预期输出：`No issues found!`。
2. **详情页进退场动效验证**：
   - 启动应用，分别从歌曲列表右键菜单、艺术家列表、专辑列表、文件夹列表、歌单列表、搜索栏等入口进入详情页；
   - 观察进场动效：页面自右向左平滑推入（8% 位移）并迅速淡入；
   - 观察 Hero 元素：专辑/艺术家封面在飞行过程中平滑就位，无跳变或坐标拉扯；
   - 点击顶部返回按钮或使用鼠标侧键/键盘快捷键返回，观察退场动效向右滑出并快速淡出；
   - 在专辑详情页内点击艺术家进入二级详情，观察底层专辑详情页向左轻微视差退移并轻度淡化，返回时自然回位。
