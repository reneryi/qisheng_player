import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/font_loader_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontLoaderHelper tests', () {
    test('extractBaseFamily strips style suffixes accurately', () {
      expect(FontLoaderHelper.extractBaseFamily('MiSans'), equals('MiSans'));
      expect(
        FontLoaderHelper.extractBaseFamily('MiSans Regular'),
        equals('MiSans'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('MiSans Bold'),
        equals('MiSans'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('MiSans Medium'),
        equals('MiSans'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('MiSans Demibold'),
        equals('MiSans'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('MiSans-Bold'),
        equals('MiSans'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('HarmonyOS Sans SC Bold'),
        equals('HarmonyOS Sans SC'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('PingFang SC 粗体'),
        equals('PingFang SC'),
      );
      expect(
        FontLoaderHelper.extractBaseFamily('Source Han Sans CN Heavy'),
        equals('Source Han Sans CN'),
      );
    });

    test('isFamilyLoaded tracks loaded status correctly', () {
      expect(FontLoaderHelper.isFamilyLoaded(null), isFalse);
      expect(FontLoaderHelper.isFamilyLoaded(''), isFalse);
      expect(FontLoaderHelper.isFamilyLoaded('NonExistentFamilyTest'), isFalse);

      FontLoaderHelper.markLoaded('TestCustomFamily');
      expect(FontLoaderHelper.isFamilyLoaded('TestCustomFamily'), isTrue);
      expect(FontLoaderHelper.isFamilyLoaded(' TestCustomFamily '), isTrue);
    });

    test('loadFontFamily handles empty and already loaded family gracefully',
        () async {
      await expectLater(
        FontLoaderHelper.loadFontFamily(familyName: ''),
        completes,
      );

      FontLoaderHelper.markLoaded('AlreadyLoadedFamily');
      await expectLater(
        FontLoaderHelper.loadFontFamily(familyName: 'AlreadyLoadedFamily'),
        completes,
      );
    });
  });
}
