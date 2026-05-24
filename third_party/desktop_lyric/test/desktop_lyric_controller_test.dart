import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses multiple complete messages from one stdin chunk', () {
    final controller = DesktopLyricController.createForTest();

    controller.parseStdinChunkForTest(
      [
        const NowPlayingChangedMessage('Song A', 'Artist A', 'Album A')
            .buildMessageJson(),
        const LyricLineChangedMessage('first line', Duration(seconds: 3))
            .buildMessageJson(),
        '',
      ].join('\n'),
    );

    expect(controller.nowPlaying.value.title, 'Song A');
    expect(controller.lyricLine.value.content, 'first line');
  });

  test('waits for incomplete message chunks before parsing', () {
    final controller = DesktopLyricController.createForTest();
    final message =
        const NowPlayingChangedMessage('Song B', 'Artist B', 'Album B')
            .buildMessageJson();
    final splitAt = message.length ~/ 2;

    controller.parseStdinChunkForTest(message.substring(0, splitAt));
    expect(controller.nowPlaying.value.title, isNot('Song B'));

    controller.parseStdinChunkForTest('${message.substring(splitAt)}\n');
    expect(controller.nowPlaying.value.title, 'Song B');
  });

  test('drops malformed newline-delimited frame and keeps parsing later frames',
      () {
    final controller = DesktopLyricController.createForTest();

    controller.parseStdinChunkForTest(
      [
        '{bad json',
        const NowPlayingChangedMessage('Song C', 'Artist C', 'Album C')
            .buildMessageJson(),
        const LyricLineChangedMessage('recovered line', Duration(seconds: 2))
            .buildMessageJson(),
        '',
      ].join('\n'),
    );

    expect(controller.nowPlaying.value.title, 'Song C');
    expect(controller.lyricLine.value.content, 'recovered line');
  });
}
