import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/component/audio_tile.dart';
import 'package:qisheng_player/play_service/playback_service.dart';

import '../test_helpers/media_test_harness.dart';

void main() {
  testWidgets('AudioTile 更多按钮精准停靠在按钮附近而非整行左侧', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Anchor Test Track',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\anchor_track.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<PlaybackController>.value(
        value: playback,
        child: MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1000,
                child: AudioTile(
                  audioIndex: 0,
                  playlist: [audio],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 找到更多按钮并获取其坐标
    final moreButtonFinder = find.byTooltip('更多');
    expect(moreButtonFinder, findsOneWidget);
    final moreButtonRect = tester.getRect(moreButtonFinder);

    // 更多按钮位于右侧（X 坐标接近 1000）
    expect(moreButtonRect.left, greaterThan(800));

    // 点击更多按钮
    await tester.tap(moreButtonFinder);
    await tester.pumpAndSettle();

    // 验证菜单已展开
    final playItem = find.text('播放');
    expect(playItem, findsOneWidget);
    final playItemRect = tester.getRect(playItem);

    // 断言菜单 X 坐标停靠在更多按钮附近，而不是在屏幕最左侧（X=0 附近）
    expect(playItemRect.left, greaterThan(700));
  });

  testWidgets('AudioTile 右键点击在鼠标指针位置弹出上下文菜单且与更多按钮互不干扰', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio = TestAudio(
      title: 'Secondary Tap Track',
      artist: 'Artist',
      album: 'Album',
      path: r'E:\Music\secondary_track.flac',
    );
    final playback = FakePlaybackController(
      audio: audio,
      queue: [audio],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<PlaybackController>.value(
        value: playback,
        child: MaterialApp(
          theme: buildTestTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1000,
                child: AudioTile(
                  audioIndex: 0,
                  playlist: [audio],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 在条目左侧 Offset(180, 32) 处触发右键次级点击
    final tileFinder = find.byType(AudioTile);
    expect(tileFinder, findsOneWidget);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(const Offset(180, 32));
    await gesture.up();
    await tester.pumpAndSettle();

    // 验证右键菜单在鼠标附近弹出
    final playItem = find.text('播放');
    expect(playItem, findsOneWidget);
    final playItemRect = tester.getRect(playItem);

    expect(playItemRect.left, lessThan(300));
  });
}


