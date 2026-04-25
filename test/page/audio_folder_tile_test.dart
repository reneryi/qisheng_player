import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/page/folders_page.dart';
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

Widget _buildApp(AudioFolder folder) {
  final router = GoRouter(
    initialLocation: '/folders',
    routes: [
      GoRoute(
        path: '/folders',
        builder: (context, state) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: AudioFolderTile(audioFolder: folder),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/folders/detail',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return MaterialApp.router(
    theme: _buildTheme(),
    routerConfig: router,
  );
}

void main() {
  testWidgets('AudioFolderTile keeps title and subtitle single line ellipsis', (
    tester,
  ) async {
    final folder = AudioFolder(
      [],
      r'E:\Very Long Music Library Name\Artist With Long Name\Album With Long Name',
      1,
      1,
    );

    await tester.pumpWidget(_buildApp(folder));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Album With Long Name'));
    final subtitle = tester.widget<Text>(find.text('Artist With Long Name'));

    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(subtitle.maxLines, 1);
    expect(subtitle.overflow, TextOverflow.ellipsis);
    expect(find.byTooltip(folder.path), findsOneWidget);
  });
}
