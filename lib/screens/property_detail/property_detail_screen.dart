import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_home_ci/config/theme.dart';
import 'package:my_home_ci/models/property.dart';
import 'package:my_home_ci/widgets/quarter_info_card.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFavorite = false;

  static final NumberFormat _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  IconData _equipmentIcon(String equipment) {
    final lower = equipment.toLowerCase();
    if (lower.contains('climatisation')) return Icons.ac_unit;
    if (lower.contains('piscine')) return Icons.pool;
    if (lower.contains('parking') || lower.contains('garage')) {
      return Icons.local_parking;
    }
    if (lower.contains('gardien') || lower.contains('securite')) {
      return Icons.security;
    }
    if (lower.contains('wifi') || lower.contains('internet')) return Icons.wifi;
    if (lower.contains('cuisine')) return Icons.kitchen;
    if (lower.contains('balcon')) return Icons.balcony;
    if (lower.contains('jardin') || lower.contains('cour')) {
      return Icons.yard;
    }
    if (lower.contains('ascenseur')) return Icons.elevator;
    if (lower.contains('eau')) return Icons.water_drop;
    if (lower.contains('electr') || lower.contains('generateur')) {
      return Icons.bolt;
    }
    if (lower.contains('meuble')) return Icons.chair;
    if (lower.contains('ventilateur')) return Icons.air;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final property =
        ModalRoute.of(context)!.settings.arguments as Property;
    final photoColors = [
      AppTheme.primaryGreen.withValues(alpha: 0.4),
      AppTheme.secondaryOrange.withValues(alpha: 0.4),
      Colors.blue.withValues(alpha: 0.4),
      Colors.purple.withValues(alpha: 0.4),
    ];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero image area ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: property.images.length.clamp(1, 10),
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemBuilder: (context, index) {
                          return Container(
                            color: photoColors[
                                index % photoColors.length],
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 56,
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Photo ${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Page indicator
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            property.images.length.clamp(1, 10),
                            (i) => Container(
                              width: _currentPage == i ? 24 : 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: _currentPage == i
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        property.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price
                      Text(
                        '${_fmt.format(property.price)} F CFA / mois',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 18, color: AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${property.quarter}, ${property.city}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryLight,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Key stats row
                      Row(
                        children: [
                          if (property.rooms > 0)
                            Expanded(
                              child: _StatCard(
                                icon: Icons.bed_outlined,
                                value: '${property.rooms}',
                                label: 'Pieces',
                              ),
                            ),
                          if (property.bathrooms > 0)
                            Expanded(
                              child: _StatCard(
                                icon: Icons.bathtub_outlined,
                                value: '${property.bathrooms}',
                                label: 'Sdb',
                              ),
                            ),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.square_foot,
                              value: '${property.surface.round()}',
                              label: 'm²',
                            ),
                          ),
                          if (property.floor > 0)
                            Expanded(
                              child: _StatCard(
                                icon: Icons.stairs,
                                value: '${property.floor}',
                                label: 'Etage',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      _SectionTitle(title: 'Description'),
                      const SizedBox(height: 8),
                      Text(
                        property.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Caracteristiques
                      _SectionTitle(title: 'Caracteristiques'),
                      const SizedBox(height: 12),
                      _CharacteristicRow(
                        label: 'Type de bien',
                        value: property.type,
                      ),
                      _CharacteristicRow(
                        label: 'Meuble',
                        value: property.isFurnished ? 'Oui' : 'Non',
                      ),
                      _CharacteristicRow(
                        label: 'Disponibilite',
                        value: property.isActive
                            ? 'Disponible'
                            : 'Indisponible',
                        valueColor: property.isActive
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                      const SizedBox(height: 24),

                      // Equipements
                      if (property.equipment.isNotEmpty) ...[
                        _SectionTitle(title: 'Equipements'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: property.equipment.map((e) {
                            return Chip(
                              avatar: Icon(
                                _equipmentIcon(e),
                                size: 16,
                                color: AppTheme.primaryGreen,
                              ),
                              label: Text(
                                e,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: AppTheme.primaryGreen
                                  .withValues(alpha: 0.08),
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Localisation
                      _SectionTitle(title: 'Localisation'),
                      const SizedBox(height: 12),
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusDefault),
                          border: Border.all(
                            color: AppTheme.primaryGreen
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 40,
                              color: AppTheme.primaryGreen
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              property.address,
                              style: TextStyle(
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Carte bientot disponible',
                              style: TextStyle(
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // A propos du quartier
                      _SectionTitle(title: 'A propos du quartier'),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                        children: const [
                          QuarterInfoCard(
                            icon: Icons.school,
                            label: 'Ecoles',
                            count: '3 a proximite',
                          ),
                          QuarterInfoCard(
                            icon: Icons.shopping_bag,
                            label: 'Commerces',
                            count: '5 a proximite',
                          ),
                          QuarterInfoCard(
                            icon: Icons.local_pharmacy,
                            label: 'Pharmacies',
                            count: '2 a proximite',
                          ),
                          QuarterInfoCard(
                            icon: Icons.directions_bus,
                            label: 'Transports',
                            count: '4 lignes',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Proprietaire
                      _SectionTitle(title: 'Proprietaire'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusDefault),
                          border: Border.all(
                              color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.primaryGreen
                                  .withValues(alpha: 0.15),
                              child: Text(
                                property.ownerName.isNotEmpty
                                    ? property.ownerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        property.ownerName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      if (true) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '2 annonces',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating top buttons ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _CircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.share_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Partage bientot disponible')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _CircleButton(
                  icon: _isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  iconColor: _isFavorite ? Colors.red : null,
                  onTap: () =>
                      setState(() => _isFavorite = !_isFavorite),
                ),
              ],
            ),
          ),

          // ── Bottom contact bar ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Messagerie bientot disponible'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline,
                          size: 18),
                      label: const Text('Contacter le proprietaire'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusDefault),
                      border: Border.all(color: AppTheme.primaryGreen),
                    ),
                    child: IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Appel vers ${property.ownerPhone}'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.phone,
                          color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  INTERNAL WIDGETS
// ══════════════════════════════════════════════

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 22),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppTheme.primaryGreen),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _CharacteristicRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _CharacteristicRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
