import 'package:flutter/material.dart';

enum ScreenType {
  /// width < 1040
  small,

  /// 1040 <= width < 1360
  medium,

  /// width >= 1360
  large,
}

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenType screenType) builder;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    if (screenSize.width < 1040) {
      return builder(context, ScreenType.small);
    } else if (screenSize.width < 1360) {
      return builder(context, ScreenType.medium);
    } else {
      return builder(context, ScreenType.large);
    }
  }
}

class ResponsiveBuilder2 extends StatelessWidget {
  const ResponsiveBuilder2({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenType screenType) builder;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    if (screenSize.width < 1040) {
      return builder(context, ScreenType.small);
    } else {
      return builder(context, ScreenType.large);
    }
  }
}
