import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.description,
    required this.action,
    this.hint,
  });

  final String description;
  final String? hint;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final textTheme = Theme.of(context).textTheme;
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.28,
                height: 1.32,
                leadingDistribution: TextLeadingDistribution.even,
              ) ?? TextStyle(
                color: scheme.onSurface,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.28,
                height: 1.32,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(
                hint!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.18,
                  height: 1.38,
                  leadingDistribution: TextLeadingDistribution.even,
                ) ?? TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.18,
                  height: 1.38,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 12), action],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: label),
            const SizedBox(width: 16),
            Flexible(child: action),
          ],
        );
      },
    );
  }
}
