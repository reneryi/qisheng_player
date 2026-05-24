import 'dart:convert';

import 'package:desktop_lyric/message.dart' as msg;
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/play_service/desktop_lyric_service.dart';

void main() {
  test('desktop lyric messages are newline-delimited JSON frames', () {
    final playerStateFrame = buildDesktopLyricMessageFrame(
      const msg.PlayerStateChangedMessage(true),
    );
    final nowPlayingFrame = buildDesktopLyricMessageFrame(
      const msg.NowPlayingChangedMessage('Title', 'Artist', 'Album'),
    );
    final lyricFrame = buildDesktopLyricMessageFrame(
      const msg.LyricLineChangedMessage(
        'current lyric',
        Duration(seconds: 4),
      ),
    );

    final frames = const LineSplitter().convert(
      playerStateFrame + nowPlayingFrame + lyricFrame,
    );

    expect(playerStateFrame, endsWith('\n'));
    expect(nowPlayingFrame, endsWith('\n'));
    expect(lyricFrame, endsWith('\n'));
    expect(frames, hasLength(3));
    expect(
      json.decode(frames[0])['type'],
      msg.getMessageTypeName<msg.PlayerStateChangedMessage>(),
    );
    expect(
      json.decode(frames[1])['type'],
      msg.getMessageTypeName<msg.NowPlayingChangedMessage>(),
    );
    expect(
      json.decode(frames[2])['type'],
      msg.getMessageTypeName<msg.LyricLineChangedMessage>(),
    );
  });
}
