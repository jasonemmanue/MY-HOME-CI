import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/payment_service.dart';

/// Choix de l'operateur Mobile Money.
///
/// Chaque tuile charge le logo officiel depuis `assets/images/operators/`. Le
/// fichier absent n'est pas une erreur : la tuile retombe sur l'initiale de
/// l'operateur posee sur sa couleur de marque. Ces logos sont des marques
/// deposees, ils ne peuvent etre ni redessines ni approximes — voir le README
/// du dossier.
class OperatorSelector extends StatelessWidget {
  final MobileMoneyOperator? selected;
  final ValueChanged<MobileMoneyOperator> onSelected;

  const OperatorSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: MobileMoneyOperator.values
          .map((o) => _tuile(context, o, isDark))
          .toList(),
    );
  }

  Widget _tuile(
      BuildContext context, MobileMoneyOperator operateur, bool isDark) {
    final actif = selected == operateur;

    return InkWell(
      onTap: () => onSelected(operateur),
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: actif
              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: actif
                ? AppTheme.primaryGreen
                : (isDark ? AppTheme.dividerDark : AppTheme.dividerLight),
            width: actif ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _logo(operateur),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                operateur.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (actif)
              const Icon(Icons.check_circle,
                  size: 18, color: AppTheme.primaryGreen),
          ],
        ),
      ),
    );
  }

  Widget _logo(MobileMoneyOperator operateur) {
    final couleur = Color(operateur.brandColor);

    return SizedBox(
      width: 34,
      height: 34,
      // Les logos officiels sont fournis sur un aplat de marque, non
      // detoures : `cover` dans un cadre arrondi les rend tous identiques,
      // la ou `contain` laisserait des marges inegales selon le fichier.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          operateur.logoAsset,
          fit: BoxFit.cover,
          // Logo pas encore fourni : l'initiale sur la couleur de marque,
          // plutot qu'une icone cassee.
          errorBuilder: (_, __, ___) => Container(
            color: couleur,
            alignment: Alignment.center,
            child: Text(
              operateur.label.characters.first,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                // Le jaune MTN est trop clair pour du blanc.
                color: operateur == MobileMoneyOperator.mtn
                    ? Colors.black87
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
