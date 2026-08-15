import 'package:cloud_functions/cloud_functions.dart';

import '../config/payment_config.dart';
import 'payment_service.dart';

/// Encaissement Mobile Money — Android et Web uniquement.
///
/// ─── Pourquoi un fichier separe de `payment_service.dart` ───────────────
/// Le parcours email d'iOS a besoin de `PaymentService`, donc de son fichier.
/// Or un `enum` est conserve integralement par le compilateur, libelles
/// compris : declarer [MobileMoneyOperator] la-bas mettrait « Wave »,
/// « Orange Money », « MTN Money » et « Moov Money » dans l'IPA soumis a
/// Apple, alors meme qu'aucun ecran iOS ne les affiche.
///
/// Ici, rien n'est reference depuis le parcours iOS : le compilateur AOT
/// retire l'ensemble du fichier des builds iOS.
///
/// Ne jamais importer ce fichier depuis un ecran commun aux deux plateformes.
class MobileMoneyService {
  MobileMoneyService._();
  static final MobileMoneyService instance = MobileMoneyService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Lance un paiement et renvoie l'URL de finalisation de la passerelle.
  ///
  /// Le service n'est pas accorde ici : il l'est a la confirmation du webhook,
  /// cote serveur. L'appelant doit ensuite observer
  /// [PaymentService.watchTransaction].
  Future<PaymentResult> initiate({
    required PaidProduct product,
    required MobileMoneyOperator operator,
    required String phone,
    String? targetId,
  }) async {
    if (!PaymentService.instance.isInAppPaymentAllowed) {
      // Garde volontairement stricte : ce chemin ne doit jamais etre
      // atteignable sur iOS, meme par erreur de branchement d'un ecran.
      return const PaymentResult(
        success: false,
        message: 'Ce parcours n\'est pas disponible sur cet appareil.',
      );
    }

    // La plateforme n'encaisse qu'en Cote d'Ivoire : un numero etranger serait
    // accepte par la passerelle puis rejete par l'operateur, apres avoir cree
    // une transaction fantome. Autant le refuser ici.
    final normalizedPhone = normalizeIvorianPhone(phone);
    if (normalizedPhone == null) {
      return const PaymentResult(
        success: false,
        message: 'Numero invalide. Saisissez un numero ivoirien a 10 chiffres.',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'initiatePayment',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final response = await callable.call<Map<String, dynamic>>({
        'product': product.code,
        'operator': operator.code,
        'phone': normalizedPhone,
        if (targetId != null) 'targetId': targetId,
      });

      final data = response.data;
      if (data['success'] == true) {
        return PaymentResult(
          success: true,
          reference: data['reference']?.toString(),
          paymentUrl: data['paymentUrl']?.toString(),
          message: 'Paiement initie.',
        );
      }
      return PaymentResult(
        success: false,
        message: data['error']?.toString() ?? 'Paiement impossible.',
      );
    } on FirebaseFunctionsException catch (e) {
      return PaymentResult(
        success: false,
        message: e.message ?? 'Le service de paiement est indisponible.',
      );
    } catch (_) {
      return const PaymentResult(
        success: false,
        message: 'Erreur reseau. Verifiez votre connexion.',
      );
    }
  }
}

/// Operateurs Mobile Money acceptes par GeniusPay en Cote d'Ivoire.
///
/// Les codes doivent rester identiques a la constante `OPERATORS` de
/// `functions/index.js` : le serveur rejette tout code inconnu.
enum MobileMoneyOperator {
  wave('wave', 'Wave'),
  orange('orange_money', 'Orange Money'),
  mtn('mtn_money', 'MTN Money'),
  moov('moov_money', 'Moov Money');

  final String code;
  final String label;
  const MobileMoneyOperator(this.code, this.label);
}
