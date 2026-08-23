import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/audio_context_menu.dart';
import 'package:qisheng_player/library/audio_library.dart';

Audio _audio() {
  return Audio(
    'Track',
    'Artist',
    'Album',
    null,
    null,
    1,
    1,
    120,
    null,
    null,
    null,
    null,
    null,
    null,
    r'E:\Music\track.flac',
    0,
    0,
    null,
  );
}

void main() {
  testWidgets('audio context menu exposes the desktop actions', (tester) async {
    final audio = _audio();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final children = buildAudioContextMenuChildren(
                context,
                audio: audio,
                playlist: [audio],
                audioIndex: 0,
                onEdit: () {},
              );
              return Column(children: children);
            },
          ),
        ),
      ),
    );

    expect(find.text('播放'), findsOneWidget);
    expect(find.text('下一首播放'), findsOneWidget);
    expect(find.text('追加到队列'), findsOneWidget);
    expect(find.text('定位到本地文件'), findsOneWidget);
    expect(find.text('匹配歌词 / 音乐编辑'), findsOneWidget);
    expect(find.text('详细信息'), findsOneWidget);
  });
}
