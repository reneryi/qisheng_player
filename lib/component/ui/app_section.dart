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

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.62),
                fontSize: 13,
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
