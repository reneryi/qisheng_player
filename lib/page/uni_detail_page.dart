import 'dart:ui';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/navigation_state.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class UniDetailPage<P, S, T> extends StatefulWidget {
  const UniDetailPage({
    super.key,
    required this.pref,
    required this.primaryContent,
    required this.primaryPic,
    required this.backgroundPic,
    required this.picShape,
    required this.title,
    required this.subtitle,
    required this.secondaryContent,
    this.secondaryContentRevision,
    required this.secondaryContentBuilder,
    required this.tertiaryContentTitle,
    required this.tertiaryContent,
    required this.tertiaryContentBuilder,
    required this.enableShufflePlay,
    required this.enableSortMethod,
    required this.enableSortOrder,
    required this.enableSecondaryContentViewSwitch,
    this.sortMethods,
    this.multiSelectController,
    this.multiSelectViewActions,
    this.primaryPicHeroTag,
    this.artworkActions = const [],
    this.headerBadges = const [],
    this.onPlayAll,
    this.onShufflePlay,
  });

  final List<Widget> artworkActions;
  final PagePreference pref;
  final P primaryContent;
  final Future<ImageProvider?> primaryPic;
  final String? primaryPicHeroTag;
  final Future<ImageProvider?> backgroundPic;
  final PicShape picShape;
  final String title;
  final String subtitle;
  final List<S> secondaryContent;
  final Object? secondaryContentRevision;
  final ContentBuilder<S> secondaryContentBuilder;
  final String tertiaryContentTitle;
  final List<T> tertiaryContent;
  final ContentBuilder<T> tertiaryContentBuilder;
  final bool enableShufflePlay;
  final bool enableSortMethod;
  final bool enableSortOrder;
  final bool enableSecondaryContentViewSwitch;
  final List<SortMethodDesc<S>>? sortMethods;
  final MultiSelectController<S>? multiSelectController;
  final List<Widget>? multiSelectViewActions;
  final List<String> headerBadges;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShufflePlay;

  @override
  State<UniDetailPage<P, S, T>> createState() => _UniDetailPageState<P, S, T>();
}

class _UniDetailPageState<P, S, T> extends State<UniDetailPage<P, S, T>> {
  late SortMethodDesc<S>? currSortMethod =
      widget.sortMethods?[widget.pref.sortMethod];
  late SortOrder currSortOrder = widget.pref.sortOrder;
  late ContentView currContentView = widget.pref.contentView;
  late List<S> _sortedContentSnapshot;

  @override
  void initState() {
    super.initState();
    _sortContent();
  }

  @override
  void didUpdateWidget(covariant UniDetailPage<P, S, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final canRestorePreviousOrder = widget.secondaryContentRevision != null &&
        widget.secondaryContentRevision == oldWidget.secondaryContentRevision &&
        restorePreviousContentOrder(
          widget.secondaryContent,
          _sortedContentSnapshot,
        );
    if (!canRestorePreviousOrder) {
      _sortContent();
    }
  }

  void _sortContent() {
    currSortMethod?.method(widget.secondaryContent, currSortOrder);
    _sortedContentSnapshot = List<S>.from(widget.secondaryContent);
  }

  void setSortMethod(SortMethodDesc<S> sortMethod) {
    setState(() {
      currSortMethod = sortMethod;
      widget.pref.sortMethod = widget.sortMethods?.indexOf(sortMethod) ?? 0;
      _sortContent();
    });
  }

  void setSortOrder(SortOrder sortOrder) {
    setState(() {
      currSortOrder = sortOrder;
      widget.pref.sortOrder = sortOrder;
      _sortContent();
    });
  }

  void setContentView(ContentView contentView) {
    setState(() {
      currContentView = contentView;
      widget.pref.contentView = contentView;
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (widget.enableShufflePlay) {
      actions.add(ShufflePlay<S>(contentList: widget.secondaryContent));
    }
    if (widget.enableSortMethod) {
      actions.add(
        SortMethodComboBox<S>(
          sortMethods: widget.sortMethods!,
          contentList: widget.secondaryContent,
          currSortMethod: currSortMethod!,
          setSortMethod: setSortMethod,
        ),
      );
    }
    if (widget.enableSortOrder) {
      actions.add(
        SortOrderSwitch<S>(
          sortOrder: currSortOrder,
          setSortOrder: setSortOrder,
        ),
      );
    }
    if (widget.enableSecondaryContentViewSwitch) {
      actions.add(
        ContentViewSwitch<S>(
          contentView: currContentView,
          setContentView: setContentView,
        ),
      );
    }

    return widget.multiSelectController == null
        ? _buildPage(context, null, actions)
        : ListenableBuilder(
            listenable: widget.multiSelectController!,
            builder: (context, _) => _buildPage(
              context,
              widget.multiSelectController!,
              actions,
            ),
          );
  }

  Widget _buildPage(
    BuildContext context,
    MultiSelectController<S>? multiSelectController,
    List<Widget> actions,
  ) {
    Widget? primaryAction;
    var secondaryActions = <Widget>[...widget.artworkActions, ...actions];
    if (multiSelectController != null) {
      if (multiSelectController.enableMultiSelectView) {
        final multiSelectActions =
            widget.multiSelectViewActions ?? const <Widget>[];
        primaryAction =
            multiSelectActions.isNotEmpty ? multiSelectActions.first : null;
        secondaryActions = multiSelectActions.length > 1
            ? multiSelectActions.sublist(1)
            : <Widget>[];
      } else {
        secondaryActions = [
          ...secondaryActions,
          IconButton.filledTonal(
            tooltip: '更多',
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
      primaryAction: primaryAction,
      secondaryActions: secondaryActions,
      body: Column(
        children: [
          CpSurface(
            key: const ValueKey('uni-detail-hero-surface'),
            tone: CpSurfaceTone.floating,
            child: _UniDetailPageHeader(
              pic: widget.primaryPic,
              backgroundPic: widget.backgroundPic,
              picShape: widget.picShape,
              heroTag: widget.primaryPicHeroTag,
              title: widget.title,
              subtitle: widget.subtitle,
              badges: widget.headerBadges,
              onPlayAll: widget.onPlayAll,
              onShufflePlay: widget.onShufflePlay,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CpSurface(
              key: const ValueKey('uni-detail-content-surface'),
              tone: CpSurfaceTone.panel,
              padding: const EdgeInsets.all(12),
              child: Material(
                type: MaterialType.transparency,
                child: CustomScrollView(
                  slivers: [
                    switch (currContentView) {
                      ContentView.list => SliverFixedExtentList.builder(
                          itemExtent: 64,
                          itemCount: widget.secondaryContent.length,
                          itemBuilder: (context, i) =>
                              widget.secondaryContentBuilder(
                            context,
                            widget.secondaryContent[i],
                            i,
                            multiSelectController,
                          ),
                        ),
                      ContentView.table => SliverGrid.builder(
                          gridDelegate: gridDelegate,
                          itemCount: widget.secondaryContent.length,
                          itemBuilder: (context, i) =>
                              widget.secondaryContentBuilder(
                            context,
                            widget.secondaryContent[i],
                            i,
                            multiSelectController,
                          ),
                        ),
                      ContentView.grid => SliverGrid.builder(
                          gridDelegate: gridDelegate,
                          itemCount: widget.secondaryContent.length,
                          itemBuilder: (context, i) =>
                              widget.secondaryContentBuilder(
                            context,
                            widget.secondaryContent[i],
                            i,
                            multiSelectController,
                          ),
                        ),
                    },
                    if (widget.tertiaryContent.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
                          child: Row(
                            children: [
                              Text(
                                widget.tertiaryContentTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${widget.tertiaryContent.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisExtent: 64,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: widget.tertiaryContent.length,
                        itemBuilder: (context, i) =>
                            widget.tertiaryContentBuilder(
                          context,
                          widget.tertiaryContent[i],
                          i,
                          null,
                        ),
                      ),
                    ],
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 32),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum PicShape { oval, rrect }

class _UniDetailPageHeader extends StatelessWidget {
  const _UniDetailPageHeader({
    required this.pic,
    required this.backgroundPic,
    required this.picShape,
    this.heroTag,
    required this.title,
    required this.subtitle,
    this.badges = const [],
    this.onPlayAll,
    this.onShufflePlay,
  });

  final Future<ImageProvider?> pic;
  final Future<ImageProvider?> backgroundPic;
  final PicShape picShape;
  final String? heroTag;
  final String title;
  final String subtitle;
  final List<String> badges;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShufflePlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 统一的底层通透磨砂底色，保持恒定色调与质感
          DecoratedBox(
            key: const ValueKey('header-base-tint'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: isDark ? 0.16 : 0.12),
                  scheme.surfaceContainerHighest
                      .withValues(alpha: isDark ? 0.55 : 0.65),
                ],
              ),
            ),
          ),
          // 封面图片以单层图像级高斯模糊（ImageFiltered）平滑淡入，彻底消除外层 BackdropFilter 引起的二次模糊突变
          FutureBuilder<ImageProvider?>(
            future: backgroundPic,
            builder: (context, snapshot) {
              final image = snapshot.data;
              if (image == null) return const SizedBox.expand();

              return TweenAnimationBuilder<double>(
                key: ValueKey(image),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, opacity, _) {
                  return Opacity(
                    opacity: opacity,
                    child: RepaintBoundary(
                      child: ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
                          child: Transform.scale(
                            scale: 1.25,
                            child: Image(
                              image: image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // 统一的前景暗度与对比度遮罩
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
                  scheme.surface.withValues(alpha: isDark ? 0.42 : 0.25),
                ],
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final artworkSize = compact ? 104.0 : 136.0;
              final artwork = _HeaderArtwork(
                pic: pic,
                picShape: picShape,
                heroTag: heroTag,
                size: artworkSize,
              );

              final badgePills = badges.isEmpty
                  ? null
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment:
                          compact ? WrapAlignment.center : WrapAlignment.start,
                      children: [
                        for (final badge in badges)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.09)
                                  : Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.88),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    );

              final textBlock = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: compact ? 22 : 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.78),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (badgePills != null) ...[
                    const SizedBox(height: 12),
                    badgePills,
                  ],
                ],
              );

              final hasQuickActions =
                  !compact && (onPlayAll != null || onShufflePlay != null);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: compact
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          artwork,
                          const SizedBox(height: 14),
                          Expanded(child: textBlock),
                        ],
                      )
                    : Row(
                        children: [
                          artwork,
                          const SizedBox(width: 24),
                          Expanded(child: textBlock),
                          if (hasQuickActions) ...[
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (onPlayAll != null)
                                      FilledButton.icon(
                                        key: const ValueKey(
                                            'uni-detail-play-all-btn'),
                                        onPressed: onPlayAll,
                                        icon: const Icon(
                                          Symbols.play_arrow_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('播放全部'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    if (onPlayAll != null &&
                                        onShufflePlay != null)
                                      const SizedBox(width: 10),
                                    if (onShufflePlay != null)
                                      FilledButton.tonalIcon(
                                        key: const ValueKey(
                                            'uni-detail-shuffle-btn'),
                                        onPressed: onShufflePlay,
                                        icon: const Icon(
                                          Symbols.shuffle_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('随机播放'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderArtwork extends StatelessWidget {
  const _HeaderArtwork({
    required this.pic,
    required this.picShape,
    required this.heroTag,
    required this.size,
  });

  final Future<ImageProvider?> pic;
  final PicShape picShape;
  final String? heroTag;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius =
        BorderRadius.circular(picShape == PicShape.oval ? size / 2 : 22);

    return FutureBuilder<ImageProvider?>(
      future: pic,
      builder: (context, snapshot) {
        final placeholder = Container(
          key: const ValueKey('artwork-placeholder'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          alignment: Alignment.center,
          child: Icon(
            picShape == PicShape.oval ? Symbols.person : Symbols.album,
            size: size * 0.42,
            color: scheme.onSurface.withValues(alpha: 0.35),
          ),
        );

        final imageProvider = snapshot.data;
        Widget artworkWidget;
        if (imageProvider == null) {
          artworkWidget = placeholder;
        } else {
          artworkWidget = switch (picShape) {
            PicShape.oval => ClipOval(
                key: ValueKey(imageProvider),
                child: Image(
                  image: imageProvider,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
              ),
            PicShape.rrect => ClipRRect(
                key: ValueKey(imageProvider),
                borderRadius: borderRadius,
                child: Image(
                  image: imageProvider,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder,
                ),
              ),
          };
        }

        final tag = heroTag;
        if (tag == null) return artworkWidget;

        return ValueListenableBuilder<ArtworkHeroTransition?>(
          valueListenable:
              AppNavigationState.instance.artworkHeroTransition,
          child: artworkWidget,
          builder: (context, _, child) {
            final navigation = AppNavigationState.instance;
            if (!navigation.canBuildArtworkHero(tag: tag)) {
              return child!;
            }
            return Hero(
              tag: tag,
              transitionOnUserGestures: true,
              flightShuttleBuilder: (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) {
                final toHero = toHeroContext.widget as Hero;
                return Material(
                  type: MaterialType.transparency,
                  child: toHero.child,
                );
              },
              child: child!,
            );
          },
        );
      },
    );
  }
}
