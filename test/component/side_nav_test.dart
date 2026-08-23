import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/component/side_nav.dart';
import 'package:qisheng_player/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

ThemeData _buildTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF53A4FF),
    brightness: Brightness.dark,
  );
  return AppTheme.build(
    colorScheme: AppTheme.applyChromeSurfaces(baseScheme),
  );
}

Widget _buildApp({
  required bool collapsed,
  required String initialLocation,
  double? expansionProgress,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: initialLocation,
        builder: (context, state) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SideNav(
              collapsed: collapsed,
              expansionProgress: expansionProgress,
              onToggleCollapsed: (_) {},
            ),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    theme: _buildTheme(),
    routerConfig: router,
  );
}

void main() {
  testWidgets('SideNav expanded width is 160 with active indicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildApp(
        collapsed: false,
        initialLocation: app_paths.AUDIOS_PAGE,
      ),
    );
    await tester.pumpAndSettle();

    // 极简主义测试：验证一体化侧边栏的扩展宽度为 160，且极细指示条为 3x18
    expect(
      tester.getSize(find.byKey(const ValueKey('side-nav-large'))).width,
      160,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('音乐'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('side-nav-active-indicator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('side-nav-active-indicator')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('side-nav-active-indicator'))),
      const Size(3, 18),
    );
  });

  testWidgets('SideNav collapsed width is 76 and keeps tooltip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildApp(
        collapsed: true,
        initialLocation: app_paths.AUDIOS_PAGE,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('side-nav-large'))).width,
      76,
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('音乐'), findsOneWidget);
  });

  testWidgets('SideNav keeps destination icons fixed during expansion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Map<String, Offset>> pumpAt(double progress) async {
      await tester.pumpWidget(
        _buildApp(
          collapsed: progress == 0,
          expansionProgress: progress,
          initialLocation: app_paths.AUDIOS_PAGE,
        ),
      );
      await tester.pumpAndSettle();
      return {
        for (final destination in destinations)
          destination.desPath: tester.getCenter(
            find.byKey(
              ValueKey('side-nav-icon-${destination.desPath}'),
            ),
          ),
      };
    }

    final collapsedPositions = await pumpAt(0);
    final halfwayPositions = await pumpAt(0.5);
    final expandedPositions = await pumpAt(1);

    for (final destination in destinations) {
      final key = destination.desPath;
      expect(halfwayPositions[key]!.dx,
          closeTo(collapsedPositions[key]!.dx, 0.01));
      expect(halfwayPositions[key]!.dy,
          closeTo(collapsedPositions[key]!.dy, 0.01));
      expect(expandedPositions[key]!.dx,
          closeTo(collapsedPositions[key]!.dx, 0.01));
      expect(expandedPositions[key]!.dy,
          closeTo(collapsedPositions[key]!.dy, 0.01));
    }

    await pumpAt(0);
    final collapsedOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('side-nav-label-${app_paths.AUDIOS_PAGE}')),
    );
    await pumpAt(0.5);
    final halfwayOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('side-nav-label-${app_paths.AUDIOS_PAGE}')),
    );
    await pumpAt(1);
    final expandedOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('side-nav-label-${app_paths.AUDIOS_PAGE}')),
    );

    expect(collapsedOpacity.opacity, 0);
    expect(halfwayOpacity.opacity, closeTo(0.5, 0.01));
    expect(expandedOpacity.opacity, 1);
    expect(tester.takeException(), isNull);
  });
}
