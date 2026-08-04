import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_home_ci/config/constants.dart';
import 'package:my_home_ci/config/theme.dart';
import 'package:my_home_ci/models/property.dart';

enum PropertyCardVariant { horizontal, vertical }

class PropertyCard extends StatefulWidget {
  final Property property;
  final PropertyCardVariant variant;
  final VoidCallback? onTap;

  const PropertyCard({
    super.key,
    required this.property,
    this.variant = PropertyCardVariant.vertical,
    this.onTap,
  });

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _isFavorite = false;

  // Couleurs de gradient par type de bien
  List<Color> get _placeholderGradient {
    switch (widget.property.type) {
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
    return widget.variant == PropertyCardVariant.horizontal
        ? _buildHorizontalCard(context)
        : _buildVerticalCard(context);
  }

  // ── Carte horizontale (pour listes) ──
  Widget _buildHorizontalCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
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
            // Image placeholder
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _placeholderGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusDefault),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.home_rounded,
                          color: Colors.white54,
                          size: 40,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.property.type,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge verifie
                if (true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildVerifiedBadge(),
                  ),
                // Bouton favori
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildFavoriteButton(),
                ),
                // Type badge
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.property.type,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          widget.property.quarter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.property.rooms > 0) ...[
                        _buildInfoChip(
                          Icons.bed_outlined,
                          '${widget.property.rooms}',
                          context,
                        ),
                        const SizedBox(width: 12),
                      ],
                      _buildInfoChip(
                        Icons.square_foot_outlined,
                        '${widget.property.surface.toInt()} m²',
                        context,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConstants.formatPricePerMonth(widget.property.price),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carte verticale (pour grilles / listes verticales) ──
  Widget _buildVerticalCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            // Image placeholder
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _placeholderGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppTheme.radiusDefault),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.home_rounded,
                      color: Colors.white54,
                      size: 36,
                    ),
                  ),
                ),
                if (true)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _buildVerifiedBadge(),
                  ),
              ],
            ),
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.property.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _buildFavoriteButton(size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.property.quarter}, ${widget.property.city}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.property.rooms > 0) ...[
                          _buildInfoChip(
                            Icons.bed_outlined,
                            '${widget.property.rooms}',
                            context,
                          ),
                          const SizedBox(width: 12),
                        ],
                        _buildInfoChip(
                          Icons.square_foot_outlined,
                          '${widget.property.surface.toInt()} m²',
                          context,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.formatPricePerMonth(widget.property.price),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.successColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Text(
            'Verifie',
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

  Widget _buildFavoriteButton({double size = 24}) {
    return GestureDetector(
      onTap: () => setState(() => _isFavorite = !_isFavorite),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite ? Colors.redAccent : Colors.grey,
          size: size,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color:
              isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
