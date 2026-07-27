import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/page/now_playing_page/component/vertical_lyric_view.dart';

void main() {
  test('large lyric view centers the current line', () {
    expect(
      resolveVerticalLyricFocusAlignment(compact: false),
      0.5,
    );
  });

  test('compact lyric view keeps the legacy upper alignment', () {
    expect(
      resolveVerticalLyricFocusAlignment(compact: true),
      0.25,
    );
  });
}
