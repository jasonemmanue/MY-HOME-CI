import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_home_ci/config/theme.dart';
import 'package:my_home_ci/models/property.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late List<Property> _favorites;

  static final NumberFormat _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    // Mock: use first 4 properties as "favorites"
    _favorites = List.from(
      Property.mockProperties.take(4),
    );
  }

  void _removeFavorite(int index) {
    final removed = _favorites[index];
    setState(() => _favorites.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.title} retire des favoris'),
        action: SnackBarAction(
          label: 'Annuler',
          textColor: AppTheme.secondaryOrange,
          onPressed: () {
            setState(() => _favorites.insert(index, removed));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris'),
      ),
      body: _favorites.isEmpty ? _buildEmptyState() : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 56,
                color: AppTheme.primaryGreen.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun favori pour l\'instant',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Parcourez les annonces et ajoutez vos logements preferes',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to explore / property list
                Navigator.pushReplacementNamed(context, '/properties');
              },
              icon: const Icon(Icons.explore, size: 18),
              label: const Text('Explorer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final property = _favorites[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey(property.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _removeFavorite(index),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
            child: _FavoriteCard(property: property),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
//  FAVORITE CARD
// ══════════════════════════════════════════════
class _FavoriteCard extends StatelessWidget {
  final Property property;

  const _FavoriteCard({required this.property});

  static final NumberFormat _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.primaryGreen.withValues(alpha: 0.3),
      AppTheme.secondaryOrange.withValues(alpha: 0.3),
      Colors.blue.withValues(alpha: 0.3),
      Colors.purple.withValues(alpha: 0.3),
    ];
    final color = colors[property.id.hashCode % colors.length];

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/property-detail',
        arguments: property,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppTheme.radiusDefault),
              ),
              child: Container(
                width: 110,
                height: 110,
                color: color,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.home_outlined,
                        size: 36,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    // Favorite heart
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.favorite,
                        size: 20,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${property.quarter}, ${property.city}',
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
                        if (property.rooms > 0) ...[
                          const Icon(Icons.bed_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('${property.rooms}',
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 10),
                        ],
                        const Icon(Icons.square_foot,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text('${property.surface.round()}m²',
                            style:
                                Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmt.format(property.price)} F CFA/mois',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
}
