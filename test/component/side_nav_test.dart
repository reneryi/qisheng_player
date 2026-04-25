import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/component/side_nav.dart';
import 'package:coriander_player/theme/app_theme.dart';
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
  testWidgets('SideNav expanded width is 240 with active indicator', (
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

    expect(
      tester.getSize(find.byKey(const ValueKey('side-nav-large'))).width,
      240,
    );
    expect(find.text('音乐'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('side-nav-active-indicator')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('side-nav-active-indicator'))),
      const Size(4, 24),
    );
  });

  testWidgets('SideNav collapsed width is 80 and keeps tooltip', (
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
      80,
    );
    expect(find.byTooltip('音乐'), findsOneWidget);
  });
}
