import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/property.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

enum PropertyCardVariant { horizontal, vertical }

/// Carte d'annonce, en version horizontale (carrousels) ou verticale (grilles).
///
/// L'état favori vient de [FavoritesProvider] et non d'un `bool` local : la
/// même annonce apparaît souvent dans plusieurs listes à la fois, et un état
/// local ferait diverger les cœurs entre l'accueil et la fiche détail.
class PropertyCard extends StatelessWidget {
  final Property property;
  final PropertyCardVariant variant;
  final VoidCallback? onTap;

  /// Distance depuis l'utilisateur, affichée quand elle est connue
  /// (section « Près de vous », carte).
  final String? distanceLabel;

  const PropertyCard({
    super.key,
    required this.property,
    this.variant = PropertyCardVariant.vertical,
    this.onTap,
    this.distanceLabel,
  });

  /// Dégradé de repli, choisi selon le type de bien.
  ///
  /// Une annonce sans photo reste rare mais possible (brouillon repris,
  /// upload interrompu) : un bloc gris serait pris pour un bug d'affichage.
  List<Color> get _fallbackGradient {
    switch (property.type) {
      case 'Studio':
        return [const Color(0xFF2E7D5B), const Color(0xFF4CAF7D)];
      case 'Appartement':
        return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
      case 'Villa':
        return [const Color(0xFFE65100), const Color(0xFFFFA726)];
      case 'Chambre':
        return [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)];
      case 'Duplex':
        return [const Color(0xFF00838F), const Color(0xFF4DD0E1)];
      case 'Maison':
        return [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
      case 'Bureau':
        return [const Color(0xFF37474F), const Color(0xFF78909C)];
      case 'Terrain':
        return [const Color(0xFF795548), const Color(0xFFA1887F)];
      default:
        return [AppTheme.primaryGreen, AppTheme.primaryGreenLight];
    }
  }

  @override
  Widget build(BuildContext context) {
    return variant == PropertyCardVariant.horizontal
        ? _horizontal(context)
        : _vertical(context);
  }

  // ── Variante horizontale ────────────────────────────────────────────────

  Widget _horizontal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _imageHeader(context, height: 140),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(context, maxLines: 1),
                  const SizedBox(height: 4),
                  _location(context),
                  const SizedBox(height: 8),
                  _price(context),
                  const SizedBox(height: 8),
                  _features(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Variante verticale ──────────────────────────────────────────────────

  Widget _vertical(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _imageHeader(context, height: 130),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _title(context, maxLines: 2),
                  const SizedBox(height: 4),
                  _location(context),
                  const SizedBox(height: 6),
                  _price(context),
                  const SizedBox(height: 6),
                  _features(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fragments ───────────────────────────────────────────────────────────

  Widget _imageHeader(BuildContext context, {required double height}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusDefault),
          ),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: _image(context),
          ),
        ),
        if (property.ownerIsVerified)
          Positioned(top: 8, left: 8, child: _verifiedBadge()),
        if (property.isBoosted)
          Positioned(
            top: 8,
            left: property.ownerIsVerified ? 90 : 8,
            child: _pill(
              icon: Icons.trending_up,
              label: 'En avant',
              background: AppTheme.secondaryOrange,
            ),
          ),
        Positioned(top: 6, right: 6, child: _favoriteButton(context)),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              property.type,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (distanceLabel != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me, size: 11, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    distanceLabel!,
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _image(BuildContext context) {
    final url = property.coverImage;
    if (url == null || url.isEmpty) return _fallbackImage();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // Le shimmer plutôt qu'un rond de progression : sur 3G, l'image met
      // plusieurs secondes et une grille de spinners donne une impression
      // d'application bloquée.
      placeholder: (context, _) => Shimmer.fromColors(
        baseColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE8E8E8),
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF5F5F5),
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, _, __) => _fallbackImage(),
    );
  }

  Widget _fallbackImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _fallbackGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_rounded, color: Colors.white54, size: 38),
            const SizedBox(height: 4),
            Text(
              property.type,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifiedBadge() => _pill(
        icon: Icons.verified,
        label: 'Verifie',
        background: AppTheme.primaryGreen,
      );

  Widget _pill({
    required IconData icon,
    required String label,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _favoriteButton(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(property.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _toggleFavorite(context),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 17,
            color: isFavorite ? const Color(0xFFE53935) : Colors.black54,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final favorites = context.read<FavoritesProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final added = await favorites.toggle(property.id);

      // Le visiteur peut mettre en favori — le stockage est local. On le
      // prévient une seule fois, à l'ajout, que ces favoris ne suivront pas
      // sans compte : le bloquer ferait perdre l'utilisateur au moment précis
      // où il manifeste de l'intérêt.
      if (added && auth.isGuest) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Favori enregistre sur cet appareil. Creez un compte pour le '
                'retrouver partout.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible de modifier vos favoris.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Widget _title(BuildContext context, {required int maxLines}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      property.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
      ),
    );
  }

  Widget _location(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 13, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            '${property.quarter}, ${property.city}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11.5, color: color),
          ),
        ),
      ],
    );
  }

  Widget _price(BuildContext context) {
    return Text(
      AppConstants.formatPricePerMonth(property.price),
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _features(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    Widget item(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: color)),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(Icons.bed_outlined, '${property.rooms} p.'),
        item(Icons.bathtub_outlined, '${property.bathrooms}'),
        if (property.surface > 0)
          item(Icons.square_foot, '${property.surface.toInt()} m²'),
      ],
    );
  }
}
