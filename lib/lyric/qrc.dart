import 'package:qisheng_player/lyric/lyric.dart';

class Qrc extends Lyric {
  Qrc(super.lines);

  static Qrc fromQrcText(String qrc, [String? transRawStr]) {
    final List<QrcLine> lines = [];
    final splited = qrc.split("\n");
    for (final item in splited) {
      final qrcLine = QrcLine.fromLine(item);

      if (qrcLine == null) continue;

      lines.add(qrcLine);
    }

    if (transRawStr != null) {
      int lineIt = 0;
      final splitedTrans = transRawStr.split("\n");
      for (var transLine in splitedTrans) {
        if (lineIt > lines.length - 1) {
          break;
        }

        final left = transLine.indexOf("[");
        final right = transLine.indexOf("]");
        if (left == -1 || right == -1 || right <= left) {
          continue;
        }

        final timeStr = transLine.substring(left + 1, right);
        // 如果是翻译行就加到歌词去
        if (int.tryParse(timeStr.split(":").first) != null) {
          final t =
              transLine.replaceAll(RegExp(r"\[\d{2}:\d{2}\.\d{2,}\]"), "");
          if (t.isNotEmpty) {
            lines[lineIt].translation = t;
            lineIt += 1;
          }
        }
      }
    }

    // 添加空白
    final List<QrcLine> fommatedLines = [];
    final firstLine = lines.firstOrNull;
    if (firstLine != null && firstLine.start > const Duration(seconds: 5)) {
      fommatedLines.add(QrcLine(Duration.zero, firstLine.start, []));
    }
    for (int i = 0; i < lines.length - 1; ++i) {
      fommatedLines.add(lines[i]);
      final transitionStart = lines[i].start + lines[i].length;
      final transitionLength = lines[i + 1].start - transitionStart;
      if (transitionLength > const Duration(seconds: 5)) {
        fommatedLines.add(QrcLine(transitionStart, transitionLength, []));
      }
    }
    final lastLine = lines.lastOrNull;
    if (lastLine != null) {
      fommatedLines.add(lastLine);
    }

    return Qrc(fommatedLines);
  }

  @override
  String toString() {
    return (lines as List<SyncLyricLine>).toString();
  }
}

class QrcLine extends SyncLyricLine {
  static final _wordTokenRegex = RegExp(r'(.*?)\((\d+),(\d+)\)');

  QrcLine(super.start, super.length, super.words, [super.translation]);

  static QrcLine? fromLine(String line, [String? translation]) {
    final left = line.indexOf("[");
    final right = line.indexOf("]");
    if (left == -1 || right == -1 || right <= left) return null;

    final splitedTime = line.substring(left + 1, right).split(",");

    if (splitedTime.length != 2) return null;

    final Duration start = Duration(
      milliseconds: int.tryParse(splitedTime[0]) ?? 0,
    );
    final Duration length = Duration(
      milliseconds: int.tryParse(splitedTime[1]) ?? 0,
    );

    final contentStr = line.substring(right + 1);
    final List<QrcWord> words = [];
    for (final match in _wordTokenRegex.allMatches(contentStr)) {
      final content = match.group(1) ?? '';
      final wordStart = Duration(
        milliseconds: int.tryParse(match.group(2) ?? '') ?? 0,
      );
      final wordLength = Duration(
        milliseconds: int.tryParse(match.group(3) ?? '') ?? 0,
      );
      words.add(QrcWord(wordStart, wordLength, content));
    }

    return QrcLine(start, length, words, translation);
  }
}

class QrcWord extends SyncLyricWord {
  static final _wordRegex = RegExp(r'^(.*?)\((\d+),(\d+)\)?$');

  QrcWord(super.start, super.length, super.content);

  static QrcWord? fromWord(String word) {
    final trimmed = word.trim();
    final match = _wordRegex.firstMatch(trimmed);
    if (match == null) return null;

    final content = match.group(1) ?? '';
    final start = Duration(
      milliseconds: int.tryParse(match.group(2) ?? '') ?? 0,
    );
    final length = Duration(
      milliseconds: int.tryParse(match.group(3) ?? '') ?? 0,
    );

    return QrcWord(start, length, content);
  }
}
