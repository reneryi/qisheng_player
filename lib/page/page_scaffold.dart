import 'package:qisheng_player/component/responsive_builder.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.titleAction,
    this.primaryAction,
    this.secondaryActions = const [],
    required this.body,
  });

  final String title;
  final String? subtitle;
  final Widget? titleAction;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final header = switch (screenType) {
          ScreenType.small => _SmallHeader(
              title: title,
              subtitle: subtitle,
              titleAction: titleAction,
              primaryAction: primaryAction,
              secondaryActions: secondaryActions,
            ),
          ScreenType.medium || ScreenType.large => _WideHeader(
              title: title,
              subtitle: subtitle,
              titleAction: titleAction,
              primaryAction: primaryAction,
              secondaryActions: secondaryActions,
            ),
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: _HeaderHitAbsorber()),
                      header,
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.visuals.contentHeaderGap),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderHitAbsorber extends StatelessWidget {
  const _HeaderHitAbsorber();

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(child: SizedBox.expand());
  }
}

class _SmallHeader extends StatelessWidget {
  const _SmallHeader({
    required this.title,
    required this.subtitle,
    required this.titleAction,
    required this.primaryAction,
    required this.secondaryActions,
  });

  final String title;
  final String? subtitle;
  final Widget? titleAction;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (primaryAction != null) primaryAction!,
      ...secondaryActions,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          title: title,
          subtitle: subtitle,
          titleAction: titleAction,
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HorizontalActions(
            actions: actions,
            alignment: MainAxisAlignment.start,
          ),
        ],
      ],
    );
  }
}

class _WideHeader extends StatelessWidget {
  const _WideHeader({
    required this.title,
    required this.subtitle,
    required this.titleAction,
    required this.primaryAction,
    required this.secondaryActions,
  });

  final String title;
  final String? subtitle;
  final Widget? titleAction;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = [
          if (primaryAction != null) primaryAction!,
          ...secondaryActions,
        ];
        final hasActions = actions.isNotEmpty;
        final titleBlock = _TitleBlock(
          title: title,
          subtitle: subtitle,
          titleAction: titleAction,
        );

        if (!hasActions) {
          return titleBlock;
        }

        final actionRow = _HorizontalActions(
          actions: actions,
          alignment: MainAxisAlignment.end,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 18),
            Flexible(
              child: Align(
                alignment: Alignment.topRight,
                child: actionRow,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalActions extends StatelessWidget {
  const _HorizontalActions({
    required this.actions,
    required this.alignment,
  });

  final List<Widget> actions;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: alignment,
        children: List.generate(actions.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const SizedBox(width: 10);
          }
          return actions[index ~/ 2];
        }),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.titleAction,
  });

  final String title;
  final String? subtitle;
  final Widget? titleAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 31,
                  height: 1.05,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (titleAction != null) ...[
              const SizedBox(width: 12),
              titleAction!,
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.64),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
