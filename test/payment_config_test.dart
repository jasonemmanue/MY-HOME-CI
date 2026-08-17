import 'package:flutter_test/flutter_test.dart';
import 'package:my_home_ci/config/payment_config.dart';

/// Tests du filtrage Cote d'Ivoire.
///
/// Ces regles decident si un paiement part ou non vers la passerelle : une
/// erreur ici cree des transactions fantomes cote GeniusPay, ou refuse des
/// clients legitimes. C'est exactement le genre de logique qu'aucune relecture
/// visuelle ne rattrape.
void main() {
  group('normalizeIvorianPhone', () {
    test('accepte les formes usuelles et les ramene au format international',
        () {
      const attendu = '+2250707123456';
      expect(normalizeIvorianPhone('0707123456'), attendu);
      expect(normalizeIvorianPhone('07 07 12 34 56'), attendu);
      expect(normalizeIvorianPhone('+225 0707123456'), attendu);
      expect(normalizeIvorianPhone('225-07-07-12-34-56'), attendu);
      expect(normalizeIvorianPhone('00225 07.07.12.34.56'), attendu);
      expect(normalizeIvorianPhone('(07) 07 12 34 56'), attendu);
    });

    test('refuse un numero qui n\'est pas ivoirien', () {
      // Numero camerounais : la plateforme n'opere qu'en Cote d'Ivoire.
      expect(normalizeIvorianPhone('+237677123456'), isNull);
      // Numero francais.
      expect(normalizeIvorianPhone('+33612345678'), isNull);
    });

    test('refuse une longueur incorrecte', () {
      // 8 chiffres : ancienne numerotation, abandonnee en 2021.
      expect(normalizeIvorianPhone('07123456'), isNull);
      expect(normalizeIvorianPhone('070712345'), isNull);
      expect(normalizeIvorianPhone('07071234567'), isNull);
    });

    test('refuse un numero ne commencant pas par zero', () {
      // Depuis 2021 tous les numeros ivoiriens commencent par 0.
      expect(normalizeIvorianPhone('7071234567'), isNull);
    });

    test('refuse une saisie non numerique', () {
      expect(normalizeIvorianPhone('07AB123456'), isNull);
      expect(normalizeIvorianPhone(''), isNull);
    });
  });

  group('phoneMatchesOperator', () {
    test('reconnait les prefixes des trois reseaux', () {
      expect(phoneMatchesOperator('0107123456', 'moov_money'), isTrue);
      expect(phoneMatchesOperator('0507123456', 'mtn_money'), isTrue);
      expect(phoneMatchesOperator('0707123456', 'orange_money'), isTrue);
    });

    test('signale une incoherence entre le reseau et le prefixe', () {
      expect(phoneMatchesOperator('0707123456', 'mtn_money'), isFalse);
      expect(phoneMatchesOperator('0107123456', 'orange_money'), isFalse);
    });

    test('n\'oppose jamais de refus sur Wave', () {
      // Un compte Wave s'ouvre sur un numero de n'importe quel reseau :
      // avertir l'utilisateur ici serait un faux positif systematique.
      expect(phoneMatchesOperator('0707123456', 'wave'), isTrue);
      expect(phoneMatchesOperator('0107123456', 'wave'), isTrue);
      expect(phoneMatchesOperator('0507123456', 'wave'), isTrue);
    });

    test('reste permissif quand le numero est incomplet ou invalide', () {
      // L'avertissement ne doit pas clignoter pendant la frappe.
      expect(phoneMatchesOperator('07', 'mtn_money'), isTrue);
      expect(phoneMatchesOperator('', 'orange_money'), isTrue);
    });
  });

  // Ces deux fonctions font le lien entre le numero saisi a l'inscription et
  // le parcours de paiement, depuis que le telephone n'est plus verifie par
  // SMS mais sert de coordonnee de debit par defaut.
  group('localPhoneDigits', () {
    test('retire l\'indicatif pour reremplir un champ de saisie', () {
      expect(localPhoneDigits('+2250707123456'), '0707123456');
      expect(localPhoneDigits('0707123456'), '0707123456');
      expect(localPhoneDigits('00225 07 07 12 34 56'), '0707123456');
    });

    test('renvoie null plutot qu\'une valeur douteuse', () {
      // Un champ prerempli avec un numero invalide ferait echouer la
      // validation sur une valeur que l'utilisateur n'a pas saisie.
      expect(localPhoneDigits(null), isNull);
      expect(localPhoneDigits(''), isNull);
      expect(localPhoneDigits('   '), isNull);
      expect(localPhoneDigits('+237677123456'), isNull);
      expect(localPhoneDigits('07123456'), isNull);
    });
  });

  group('operatorForPhone', () {
    test('deduit l\'operateur des prefixes exclusifs', () {
      expect(operatorForPhone('+2250107123456'), 'moov_money');
      expect(operatorForPhone('0507123456'), 'mtn_money');
      expect(operatorForPhone('+225 07 07 12 34 56'), 'orange_money');
    });

    test('ne devine pas Wave', () {
      // Wave n'a pas de plage propre : le preselectionner sur un prefixe
      // Orange choisirait le mauvais operateur pour la majorite des paiements.
      expect(operatorForPhone('0707123456'), isNot('wave'));
    });

    test('ne devine rien sur un prefixe non attribue', () {
      expect(operatorForPhone('0907123456'), isNull);
      expect(operatorForPhone('0207123456'), isNull);
    });

    test('ne devine rien sur un numero absent ou invalide', () {
      expect(operatorForPhone(null), isNull);
      expect(operatorForPhone(''), isNull);
      expect(operatorForPhone('07'), isNull);
      expect(operatorForPhone('+33612345678'), isNull);
    });

    test('l\'operateur devine reste coherent avec l\'avertissement affiche', () {
      // Si les deux fonctions divergeaient, l'ecran preselectionnerait un
      // operateur puis avertirait aussitot que le numero ne lui correspond pas.
      for (final numero in ['0107123456', '0507123456', '0707123456']) {
        final code = operatorForPhone(numero);
        expect(code, isNotNull);
        expect(phoneMatchesOperator(numero, code!), isTrue);
      }
    });
  });

  group('garde de compilation', () {
    test('le parcours Mobile Money est actif par defaut', () {
      // Le defaut vaut pour Android et le web. Les builds iOS passent
      // --dart-define=MOBILE_MONEY=false (voir codemagic.yaml) : ce test
      // echouerait alors, ce qui est le comportement attendu — il ne doit
      // jamais etre execute dans un contexte de build iOS.
      expect(kMobileMoneyEnabled, isTrue);
      expect(kCountryCode, 'CI');
      expect(kCountryDialCode, '+225');
    });
  });
}
