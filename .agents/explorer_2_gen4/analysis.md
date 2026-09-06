# R3: 右键菜单与二级子菜单视觉与悬停交互重构 — 详细调研与架构方案报告

## 1. 调研背景与核心目标

根据任务需求 **R3: 右键菜单与二级子菜单视觉与悬停交互重构**，本项目需对桌面端音乐播放器（`qisheng_player`）中所有的右键上下文菜单（Context Menu）、二级子菜单（Cascading Sub-menu）及弹出菜单（Popup Menu Anchor）进行视觉质感与悬停交互全面升级：
1. **彻底消除黑边与生硬外边框**：查明黑边、生硬线框产生的底层机理，并在主题与组件层彻底根除。
2. **现代半透明磨砂/毛玻璃质感容器**：重构菜单面板背景为半透明微光质感（Translucent Surface）、8~12px 精致圆角与柔和漫反射外发光阴影。
3. **菜单项平滑胶囊悬停高亮（Capsule Hover Highlight）**：为菜单项提供 6~8px 内嵌胶囊圆角、平滑的颜色渐变动效（`animationDuration: 140ms`）、精致的内边距与统一步长的图标/文字排版。
4. **二级子菜单丝滑级联展开动效**：解决当前二级菜单（如“添加到歌单”、“艺术家”等）弹出时突兀生硬无动画的问题，实现双向平滑的级联淡入位移动效。

---

## 2. 代码库菜单组件与调用链路全景调查

通过全库检索与依赖分析，本项目所有右键菜单与弹出菜单均基于 Flutter Material 3 的 `MenuAnchor` / `MenuItemButton` / `SubmenuButton` 体系构建，涉及的文件分布如下：

| 文件路径 | 组件/方法名称 | 角色与用途 | 涉及问题分析 |
| :--- | :--- | :--- | :--- |
| `lib/theme/app_component_themes.dart` | `AppComponentThemes.menuTheme` & `menuButtonTheme` | 全局菜单面板与菜单项按钮的主题样式配置 | 容器圆角过大（26px）、边框使用 `Colors.transparent` 导致渲染边缘黑线伪影、缺失内边距（Padding）、阴影为透明色 |
| `lib/theme/app_theme.dart` | `AppTheme.build` | 注册 `menuTheme` 与 `menuButtonTheme` | 挂载全局菜单样式 |
| `lib/component/animated_menu_content.dart` | `AnimatedMenuContent` & `animatedMenuChildren` | 菜单项进场微动效包装器 | 仅支持顶级菜单项，未支持二级子菜单项的级联挂载，无参数化延迟控制 |
| `lib/component/audio_context_menu.dart` | `AudioContextMenu` & `buildAudioContextMenuChildren` | 单曲右键与“更多”按钮共享菜单构建器 | “添加到歌单”、“艺术家”二级子菜单未接入动画；部分子菜单项缺失 Leading Icon 导致文字错位 |
| `lib/component/album_context_menu.dart` | `AlbumContextMenu` & `buildAlbumContextMenuChildren` | 专辑右键与操作菜单构建器 | “添加到歌单”、“艺术家”二级子菜单未接入动画；部分子菜单项缺失 Leading Icon |
| `lib/page/now_playing_page/top_actions.dart` | `NowPlayingMoreMenuAction` | 播放详情页右上角“更多”操作菜单 | 二级子菜单未接入动画 |
| `lib/page/now_playing_page/component/lyric_source_view.dart` | `_SetLyricSourceBtn` | 歌词来源切换菜单（MenuAnchor） | 需适配全新的全局玻璃质感与胶囊悬停 |
| `lib/page/playlist_detail_page.dart` | `_MoveToPlaylistMenuAction` | 歌单详情批量“移动到歌单”菜单 | 需适配全新的全局玻璃质感与胶囊悬停 |
| `lib/page/uni_page_components.dart` | `SortMethodSelectBtn` | 歌曲/专辑排序方式切换菜单 | 本地硬编码了 `borderRadius: BorderRadius.circular(20)` 与独立 Style，破坏了全局一致性 |
| `lib/component/audio_tile.dart` & `audio_grid_tile.dart` | 歌曲条目（行/网格） | 触发 `AudioContextMenu` 的主要载体 | 右键点击与“更多（...）”按钮点击分别调用 `controller.open()`，交互无缝接入 |
| `lib/component/album_tile.dart` & `album_grid_tile.dart` | 专辑条目（行/网格） | 触发 `AlbumContextMenu` 的主要载体 | 右键与操作按钮调用 |

---

## 3. 根因剖析（Root Causes）

### 3.1 为什么会出现黑色边框/生硬线框？
1. **透明 BorderSide 渲染引擎伪影**：
   在 `lib/theme/app_component_themes.dart` 第 381 行中：
   ```dart
   shape: WidgetStatePropertyAll(
     RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(surfaces.radiusLg),
       side: BorderSide(color: surfaces.strokeSubtle.withValues(alpha: 0.38)),
     ),
   ),
   ```
   在 `AppTheme._surfaceTokens` 中，`strokeSubtle` 被硬编码配置为 `Colors.transparent`。在 Flutter Windows 渲染引擎（DirectX / Skia）下，当 `Material` 绘制带有 `BorderSide(color: Color(0x00000000), width: 1.0)` 的圆角矩形时，抗锯齿算法会在多边形外缘与阴影交界处生成 1px 的半透明黑灰色切边（Aliasing Seam），视觉上表现为一圈脏脏的黑边。
2. **缺乏容器内边距导致的项边缘碰撞（Edge Collision）**：
   `MenuStyle` 默认的水平内边距为 0。当鼠标悬停在 `MenuItemButton` 上时，其悬停背景矩形直接顶满菜单卡片的左右边界（Width 100%）。此时如果外层容器有圆角，而内层项也是方角/微圆角，鼠标划过时四周就会出现忽明忽暗的方块硬边界，给人一种“生硬线框”的割裂感。
3. **圆角半径与菜单尺寸不匹配**：
   目前使用的 `surfaces.radiusLg` 值为 **26.0px**。对于一个宽度仅 180~220px 的桌面右键菜单而言，26px 的超大圆角会导致菜单上下两个角的项内容被向内挤压，且四角过于臃肿。现代桌面设计规范（macOS / Windows 11 Fluent 2）推荐的菜单圆角通常为 **8~12px**。

### 3.2 为什么容器质感单薄、缺乏半透明毛玻璃与柔和漫反射？
1. `AppComponentThemes.menuTheme` 中背景色直接混合为 `0.96` 不透明度，且缺乏高亮微光描边（Hairline Highlight Rim）。
2. `shadowColor` 被指定为 `surfaces.shadowColor.withValues(alpha: 0.28)`，而 `surfaces.shadowColor` 在 Token 中为 `Colors.transparent`，导致菜单完全失去弥散阴影（Diffuse Shadow），悬浮层级感完全丧失。

### 3.3 为什么鼠标悬停没有平滑胶囊感？
1. `menuButtonTheme` 没有声明 `animationDuration`，导致悬停状态变化时颜色瞬间突变，没有过渡过程。
2. 菜单项宽度直接紧贴外框，没有预留四周的 Inset Padding（建议容器提供 `EdgeInsets.all(6)`，使每个项在容器内部像一块悬浮的“胶囊小药丸”）。
3. 缺少对 `overlayColor`（去除 Material 水波纹干扰）和 `iconSize`（统一为精致的 18px）的精确控制。

### 3.4 为什么二级子菜单展开生硬突兀？
1. `SubmenuButton`（如“添加到歌单”、“艺术家”等）在展开子菜单面板时，其内部 `menuChildren` 直接是裸露的 `MenuItemButton`，并未经过 `animatedMenuChildren` 包装。
2. 当用户鼠标悬停触发二级菜单时，子菜单面板瞬间闪现在屏幕上，缺乏级联进场位移与淡入动效。

---

## 4. 详细技术改造方案（Proposed Technical Design）

### 4.1 全局菜单主题重构（`lib/theme/app_component_themes.dart`）

#### A. 菜单面板容器样式 (`menuTheme`)
- **圆角规范**：统一采用 `BorderRadius.circular(10)`（符合 8-12px 精致现代桌面规范）。
- **容器内边距**：设置 `padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6, vertical: 6))`，使所有菜单项与外框保留 6px 的精致留白。
- **高质感半透明背景**：
  - 暗色模式：`Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), const Color(0xE81C1D22))`
  - 亮色模式：`Color.alphaBlend(scheme.primary.withValues(alpha: 0.04), const Color(0xF4FFFFFF))`
- **精致高光微边框（消灭黑边）**：
  - 暗色模式：`BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 0.8)`
  - 亮色模式：`BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38), width: 0.8)`
- **柔和漫反射阴影**：
  - `elevation: const WidgetStatePropertyAll(10)`
  - `shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: isDark ? 0.45 : 0.14))`

#### B. 菜单项按钮样式 (`menuButtonTheme`)
- **胶囊形态**：`shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))`。
- **交互尺寸与内边距**：`minimumSize: const WidgetStatePropertyAll(Size(0, 36))`，`padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 8))`。
- **平滑颜色渐变动效**：设置 `animationDuration: const Duration(milliseconds: 140)`。
- **悬停与按下背景色**：
  - 悬停（Hovered）/ 聚焦（Focused）：`scheme.primary.withValues(alpha: isDark ? 0.15 : 0.09)`
  - 按下（Pressed）：`scheme.primary.withValues(alpha: isDark ? 0.25 : 0.18)`
  - 默认（Normal）：`Colors.transparent`
- **文字与图标色彩协同**：
  - 默认文字：`scheme.onSurface.withValues(alpha: 0.88)`
  - 悬停文字：`scheme.onSurface`
  - 按下文字：`scheme.primary`
  - 默认图标：`scheme.onSurface.withValues(alpha: 0.72)`
  - 悬停图标：`scheme.primary`
  - 按下图标：`scheme.primary`
  - 图标尺寸：`iconSize: const WidgetStatePropertyAll(18.0)`
- **消除水波纹干扰**：`overlayColor: const WidgetStatePropertyAll(Colors.transparent)`，`side: const WidgetStatePropertyAll(BorderSide.none)`。

---

### 4.2 级联进场动效与包装器升级（`lib/component/animated_menu_content.dart`）

将 `AnimatedMenuContent` 动效优化为适用于**一级菜单与二级子菜单**的统一级联体验：
1. **动画参数**：
   - 持续时间：`130ms`
   - 缓动曲线：`Curves.easeOutCubic`
   - 效果：`FadeEffect(begin: 0.0, end: 1.0)` + `MoveEffect(begin: const Offset(0, 4), end: Offset.zero)`
2. **多级菜单自动化支持**：
   - 保持 `animatedMenuChildren(BuildContext context, Iterable<Widget> children)` 接口简洁性，并在各级菜单中均统一调用。

---

### 4.3 右键菜单与子菜单业务组件重构

#### A. 单曲上下文菜单（`lib/component/audio_context_menu.dart`）
1. 在 `buildAudioContextMenuChildren` 中：
   - 为“添加到歌单”的 `SubmenuButton` 补充 `leadingIcon: const Icon(Symbols.playlist_add)`，并将子项列表用 `animatedMenuChildren(context, [...])` 包装。
   - 为“艺术家”的 `SubmenuButton` 补充 `leadingIcon: const Icon(Symbols.artist)`，并将子项列表用 `animatedMenuChildren(context, [...])` 包装。
   - 为“专辑”的 `MenuItemButton` 保持 `Symbols.album`。
   - 确保所有菜单项均有统一的 `leadingIcon`，使菜单项文字对齐保持绝对垂直一致，杜绝锯齿错位。

#### B. 专辑上下文菜单（`lib/component/album_context_menu.dart`）
1. 在 `buildAlbumContextMenuChildren` 中：
   - 为“添加到歌单”的 `SubmenuButton` 补充 `leadingIcon: const Icon(Symbols.playlist_add)`，并将子项用 `animatedMenuChildren(context, [...])` 包装。
   - 为“艺术家”的 `SubmenuButton` 补充 `leadingIcon: const Icon(Symbols.artist)`，并将子项用 `animatedMenuChildren(context, [...])` 包装。

#### C. 播放详情页更多操作菜单（`lib/page/now_playing_page/top_actions.dart`）
1. 在 `NowPlayingMoreMenuAction` 中：
   - 将“添加到歌单”与“艺术家”的 `SubmenuButton.menuChildren` 分别用 `animatedMenuChildren(context, [...])` 包装。

#### D. 排序选择菜单清理（`lib/page/uni_page_components.dart`）
1. 移除 `SortMethodSelectBtn` 中过时的局部 `MenuStyle(shape: ...)` 与 `MenuItemButton(style: ...)` 硬编码配置，使其完全继承全局现代无边框玻璃菜单主题。

---

## 5. 精确代码修改对照表（Code Diff Snippets）

### 5.1 `lib/theme/app_component_themes.dart`

```dart
<<<<
  static MenuThemeData menuTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
  ) {
    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Color.alphaBlend(
            scheme.primary.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.16 : 0.08,
            ),
            surfaces.surfaceFloating.withValues(alpha: 0.96),
          ),
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusLg),
            side: BorderSide(
                color: surfaces.strokeSubtle.withValues(alpha: 0.38)),
          ),
        ),
        elevation: const WidgetStatePropertyAll(12),
        shadowColor: WidgetStatePropertyAll(
          surfaces.shadowColor.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  static MenuButtonThemeData menuButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return MenuButtonThemeData(
      style: ButtonStyle(
        enableFeedback: false,
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accentSoft;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            final isDark = scheme.brightness == Brightness.dark;
            return scheme.primary.withValues(
              alpha: isDark ? 0.12 : 0.08,
            );
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accent;
          }
          return scheme.onSurface;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accent;
          }
          return scheme.onSurface.withValues(alpha: 0.82);
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusSm),
          ),
        ),
      ),
    );
  }
====
  static MenuThemeData menuTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    // 现代半透明微光质感容器背景（88%~92% 通透度）
    final menuBgColor = isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.08),
            const Color(0xE81C1D22),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.04),
            const Color(0xF4FFFFFF),
          );

    // 精致高光微边框：彻底消除黑边与伪影，在暗色下呈极细微光，在亮色下呈柔和轮廓
    final borderSide = isDark
        ? BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          )
        : BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.38),
            width: 0.8,
          );

    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(menuBgColor),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        // 8~12px 精致圆角规范
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: borderSide,
          ),
        ),
        // 容器内边距：为内部菜单项预留 6px 呼吸留白，实现真正的悬浮胶囊感
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        // 柔和漫反射外发光阴影
        elevation: const WidgetStatePropertyAll(10),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
        ),
      ),
    );
  }

  static MenuButtonThemeData menuButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return MenuButtonThemeData(
      style: ButtonStyle(
        enableFeedback: false,
        animationDuration: const Duration(milliseconds: 140), // 丝滑悬停动效
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        // 彻底移除菜单项描边
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        // 悬停胶囊背景高亮
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: isDark ? 0.25 : 0.18);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return scheme.primary.withValues(alpha: isDark ? 0.15 : 0.09);
          }
          return Colors.transparent;
        }),
        // 字体色彩
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary;
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.onSurface;
          }
          return scheme.onSurface.withValues(alpha: 0.88);
        }),
        // 图标色彩与尺寸
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return scheme.primary;
          }
          return scheme.onSurface.withValues(alpha: 0.72);
        }),
        iconSize: const WidgetStatePropertyAll(18.0),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        // 精致 8px 胶囊形态
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
>>>>
```

### 5.2 `lib/component/audio_context_menu.dart`

```dart
<<<<
    SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: () async {
            ...
          },
          leadingIcon: const Icon(Symbols.add),
          child: const Text("新建歌单并添加"),
        ),
        if (PLAYLISTS.isEmpty)
          const MenuItemButton(
            onPressed: null,
            child: Text("暂无歌单"),
          )
        else
          ...List.generate(
            PLAYLISTS.length,
            (i) => MenuItemButton(
              onPressed: () {
                ...
              },
              leadingIcon: const Icon(Symbols.queue_music),
              child: Text(PLAYLISTS[i].name),
            ),
          ),
      ],
      child: const Text("添加到歌单"),
    ),
    if (audio.splitedArtists.isNotEmpty)
      SubmenuButton(
        menuChildren: List.generate(
          audio.splitedArtists.length,
          (i) {
            final artistName = audio.splitedArtists[i];
            return MenuItemButton(
              onPressed: () {
                ...
              },
              leadingIcon: const Icon(Symbols.artist),
              child: Text(artistName),
            );
          },
        ),
        child: const Text("艺术家"),
      ),
====
    SubmenuButton(
      leadingIcon: const Icon(Symbols.playlist_add),
      menuChildren: animatedMenuChildren(context, [
        MenuItemButton(
          onPressed: () async {
            ...
          },
          leadingIcon: const Icon(Symbols.add),
          child: const Text("新建歌单并添加"),
        ),
        if (PLAYLISTS.isEmpty)
          const MenuItemButton(
            onPressed: null,
            leadingIcon: Icon(Symbols.info),
            child: Text("暂无歌单"),
          )
        else
          ...List.generate(
            PLAYLISTS.length,
            (i) => MenuItemButton(
              onPressed: () {
                ...
              },
              leadingIcon: const Icon(Symbols.queue_music),
              child: Text(PLAYLISTS[i].name),
            ),
          ),
      ]),
      child: const Text("添加到歌单"),
    ),
    if (audio.splitedArtists.isNotEmpty)
      SubmenuButton(
        leadingIcon: const Icon(Symbols.artist),
        menuChildren: animatedMenuChildren(
          context,
          List.generate(
            audio.splitedArtists.length,
            (i) {
              final artistName = audio.splitedArtists[i];
              return MenuItemButton(
                onPressed: () {
                  ...
                },
                leadingIcon: const Icon(Symbols.artist),
                child: Text(artistName),
              );
            },
          ),
        ),
        child: const Text("艺术家"),
      ),
>>>>
```

### 5.3 `lib/component/album_context_menu.dart`

```dart
<<<<
    SubmenuButton(
      menuChildren: [
        if (works.isEmpty || PLAYLISTS.isEmpty)
          MenuItemButton(
            onPressed: null,
            child: Text(works.isEmpty ? '暂无歌曲' : '暂无歌单'),
          )
        else
          ...PLAYLISTS.map(
            (playlist) => MenuItemButton(
              ...
              leadingIcon: const Icon(Symbols.queue_music),
              child: Text(playlist.name),
            ),
          ),
      ],
      child: const Text('添加到歌单'),
    ),
    MenuItemButton(
      onPressed: () => context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album),
      leadingIcon: const Icon(Symbols.album),
      child: const Text('查看专辑详情'),
    ),
    if (album.artistsMap.isNotEmpty)
      SubmenuButton(
        menuChildren: album.artistsMap.values
            .map(
              (artist) => MenuItemButton(
                onPressed: () => context.push(
                  app_paths.ARTIST_DETAIL_PAGE,
                  extra: artist,
                ),
                leadingIcon: const Icon(Symbols.artist),
                child: Text(artist.name),
              ),
            )
            .toList(),
        child: const Text('艺术家'),
      ),
====
    SubmenuButton(
      leadingIcon: const Icon(Symbols.playlist_add),
      menuChildren: animatedMenuChildren(context, [
        if (works.isEmpty || PLAYLISTS.isEmpty)
          MenuItemButton(
            onPressed: null,
            leadingIcon: const Icon(Symbols.info),
            child: Text(works.isEmpty ? '暂无歌曲' : '暂无歌单'),
          )
        else
          ...PLAYLISTS.map(
            (playlist) => MenuItemButton(
              ...
              leadingIcon: const Icon(Symbols.queue_music),
              child: Text(playlist.name),
            ),
          ),
      ]),
      child: const Text('添加到歌单'),
    ),
    MenuItemButton(
      onPressed: () => context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album),
      leadingIcon: const Icon(Symbols.album),
      child: const Text('查看专辑详情'),
    ),
    if (album.artistsMap.isNotEmpty)
      SubmenuButton(
        leadingIcon: const Icon(Symbols.artist),
        menuChildren: animatedMenuChildren(
          context,
          album.artistsMap.values.map(
            (artist) => MenuItemButton(
              onPressed: () => context.push(
                app_paths.ARTIST_DETAIL_PAGE,
                extra: artist,
              ),
              leadingIcon: const Icon(Symbols.artist),
              child: Text(artist.name),
            ),
          ),
        ),
        child: const Text('艺术家'),
      ),
>>>>
```

### 5.4 `lib/page/now_playing_page/top_actions.dart`

```dart
<<<<
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              ...
            ),
            if (PLAYLISTS.isEmpty)
              const MenuItemButton(
                onPressed: null,
                child: Text("暂无歌单"),
              )
            else
              ...List.generate(
                PLAYLISTS.length,
                (i) => MenuItemButton(
                  ...
                ),
              ),
          ],
          leadingIcon: const Icon(Symbols.queue_music),
          child: const Text("添加到歌单"),
        ),
        SubmenuButton(
          menuChildren: List.generate(
            nowPlaying.splitedArtists.length,
            (i) => MenuItemButton(
              ...
            ),
          ),
          child: const Text("艺术家"),
        ),
====
        SubmenuButton(
          menuChildren: animatedMenuChildren(context, [
            MenuItemButton(
              ...
            ),
            if (PLAYLISTS.isEmpty)
              const MenuItemButton(
                onPressed: null,
                leadingIcon: Icon(Symbols.info),
                child: Text("暂无歌单"),
              )
            else
              ...List.generate(
                PLAYLISTS.length,
                (i) => MenuItemButton(
                  ...
                ),
              ),
          ]),
          leadingIcon: const Icon(Symbols.playlist_add),
          child: const Text("添加到歌单"),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Symbols.artist),
          menuChildren: animatedMenuChildren(
            context,
            List.generate(
              nowPlaying.splitedArtists.length,
              (i) => MenuItemButton(
                ...
              ),
            ),
          ),
          child: const Text("艺术家"),
        ),
>>>>
```

### 5.5 `lib/page/uni_page_components.dart`

```dart
<<<<
    return MenuAnchor(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      menuChildren: animatedMenuChildren(
        context,
        List.generate(
          sortMethods.length,
          (i) => MenuItemButton(
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
            ),
            leadingIcon: Icon(sortMethods[i].icon),
            child: Text(sortMethods[i].name),
            onPressed: () => setSortMethod(sortMethods[i]),
          ),
        ),
      ),
====
    return MenuAnchor(
      menuChildren: animatedMenuChildren(
        context,
        List.generate(
          sortMethods.length,
          (i) => MenuItemButton(
            leadingIcon: Icon(sortMethods[i].icon),
            child: Text(sortMethods[i].name),
            onPressed: () => setSortMethod(sortMethods[i]),
          ),
        ),
      ),
>>>>
```

---

## 6. 验收标准与验证方案（Verification Plan）

### 6.1 静态检查与无回归要求
- 运行 `flutter analyze` 确保全库 0 issues、0 warnings、0 errors。
- 保证单曲播放、切歌、追加队列、跳转专辑/歌手、多选添加到歌单、在资源管理器中定位等现有业务逻辑 100% 完整可用，无任何副作用。

### 6.2 视觉与交互验收清单
1. **去黑边验证**：在亮色模式（Light Mode）与暗色模式（Dark Mode）下，右键弹出菜单无任何黑灰色边框、无锯齿状切割线，边界呈现 0.8px 的高光微边框。
2. **容器质感验证**：菜单背景具备 88%~94% 的半透明微光质感，四周带有 10px 的优雅圆角，外侧伴随柔和自然的弥散漫反射阴影（elevation 10）。
3. **悬停胶囊感验证**：鼠标划过菜单项时，呈现 8px 胶囊高亮背景，四周距离菜单外框保持 6px 均匀内边距；悬停动画过渡时间为 140ms，顺滑自然且无迟滞感；图标与文本随悬停同步变色。
4. **二级菜单动效验证**：当鼠标悬停在“添加到歌单”、“艺术家”等二级菜单上时，二级菜单面板在侧方展开，并且子项顺滑级联淡入位移进场（130ms），无任何突兀闪烁或瞬间切入。
