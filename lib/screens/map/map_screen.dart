import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_home_ci/config/constants.dart';
import 'package:my_home_ci/config/theme.dart';
import 'package:my_home_ci/models/property.dart';
import 'package:my_home_ci/widgets/search_bar_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedDistanceIndex = 2; // 3km par defaut
  final List<Property> _nearbyProperties = Property.mockProperties.take(5).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond simulant une carte ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1A3A2A),
                        const Color(0xFF0D1F17),
                        const Color(0xFF162D22),
                      ]
                    : [
                        const Color(0xFFD4E8DC),
                        const Color(0xFFE8F5E9),
                        const Color(0xFFC8E6C9),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Lignes de route simulees ──
          CustomPaint(
            size: Size.infinite,
            painter: _MapGridPainter(isDark: isDark),
          ),

          // ── Marqueurs ──
          ..._buildMapMarkers(context),

          // ── Barre de recherche en haut ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: SearchBarWidget(
              onTap: () {},
              onFilterTap: () {},
            ),
          ),

          // ── Chips de distance ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: AppConstants.distanceFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedDistanceIndex;
                  final label = AppConstants.distanceLabel(
                    AppConstants.distanceFilters[index],
                  );
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedDistanceIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : (isDark
                                ? AppTheme.cardDark
                                : AppTheme.surfaceLight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Bottom sheet avec proprietes proches ──
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusLarge),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Poignee
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.dividerDark
                              : AppTheme.dividerLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        '${_nearbyProperties.length} biens a proximite',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    ..._nearbyProperties.map(
                      (property) => _buildMiniPropertyTile(context, property),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // ── FAB "Ma position" ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 200),
        child: FloatingActionButton.small(
          onPressed: () {},
          backgroundColor: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
          child: Icon(
            Icons.my_location_rounded,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }

  // ── Marqueurs sur la carte ──
  List<Widget> _buildMapMarkers(BuildContext context) {
    // Positions relatives simulees (en fraction de l'ecran)
    final positions = [
      const Offset(0.3, 0.30),
      const Offset(0.6, 0.35),
      const Offset(0.2, 0.50),
      const Offset(0.7, 0.45),
      const Offset(0.5, 0.55),
    ];

    return List.generate(
      _nearbyProperties.length.clamp(0, positions.length),
      (index) {
        final pos = positions[index];
        final property = _nearbyProperties[index];
        return Positioned(
          left: MediaQuery.of(context).size.width * pos.dx - 20,
          top: MediaQuery.of(context).size.height * pos.dy - 40,
          child: _buildMarker(context, property),
        );
      },
    );
  }

  Widget _buildMarker(BuildContext context, Property property) {
    return GestureDetector(
      onTap: () {
        // TODO: afficher le detail du bien
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppTheme.softShadow,
            ),
            child: Text(
              AppConstants.formatPrice(property.price),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _TrianglePainter(color: AppTheme.primaryGreen),
          ),
          const Icon(
            Icons.location_on,
            color: AppTheme.primaryGreen,
            size: 28,
          ),
        ],
      ),
    );
  }

  // ── Mini tuile de propriete dans le bottom sheet ──
  Widget _buildMiniPropertyTile(BuildContext context, Property property) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          // Mini image placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.home_rounded,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  property.quarter,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            AppConstants.formatPricePerMonth(property.price),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Peintre de grille simulant des routes ──
class _MapGridPainter extends CustomPainter {
  final bool isDark;

  _MapGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Routes horizontales
    for (double y = 80; y < size.height; y += 120) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Routes verticales
    for (double x = 60; x < size.width; x += 100) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Routes diagonales (quelques-unes)
    final diagonalPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.7),
      diagonalPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.4, 0),
      Offset(size.width, size.height * 0.5),
      diagonalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Petit triangle pour la bulle de prix ──
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
