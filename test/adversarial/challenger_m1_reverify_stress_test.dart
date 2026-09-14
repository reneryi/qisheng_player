import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/lyric/qrc.dart';

void main() {
  group('Challenger M1 Re-verification Empirical Stress Tests', () {
    test('1. Dispatch target case: word with parenthesis in middle', () {
      final line = QrcLine.fromLine('[1000,2000]say (yeah)(100,200)hello(300,400)');
      expect(line, isNotNull);
      expect(line!.start, equals(const Duration(milliseconds: 1000)));
      expect(line.length, equals(const Duration(milliseconds: 2000)));
      expect(line.words.length, equals(2));
      expect(line.words[0].content, equals('say (yeah)'));
      expect(line.words[0].start, equals(const Duration(milliseconds: 100)));
      expect(line.words[0].length, equals(const Duration(milliseconds: 200)));
      expect(line.words[1].content, equals('hello'));
      expect(line.words[1].start, equals(const Duration(milliseconds: 300)));
      expect(line.words[1].length, equals(const Duration(milliseconds: 400)));
    });

    test('2. Dispatch target case: leading parenthesis (feat. artist) title', () {
      final line = QrcLine.fromLine('[0,5000](feat. artist) title(0,2000)');
      expect(line, isNotNull);
      expect(line!.start, equals(Duration.zero));
      expect(line.length, equals(const Duration(milliseconds: 5000)));
      expect(line.words.length, equals(1));
      expect(line.words[0].content, equals('(feat. artist) title'));
      expect(line.words[0].start, equals(Duration.zero));
      expect(line.words[0].length, equals(const Duration(milliseconds: 2000)));
    });

    test('3. Nested and multiple parentheses in single word', () {
      final line = QrcLine.fromLine('[2000,3000]complex ((nested)) [brackets] (yeah) (1999)(500,1500)');
      expect(line, isNotNull);
      expect(line!.words.length, equals(1));
      expect(line.words[0].content, equals('complex ((nested)) [brackets] (yeah) (1999)'));
      expect(line.words[0].start, equals(const Duration(milliseconds: 500)));
      expect(line.words[0].length, equals(const Duration(milliseconds: 1500)));
    });

    test('4. Full QRC text with multiple lines and translations containing parentheses', () {
      const qrcRaw = '''
[ti:Test Song]
[ar:Challenger]
[1000,3000]Intro (yeah)(0,1000)verse (1)(1000,2000)
[4000,4000](feat. guest) chorus(0,4000)
''';
      const transRaw = '''
[00:01.00]前奏 (是的) 主歌 (一)
[00:04.00](特邀嘉宾) 副歌
''';
      final qrc = Qrc.fromQrcText(qrcRaw, transRaw);
      expect(qrc.lines, isNotEmpty);
      final qrcLines = qrc.lines.whereType<QrcLine>().where((l) => l.words.isNotEmpty).toList();
      expect(qrcLines.length, equals(2));
      
      // Line 1
      expect(qrcLines[0].words.length, equals(2));
      expect(qrcLines[0].words[0].content, equals('Intro (yeah)'));
      expect(qrcLines[0].words[1].content, equals('verse (1)'));
      expect(qrcLines[0].translation, equals('前奏 (是的) 主歌 (一)'));

      // Line 2
      expect(qrcLines[1].words.length, equals(1));
      expect(qrcLines[1].words[0].content, equals('(feat. guest) chorus'));
      expect(qrcLines[1].translation, equals('(特邀嘉宾) 副歌'));
    });

    test('5. Extreme input: 100 words with parentheses parsed rapidly without catastrophic backtracking', () {
      final buffer = StringBuffer('[0,100000]');
      for (int i = 0; i < 100; i++) {
        buffer.write('word ($i) (part-$i)($i,${i + 10})');
      }
      final stopwatch = Stopwatch()..start();
      final line = QrcLine.fromLine(buffer.toString());
      stopwatch.stop();

      expect(line, isNotNull);
      expect(line!.words.length, equals(100));
      expect(line.words[0].content, equals('word (0) (part-0)'));
      expect(line.words[99].content, equals('word (99) (part-99)'));
      expect(line.words[99].start, equals(const Duration(milliseconds: 99)));
      expect(line.words[99].length, equals(const Duration(milliseconds: 109)));
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Parsing 100 complex words must complete in <100ms');
    });

    test('6. Malformed and boundary line inputs return expected safe values', () {
      // Missing brackets
      expect(QrcLine.fromLine('plain text without brackets'), isNull);
      // Inverted brackets
      expect(QrcLine.fromLine(']1000,2000[test(100,200)'), isNull);
      // Empty bracket
      expect(QrcLine.fromLine('[]test(100,200)'), isNull);
      // Only one timestamp in header
      expect(QrcLine.fromLine('[1000]test(100,200)'), isNull);
      // Non-numeric timestamps in header safely default to 0ms
      final nonNumericHeader = QrcLine.fromLine('[abc,def]test(100,200)');
      expect(nonNumericHeader, isNotNull);
      expect(nonNumericHeader!.start, equals(Duration.zero));
      expect(nonNumericHeader.length, equals(Duration.zero));
      expect(nonNumericHeader.words.length, equals(1));
      expect(nonNumericHeader.words[0].content, equals('test'));
    });
  });
}
