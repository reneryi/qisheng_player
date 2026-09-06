import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/page/search_page/search_page.dart';
import 'package:qisheng_player/page/search_page/search_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test_helpers/media_test_harness.dart';

GoRouter buildSearchRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: app_paths.SEARCH_PAGE,
        builder: (context, state) => const Scaffold(body: SearchPage()),
        routes: [
          GoRoute(
            path: 'result',
            redirect: (context, state) {
              final query = state.uri.queryParameters['q']?.trim() ?? '';
              return query.isEmpty ? app_paths.SEARCH_PAGE : null;
            },
            pageBuilder: (context, state) {
              final query = state.uri.queryParameters['q']!.trim();
              final extraResult = state.extra;
              final result =
                  extraResult is UnionSearchResult && extraResult.query == query
                      ? extraResult
                      : UnionSearchResult.search(query);
              return MaterialPage<void>(
                child: Scaffold(
                  body: SearchResultPage(
                    initialQuery: query,
                    initialResult: result,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('search result route restores from query parameter',
      (tester) async {
    final router = buildSearchRouter(
      initialLocation: app_paths.buildSearchResultLocation('luhan'),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildTestTheme(),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchResultPage), findsOneWidget);
    expect(find.text('luhan'), findsAtLeastNWidgets(1));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('search result route redirects to search page when q is missing',
      (tester) async {
    final router = buildSearchRouter(
      initialLocation: app_paths.SEARCH_RESULT_PAGE,
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildTestTheme(),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byType(SearchResultPage), findsNothing);
  });
}
