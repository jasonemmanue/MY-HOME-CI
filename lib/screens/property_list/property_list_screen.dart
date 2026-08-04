import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_home_ci/config/theme.dart';
import 'package:my_home_ci/models/property.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  bool _isGridView = true;
  String _sortOption = 'Plus recent';
  List<Property> _properties = [];
  List<Property> _filteredProperties = [];

  // Filter state
  final Set<String> _selectedTypes = {};
  RangeValues _priceRange = const RangeValues(25000, 1000000);
  int? _selectedRooms;
  bool? _isFurnishedFilter;
  final Set<String> _selectedQuarters = {};

  final NumberFormat _priceFormat =
      NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    _properties = List.from(Property.mockProperties);
    _filteredProperties = List.from(_properties);
    _applySorting();
  }

  void _applySorting() {
    switch (_sortOption) {
      case 'Prix croissant':
        _filteredProperties.sort((a, b) => a.price.compareTo(b.price));
      case 'Prix decroissant':
        _filteredProperties.sort((a, b) => b.price.compareTo(a.price));
      case 'Plus proche':
        // Mock: no real location, keep current order
        break;
      default:
        _filteredProperties
            .sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProperties = _properties.where((p) {
        if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(p.type)) {
          return false;
        }
        if (p.price < _priceRange.start || p.price > _priceRange.end) {
          return false;
        }
        if (_selectedRooms != null) {
          if (_selectedRooms == 4) {
            if (p.rooms < 4) return false;
          } else if (p.rooms != _selectedRooms) {
            return false;
          }
        }
        if (_isFurnishedFilter != null &&
            p.isFurnished != _isFurnishedFilter) {
          return false;
        }
        if (_selectedQuarters.isNotEmpty &&
            !_selectedQuarters.contains(p.quarter)) {
          return false;
        }
        return true;
      }).toList();
      _applySorting();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedTypes.clear();
      _priceRange = const RangeValues(25000, 1000000);
      _selectedRooms = null;
      _isFurnishedFilter = null;
      _selectedQuarters.clear();
      _filteredProperties = List.from(_properties);
      _applySorting();
    });
  }

  void _showFilterSheet() {
    final types = [
      'Studio',
      'Appartement',
      'Villa',
      'Duplex',
      'Maison',
      'Chambre',
      'Bureau',
      'Terrain',
    ];

    final quarters = _properties.map((p) => p.quarter).toSet().toList()..sort();

    // Work with temporary state so cancel doesn't apply
    Set<String> tempTypes = Set.from(_selectedTypes);
    RangeValues tempPriceRange = _priceRange;
    int? tempRooms = _selectedRooms;
    bool? tempFurnished = _isFurnishedFilter;
    Set<String> tempQuarters = Set.from(_selectedQuarters);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Filtrer les logements',
                        style:
                            Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),

                      // Type de bien
                      Text(
                        'Type de bien',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: types.map((type) {
                          final selected = tempTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  tempTypes.add(type);
                                } else {
                                  tempTypes.remove(type);
                                }
                              });
                            },
                            selectedColor: AppTheme.primaryGreen
                                .withValues(alpha: 0.15),
                            checkmarkColor: AppTheme.primaryGreen,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppTheme.primaryGreen
                                  : null,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Fourchette de loyer
                      Text(
                        'Fourchette de loyer',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_priceFormat.format(tempPriceRange.start.round())} - '
                        '${_priceFormat.format(tempPriceRange.end.round())} F CFA',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      RangeSlider(
                        values: tempPriceRange,
                        min: 25000,
                        max: 1000000,
                        divisions: 39,
                        activeColor: AppTheme.primaryGreen,
                        inactiveColor:
                            AppTheme.primaryGreen.withValues(alpha: 0.2),
                        labels: RangeLabels(
                          '${_priceFormat.format(tempPriceRange.start.round())}',
                          '${_priceFormat.format(tempPriceRange.end.round())}',
                        ),
                        onChanged: (values) {
                          setModalState(() {
                            tempPriceRange = values;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Nombre de pieces
                      Text(
                        'Nombre de pieces',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [1, 2, 3, 4].map((n) {
                          final label = n == 4 ? '4+' : '$n';
                          final selected = tempRooms == n;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (val) {
                                setModalState(() {
                                  tempRooms = val ? n : null;
                                });
                              },
                              selectedColor: AppTheme.primaryGreen
                                  .withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: selected
                                    ? AppTheme.primaryGreen
                                    : null,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Meuble / Non meuble
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Meuble uniquement',
                            style:
                                Theme.of(context).textTheme.titleSmall,
                          ),
                          Switch(
                            value: tempFurnished ?? false,
                            activeColor: AppTheme.primaryGreen,
                            onChanged: (val) {
                              setModalState(() {
                                tempFurnished = val ? true : null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quartier
                      Text(
                        'Quartier',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quarters.map((q) {
                          final selected = tempQuarters.contains(q);
                          return FilterChip(
                            label: Text(q),
                            selected: selected,
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  tempQuarters.add(q);
                                } else {
                                  tempQuarters.remove(q);
                                }
                              });
                            },
                            selectedColor: AppTheme.primaryGreen
                                .withValues(alpha: 0.15),
                            checkmarkColor: AppTheme.primaryGreen,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppTheme.primaryGreen
                                  : null,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Buttons
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTypes
                              ..clear()
                              ..addAll(tempTypes);
                            _priceRange = tempPriceRange;
                            _selectedRooms = tempRooms;
                            _isFurnishedFilter = tempFurnished;
                            _selectedQuarters
                              ..clear()
                              ..addAll(tempQuarters);
                          });
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Appliquer les filtres'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reinitialiser'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logements'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterSheet,
            tooltip: 'Filtrer',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sort dropdown + count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredProperties.length} logements trouves',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                        color: Theme.of(context).dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortOption,
                      isDense: true,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      items: [
                        'Plus recent',
                        'Prix croissant',
                        'Prix decroissant',
                        'Plus proche',
                      ]
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _sortOption = val;
                            _applySorting();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Property list/grid
          Expanded(
            child: _filteredProperties.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun logement trouve',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Essayez de modifier vos filtres',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _filteredProperties.length,
                        itemBuilder: (context, index) {
                          return _PropertyCard(
                            property: _filteredProperties[index],
                            isGrid: true,
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProperties.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PropertyCard(
                              property: _filteredProperties[index],
                              isGrid: false,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  PROPERTY CARD
// ══════════════════════════════════════════════
class _PropertyCard extends StatelessWidget {
  final Property property;
  final bool isGrid;

  const _PropertyCard({required this.property, required this.isGrid});

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

    if (isGrid) {
      return _buildGridCard(context, color);
    }
    return _buildListCard(context, color);
  }

  Widget _buildGridCard(BuildContext context, Color color) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusDefault),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                color: color,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.home_outlined,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          property.type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (property.isFurnished)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryOrange,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall),
                          ),
                          child: const Text(
                            'Meuble',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.primaryGreen),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${property.quarter}, ${property.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (property.rooms > 0) ...[
                          const Icon(Icons.bed_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('${property.rooms}',
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.square_foot,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text('${property.surface.round()}m²',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmt.format(property.price)} F CFA/mois',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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

  Widget _buildListCard(BuildContext context, Color color) {
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
                width: 120,
                height: 120,
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
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          property.type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppTheme.primaryGreen),
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
                          Text('${property.rooms} ch',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 12),
                        ],
                        if (property.bathrooms > 0) ...[
                          const Icon(Icons.bathtub_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('${property.bathrooms} sdb',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 12),
                        ],
                        const Icon(Icons.square_foot,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text('${property.surface.round()}m²',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
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
