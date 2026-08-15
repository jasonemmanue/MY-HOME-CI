/// Reglages de paiement, communs aux deux parcours.
///
/// Ce fichier existe pour une seule raison : concentrer en un point la
/// difference entre le build Android et le build iOS. Tout le reste du code
/// interroge [kMobileMoneyEnabled] et n'a pas a connaitre la plateforme.
library;

/// Faux dans les builds iOS.
///
/// Injecte au build par `--dart-define=MOBILE_MONEY=false` (voir les workflows
/// iOS de `codemagic.yaml`). C'est une constante de compilation, pas un test a
/// l'execution : le compilateur AOT elimine les branches gardees par
/// `kMobileMoneyEnabled && …`, et l'ecran Mobile Money — avec ses libelles
/// d'operateurs et ses montants — n'entre alors pas dans le binaire iOS.
///
/// Un simple `Platform.isIOS` ne suffirait pas : le code resterait present
/// dans l'IPA, et les chaines « Wave », « Orange Money » ou « FCFA » seraient
/// extractibles du binaire soumis a la revue.
const bool kMobileMoneyEnabled =
    bool.fromEnvironment('MOBILE_MONEY', defaultValue: true);

/// Indicatif telephonique de la Cote d'Ivoire. La plateforme n'opere que la.
const String kCountryDialCode = '+225';

/// Code pays ISO transmis a la passerelle.
const String kCountryCode = 'CI';

/// Longueur d'un numero ivoirien depuis la renumerotation de 2021.
const int kLocalPhoneLength = 10;

/// Prefixes attribues par operateur en Cote d'Ivoire.
///
/// Sert a avertir l'utilisateur d'une incoherence probable, jamais a bloquer :
/// la portabilite des numeros existe, et un compte Wave s'ouvre sur un numero
/// de n'importe quel reseau. Refuser fermement ferait perdre des paiements
/// legitimes.
const Map<String, List<String>> kOperatorPrefixes = {
  'moov_money': ['01'],
  'mtn_money': ['05'],
  'orange_money': ['07'],
  // Wave n'a pas de plage propre : le compte est adosse a un numero existant.
  'wave': [],
};

/// Normalise un numero saisi en format international ivoirien.
///
/// Accepte « 07 07 12 34 56 », « 0707123456 », « +225 0707123456 »,
/// « 225 07 07 12 34 56 ». Renvoie `null` si le resultat n'est pas un numero
/// ivoirien plausible.
String? normalizeIvorianPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[\s\-().]'), '');

  if (digits.startsWith('+225')) {
    digits = digits.substring(4);
  } else if (digits.startsWith('00225')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('225') && digits.length > kLocalPhoneLength) {
    digits = digits.substring(3);
  }

  if (digits.length != kLocalPhoneLength) return null;
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
  // Tous les numeros ivoiriens commencent par 0 depuis 2021.
  if (!digits.startsWith('0')) return null;

  return '$kCountryDialCode$digits';
}

/// Vrai si le prefixe du numero correspond a l'operateur choisi.
///
/// Renvoie `true` quand aucune verification n'est possible (Wave, numero
/// incomplet) : l'appelant ne doit avertir que sur un `false` franc.
bool phoneMatchesOperator(String localOrFullNumber, String operatorCode) {
  final prefixes = kOperatorPrefixes[operatorCode];
  if (prefixes == null || prefixes.isEmpty) return true;

  final normalized = normalizeIvorianPhone(localOrFullNumber);
  if (normalized == null) return true;

  final local = normalized.substring(kCountryDialCode.length);
  return prefixes.any(local.startsWith);
}
