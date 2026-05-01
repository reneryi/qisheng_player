import 'dart:ui';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/page/uni_page_components.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
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
  descending;

  static SortOrder? fromString(String sortOrder) {
    if (sortOrder == 'decending') return SortOrder.descending;
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

/// `AudiosPage`, `ArtistsPage`, `AlbumsPage`, `FoldersPage`, `FolderDetailPage`
/// 鐨勯€氱敤椤甸潰瀹瑰櫒锛屾彁渚涙帓搴忋€佽鍥惧垏鎹€佸閫夊拰瀹氫綅绛夎兘鍔涖€?
class UniPage<T> extends StatefulWidget {
  const UniPage({
    super.key,
    required this.pref,
    required this.title,
    this.subtitle,
    this.titleAction,
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
    this.extraActions = const <Widget>[],
    this.rightPaneBuilder,
    this.showRightPane = false,
    this.rightPaneWidth = 296,
  });

  final PagePreference pref;

  final String title;
  final String? subtitle;
  final Widget? titleAction;

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
  final List<Widget> extraActions;
  final WidgetBuilder? rightPaneBuilder;
  final bool showRightPane;
  final double rightPaneWidth;

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
    Widget? primaryAction = widget.primaryAction;
    final secondaryActions = <Widget>[];
    if (widget.enableShufflePlay) {
      final shufflePlay = ShufflePlay<T>(contentList: widget.contentList);
      if (primaryAction == null) {
        primaryAction = shufflePlay;
      } else {
        secondaryActions.add(shufflePlay);
      }
    }
    if (widget.enableSortMethod) {
      secondaryActions.add(SortMethodComboBox<T>(
        sortMethods: widget.sortMethods!,
        contentList: widget.contentList,
        currSortMethod: currSortMethod!,
        setSortMethod: setSortMethod,
      ));
    }
    if (widget.enableSortOrder) {
      secondaryActions.add(SortOrderSwitch<T>(
        sortOrder: currSortOrder,
        setSortOrder: setSortOrder,
      ));
    }
    if (widget.enableContentViewSwitch) {
      secondaryActions.add(ContentViewSwitch<T>(
        contentView: currContentView,
        setContentView: setContentView,
      ));
    }
    secondaryActions.addAll(widget.extraActions);

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
  }

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
    final rightPaneChild = widget.rightPaneBuilder?.call(context);

    final scheme = Theme.of(context).colorScheme;
    final body = Stack(
      children: [
        listBody,
        if (hasRightPane)
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
        if (hasSideIndex)
          AnimatedPositioned(
            duration: context.motion.panelTransitionDuration,
            curve: context.motion.normal,
            right: sideRailRight,
            top: 8,
            bottom: hasLocateButton ? 58 : 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final innerHeight = (availableHeight - 12.0)
                    .clamp(0.0, double.infinity)
                    .toDouble();
                final itemHeight = sideIndexLabels.isEmpty
                    ? 0.0
                    : innerHeight / sideIndexLabels.length;
                final fontSize = (itemHeight - 2.0).clamp(6.0, 13.0);
                final tapHeight = (itemHeight - 1.0).clamp(12.0, 24.0);

                return SizedBox(
                  key: const ValueKey('uni-page-side-index'),
                  width: sideRailWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      sideIndexLabels.length,
                      (i) {
                        final label = sideIndexLabels[i];
                        final selected = label == _activeSideIndexLabel;
                        final selectedHeight = tapHeight.clamp(18.0, 24.0);
                        return Expanded(
                          child: Center(
                            child: InkWell(
                              enableFeedback: false,
                              onTap: () => _jumpBySideIndex(label),
                              borderRadius: BorderRadius.circular(
                                  context.surfaces.radiusSm),
                              child: AnimatedContainer(
                                duration:
                                    context.motion.microInteractionDuration,
                                curve: context.motion.fast,
                                width: 24,
                                height: selected ? selectedHeight : tapHeight,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? scheme.primary.withValues(alpha: 0.9)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    context.surfaces.radiusSm,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: scheme.primary
                                                .withValues(alpha: 0.28),
                                            blurRadius: 12,
                                            spreadRadius: -4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  label,
                                  strutStyle: StrutStyle(
                                    fontSize: fontSize,
                                    height: 1,
                                    forceStrutHeight: true,
                                  ),
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    height: 1,
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
                );
              },
            ),
          ),
        if (hasLocateButton)
          AnimatedPositioned(
            duration: context.motion.panelTransitionDuration,
            curve: context.motion.normal,
            right: sideRailRight,
            bottom: 12,
            child: SizedBox(
              width: sideRailWidth,
              height: sideRailWidth,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.18),
                        blurRadius: 18,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: IconButton(
                    key: const ValueKey('uni-page-locate-button'),
                    tooltip: '定位当前音乐',
                    onPressed: _jumpToLocateTarget,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    Widget? effectivePrimaryAction = primaryAction;
    List<Widget> effectiveSecondaryActions = [...secondaryActions];
    if (multiSelectController != null) {
      if (multiSelectController.enableMultiSelectView) {
        final multiSelectActions =
            widget.multiSelectViewActions ?? const <Widget>[];
        effectivePrimaryAction =
            multiSelectActions.isNotEmpty ? multiSelectActions.first : null;
        effectiveSecondaryActions = multiSelectActions.length > 1
            ? multiSelectActions.sublist(1)
            : <Widget>[];
      } else {
        effectiveSecondaryActions = [
          ...effectiveSecondaryActions,
          IconButton.filledTonal(
            tooltip: "更多",
            onPressed: () {
              multiSelectController.useMultiSelectView(true);
              multiSelectController.clear();
            },
            icon: const Icon(Icons.checklist),
          ),
        ];
      }
    }

    return PageScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      titleAction: widget.titleAction,
      primaryAction: effectivePrimaryAction,
      secondaryActions: effectiveSecondaryActions,
      body: body,
    );
  }
}
