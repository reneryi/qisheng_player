import 'dart:ui';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/page/uni_page_components.dart';
import 'package:coriander_player/page/page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ContentBuilder<T> = Widget Function(BuildContext context, T item,
    int index, MultiSelectController<T>? multiSelectController);

typedef SortMethod<T> = void Function(List<T> list, SortOrder order);
typedef ReorderCallback<T> = void Function(
    List<T> list, int oldIndex, int newIndex);
typedef ReorderEnabled<T> = bool Function(SortMethodDesc<T>? currSortMethod);
typedef SideIndexResolver<T> = int? Function(List<T> list, String label);
typedef LocateIndexResolver<T> = int? Function(List<T> list);

class SortMethodDesc<T> {
  IconData icon;
  String name;
  SortMethod<T> method;

  SortMethodDesc({
    required this.icon,
    required this.name,
    required this.method,
  });
}

enum SortOrder {
  ascending,
  decending;

  static SortOrder? fromString(String sortOrder) {
    for (var value in SortOrder.values) {
      if (value.name == sortOrder) return value;
    }
    return null;
  }
}

enum ContentView {
  list,
  table;

  static ContentView? fromString(String contentView) {
    for (var value in ContentView.values) {
      if (value.name == contentView) return value;
    }
    return null;
  }
}

const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 300,
  mainAxisExtent: 64,
  mainAxisSpacing: 8.0,
  crossAxisSpacing: 8.0,
);

class MultiSelectController<T> extends ChangeNotifier {
  final Set<T> selected = {};
  bool enableMultiSelectView = false;
  int? _lastSelectedIndex;

  static bool isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  void useMultiSelectView(bool multiSelectView) {
    enableMultiSelectView = multiSelectView;
    if (!multiSelectView) {
      _lastSelectedIndex = null;
    }
    notifyListeners();
  }

  void select(T item) {
    selected.add(item);
    notifyListeners();
  }

  void unselect(T item) {
    selected.remove(item);
    notifyListeners();
  }

  void clear() {
    selected.clear();
    notifyListeners();
  }

  void selectAll(Iterable<T> items) {
    selected.addAll(items);
    _lastSelectedIndex = null;
    notifyListeners();
  }

  void toggleSelectionWithIndex({
    required int index,
    required T item,
    required List<T> items,
    required bool shiftPressed,
  }) {
    if (shiftPressed && _lastSelectedIndex != null && items.isNotEmpty) {
      final start = _lastSelectedIndex!;
      final from = start < index ? start : index;
      final to = start < index ? index : start;
      for (int i = from; i <= to && i < items.length; i++) {
        selected.add(items[i]);
      }
      _lastSelectedIndex = index;
      notifyListeners();
      return;
    }

    if (selected.contains(item)) {
      selected.remove(item);
    } else {
      selected.add(item);
    }
    _lastSelectedIndex = index;
    notifyListeners();
  }
}

/// `AudiosPage`, `ArtistsPage`, `AlbumsPage`, `FoldersPage`, `FolderDetailPage` 页面的主要组件，
/// 提供随机播放以及更改排序方式、排序顺序、内容视图的支持。
///
/// `enableShufflePlay` 只能在 `T` 是 `Audio` 时为 `ture`
///
/// `enableSortMethod` 为 `true` 时，`sortMethods` 不可为空且必须包含一个 `SortMethodDesc`
///
/// `defaultContentView` 表示默认的内容视图。如果设置为 `ContentView.list`，就以单行列表视图展示内容；
/// 如果是 `ContentView.table`，就以最大 300 * 64 的子组件以 8 为间距组成的表格展示内容。
///
/// `multiSelectController` 可以使页面进入多选状态。如果它不为空，则 `multiSelectViewActions` 也不可为空
class UniPage<T> extends StatefulWidget {
  const UniPage({
    super.key,
    required this.pref,
    required this.title,
    this.subtitle,
    required this.contentList,
    required this.contentBuilder,
    this.primaryAction,
    required this.enableShufflePlay,
    required this.enableSortMethod,
    required this.enableSortOrder,
    required this.enableContentViewSwitch,
    this.sortMethods,
    this.locateTo,
    this.multiSelectController,
    this.multiSelectViewActions,
    this.onReorder,
    this.enableReorder,
    this.sideIndexLabels,
    this.sideIndexResolver,
    this.locateIndexResolver,
  });

  final PagePreference pref;

  final String title;
  final String? subtitle;

  final List<T> contentList;
  final ContentBuilder<T> contentBuilder;

  final Widget? primaryAction;

  final bool enableShufflePlay;
  final bool enableSortMethod;
  final bool enableSortOrder;
  final bool enableContentViewSwitch;

  final List<SortMethodDesc<T>>? sortMethods;

  final T? locateTo;

  final MultiSelectController<T>? multiSelectController;
  final List<Widget>? multiSelectViewActions;
  final ReorderCallback<T>? onReorder;
  final ReorderEnabled<T>? enableReorder;
  final List<String>? sideIndexLabels;
  final SideIndexResolver<T>? sideIndexResolver;
  final LocateIndexResolver<T>? locateIndexResolver;

  @override
  State<UniPage<T>> createState() => _UniPageState<T>();
}

class _UniPageState<T> extends State<UniPage<T>> {
  late SortMethodDesc<T>? currSortMethod =
      widget.sortMethods?[widget.pref.sortMethod];
  late SortOrder currSortOrder = widget.pref.sortOrder;
  late ContentView currContentView = widget.pref.contentView;
  late ScrollController scrollController = ScrollController();
  String? _activeSideIndexLabel;

  @override
  void initState() {
    super.initState();
    currSortMethod?.method(widget.contentList, currSortOrder);
    if (widget.locateTo == null) return;

    int targetAt = widget.contentList.indexOf(widget.locateTo as T);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currContentView == ContentView.list) {
        scrollController.jumpTo(targetAt * 64);
      } else {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox) {
          final ratio =
              PlatformDispatcher.instance.views.first.devicePixelRatio;
          final width = renderObject.size.width - 32;
          final crossAxisCount = (width * ratio / 300).floor();
          final offset = (targetAt ~/ crossAxisCount) * (64.0 + 8.0);
          scrollController.jumpTo(offset);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant UniPage<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    currSortMethod?.method(widget.contentList, currSortOrder);
  }

  void setSortMethod(SortMethodDesc<T> sortMethod) {
    setState(() {
      currSortMethod = sortMethod;
      widget.pref.sortMethod = widget.sortMethods?.indexOf(sortMethod) ?? 0;
      currSortMethod?.method(widget.contentList, currSortOrder);
    });
  }

  void setSortOrder(SortOrder sortOrder) {
    setState(() {
      currSortOrder = sortOrder;
      widget.pref.sortOrder = sortOrder;
      currSortMethod?.method(widget.contentList, currSortOrder);
    });
  }

  void setContentView(ContentView contentView) {
    setState(() {
      currContentView = contentView;
      widget.pref.contentView = contentView;
    });
  }

  bool get _canReorder =>
      widget.onReorder != null &&
      (widget.enableReorder?.call(currSortMethod) ?? true);

  void _handleReorder(int oldIndex, int newIndex) {
    if (widget.onReorder == null) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;
    setState(() {
      widget.onReorder!(widget.contentList, oldIndex, newIndex);
    });
  }

  void _jumpToListIndex(int index) {
    if (index < 0 || index >= widget.contentList.length) return;
    if (!scrollController.hasClients) return;
    if (currContentView == ContentView.list) {
      scrollController.animateTo(
        index * 64.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final ratio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final width = renderObject.size.width - 32;
    final crossAxisCount = (width * ratio / 300).floor().clamp(1, 999);
    final targetOffset = (index ~/ crossAxisCount) * (64.0 + 8.0);
    scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpBySideIndex(String label) {
    setState(() {
      _activeSideIndexLabel = label;
    });
    final resolver = widget.sideIndexResolver;
    if (resolver == null) return;
    final target = resolver(widget.contentList, label);
    if (target == null) return;
    _jumpToListIndex(target);
  }

  void _jumpToLocateTarget() {
    final locateIndexResolver = widget.locateIndexResolver;
    if (locateIndexResolver != null) {
      final target = locateIndexResolver(widget.contentList);
      if (target == null || target < 0) return;
      _jumpToListIndex(target);
      return;
    }
    final locateTo = widget.locateTo;
    if (locateTo == null) return;
    final target = widget.contentList.indexOf(locateTo);
    if (target < 0) return;
    _jumpToListIndex(target);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];
    if (widget.primaryAction != null) {
      actions.add(widget.primaryAction!);
    }
    if (widget.enableShufflePlay) {
      actions.add(ShufflePlay<T>(contentList: widget.contentList));
    }
    if (widget.enableSortMethod) {
      actions.add(SortMethodComboBox<T>(
        sortMethods: widget.sortMethods!,
        contentList: widget.contentList,
        currSortMethod: currSortMethod!,
        setSortMethod: setSortMethod,
      ));
    }
    if (widget.enableSortOrder) {
      actions.add(SortOrderSwitch<T>(
        sortOrder: currSortOrder,
        setSortOrder: setSortOrder,
      ));
    }
    if (widget.enableContentViewSwitch) {
      actions.add(ContentViewSwitch<T>(
        contentView: currContentView,
        setContentView: setContentView,
      ));
    }

    return widget.multiSelectController == null
        ? result(null, actions)
        : ListenableBuilder(
            listenable: widget.multiSelectController!,
            builder: (context, _) => result(
              widget.multiSelectController!,
              actions,
            ),
          );
  }

  Widget result(
      MultiSelectController<T>? multiSelectController, List<Widget> actions) {
    final sideIndex = widget.sideIndexLabels;
    final hasSideIndex = sideIndex != null && sideIndex.isNotEmpty;
    final sideIndexLabels = sideIndex ?? const <String>[];
    final hasLocateButton =
        widget.locateTo != null || widget.locateIndexResolver != null;
    final rightReserved = (hasSideIndex || hasLocateButton) ? 64.0 : 0.0;
    final listPadding = EdgeInsets.fromLTRB(0, 0, rightReserved, 132.0);

    final listBody = Material(
      type: MaterialType.transparency,
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
        ContentView.table => GridView.builder(
            controller: scrollController,
            padding: listPadding,
            gridDelegate: gridDelegate,
            itemCount: widget.contentList.length,
            itemBuilder: (context, i) => widget.contentBuilder(
              context,
              widget.contentList[i],
              i,
              multiSelectController,
            ),
          ),
      },
    );

    final scheme = Theme.of(context).colorScheme;
    final body = Stack(
      children: [
        listBody,
        if (hasSideIndex)
          Positioned(
            right: 4,
            top: 12,
            bottom: hasLocateButton ? 72 : 12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final itemHeight =
                    ((availableHeight - 12.0) / sideIndexLabels.length)
                        .clamp(12.0, 20.0)
                        .toDouble();
                final fontSize = (itemHeight - 5.0).clamp(10.0, 13.0);

                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        sideIndexLabels.length,
                        (i) {
                          final label = sideIndexLabels[i];
                          final selected = label == _activeSideIndexLabel;
                          return SizedBox(
                            width: 26,
                            height: itemHeight,
                            child: InkWell(
                              onTap: () => _jumpBySideIndex(label),
                              borderRadius: BorderRadius.circular(9),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? scheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: selected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
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
                );
              },
            ),
          ),
        if (hasLocateButton)
          Positioned(
            right: 4,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: "定位当前音乐",
              onPressed: _jumpToLocateTarget,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
      ],
    );

    return PageScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: multiSelectController == null
          ? actions
          : multiSelectController.enableMultiSelectView
              ? widget.multiSelectViewActions!
              : [
                  ...actions,
                  IconButton.filledTonal(
                    tooltip: "多选",
                    onPressed: () {
                      multiSelectController.useMultiSelectView(true);
                      multiSelectController.clear();
                    },
                    icon: const Icon(Icons.checklist),
                  ),
                ],
      body: body,
    );
  }
}
