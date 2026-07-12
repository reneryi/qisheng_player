import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PagePreference reads legacy misspelled descending sort order', () {
    expect(SortOrder.fromString('descending'), SortOrder.descending);
    expect(SortOrder.fromString('decending'), SortOrder.descending);

    final preference = PagePreference.fromMap({
      'sortMethod': 2,
      'sortOrder': 'decending',
      'contentView': ContentView.table.name,
    });

    expect(preference.sortMethod, 2);
    expect(preference.sortOrder, SortOrder.descending);
    expect(preference.contentView, ContentView.table);
    expect(preference.showLyricPreview, isFalse);
    expect(preference.toMap()['sortOrder'], 'descending');
  });

  test('PagePreference persists lyric preview visibility flag', () {
    final preference = PagePreference(
      1,
      SortOrder.ascending,
      ContentView.list,
      showLyricPreview: true,
    );

    final restored = PagePreference.fromMap(preference.toMap());

    expect(restored.showLyricPreview, isTrue);
    expect(restored.toMap()['showLyricPreview'], isTrue);
  });

  test('NowPlayingPagePreference silently ignores legacy style mode', () {
    final preference = NowPlayingPagePreference.fromMap({
      'nowPlayingViewMode': NowPlayingViewMode.withPlaylist.name,
      'styleMode': 'studio',
      'lyricTextAlign': LyricTextAlign.center.name,
      'showTranslation': false,
      'lyricFontSize': 24.0,
      'translationFontSize': 16.0,
    });

    expect(preference.nowPlayingViewMode, NowPlayingViewMode.withPlaylist);
    expect(preference.lyricTextAlign, LyricTextAlign.center);
    expect(preference.showTranslation, isFalse);
    expect(preference.lyricFontSize, 24.0);
    expect(preference.translationFontSize, 16.0);
    expect(preference.toMap(), isNot(contains('styleMode')));
  });
}
