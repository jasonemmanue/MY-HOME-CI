import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_home_ci/config/constants.dart';
import 'package:my_home_ci/config/theme.dart';
import 'package:my_home_ci/models/property.dart';
import 'package:my_home_ci/widgets/filter_chip_bar.dart';
import 'package:my_home_ci/widgets/property_card.dart';
import 'package:my_home_ci/widgets/search_bar_widget.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _selectedTypeIndex = 0;
  final List<String> _typeFilters = ['Tout', ...AppConstants.propertyTypes];

  List<Property> get _filteredProperties {
    if (_selectedTypeIndex == 0) return Property.mockProperties;
    final type = _typeFilters[_selectedTypeIndex];
    return Property.mockProperties
        .where((p) => p.type == type)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar ──
        SliverAppBar(
          floating: true,
          snap: true,
          elevation: 0,
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          title: Text(
            AppConstants.appName,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          centerTitle: false,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.secondaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),

        // ── Barre de recherche ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: SearchBarWidget(
              onTap: () {
                // Navigation vers ecran de recherche a venir
              },
              onFilterTap: () {
                // Ouvrir filtres
              },
            ),
          ),
        ),

        // ── Chips types de bien ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FilterChipBar(
              labels: _typeFilters,
              selectedIndex: _selectedTypeIndex,
              onSelected: (index) {
                setState(() => _selectedTypeIndex = index);
              },
            ),
          ),
        ),

        // ── Section "Pres de vous" ──
        SliverToBoxAdapter(
          child: _buildSectionHeader(
            context,
            title: 'Pres de vous',
            onSeeAll: () {},
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredProperties.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final property = _filteredProperties[index];
                return PropertyCard(
                  property: property,
                  variant: PropertyCardVariant.horizontal,
                  onTap: () {
                    // TODO: naviguer vers le detail
                  },
                );
              },
            ),
          ),
        ),

        // ── Section "Quartiers populaires" ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildSectionHeader(
              context,
              title: 'Quartiers populaires',
              onSeeAll: () {},
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: AppConstants.popularQuarters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildQuarterCard(
                  context,
                  name: AppConstants.popularQuarters[index],
                  index: index,
                );
              },
            ),
          ),
        ),

        // ── Section "Annonces recentes" ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildSectionHeader(
              context,
              title: 'Annonces recentes',
              onSeeAll: () {},
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final sorted = List<Property>.from(_filteredProperties)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final property = sorted[index];
              return PropertyCard(
                property: property,
                variant: PropertyCardVariant.vertical,
                onTap: () {
                  // TODO: naviguer vers le detail
                },
              );
            },
            childCount: _filteredProperties.length,
          ),
        ),

        // Espacement en bas
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  // ── En-tete de section ──
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'Voir tout',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte quartier ──
  Widget _buildQuarterCard(
    BuildContext context, {
    required String name,
    required int index,
  }) {
    final colors = [
      const Color(0xFF2E7D5B),
      const Color(0xFFF5A623),
      const Color(0xFF1565C0),
      const Color(0xFFE65100),
      const Color(0xFF6A1B9A),
      const Color(0xFF00838F),
      const Color(0xFF2E7D32),
      const Color(0xFF795548),
      const Color(0xFF37474F),
      const Color(0xFFC62828),
    ];

    final icons = [
      Icons.apartment_rounded,
      Icons.location_city_rounded,
      Icons.business_rounded,
      Icons.home_work_rounded,
      Icons.villa_rounded,
      Icons.store_rounded,
      Icons.domain_rounded,
      Icons.holiday_village_rounded,
      Icons.maps_home_work_rounded,
      Icons.other_houses_rounded,
    ];

    final color = colors[index % colors.length];

    return GestureDetector(
      onTap: () {
        // TODO: filtrer par quartier
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icons[index % icons.length],
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
