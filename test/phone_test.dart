import 'package:flutter_test/flutter_test.dart';
import 'package:my_home_ci/utils/phone.dart';

void main() {
  group('toE164', () {
    test('partie locale simple', () {
      expect(toE164('0700000000'), '+2250700000000');
    });

    test('separateurs de saisie ignores', () {
      expect(toE164('07 00 00 00 00'), '+2250700000000');
      expect(toE164('07-00-00-00-00'), '+2250700000000');
    });

    // Le champ affiche deja « +225 » : un numero colle en entier ne doit pas
    // produire « +225+225... ».
    test('indicatif deja present, sous ses trois formes', () {
      expect(toE164('+2250700000000'), '+2250700000000');
      expect(toE164('2250700000000'), '+2250700000000');
      expect(toE164('002250700000000'), '+2250700000000');
    });

    test('champ vide', () {
      expect(toE164(''), isNull);
      expect(toE164(null), isNull);
      expect(toE164('   '), isNull);
    });
  });

  group('toLocal', () {
    test('retire l indicatif pour reafficher dans un champ prefixe', () {
      expect(toLocal('+2250700000000'), '0700000000');
    });

    test('valeur absente', () {
      expect(toLocal(null), '');
    });

    // Aller-retour : editer son profil sans toucher au champ ne doit pas
    // alterer le numero stocke.
    test('aller-retour stable', () {
      const stocke = '+2250700000000';
      expect(toE164(toLocal(stocke)), stocke);
    });
  });

  group('isPlausiblePhone', () {
    test('accepte 8 a 10 chiffres', () {
      expect(isPlausiblePhone('0700000000'), isTrue);
      expect(isPlausiblePhone('07000000'), isTrue);
    });

    test('refuse trop court ou vide', () {
      expect(isPlausiblePhone('0700'), isFalse);
      expect(isPlausiblePhone(''), isFalse);
    });

    test('accepte un numero deja complet', () {
      expect(isPlausiblePhone('+2250700000000'), isTrue);
    });
  });
}
