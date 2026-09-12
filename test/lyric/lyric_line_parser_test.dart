import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/lyric/lyric_line_parser.dart';

void main() {
  group('LyricLineParser', () {
    test('handles empty or whitespace strings', () {
      final res1 = LyricLineParser.parse('');
      expect(res1.primary, isEmpty);
      expect(res1.translation, isNull);
      expect(res1.isCredit, isFalse);

      final res2 = LyricLineParser.parse('   \n  \t ');
      expect(res2.primary, isEmpty);
      expect(res2.translation, isNull);
      expect(res2.isCredit, isFalse);
    });

    test('parses explicit separator ─', () {
      final res = LyricLineParser.parse('Broken Hearts─碎了的心');
      expect(res.primary, 'Broken Hearts');
      expect(res.translation, '碎了的心');
      expect(res.isCredit, isFalse);
    });

    test('parses explicit separator ┃', () {
      final res = LyricLineParser.parse('Never Gonna Give You Up┃永不言弃');
      expect(res.primary, 'Never Gonna Give You Up');
      expect(res.translation, '永不言弃');
      expect(res.isCredit, isFalse);
    });

    test('parses explicit separator //', () {
      final res = LyricLineParser.parse('Hello // 你好');
      expect(res.primary, 'Hello');
      expect(res.translation, '你好');
      expect(res.isCredit, isFalse);
    });

    test('identifies and handles credit / metadata lines without splitting', () {
      final res1 = LyricLineParser.parse(
          'Broken Hearts - Justin Caruso/Hilda QQ音乐享有本翻译作品的著作权');
      expect(res1.primary,
          'Broken Hearts - Justin Caruso/Hilda QQ音乐享有本翻译作品的著作权');
      expect(res1.isCredit, isTrue);

      final res2 = LyricLineParser.parse(
          'Lyrics by: Shy Martin/Justin Caruso/Andrelli/Gustav Nystrom/Hilda');
      expect(res2.primary,
          'Lyrics by: Shy Martin/Justin Caruso/Andrelli/Gustav Nystrom/Hilda');
      expect(res2.isCredit, isTrue);

      final res3 = LyricLineParser.parse(
          'Composed by: Shy Martin/Justin Caruso/Andrelli/Gustav Nystrom/Hilda');
      expect(res3.primary,
          'Composed by: Shy Martin/Justin Caruso/Andrelli/Gustav Nystrom/Hilda');
      expect(res3.isCredit, isTrue);

      final res4 = LyricLineParser.parse('作词：方文山');
      expect(res4.primary, '作词：方文山');
      expect(res4.isCredit, isTrue);

      final res5 = LyricLineParser.parse('作曲 : 周杰伦');
      expect(res5.primary, '作曲 : 周杰伦');
      expect(res5.isCredit, isTrue);

      // 验证：包含分隔符的演职员/制作信息不会被错误拆解丢弃
      final res6 = LyricLineParser.parse('作词：方文山 | 作曲：周杰伦');
      expect(res6.primary, '作词：方文山 | 作曲：周杰伦');
      expect(res6.translation, isNull);
      expect(res6.isCredit, isTrue);

      final res7 = LyricLineParser.parse('Lyrics by: Shy Martin // Composed by: Justin Caruso');
      expect(res7.primary, 'Lyrics by: Shy Martin // Composed by: Justin Caruso');
      expect(res7.translation, isNull);
      expect(res7.isCredit, isTrue);
    });

    test('splits bracketed translations cleanly', () {
      final res1 = LyricLineParser.parse("You tell me you're sorry (你对我说抱歉)");
      expect(res1.primary, "You tell me you're sorry");
      expect(res1.translation, '你对我说抱歉');
      expect(res1.isCredit, isFalse);

      final res2 = LyricLineParser.parse("如果这就是爱（If this is love）");
      expect(res2.primary, "如果这就是爱");
      expect(res2.translation, 'If this is love');
      expect(res2.isCredit, isFalse);
    });

    test('splits CJK lyrics followed by Latin translation with whitespace', () {
      final res = LyricLineParser.parse("如果这就是爱 If this is love");
      expect(res.primary, "如果这就是爱");
      expect(res.translation, 'If this is love');
      expect(res.isCredit, isFalse);
    });

    test('splits Latin lyrics followed by CJK translation with whitespace', () {
      final res1 =
          LyricLineParser.parse("You tell me you're sorry 你对我说抱歉");
      expect(res1.primary, "You tell me you're sorry");
      expect(res1.translation, '你对我说抱歉');
      expect(res1.isCredit, isFalse);

      final res2 = LyricLineParser.parse(
          'And then you go on "it\'s not your fault" 接着解释说不是我的错');
      expect(res2.primary, 'And then you go on "it\'s not your fault"');
      expect(res2.translation, '接着解释说不是我的错');
      expect(res2.isCredit, isFalse);

      final res3 =
          LyricLineParser.parse('It feels like a classic 如此经典的分手说辞');
      expect(res3.primary, 'It feels like a classic');
      expect(res3.translation, '如此经典的分手说辞');
      expect(res3.isCredit, isFalse);

      final res4 =
          LyricLineParser.parse("Still it hurts and I won't lie 仍然很刺痛 我说实话");
      expect(res4.primary, "Still it hurts and I won't lie");
      expect(res4.translation, '仍然很刺痛 我说实话');
      expect(res4.isCredit, isFalse);
    });

    test('preserves purely monolingual lines', () {
      final res1 = LyricLineParser.parse('青花瓷');
      expect(res1.primary, '青花瓷');
      expect(res1.translation, isNull);
      expect(res1.isCredit, isFalse);

      final res2 = LyricLineParser.parse('Just a single line of English');
      expect(res2.primary, 'Just a single line of English');
      expect(res2.translation, isNull);
      expect(res2.isCredit, isFalse);
    });
  });
}
