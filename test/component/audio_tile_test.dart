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

  testWidgets('右键展开后点击更多按钮，前一状态自动消失，全局始终仅保留当前触发的一个菜单', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final audio1 = TestAudio(
      title: 'Track 1',
      artist: 'Artist 1',
      album: 'Album 1',
      path: r'E:\Music\track1.flac',
    );
    final audio2 = TestAudio(
      title: 'Track 2',
      artist: 'Artist 2',
      album: 'Album 2',
      path: r'E:\Music\track2.flac',
    );
    final playback = FakePlaybackController(
      audio: audio1,
      queue: [audio1, audio2],
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
                child: Column(
                  children: [
                    AudioTile(audioIndex: 0, playlist: [audio1, audio2]),
                    AudioTile(audioIndex: 1, playlist: [audio1, audio2]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 在 Track 1 处右键展开上下文菜单
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(const Offset(180, 32));
    await gesture.up();
    await tester.pumpAndSettle();

    // 验证此时存在菜单且仅有1个“播放”按钮
    expect(find.text('播放'), findsOneWidget);
    final playRect1 = tester.getRect(find.text('播放'));
    expect(playRect1.left, lessThan(300));

    // 2. 点击 Track 1 的“更多”按钮
    final moreButtons = find.byTooltip('更多');
    expect(moreButtons, findsNWidgets(2));
    await tester.tap(moreButtons.first);
    await tester.pumpAndSettle();

    // 验证前一右键菜单已消失，且当前仅保留1个菜单（停靠在右侧）
    expect(find.text('播放'), findsOneWidget);
    final playRect2 = tester.getRect(find.text('播放'));
    expect(playRect2.left, greaterThan(700));

    // 3. 在 Track 2 处右键点击
    await gesture.down(const Offset(220, 100));
    await gesture.up();
    await tester.pumpAndSettle();

    // 验证 Track 1 的“更多”菜单自动关闭，仅保留 Track 2 的右键菜单（停靠在左侧）
    expect(find.text('播放'), findsOneWidget);
    final playRect3 = tester.getRect(find.text('播放'));
    expect(playRect3.left, lessThan(300));

    // 4. 点击 Track 2 的“更多”按钮
    await tester.tap(moreButtons.last);
    await tester.pumpAndSettle();

    // 验证 Track 2 的右键菜单自动关闭，仅保留 Track 2 的“更多”菜单（停靠在右侧）
    expect(find.text('播放'), findsOneWidget);
    final playRect4 = tester.getRect(find.text('播放'));
    expect(playRect4.left, greaterThan(700));

    // 5. 再次点击 Track 2 的“更多”按钮，验证菜单正常关闭（Toggle 收起）
    await tester.tap(moreButtons.last);
    await tester.pumpAndSettle();
    expect(find.text('播放'), findsNothing);

    // 6. 再次点击 Track 1 的“更多”按钮展开，然后直接右键 Track 1，验证“更多”菜单关闭且右键菜单于光标处打开
    await tester.tap(moreButtons.first);
    await tester.pumpAndSettle();
    expect(find.text('播放'), findsOneWidget);
    expect(tester.getRect(find.text('播放')).left, greaterThan(700));

    await gesture.down(const Offset(200, 32));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('播放'), findsOneWidget);
    expect(tester.getRect(find.text('播放')).left, lessThan(300));

    // 7. 左键单击条目任意位置，验证菜单安全收起且不会错误触发播放
    await tester.tapAt(const Offset(200, 32));
    await tester.pumpAndSettle();
    expect(find.text('播放'), findsNothing);
  });
}


