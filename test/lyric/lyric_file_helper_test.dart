import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric.dart';
import 'package:qisheng_player/lyric/lyric_file_helper.dart';

class _TestSyncLine extends SyncLyricLine {
  _TestSyncLine(super.start, super.length, super.words, [super.translation]);
}

class _TestSyncWord extends SyncLyricWord {
  _TestSyncWord(super.start, super.length, super.content);
}

class _TestSyncLyric extends Lyric {
  _TestSyncLyric(super.lines);
}

void main() {
  group('LyricFileHelper 文件名净化与路径计算测试', () {
    test('sanitizeFileName 过滤操作系统非法字符并处理首尾点和空格', () {
      expect(LyricFileHelper.sanitizeFileName('晴天'), equals('晴天'));
      expect(
        LyricFileHelper.sanitizeFileName('Song: A / B <Test> * ? " | \\'),
        equals('Song_ A _ B _Test'),
      );
      expect(LyricFileHelper.sanitizeFileName(' ..Hidden Song.. '), equals('Hidden Song'));
      expect(LyricFileHelper.sanitizeFileName(''), equals('unnamed'));
      expect(LyricFileHelper.sanitizeFileName('   ???:::   '), equals('unnamed'));
      // Windows 保留设备名称保护
      expect(LyricFileHelper.sanitizeFileName('CON'), equals('_CON'));
      expect(LyricFileHelper.sanitizeFileName('aux'), equals('_aux'));
      expect(LyricFileHelper.sanitizeFileName('COM1'), equals('_COM1'));
      expect(LyricFileHelper.sanitizeFileName('nul'), equals('_nul'));
      // 超长文件名截断保护（120 字符上限）
      final veryLong = 'A' * 150;
      expect(LyricFileHelper.sanitizeFileName(veryLong).length, equals(120));
    });

    test('getLrcFilePath 为普通单曲生成同级同名 .lrc 路径', () {
      final audio = Audio(
        '晴天',
        '周杰伦',
        '叶惠美',
        null,
        null,
        1,
        1,
        240,
        320,
        48000,
        null,
        null,
        null,
        null,
        r'E:\Music\Jay\qingtian.flac',
        1,
        1,
        'Lofty',
      );

      final lrcPath = LyricFileHelper.getLrcFilePath(audio);
      expect(lrcPath, equals(r'E:\Music\Jay\qingtian.lrc'));
    });

    test('getLrcFilePath 为 CUE 分轨在母带同级目录生成包含音轨号的分轨专属 .lrc 路径', () {
      final cueAudio = Audio(
        '七里香',
        '周杰伦',
        '七里香',
        null,
        null,
        1,
        5,
        300,
        320,
        48000,
        null,
        r'E:\Music\Jay\CDImage.flac',
        12000,
        312000,
        r'E:\Music\Jay\CDImage.flac#CUE:5:900',
        1,
        1,
        'CUE',
      );

      expect(cueAudio.isCueTrack, isTrue);
      final lrcPath = LyricFileHelper.getLrcFilePath(cueAudio);
      expect(lrcPath, equals(r'E:\Music\Jay\05. 七里香.lrc'));
    });

    test('getLrcFilePath 为已包含音轨号前缀的 CUE 标题避免重复前缀', () {
      final cueAudio = Audio(
        '05. 七里香',
        '周杰伦',
        '七里香',
        null,
        null,
        1,
        5,
        300,
        320,
        48000,
        null,
        r'E:\Music\Jay\CDImage.flac',
        12000,
        312000,
        r'E:\Music\Jay\CDImage.flac#CUE:5:900',
        1,
        1,
        'CUE',
      );

      final lrcPath = LyricFileHelper.getLrcFilePath(cueAudio);
      expect(lrcPath, equals(r'E:\Music\Jay\05. 七里香.lrc'));
    });
  });

  group('LyricFileHelper 歌词序列化与 LRC 格式化测试', () {
    test('lyricToLrcString 正确格式化 LrcLine 时间戳与内容', () {
      final lines = [
        LrcLine(const Duration(seconds: 1, milliseconds: 500), '第一句歌词', isBlank: false),
        LrcLine(const Duration(seconds: 5, milliseconds: 20), '第二句歌词', isBlank: false),
        LrcLine(const Duration(seconds: 10), '', isBlank: true),
      ];
      final lrc = Lrc(lines, LrcSource.local);

      final lrcText = LyricFileHelper.lyricToLrcString(lrc);
      expect(lrcText, contains('[00:01.50]第一句歌词'));
      expect(lrcText, contains('[00:05.02]第二句歌词'));
      expect(lrcText.contains('[00:10.00]'), isFalse);
    });

    test('lyricToLrcString 支持逐字同步歌词 SyncLyricLine 及其译文序列化', () {
      final syncLine = _TestSyncLine(
        const Duration(minutes: 1, seconds: 12, milliseconds: 340),
        const Duration(seconds: 3),
        [
          _TestSyncWord(Duration.zero, const Duration(milliseconds: 500), 'Hello'),
          _TestSyncWord(const Duration(milliseconds: 500), const Duration(milliseconds: 500), ' World'),
        ],
        '你好世界',
      );
      final syncLyric = _TestSyncLyric([syncLine]);

      final lrcText = syncLyric.toLrcString();
      expect(lrcText, equals('[01:12.34]Hello World ─ 你好世界'));
    });
  });

  group('LyricFileHelper 本地外挂文件写入与 CUE 保护测试', () {
    test('saveLrcToFile 成功在同级目录写入并支持覆写', () async {
      final tempDir = Directory.systemTemp.createTempSync('qisheng_lrc_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final audioFile = File('${tempDir.path}${Platform.pathSeparator}test_song.mp3');
      audioFile.writeAsStringSync('fake audio');

      final audio = Audio(
        'Test Song',
        'Test Artist',
        'Test Album',
        null,
        null,
        1,
        1,
        180,
        320,
        48000,
        null,
        null,
        null,
        null,
        audioFile.path,
        1,
        1,
        'Lofty',
      );

      const lrcContent1 = '[00:01.00]Initial Lyric';
      final ok1 = await LyricFileHelper.saveLrcToFile(audio, lrcContent1);
      expect(ok1, isTrue);

      final expectedLrcFile = File('${tempDir.path}${Platform.pathSeparator}test_song.lrc');
      expect(expectedLrcFile.existsSync(), isTrue);
      expect(expectedLrcFile.readAsStringSync().trim(), equals(lrcContent1));

      // 覆写测试
      const lrcContent2 = '[00:02.00]Updated Lyric';
      final ok2 = await LyricFileHelper.saveLrcToFile(audio, lrcContent2);
      expect(ok2, isTrue);
      expect(expectedLrcFile.readAsStringSync().trim(), equals(lrcContent2));
    });

    test('writeEmbeddedLyric 拦截并保护 CUE 轨道，防止破坏母带音频', () async {
      final cueAudio = Audio(
        'CUE 分轨',
        '歌手',
        '专辑',
        null,
        null,
        1,
        1,
        200,
        320,
        48000,
        null,
        r'C:\Music\mother.flac',
        0,
        200000,
        r'C:\Music\mother.flac#CUE:1:0',
        1,
        1,
        'CUE',
      );

      final ok = await LyricFileHelper.writeEmbeddedLyric(cueAudio, '[00:01.00]Lyric');
      expect(ok, isFalse);
    });

    test('Lrc.fromAudioPath 在 CUE 轨道存在同级专属外挂 .lrc 时优先加载该分轨歌词', () async {
      final tempDir = Directory.systemTemp.createTempSync('qisheng_cue_lrc_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final motherFile = File('${tempDir.path}${Platform.pathSeparator}Album.flac');
      motherFile.writeAsStringSync('dummy mother file');

      final cueAudio = Audio(
        '晴天',
        '周杰伦',
        '叶惠美',
        null,
        null,
        1,
        3,
        240,
        320,
        48000,
        null,
        motherFile.path,
        60000,
        300000,
        '${motherFile.path}#CUE:3:4500',
        1,
        1,
        'CUE',
      );

      // 保存专属分轨外挂歌词文件 "03. 晴天.lrc"
      const lrcContent = '[00:01.00]故事的小黄花\n[00:05.00]从出生那年就飘着';
      final ok = await LyricFileHelper.saveLrcToFile(cueAudio, lrcContent);
      expect(ok, isTrue);

      final loadedLrc = await Lrc.fromAudioPath(cueAudio);
      expect(loadedLrc, isNotNull);
      expect(loadedLrc!.lines.length, equals(2));
      expect(loadedLrc.lines.first.start, equals(const Duration(seconds: 1)));
      expect((loadedLrc.lines.first as UnsyncLyricLine).content, equals('故事的小黄花'));
    });

    test('Lrc.fromAudioPath 在 CUE 轨道仅有不带音轨号同名 .lrc 时仍能正确识别', () async {
      final tempDir = Directory.systemTemp.createTempSync('qisheng_cue_cand_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final motherFile = File('${tempDir.path}${Platform.pathSeparator}Album.flac');
      motherFile.writeAsStringSync('dummy mother file');

      final cueAudio = Audio(
        '借口',
        '周杰伦',
        '七里香',
        null,
        null,
        1,
        2,
        250,
        320,
        48000,
        null,
        motherFile.path,
        30000,
        280000,
        '${motherFile.path}#CUE:2:2250',
        1,
        1,
        'CUE',
      );

      // 保存不带音轨号的 "借口.lrc"
      final unpaddedLrc = File('${tempDir.path}${Platform.pathSeparator}借口.lrc');
      unpaddedLrc.writeAsStringSync('[00:03.00]在我的地盘你就得听我的');

      final loadedLrc = await Lrc.fromAudioPath(cueAudio);
      expect(loadedLrc, isNotNull);
      expect(loadedLrc!.lines.length, equals(1));
      expect((loadedLrc.lines.first as UnsyncLyricLine).content, equals('在我的地盘你就得听我的'));
    });

    test('Lrc.fromAudioPath 支持 UTF-16 LE 编码的 .lrc 歌词文件解码', () async {
      final tempDir = Directory.systemTemp.createTempSync('qisheng_utf16_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final motherFile = File('${tempDir.path}${Platform.pathSeparator}Song.flac');
      motherFile.writeAsStringSync('dummy');

      final cueAudio = Audio(
        '枫',
        '周杰伦',
        '十一月的萧邦',
        null,
        null,
        1,
        4,
        270,
        320,
        48000,
        null,
        motherFile.path,
        0,
        270000,
        '${motherFile.path}#CUE:4:0',
        1,
        1,
        'CUE',
      );

      // 写入 UTF-16 LE with BOM (0xFF, 0xFE)
      final lrcFile = File('${tempDir.path}${Platform.pathSeparator}04. 枫.lrc');
      const text = '[00:02.50]缓缓飘落的枫叶像思念';
      final bytes = <int>[0xFF, 0xFE];
      for (final unit in text.codeUnits) {
        bytes.add(unit & 0xFF);
        bytes.add((unit >> 8) & 0xFF);
      }
      lrcFile.writeAsBytesSync(bytes);

      final loadedLrc = await Lrc.fromAudioPath(cueAudio);
      expect(loadedLrc, isNotNull);
      expect((loadedLrc!.lines.first as UnsyncLyricLine).content, equals('缓缓飘落的枫叶像思念'));
    });
  });
}
