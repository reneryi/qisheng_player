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
        final isDark = scheme.brightness == Brightness.dark;
        final textTheme = Theme.of(context).textTheme;
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.32,
                leadingDistribution: TextLeadingDistribution.even,
              ) ?? TextStyle(
                color: scheme.onSurface,
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.32,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(
                hint!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: isDark ? 0.86 : 0.96),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.40,
                  leadingDistribution: TextLeadingDistribution.even,
                ) ?? TextStyle(
                  color: scheme.onSurface.withValues(alpha: isDark ? 0.86 : 0.96),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.40,
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
