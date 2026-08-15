import 'package:flutter/material.dart';

import '../../config/payment_config.dart';
import '../../services/payment_service.dart';
import 'activation_email_screen.dart';
import 'mobile_money_screen.dart';

/// Point d'entree unique des deux parcours d'activation.
///
/// Aucun ecran de l'application ne doit instancier [MobileMoneyScreen] ni
/// [ActivationEmailScreen] directement : ils passent tous par ici. C'est la
/// seule facon de garantir qu'un nouvel ecran ne fera pas apparaitre un
/// parcours de paiement sur iOS par simple oubli.
///
/// La garde `kMobileMoneyEnabled &&` en tete du test n'est pas redondante avec
/// [PaymentService.isInAppPaymentAllowed] : etant une constante de
/// compilation valant `false` sur iOS, elle rend la branche statiquement
/// morte et fait disparaitre [MobileMoneyScreen] — et donc les montants et les
/// noms d'operateurs — du binaire iOS.
abstract final class PaymentEntry {
  /// Ouvre le parcours adapte a la plateforme.
  ///
  /// Renvoie `true` si l'operation a abouti dans l'application (parcours
  /// Android). Sur iOS, renvoie toujours `null` : l'activation se termine hors
  /// de l'application et l'ecran appelant doit se contenter d'observer le
  /// profil utilisateur.
  static Future<bool?> start(
    BuildContext context, {
    required PaidProduct product,
    String? targetId,
  }) {
    if (kMobileMoneyEnabled && PaymentService.instance.isInAppPaymentAllowed) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MobileMoneyScreen(
            product: product,
            targetId: targetId,
          ),
          fullscreenDialog: true,
        ),
      );
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivationEmailScreen(
          product: product,
          serviceLabel: _serviceLabel(product),
          targetId: targetId,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Libelle affiche sur le parcours iOS.
  ///
  /// Volontairement descriptif du service rendu, jamais de son prix.
  static String _serviceLabel(PaidProduct product) {
    switch (product) {
      case PaidProduct.pro:
        return 'Espace Pro proprietaire';
      case PaidProduct.boost:
        return 'Mise en avant de votre annonce';
    }
  }
}
