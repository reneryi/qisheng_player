class ParsedLyricLine {
  final String primary;
  final String? translation;
  final bool isCredit;

  const ParsedLyricLine({
    required this.primary,
    this.translation,
    this.isCredit = false,
  });

  @override
  String toString() =>
      'ParsedLyricLine(primary: $primary, translation: $translation, isCredit: $isCredit)';
}

class LyricLineParser {
  static final RegExp _creditPattern = RegExp(
    r'^(lyrics? by|composed by|written by|produced by|arranged by|mixed by|mastered by|vocals? by|engineered by|guitar|bass|drums|piano|keyboards?|strings?|作词|作曲|编曲|制作人?|监制|和[音声]|录音|混音|母带|吉他|贝[斯司]|鼓|键盘|弦乐|企划|统筹|出品|发行)\s*[:：]|(享有.*著作权|未经.*许可|未经许可不得翻唱|保留所有权利|All rights reserved|Copyright)',
    caseSensitive: false,
  );

  static final List<String> _explicitSeparators = [
    '─', // \u2500
    '┃', // \u2503
    ' // ',
    ' —— ',
    ' | ',
  ];

  static final RegExp _latinCjkPattern = RegExp(
    r"""^([a-zA-Z0-9\s\.,!?’"'\(\)\-\/:;]+?)\s+([\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af].*)$""",
  );

  static final RegExp _cjkLatinPattern = RegExp(
    r"""^([\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af\s\.,!?’"'\-\/:;]+?)\s+([a-zA-Z0-9\s\.,!?’"'\-\/:;]{3,}.*)$""",
  );

  static final RegExp _bracketTranslationPattern = RegExp(
    r"""^(.+?)\s*[（\(]([^）\)]+)[）\)]$""",
  );

  static ParsedLyricLine parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const ParsedLyricLine(primary: '');
    }

    final isCredit = _creditPattern.hasMatch(text);

    // 1. 若识别为演职员/著作权声明行，则整体作为原行完整呈现，杜绝分词导致后续制作人员信息丢失
    if (isCredit) {
      return ParsedLyricLine(primary: text, isCredit: true);
    }

    // 2. 括号式双语翻译：如 "Original (中文翻译)" 或 "原文（Translation）"
    final bracketMatch = _bracketTranslationPattern.firstMatch(text);
    if (bracketMatch != null) {
      final primary = bracketMatch.group(1)!.trim();
      final translation = bracketMatch.group(2)!.trim();
      final hasCjkTranslation = RegExp(r'[\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af]').hasMatch(translation);
      final hasCjkPrimary = RegExp(r'[\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af]').hasMatch(primary);
      final hasLatinTranslation = RegExp(r'[a-zA-Z]{2,}').hasMatch(translation);
      if (primary.isNotEmpty &&
          translation.isNotEmpty &&
          (hasCjkTranslation || (hasCjkPrimary && hasLatinTranslation))) {
        return ParsedLyricLine(
          primary: primary,
          translation: translation,
          isCredit: false,
        );
      }
    }

    // 3. 显式分隔符切分 (兼容历史 ─、┃ 等特定标记)
    for (final sep in _explicitSeparators) {
      if (text.contains(sep)) {
        final parts = text.split(sep);
        final primary = parts.first.trim();
        final sec = parts.skip(1).join(' ').trim();
        return ParsedLyricLine(
          primary: primary.isEmpty ? '...' : primary,
          translation: sec.isEmpty ? null : sec,
          isCredit: false,
        );
      }
    }

    // 4. 拉丁文原词紧随中日韩翻译 (常见如 "You tell me you're sorry 你对我说抱歉")
    final latinCjkMatch = _latinCjkPattern.firstMatch(text);
    if (latinCjkMatch != null) {
      final primary = latinCjkMatch.group(1)!.trim();
      final translation = latinCjkMatch.group(2)!.trim();
      if (primary.isNotEmpty && translation.isNotEmpty) {
        return ParsedLyricLine(
          primary: primary,
          translation: translation,
          isCredit: false,
        );
      }
    }

    // 5. 中日韩原词紧随英文翻译 (如 "如果这就是爱 If this is love")
    final cjkLatinMatch = _cjkLatinPattern.firstMatch(text);
    if (cjkLatinMatch != null) {
      final primary = cjkLatinMatch.group(1)!.trim();
      final translation = cjkLatinMatch.group(2)!.trim();
      if (primary.isNotEmpty && translation.isNotEmpty) {
        return ParsedLyricLine(
          primary: primary,
          translation: translation,
          isCredit: false,
        );
      }
    }

    // 6. 单行常规歌词
    return ParsedLyricLine(primary: text, isCredit: false);
  }
}
