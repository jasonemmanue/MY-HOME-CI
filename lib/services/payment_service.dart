import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Services payants proposes par la plateforme.
///
/// Volontairement limite a deux : le Pack Pro et la mise en avant. La grille
/// tarifaire du cahier des charges en prevoit d'autres, mais chaque produit
/// supplementaire alourdit la conformite App Store sans apporter de revenu au
/// lancement.
enum PaidProduct {
  pro,
  boost,
  adVideo,
  publication;

  /// Code attendu par les Cloud Functions.
  ///
  /// Ne peut pas se deduire de `name` : Dart impose le lowerCamelCase aux
  /// valeurs d'enumeration, tandis que `PRODUCTS` cote serveur emploie le
  /// snake_case. Un `name` renvoye tel quel donnerait « adVideo » et le
  /// paiement serait refuse avec « Service inconnu ».
  String get code {
    switch (this) {
      case PaidProduct.adVideo:
        return 'ad_video';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case PaidProduct.pro:
        return 'Pack Pro Proprietaire';
      case PaidProduct.boost:
        return 'Mise en avant';
      case PaidProduct.adVideo:
        return 'Publicite video';
      case PaidProduct.publication:
        return "Publication d'annonce";
    }
  }

  String get description {
    switch (this) {
      case PaidProduct.pro:
        return 'Annonces illimitees, badge verifie et statistiques detaillees '
            'pendant 30 jours.';
      case PaidProduct.boost:
        return 'Votre annonce apparait en tete des resultats pendant 7 jours.';
      case PaidProduct.adVideo:
        return "Votre video est diffusee dans l'application pendant 3 jours.";
      case PaidProduct.publication:
        return "Publication ou remise en ligne d'une annonce, visible "
            "30 jours.";
    }
  }
}

/// Operateurs Mobile Money acceptes par GeniusPay en Cote d'Ivoire.
enum MobileMoneyOperator {
  wave('wave', 'Wave', 0xFF1DC8FF),
  orange('orange_money', 'Orange Money', 0xFFFF7900),
  mtn('mtn_money', 'MTN Money', 0xFFFFCB05),
  moov('moov_money', 'Moov Money', 0xFF0057B8);

  final String code;
  final String label;

  /// Couleur de marque, utilisee tant que le logo officiel n'est pas fourni.
  final int brandColor;

  const MobileMoneyOperator(this.code, this.label, this.brandColor);

  /// Logo officiel attendu dans `assets/images/operators/`.
  ///
  /// Ces logos sont des marques deposees : ils ne peuvent etre ni dessines de
  /// memoire, ni repris d'une source approximative — un logo faux sur un
  /// ecran de paiement est pire que pas de logo du tout. Le selecteur affiche
  /// un repli aux couleurs de la marque tant que le fichier est absent, et
  /// bascule seul des qu'il est depose.
  String get logoAsset => 'assets/images/operators/$code.png';
}

/// Etat d'une transaction, tel qu'ecrit par les Cloud Functions.
enum PaymentStatus {
  pending,
  initiated,
  succeeded,
  failed,
  cancelled;

  static PaymentStatus fromString(String? value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }

  bool get isFinal =>
      this == succeeded || this == failed || this == cancelled;
}

class PaymentResult {
  final bool success;
  final String? reference;
  final String? paymentUrl;
  final String message;

  const PaymentResult({
    required this.success,
    this.reference,
    this.paymentUrl,
    required this.message,
  });
}

/// Paiements Mobile Money via GeniusPay, plus le contournement iOS.
///
/// ─── Pourquoi deux parcours ─────────────────────────────────────────────
/// La regle App Store 3.1.1 interdit d'encaisser un bien numerique autrement
/// que par l'achat in-app d'Apple, et interdit meme de renvoyer l'utilisateur
/// vers un paiement externe depuis l'application. Un parcours Mobile Money
/// visible sur iOS fait rejeter l'application, sans discussion possible.
///
/// Le contournement retenu — celui qui passe en revue — est le modele
/// « compte » : sur iOS, l'application ne montre ni tarif, ni operateur, ni
/// bouton de paiement. Elle propose uniquement de recevoir un email. Le
/// paiement se deroule integralement hors application, sur une page web, et
/// l'application se contente de constater l'activation.
///
/// C'est pourquoi [isInAppPaymentAllowed] gouverne l'affichage, et pourquoi
/// [initiateMobileMoneyPayment] refuse de s'executer sur iOS : la garde est
/// dans le service, pas seulement dans l'interface, pour qu'un futur ecran ne
/// puisse pas contourner la regle par inadvertance.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// `false` sur iOS. Toute interface tarifaire doit tester ce drapeau.
  bool get isInAppPaymentAllowed => kIsWeb || !Platform.isIOS;

  // ── Parcours Android / Web ──────────────────────────────────────────────

  /// Lance un paiement Mobile Money et renvoie l'URL de finalisation.
  Future<PaymentResult> initiateMobileMoneyPayment({
    required PaidProduct product,
    required MobileMoneyOperator operator,
    required String phone,
    String? targetId,
    Map<String, dynamic>? params,
  }) async {
    if (!isInAppPaymentAllowed) {
      // Garde volontairement stricte : sur iOS, ce chemin ne doit jamais etre
      // atteignable, meme par erreur de branchement d'un ecran.
      return const PaymentResult(
        success: false,
        message: 'Ce parcours n\'est pas disponible sur cet appareil.',
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
        'phone': phone.trim(),
        if (targetId != null) 'targetId': targetId,
        if (params != null) 'params': params,
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
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Erreur reseau. Verifiez votre connexion.',
      );
    }
  }

  /// Suit l'etat d'une transaction jusqu'a son issue.
  ///
  /// GeniusPay confirme par webhook : c'est la Cloud Function qui fait foi, et
  /// l'application se contente d'observer le document. Interroger l'API de
  /// paiement depuis le client permettrait de falsifier une confirmation.
  Stream<PaymentStatus> watchTransaction(String reference) {
    return _db.collection('transactions').doc(reference).snapshots().map((doc) {
      if (!doc.exists) return PaymentStatus.pending;
      return PaymentStatus.fromString(doc.data()?['status'] as String?);
    });
  }

  // ── Parcours iOS (activation par email) ─────────────────────────────────

  /// Demande l'envoi d'un lien d'activation par email.
  ///
  /// Aucun montant ne transite ici : il est calcule cote serveur et n'apparait
  /// que sur la page web. L'application iOS ne connait donc jamais de prix.
  Future<PaymentResult> requestActivationByEmail({
    required PaidProduct product,
    required String email,
    String? targetId,
    Map<String, dynamic>? params,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'sendActivationEmail',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final response = await callable.call<Map<String, dynamic>>({
        'product': product.code,
        'email': email.trim(),
        if (targetId != null) 'targetId': targetId,
        if (params != null) 'params': params,
      });

      final data = response.data;
      if (data['success'] == true) {
        return PaymentResult(
          success: true,
          reference: data['token']?.toString(),
          message:
              'Un email vient de vous etre envoye. Suivez les instructions '
              'qu\'il contient pour finaliser l\'activation.',
        );
      }
      return PaymentResult(
        success: false,
        message: data['error']?.toString() ?? 'Envoi impossible.',
      );
    } on FirebaseFunctionsException catch (e) {
      return PaymentResult(
        success: false,
        message: e.message ?? 'Service indisponible.',
      );
    } catch (_) {
      return PaymentResult(
        success: false,
        message: 'Erreur reseau. Verifiez votre connexion.',
      );
    }
  }

  // ── Historique ──────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchUserTransactions(String uid) {
    return _db
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
