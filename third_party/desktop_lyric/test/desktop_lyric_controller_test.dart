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

  test('parses ThemeChangedMessage and updates theme notifier for hover material', () {
    final controller = DesktopLyricController.createForTest();
    const themeMsg = ThemeChangedMessage(
      0xFF00F5D4,
      0xFF2D3748,
      0xFFE2E8F0,
    );

    controller.parseStdinChunkForTest('${themeMsg.buildMessageJson()}\n');

    expect(controller.theme.value.primary, 0xFF00F5D4);
    expect(controller.theme.value.surfaceContainer, 0xFF2D3748);
    expect(controller.theme.value.onSurface, 0xFFE2E8F0);
  });

  test('initWithArgs initializes isDarkMode and theme for body styling', () {
    const initArgsJson = '{"isPlaying":true,"title":"Test Song","artist":"Test Artist",'
        '"album":"Test Album","darkMode":true,"primary":4278253012,'
        '"surfaceContainer":4280231464,"onSurface":4294967295}';

    DesktopLyricController.initWithArgs([initArgsJson]);

    expect(DesktopLyricController.instance.isDarkMode.value, isTrue);
    expect(DesktopLyricController.instance.theme.value.primary, 4278253012);
    expect(DesktopLyricController.instance.nowPlaying.value.title, 'Test Song');
  });
}
