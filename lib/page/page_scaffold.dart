import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/ui/app_surface.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryAction,
    this.secondaryActions = const [],
    required this.body,
  });

  final String title;
  final String? subtitle;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSurface(
                variant: AppSurfaceVariant.inset,
                radius: context.surfaces.radiusXl,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: switch (screenType) {
                  ScreenType.small => _SmallHeader(
                      title: title,
                      subtitle: subtitle,
                      primaryAction: primaryAction,
                      secondaryActions: secondaryActions,
                    ),
                  ScreenType.medium || ScreenType.large => _WideHeader(
                      title: title,
                      subtitle: subtitle,
                      primaryAction: primaryAction,
                      secondaryActions: secondaryActions,
                    ),
                },
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

class _SmallHeader extends StatelessWidget {
  const _SmallHeader({
    required this.title,
    required this.subtitle,
    required this.primaryAction,
    required this.secondaryActions,
  });

  final String title;
  final String? subtitle;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(title: title, subtitle: subtitle),
        if (primaryAction != null || secondaryActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (primaryAction != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: primaryAction!,
              ),
            ),
          if (secondaryActions.isNotEmpty)
            _HorizontalActions(
              actions: secondaryActions,
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
    required this.primaryAction,
    required this.secondaryActions,
  });

  final String title;
  final String? subtitle;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasActions = primaryAction != null || secondaryActions.isNotEmpty;
        final compact = constraints.maxWidth < 1120;

        if (!hasActions) {
          return _TitleBlock(title: title, subtitle: subtitle);
        }

        final actions = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? constraints.maxWidth : 640,
          ),
          child: Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              if (primaryAction != null)
                Align(
                  alignment:
                      compact ? Alignment.centerLeft : Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: primaryAction!,
                  ),
                ),
              if (secondaryActions.isNotEmpty) ...[
                if (primaryAction != null) const SizedBox(height: 10),
                _HorizontalActions(
                  actions: secondaryActions,
                  alignment:
                      compact ? MainAxisAlignment.start : MainAxisAlignment.end,
                ),
              ],
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TitleBlock(title: title, subtitle: subtitle),
              const SizedBox(height: 14),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _TitleBlock(title: title, subtitle: subtitle),
              ),
            ),
            const SizedBox(width: 18),
            Flexible(child: actions),
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
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 32,
            height: 1.05,
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
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
