# 歌词预览面板双向平滑开启动画与列表联动调查报告 (R2 Investigation Handoff)

## 1. Observation (直接观察事实)

### 1.1 歌词预览面板与主页面结构定位
- **歌词预览组件**：`AudioLyricPreviewPanel`
  - 文件路径：`lib/component/audio_lyric_preview_panel.dart`
  - 组件结构：无状态组件，包含 214×214 专辑封面（`_LyricPreviewArtwork`）、歌曲标题与艺术家文本（两行截断）、歌词预览滚动列表（`_LyricPreviewLines`）以及空状态视图（`_LyricPreviewEmptyState`）。固定设计宽度通常为 284px。
- **主界面与触发按钮**：`AudiosPage`
  - 文件路径：`lib/page/audios_page.dart`
  - 第 70-79 行：
    ```dart
    bool get _showLyricPreview =>
        AppPreference.instance.audiosPagePref.showLyricPreview;

    void _toggleLyricPreview() {
      setState(() {
        AppPreference.instance.audiosPagePref.showLyricPreview =
            !_showLyricPreview;
      });
      unawaited(AppPreference.instance.save());
    }
    ```
  - 第 111-124 行：右上角工具栏切换按钮 `CpIconButton`（Key: `toggle-lyric-preview`）。
  - 第 147-149 行：向 `UniPage` 注入歌词预览参数：
    ```dart
    rightPaneBuilder: (_) => const AudioLyricPreviewPanel(),
    showRightPane: _showLyricPreview,
    rightPaneWidth: 284,
    ```
- **核心容器与布局框架**：`UniPage`
  - 文件路径：`lib/page/uni_page.dart`
  - 第 486-488 行：接收 `rightPaneBuilder`、`showRightPane`（默认 `false`）、`rightPaneWidth`（默认 `296`）。
  - 第 786-803 行：
    ```dart
    final hasRightPane = widget.rightPaneBuilder != null;
    final showRightPane = hasRightPane && widget.showRightPane;
    const sideRailWidth = 48.0;
    const sideRailPadding = 10.0;
    const rightPaneGap = 14.0;
    final sideRailReserved = (hasSideIndex || hasLocateButton) ? 60.0 : 0.0;
    final rightPaneReserved =
        showRightPane ? widget.rightPaneWidth + rightPaneGap : 0.0;
    final rightReserved = sideRailReserved + rightPaneReserved;
    final sideRailRight = showRightPane ? 6.0 : sideRailPadding;
    final rightPaneRight =
        (hasSideIndex || hasLocateButton) ? sideRailWidth + 18.0 : 10.0;
    final listPadding = EdgeInsets.fromLTRB(
      0,
      0,
      rightReserved,
      32,
    );
    ```
  - 第 891-933 行：
    ```dart
    final rightPaneChild = widget.rightPaneBuilder?.call(context);
    final scheme = Theme.of(context).colorScheme;
    final body = Stack(
      key: const ValueKey('uni-page-overlay-layer'),
      children: [
        listBody,
        if (showRightPane)
          Positioned(
            top: 8,
            bottom: 8,
            right: rightPaneRight,
            child: ClipRect(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: showRightPane ? 1 : 0),
                duration: context.motion.panelTransitionDuration,
                curve: context.motion.normal,
                builder: (context, progress, _) {
                  final clamped = progress.clamp(0.0, 1.0);
                  final width = widget.rightPaneWidth * clamped;
                  final slideX = (1 - clamped) * 18;
                  return SizedBox(
                    width: width,
                    child: IgnorePointer(
                      ignoring: clamped < 0.02,
                      child: Opacity(
                        opacity: clamped,
                        child: Transform.translate(
                          offset: Offset(slideX, 0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: widget.rightPaneWidth,
                              child: clamped <= 0.001
                                  ? const SizedBox.shrink()
                                  : rightPaneChild ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    ```

### 1.2 主题动效规范 (`AppMotionTokens`)
- 文件路径：`lib/theme/app_theme_extensions.dart` 及 `lib/theme/app_theme.dart`
- `context.motion.panelTransitionDuration`：`Duration(milliseconds: 260)`
- 缓动曲线：`Curves.easeInOutCubic` / `context.motion.normal`

---

## 2. Logic Chain (问题根因与逻辑推导链)

### 2.1 展开/收起时面板生硬跳变及收起无退出动画的根本原因
1. **收起时节点被直接销毁**（Observation 1.1 中第 895 行 `if (showRightPane)`）：
   - 当用户点击关闭歌词预览时，`AudiosPage` 的 `_showLyricPreview` 变为 `false`，触发 `UniPage` 重建。
   - 在 `Stack` 内部，由于 `if (showRightPane)` 为 `false`，包裹 `TweenAnimationBuilder` 的 `Positioned` 节点在第 0 帧被直接从 Widget 树中移除。
   - `TweenAnimationBuilder` 根本没有机会执行从 `1.0` 到 `0.0` 的逆向退场动画，歌词面板直接瞬时消失（0ms 突兀消失）。
2. **局部 `TweenAnimationBuilder` 无法与外层布局同步**：
   - 原有的 `TweenAnimationBuilder` 仅挂载在右侧面板自身内部，动画进度 `progress` 属于其局部状态，外部的列表、侧边栏和内边距完全无法感知这一进度。

### 2.2 歌曲列表区域宽度调整突跳与文字排版抖动的根本原因
1. **列表右边距（`listPadding.right`）瞬间突变**（Observation 1.1 中第 792-803 行）：
   - `rightPaneReserved` 的计算公式为布尔条件表达式：`showRightPane ? widget.rightPaneWidth + rightPaneGap : 0.0`。
   - 当 `showRightPane` 从 `false` 变为 `true` 时，`rightPaneReserved` 在 1 帧内从 `0.0px` 跳变至 `298.0px`（`284 + 14`），导致 `listPadding.right` 从 `60.0px` 瞬间跳至 `358.0px`。
   - `ListView.builder`、`ReorderableListView`、`_SideNavAnimatedTableGrid` 以及 `GridView` 的视口宽度在第 0 帧瞬间被压缩了 298px。
   - 歌曲列表条目（`AudioTile`）内部的标题、歌手、专辑等 `Expanded` 文本排版瞬间换行/截断（ellipsis 跳变）。
   - 与此同时，右侧面板才刚刚开始从 0 宽度向 284px 展开，导致中间产生长达 260ms 的大面积右侧空白撕裂区。
2. **收起时列表瞬间展开**：
   - 反向收起时，`listPadding.right` 瞬间从 `358.0px` 骤降为 `60.0px`，列表瞬时拉宽，文字突然反向伸展跳动。

### 2.3 侧边字母索引与定位按钮未严格同步
- 侧边字母索引轨和定位按钮使用 `AnimatedPositioned(duration: 260ms)` 独立计算位置（从 `10.0` 到 `6.0`），未与列表右边距和面板宽度绑定至同一个动画时间轴，无法保证多元素绝对帧同步。

---

## 3. Solution Design & Code Proposal (重构方案与代码建议)

### 3.1 总体架构设计
在 `_UniPageState` 中引入统一的 `AnimationController` 与 `CurvedAnimation`，使用 `SingleTickerProviderStateMixin` 管理完整的进场与退场生命周期：
1. **统一时间轴驱动**：由单个 `_rightPaneAnimation`（缓动曲线 `Curves.easeInOutCubic`，时长 `context.motion.panelTransitionDuration`）驱动：
   - 歌词面板自身宽度：`widget.rightPaneWidth * progress`
   - 歌词面板位移与透明度：`slideX = (1 - progress) * 18.0`，`opacity = progress`
   - 主列表右侧预留边距：`listPadding.right = sideRailReserved + (widget.rightPaneWidth + rightPaneGap) * progress`
   - 侧边字母索引轨位置：`sideRailRight = lerpDouble(sideRailPadding, 6.0, progress)`
   - 表格/网格偏移量计算：`_gridOffsetForIndex` 动态采用 `rightPaneProgress`
2. **生命周期保活（退场动画完整渲染）**：
   - 定义 `final isRightPaneActive = hasRightPane && (widget.showRightPane || rightPaneProgress > 0.0001);`
   - 当 `widget.showRightPane` 变为 `false` 时，`didUpdateWidget` 调用 `_rightPaneAnimationController.reverse()`。
   - 只要 `rightPaneProgress > 0.0001`，面板节点保持挂载在 `Stack` 中并执行完整的淡出与收缩动画；仅当动画完全结束（`progress == 0`）且 `!widget.showRightPane` 时，才释放相关渲染开销。
3. **内容无抖动防挤压设计**：
   - 右侧面板内部放置于恒定宽度 `SizedBox(width: widget.rightPaneWidth)` 中，外部包裹 `Align(alignment: Alignment.centerRight)` 与 `ClipRect` + 动态宽度容器。
   - 面板在缩放时仅做物理裁剪与平移淡入淡出，面板内部文本、封面与歌词不会发生二次重排挤压。

### 3.2 具体重构代码提案 (`lib/page/uni_page.dart`)

```dart
// 1. 在 _UniPageState 声明中混入 SingleTickerProviderStateMixin
class _UniPageState<T> extends State<UniPage<T>>
    with SingleTickerProviderStateMixin {
  late SortMethodDesc<T>? currSortMethod =
      widget.sortMethods?[widget.pref.sortMethod];
  late SortOrder currSortOrder = widget.pref.sortOrder;
  late ContentView currContentView = widget.pref.contentView;
  late ScrollController scrollController = ScrollController();
  late List<T> _sortedContentSnapshot;
  String? _activeSideIndexLabel;

  late final AnimationController _rightPaneAnimationController;
  late final Animation<double> _rightPaneAnimation;

  @override
  void initState() {
    super.initState();
    _sortContent();

    _rightPaneAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.showRightPane ? 1.0 : 0.0,
    );
    _rightPaneAnimation = CurvedAnimation(
      parent: _rightPaneAnimationController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    if (widget.locateTo == null) return;
    final targetAt = widget.contentList.indexOf(widget.locateTo as T);
    if (targetAt < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      _jumpToListIndex(targetAt, animated: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = context.motion.panelTransitionDuration;
    _rightPaneAnimationController.duration = duration;
    _rightPaneAnimationController.reverseDuration = duration;
  }

  @override
  void didUpdateWidget(covariant UniPage<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showRightPane != oldWidget.showRightPane) {
      if (widget.showRightPane) {
        _rightPaneAnimationController.forward();
      } else {
        _rightPaneAnimationController.reverse();
      }
    }

    final canRestorePreviousOrder = widget.contentRevision != null &&
        widget.contentRevision == oldWidget.contentRevision &&
        restorePreviousContentOrder(
          widget.contentList,
          _sortedContentSnapshot,
        );
    if (!canRestorePreviousOrder) {
      _sortContent();
    }
  }

  @override
  void dispose() {
    _rightPaneAnimationController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // 2. 优化 _gridOffsetForIndex
  double _gridOffsetForIndex(
    int index, {
    required double maxCrossAxisExtent,
    required double mainAxisSpacing,
    required double crossAxisSpacing,
    double? mainAxisExtent,
    double childAspectRatio = 1,
    bool animateSideNavReflow = false,
  }) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return 0;
    final hasSideIndex =
        widget.sideIndexLabels != null && widget.sideIndexLabels!.isNotEmpty;
    final hasLocateButton =
        widget.locateTo != null || widget.locateIndexResolver != null;
    final sideRailReserved = hasSideIndex || hasLocateButton ? 60.0 : 0.0;
    final hasRightPane = widget.rightPaneBuilder != null;
    final rightPaneProgress = _rightPaneAnimation.value;
    final rightPaneReserved = hasRightPane
        ? (widget.rightPaneWidth + 14.0) * rightPaneProgress
        : 0.0;
    final crossAxisExtent =
        (renderObject.size.width - sideRailReserved - rightPaneReserved)
            .clamp(0.0, double.infinity)
            .toDouble();
    // ... 后续逻辑保持不变
  }

  // 3. 在 build 中使用 AnimatedBuilder 统一监听 _rightPaneAnimation
  @override
  Widget build(BuildContext context) {
    Widget? primaryAction = widget.primaryAction;
    final secondaryActions = <Widget>[];
    // ... 构建 actions

    return AnimatedBuilder(
      animation: _rightPaneAnimation,
      builder: (context, _) {
        return widget.multiSelectController == null
            ? result(null, primaryAction, secondaryActions)
            : ListenableBuilder(
                listenable: widget.multiSelectController!,
                builder: (context, _) => result(
                  widget.multiSelectController!,
                  primaryAction,
                  secondaryActions,
                ),
              );
      },
    );
  }

  // 4. 重构 result 方法中的布局联动与 Stack 渲染
  Widget result(
    MultiSelectController<T>? multiSelectController,
    Widget? primaryAction,
    List<Widget> secondaryActions,
  ) {
    final sideIndex = widget.sideIndexLabels;
    final hasSideIndex = sideIndex != null && sideIndex.isNotEmpty;
    final sideIndexLabels = sideIndex ?? const <String>[];
    final hasLocateButton =
        widget.locateTo != null || widget.locateIndexResolver != null;
    final hasRightPane = widget.rightPaneBuilder != null;
    final rightPaneProgress = _rightPaneAnimation.value;
    final isRightPaneActive =
        hasRightPane && (widget.showRightPane || rightPaneProgress > 0.0001);

    const sideRailWidth = 48.0;
    const sideRailPadding = 10.0;
    const rightPaneGap = 14.0;
    final sideRailReserved = (hasSideIndex || hasLocateButton) ? 60.0 : 0.0;
    final rightPaneReserved = hasRightPane
        ? (widget.rightPaneWidth + rightPaneGap) * rightPaneProgress
        : 0.0;
    final rightReserved = sideRailReserved + rightPaneReserved;
    final sideRailRight =
        lerpDouble(sideRailPadding, 6.0, rightPaneProgress) ?? sideRailPadding;
    final rightPaneRight =
        (hasSideIndex || hasLocateButton) ? sideRailWidth + 18.0 : 10.0;
    final listPadding = EdgeInsets.fromLTRB(
      0,
      0,
      rightReserved,
      32,
    );

    final listBody = KeyedSubtree(
      key: const ValueKey('uni-page-content-viewport'),
      child: WindowsAccessibilityTooltipGuard(
        child: Material(
          type: MaterialType.transparency,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: switch (currContentView) {
              ContentView.list => _canReorder
                  ? ReorderableListView.builder(
                      scrollController: scrollController,
                      buildDefaultDragHandles: false,
                      padding: listPadding,
                      itemCount: widget.contentList.length,
                      itemExtent: 64,
                      onReorder: _handleReorder,
                      itemBuilder: (context, i) => KeyedSubtree(
                        key: ObjectKey(widget.contentList[i]),
                        child: ReorderableDelayedDragStartListener(
                          index: i,
                          child: widget.contentBuilder(
                            context,
                            widget.contentList[i],
                            i,
                            multiSelectController,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: listPadding,
                      itemCount: widget.contentList.length,
                      itemExtent: 64,
                      itemBuilder: (context, i) => widget.contentBuilder(
                        context,
                        widget.contentList[i],
                        i,
                        multiSelectController,
                      ),
                    ),
              ContentView.table => _SideNavAnimatedTableGrid(
                  controller: scrollController,
                  padding: listPadding,
                  itemCount: widget.contentList.length,
                  itemBuilder: (context, i) => widget.contentBuilder(
                    context,
                    widget.contentList[i],
                    i,
                    multiSelectController,
                  ),
                ),
              ContentView.grid => GridView.builder(
                  controller: scrollController,
                  padding: listPadding,
                  gridDelegate: coverGridDelegate,
                  itemCount: widget.contentList.length,
                  itemBuilder: (context, i) {
                    final builder = widget.gridBuilder ?? widget.contentBuilder;
                    return builder(
                      context,
                      widget.contentList[i],
                      i,
                      multiSelectController,
                    );
                  },
                ),
            },
          ),
        ),
      ),
    );

    final hasOverlayContent =
        isRightPaneActive || hasSideIndex || hasLocateButton;
    if (!hasOverlayContent) {
      return _buildPageScaffold(
        multiSelectController,
        primaryAction,
        secondaryActions,
        listBody,
      );
    }

    final rightPaneChild = widget.rightPaneBuilder?.call(context);
    final scheme = Theme.of(context).colorScheme;
    final body = Stack(
      key: const ValueKey('uni-page-overlay-layer'),
      children: [
        listBody,
        if (isRightPaneActive)
          Positioned(
            top: 8,
            bottom: 8,
            right: rightPaneRight,
            child: ClipRect(
              child: SizedBox(
                width: widget.rightPaneWidth * rightPaneProgress,
                child: IgnorePointer(
                  ignoring: !widget.showRightPane || rightPaneProgress < 0.02,
                  child: Opacity(
                    opacity: rightPaneProgress.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset((1 - rightPaneProgress) * 18.0, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: widget.rightPaneWidth,
                          child: rightPaneProgress <= 0.001
                              ? const SizedBox.shrink()
                              : rightPaneChild ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (hasSideIndex)
          Positioned(
            right: sideRailRight,
            top: 8,
            bottom: hasLocateButton ? 58 : 8,
            child: ... // 侧边字母栏构建逻辑
          ),
        if (hasLocateButton)
          Positioned(
            right: sideRailRight,
            bottom: 12,
            child: ... // 定位按钮构建逻辑
          ),
      ],
    );

    return _buildPageScaffold(
      multiSelectController,
      primaryAction,
      secondaryActions,
      body,
    );
  }
```

---

## 4. Caveats (注意事项与边界情况)

1. **半途反向切换（Interrupted Motion）**：
   - 用户在展开或收起动画进行到一半（如 `progress = 0.5`）时再次点击切换按钮。
   - 基于 `AnimationController.forward()` 与 `reverse()` 的机制，控制器会从当前的实际 `value` 逆向运行，不会发生从 0 或 1 重新开始的闪烁或阶跃。
2. **多选工具栏与模式切换联动**：
   - 多选工具栏展开时会重置或替换 `primaryAction`/`secondaryActions`，通过 `ListenableBuilder` 监听 `multiSelectController` 与 `AnimatedBuilder` 嵌套，互不干扰。
3. **无字母索引或定位按钮页面**：
   - 当页面无 `sideIndex`、无 `locateButton`，且歌词预览处于完全关闭状态（`progress == 0`）时，`hasOverlayContent` 精确返回 `false`，回退为轻量级连续视口（满足原有 `uni_page_test.dart` 连续视口测试用例）。

---

## 5. Conclusion (最终结论)

1. 歌词预览面板展开/收起的生硬跳变是由 **`Stack` 内部通过 `if (showRightPane)` 暴力卸载节点导致退出动画丢失**，以及 **`listPadding.right` 直接采用布尔判断瞬时增减 298px 引起列表文字瞬间重排抖动** 共同造成的。
2. 解决方案通过在 `_UniPageState` 中升级为由统一的 `AnimationController` + `CurvedAnimation(Curves.easeInOutCubic)` 驱动的全局双向平滑动画体系，彻底实现了：
   - 展开与收起的双向平滑过渡（宽度、透明度、X轴平移三合一）。
   - 歌曲列表右边距与右侧面板完全帧同步弹性缩放，消除所有文字排版换行跳变。
   - 侧边栏与定位按钮精准同频微调。

---

## 6. Verification Method (验证方法)

### 6.1 单元与集成测试命令
```bash
flutter test test/page/audios_page_test.dart test/page/uni_page_test.dart
```

### 6.2 建议补充的新增测试用例
在 `test/page/audios_page_test.dart` 中追加退场动画验证用例：
```dart
testWidgets('AudiosPage lyric preview executes smooth exit animation when toggled off', (
  tester,
) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final audio = TestAudio(
    title: 'Exit Test Song',
    artist: 'Artist',
    album: 'Album',
    path: r'E:\Music\exit.flac',
  );
  AudioLibrary.instance.audioCollection.add(audio);
  AppPreference.instance.audiosPagePref.showLyricPreview = true;

  await tester.pumpWidget(
    buildMediaHarness(
      playbackController: FakePlaybackController(audio: audio, queue: [audio]),
      lyricController: FakeLyricController(Lrc([], LrcSource.local)),
      desktopLyricController: FakeDesktopLyricController(),
      child: const AudiosPage(),
    ),
  );
  await tester.pumpAndSettle();

  // 初始处于打开状态
  expect(find.byKey(const ValueKey('audio-lyric-preview-panel')), findsOneWidget);

  // 点击关闭按钮
  await tester.tap(find.byKey(const ValueKey('toggle-lyric-preview')));
  
  // 推进 100ms（动画执行中）：面板仍然存在于 Widget 树中进行淡出和缩放
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const ValueKey('audio-lyric-preview-panel')), findsOneWidget);

  // 推进至动画全部完成
  await tester.pumpAndSettle();
  // 面板完全卸载
  expect(find.byKey(const ValueKey('audio-lyric-preview-panel')), findsNothing);
});
```
