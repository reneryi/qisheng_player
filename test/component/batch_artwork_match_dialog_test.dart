import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/batch_artwork_match_dialog.dart';
import 'package:qisheng_player/library/audio_library.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatchArtworkMatchDialog Tests', () {
    testWidgets('renders artist batch match dialog properly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final artists = [
        Artist(name: 'Jay Chou'),
        Artist(name: 'Taylor Swift'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBatchArtworkMatchDialog(
                    context,
                    kind: 'artist',
                    artists: artists,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('一键匹配歌手头像'), findsOneWidget);
      expect(find.text('共 2 位艺术家'), findsOneWidget);
      expect(find.text('严格校验标准'), findsOneWidget);
      expect(find.text('跳过已有图片的实体（推荐）'), findsOneWidget);
      expect(find.text('开始一键匹配'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // Toggle skip existing checkbox
      await tester.tap(find.text('跳过已有图片的实体（推荐）'));
      await tester.pumpAndSettle();

      // Close dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('一键匹配歌手头像'), findsNothing);
    });

    testWidgets('renders album batch match dialog properly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final albums = [
        Album(name: 'Fantasy'),
        Album(name: '1989'),
        Album(name: 'Red'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showBatchArtworkMatchDialog(
                    context,
                    kind: 'album',
                    albums: albums,
                  ),
                  child: const Text('Open Album Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Album Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('一键匹配专辑封面'), findsOneWidget);
      expect(find.text('共 3 张专辑'), findsOneWidget);
      expect(find.text('开始一键匹配'), findsOneWidget);
    });
  });
}
