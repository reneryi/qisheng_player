import 'package:flutter/material.dart';

enum ScreenType {
  /// width < 760
  small,

  /// 760 <= width < 1280
  medium,

  /// width >= 1280
  large,
}

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenType screenType) builder;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    if (screenSize.width < 760) {
      return builder(context, ScreenType.small);
    } else if (screenSize.width < 1280) {
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

    if (screenSize.width < 760) {
      return builder(context, ScreenType.small);
    } else {
      return builder(context, ScreenType.large);
    }
  }
}
