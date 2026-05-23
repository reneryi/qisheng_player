import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github/github.dart';
import 'package:go_router/go_router.dart';
import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/page/settings_page/check_update.dart';
import 'package:qisheng_player/utils.dart';

Release _release({
  required String tagName,
  bool isDraft = false,
  bool isPrerelease = false,
}) =>
    Release(
      tagName: tagName,
      name: 'Qisheng Player $tagName',
      body: 'test release',
      isDraft: isDraft,
      isPrerelease: isPrerelease,
    );

GoRouter _buildRouter() => GoRouter(
      navigatorKey: ROUTER_KEY,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Text('home'),
          ),
        ),
      ],
    );

void main() {
  test('ReleaseVersion parses only stable semantic versions', () {
    expect(
      ReleaseVersion.parse('1.2.3')!.compareTo(ReleaseVersion.parse('1.2.2')!),
      greaterThan(0),
    );
    expect(
      ReleaseVersion.parse('v1.10.0')!
          .compareTo(ReleaseVersion.parse('v1.2.9')!),
      greaterThan(0),
    );
    expect(ReleaseVersion.parse('v1.2.3-beta'), isNull);
    expect(ReleaseVersion.parse('not-a-version'), isNull);
  });

  test('findLatestStableRelease ignores prereleases and unordered releases',
      () {
    final latest = findLatestStableRelease(
      [
        _release(tagName: 'v1.7.1', isPrerelease: true),
        _release(tagName: 'v1.2.1'),
        _release(tagName: 'not-a-version'),
        _release(tagName: 'v1.2.3'),
        _release(tagName: 'v1.2.4', isDraft: true),
        _release(tagName: 'v1.2.2'),
      ],
      currentVersion: '1.2.2',
    );

    expect(latest?.tagName, 'v1.2.3');
  });

  test('findLatestStableRelease returns null when current is up to date', () {
    final latest = findLatestStableRelease(
      [
        _release(tagName: 'v1.2.1'),
        _release(tagName: 'v1.2.2'),
      ],
      currentVersion: '1.2.2',
    );

    expect(latest, isNull);
  });

  testWidgets('StartupUpdatePrompt shows dialog from above router child', (
    tester,
  ) async {
    AppPreference.instance.ignoredUpdateTag = null;
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => StartupUpdatePrompt(
          checkForRelease: () async => _release(tagName: 'v9.9.9'),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Qisheng Player v9.9.9'), findsOneWidget);
    expect(find.text('获取更新'), findsOneWidget);
  });

  testWidgets('StartupUpdatePrompt retries failed startup checks', (
    tester,
  ) async {
    AppPreference.instance.ignoredUpdateTag = null;
    final router = _buildRouter();
    addTearDown(router.dispose);

    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => StartupUpdatePrompt(
          checkForRelease: () async {
            attempts += 1;
            if (attempts == 1) {
              throw Exception('temporary network failure');
            }
            return _release(tagName: 'v9.9.8');
          },
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Qisheng Player v9.9.8'), findsOneWidget);
  });

  testWidgets('StartupUpdatePrompt skips ignored tag but shows newer tag', (
    tester,
  ) async {
    AppPreference.instance.ignoredUpdateTag = 'v9.9.7';
    final ignoredRouter = _buildRouter();
    addTearDown(ignoredRouter.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: ignoredRouter,
        builder: (context, child) => StartupUpdatePrompt(
          checkForRelease: () async => _release(tagName: 'v9.9.7'),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qisheng Player v9.9.7'), findsNothing);

    AppPreference.instance.ignoredUpdateTag = 'v9.9.7';
    final newerRouter = _buildRouter();
    addTearDown(newerRouter.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: newerRouter,
        builder: (context, child) => StartupUpdatePrompt(
          key: const ValueKey('newer-update-prompt'),
          checkForRelease: () async => _release(tagName: 'v9.9.9'),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qisheng Player v9.9.9'), findsOneWidget);
  });
}
