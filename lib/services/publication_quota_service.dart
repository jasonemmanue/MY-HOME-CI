import 'package:cloud_functions/cloud_functions.dart';

/// Etat du quota de publication d'un proprietaire.
///
/// Toutes les valeurs viennent du serveur, y compris le montant du : les
/// recalculer ici creerait une seconde source de verite, et l'ecart se
/// decouvrirait au pire moment — devant l'ecran de paiement.
class PublicationQuota {
  /// Operations gratuites accordees a chaque proprietaire.
  final int freeTotal;

  /// Operations gratuites deja consommees.
  final int freeUsed;

  /// Operations gratuites restantes.
  final int freeRemaining;

  /// Publications payees d'avance et pas encore utilisees.
  final int paidCredits;

  /// Pack Pro actif : aucune operation n'est facturee.
  final bool isPro;

  /// La prochaine publication ou remise en ligne doit-elle etre payee ?
  final bool requiresPayment;

  /// Montant du pour l'annonce interrogee, en francs CFA.
  final int amountDue;

  /// Duree de visibilite d'une annonce, en jours.
  final int visibilityDays;

  /// Part du prix de l'annonce facturee, ex. `0.05` pour 5 %.
  final double feeRate;

  /// Plancher applique quel que soit le prix de l'annonce.
  final int feeMinimum;

  const PublicationQuota({
    required this.freeTotal,
    required this.freeUsed,
    required this.freeRemaining,
    required this.paidCredits,
    required this.isPro,
    required this.requiresPayment,
    required this.amountDue,
    required this.visibilityDays,
    required this.feeRate,
    required this.feeMinimum,
  });

  /// Repli utilise quand le serveur est injoignable.
  ///
  /// `requiresPayment` est volontairement a `false` : bloquer une publication
  /// sur un simple defaut de reseau serait plus dommageable qu'une operation
  /// non decomptee. Le decompte reel se fait de toute facon cote serveur, au
  /// declenchement, et non d'apres cette valeur.
  const PublicationQuota.inconnu()
      : freeTotal = 4,
        freeUsed = 0,
        freeRemaining = 4,
        paidCredits = 0,
        isPro = false,
        requiresPayment = false,
        amountDue = 500,
        visibilityDays = 30,
        feeRate = 0.05,
        feeMinimum = 500;

  factory PublicationQuota.fromMap(Map<String, dynamic> d) {
    return PublicationQuota(
      freeTotal: (d['freeTotal'] as num?)?.toInt() ?? 4,
      freeUsed: (d['freeUsed'] as num?)?.toInt() ?? 0,
      freeRemaining: (d['freeRemaining'] as num?)?.toInt() ?? 0,
      paidCredits: (d['paidCredits'] as num?)?.toInt() ?? 0,
      isPro: d['isPro'] as bool? ?? false,
      requiresPayment: d['requiresPayment'] as bool? ?? false,
      amountDue: (d['amountDue'] as num?)?.toInt() ?? 500,
      visibilityDays: (d['visibilityDays'] as num?)?.toInt() ?? 30,
      feeRate: (d['feeRate'] as num?)?.toDouble() ?? 0.05,
      feeMinimum: (d['feeMinimum'] as num?)?.toInt() ?? 500,
    );
  }

  /// Pourcentage lisible, ex. « 5 % ».
  String get feeRateLabel => '${(feeRate * 100).toStringAsFixed(0)} %';
}

class PublicationQuotaService {
  PublicationQuotaService._();
  static final PublicationQuotaService instance = PublicationQuotaService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Interroge le quota, en passant le prix de l'annonce concernee pour que
  /// le serveur renvoie le montant exact plutot que le seul plancher.
  Future<PublicationQuota> fetch({int? price}) async {
    try {
      final callable = _functions.httpsCallable(
        'getPublicationQuota',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final res = await callable.call<Map<String, dynamic>>({
        if (price != null) 'price': price,
      });
      return PublicationQuota.fromMap(Map<String, dynamic>.from(res.data));
    } catch (_) {
      return const PublicationQuota.inconnu();
    }
  }
}
