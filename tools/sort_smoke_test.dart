import 'package:coriander_player/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('中文拼音与英文标题统一排序', () {
    expect('稻dao香'.localeCompareTo('Love Story') < 0, isTrue);
    expect('光辉岁月'.localeCompareTo('Holiday') < 0, isTrue);
  });

  test('中文和英文都可映射到字母索引', () {
    expect('光辉岁月'.toLocaleSortKey().startsWith('g'), isTrue);
    expect('Good Time'.toLocaleSortKey().startsWith('g'), isTrue);
  });
}
