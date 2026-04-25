import 'package:coriander_player/page/folders_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseFolderDisplay extracts last two directory segments', () {
    expect(
      parseFolderDisplay(r'E:\Music\Aimer\BEST ALBUM'),
      (title: 'BEST ALBUM', subtitle: 'Aimer'),
    );
    expect(
      parseFolderDisplay(r'C:\Library'),
      (title: 'Library', subtitle: 'C:'),
    );
    expect(
      parseFolderDisplay(r'/mnt/music/live'),
      (title: 'live', subtitle: 'music'),
    );
  });
}
