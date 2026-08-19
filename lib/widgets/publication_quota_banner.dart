import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../services/publication_quota_service.dart';

/// Annonce au proprietaire ce que sa prochaine publication va lui couter.
///
/// Le message est volontairement complet et affiche AVANT le geste : decouvrir
/// des frais au moment de valider, apres avoir saisi une annonce entiere, est
/// la meilleure facon de perdre un proprietaire — et de recolter un
/// signalement pour facturation surprise.
class PublicationQuotaBanner extends StatelessWidget {
  final PublicationQuota quota;

  /// Affiche le montant du pour l'annonce en cours. A laisser a `false` la
  /// ou aucun prix n'est encore connu — un tableau de bord, par exemple.
  final bool showAmount;

  const PublicationQuotaBanner({
    super.key,
    required this.quota,
    this.showAmount = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (IconData icone, Color couleur, String titre, String corps) =
        _contenu();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  corps,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La regle de visibilite est rappelee dans tous les cas : c'est elle qui
  /// justifie le tarif, et c'est aussi ce qui distingue une modification
  /// gratuite d'une republication facturee.
  String get _visibilite =>
      'Votre annonce reste visible ${quota.visibilityDays} jours, modifiable '
      'librement pendant toute cette periode. Passe ce delai, la remettre en '
      'ligne compte pour une nouvelle operation.';

  (IconData, Color, String, String) _contenu() {
    if (quota.isPro) {
      return (
        Icons.workspace_premium_outlined,
        AppTheme.primaryGreen,
        'Pack Pro actif',
        'Publications et mises a jour illimitees, sans frais. $_visibilite',
      );
    }

    if (quota.paidCredits > 0) {
      return (
        Icons.check_circle_outline,
        AppTheme.primaryGreen,
        'Publication deja reglee',
        'Vous disposez de ${quota.paidCredits} publication(s) payee(s) '
            'd\'avance. $_visibilite',
      );
    }

    if (quota.freeRemaining > 0) {
      return (
        Icons.card_giftcard_outlined,
        AppTheme.primaryGreen,
        'Il vous reste ${quota.freeRemaining} operation(s) gratuite(s) '
            'sur ${quota.freeTotal}',
        'Publier une annonce ou la remettre en ligne consomme une operation. '
            '$_visibilite Au-dela, chaque operation coute '
            '${quota.feeRateLabel} du prix de l\'annonce, avec un minimum de '
            '${AppConstants.formatPrice(quota.feeMinimum)}.',
      );
    }

    final montant = showAmount
        ? 'Cette operation coute ${AppConstants.formatPrice(quota.amountDue)}'
        : 'Chaque operation coute ${quota.feeRateLabel} du prix de l\'annonce, '
            'avec un minimum de ${AppConstants.formatPrice(quota.feeMinimum)}';

    return (
      Icons.info_outline,
      AppTheme.secondaryOrange,
      'Operations gratuites epuisees',
      'Vos ${quota.freeTotal} operations gratuites sont utilisees. '
          '$montant (${quota.feeRateLabel} du prix, minimum '
          '${AppConstants.formatPrice(quota.feeMinimum)}). $_visibilite',
    );
  }
}
