/// Manipulation des numeros de telephone ivoiriens.
///
/// Les champs de saisie affichent « +225 » en prefixe fixe : l'utilisateur ne
/// tape que la partie locale. Le stockage, lui, se fait toujours au format
/// E.164 (`+2250700000000`), pour deux raisons :
///
///  * Firebase Auth n'accepte que ce format pour l'envoi d'un OTP ;
///  * le numero sert de valeur par defaut aux paiements Mobile Money, ou
///    l'operateur exige egalement l'indicatif.
///
/// Sans normalisation a l'ecriture, la meme personne pourrait etre enregistree
/// tantot « 07 00 00 00 00 », tantot « +2250700000000 » selon l'ecran utilise.
library;

/// Indicatif de la Cote d'Ivoire.
const String kCountryCallingCode = '225';

/// Prefixe affiche dans les champs de saisie.
const String kPhonePrefixLabel = '+$kCountryCallingCode ';

/// Met [input] au format E.164, ou renvoie `null` si le champ est vide.
///
/// Tolere qu'un utilisateur colle un numero deja complet — « +225… », « 225… »
/// ou « 00225… » — alors que le champ affiche deja l'indicatif : sans ce
/// nettoyage, on obtiendrait « +225+2250700000000 ».
String? toE164(String? input) {
  if (input == null) return null;

  var digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return null;

  digits = digits.replaceFirst(RegExp(r'^\+'), '');
  digits = digits.replaceFirst(RegExp('^00'), '');
  digits = digits.replaceFirst(RegExp('^$kCountryCallingCode'), '');

  if (digits.isEmpty) return null;
  return '+$kCountryCallingCode$digits';
}

/// Retire l'indicatif pour reafficher un numero stocke dans un champ qui
/// porte deja le prefixe « +225 ».
String toLocal(String? e164) {
  if (e164 == null || e164.isEmpty) return '';
  return e164
      .replaceAll(RegExp(r'[^0-9+]'), '')
      .replaceFirst(RegExp(r'^\+'), '')
      .replaceFirst(RegExp('^00'), '')
      .replaceFirst(RegExp('^$kCountryCallingCode'), '');
}

/// Le numero saisi est-il exploitable ?
///
/// Un numero ivoirien compte dix chiffres depuis 2021, mais on accepte a
/// partir de huit : les anciens numeros a huit chiffres circulent encore, et
/// bloquer une inscription sur ce critere couterait plus qu'il ne protege.
bool isPlausiblePhone(String? input) {
  final local = toLocal(toE164(input));
  return local.length >= 8 && local.length <= 15;
}
