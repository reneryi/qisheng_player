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
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
              height: 1.30,
              leadingDistribution: TextLeadingDistribution.even,
            ) ?? TextStyle(
              color: scheme.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
              height: 1.30,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 5),
            Text(
              description!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.64),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.18,
                height: 1.38,
                leadingDistribution: TextLeadingDistribution.even,
              ) ?? TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.64),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.18,
                height: 1.38,
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
