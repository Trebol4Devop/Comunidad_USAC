import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/services/sponsored_preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SponsoredPreferencesService', () {
    test(
      'recuerda el anuncio oculto de forma persistente por usuario',
      () async {
        await SponsoredPreferencesService.hideItem(
          'ad-17',
          userId: 'student-a',
        );

        expect(
          await SponsoredPreferencesService.hiddenItemIds(userId: 'student-a'),
          contains('ad-17'),
        );
        expect(
          await SponsoredPreferencesService.hiddenItemIds(userId: 'student-b'),
          isEmpty,
        );
      },
    );

    test('no duplica elementos al ocultarlos varias veces', () async {
      await SponsoredPreferencesService.hideItem('ad-18', userId: 'student-c');
      await SponsoredPreferencesService.hideItem('ad-18', userId: 'student-c');

      expect(
        await SponsoredPreferencesService.hiddenItemIds(userId: 'student-c'),
        {'ad-18'},
      );
    });
  });
}
