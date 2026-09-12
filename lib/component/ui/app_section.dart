import 'package:flutter/material.dart';

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final separatorColor = scheme.outlineVariant.withValues(alpha: 0.62);

    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.30,
              leadingDistribution: TextLeadingDistribution.even,
            ) ?? TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.30,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 5),
            Text(
              description!,
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
          const SizedBox(height: 14),
          Divider(height: 1, color: separatorColor),
          for (var index = 0; index < children.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: children[index],
            ),
            if (index != children.length - 1)
              Divider(height: 1, color: separatorColor),
          ],
        ],
      ),
    );
  }
}
