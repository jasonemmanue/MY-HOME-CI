import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/property_provider.dart';
import '../../services/alert_service.dart';
import '../../services/property_service.dart';
import '../../widgets/property_card.dart';
import '../property_detail/property_detail_screen.dart';

class PropertyListArgs {
  final String? title;
  const PropertyListArgs({this.title});
}

/// Catalogue des annonces : recherche, filtres, tri, pagination infinie.
class PropertyListScreen extends StatefulWidget {
  final PropertyListArgs? args;

  const PropertyListScreen({super.key, this.args});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final provider = context.read<PropertyProvider>();
    _searchController.text = provider.filters.query ?? '';

    // Le provider est partagé avec l'accueil et la carte : il porte peut-être
    // déjà des résultats correspondant aux filtres qu'on vient d'appliquer.
    // On ne recharge que s'il est vide, pour ne pas refaire une requête juste
    // après celle déclenchée par l'écran appelant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.items.isEmpty && !provider.isLoading) {
        provider.refresh();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Déclenche le chargement de la page suivante avant d'atteindre le bas,
  /// pour que la liste ne marque pas d'arrêt visible.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      context.read<PropertyProvider>().loadMore();
    }
  }

  Future<void> _openFilters() async {
    final provider = context.read<PropertyProvider>();
    final result = await showModalBottomSheet<PropertyFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FilterSheet(initial: provider.filters),
    );
    if (result != null) provider.applyFilters(result);
  }

  Future<void> _openSort() async {
    final provider = context.read<PropertyProvider>();
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        // RadioGroup porte desormais la valeur selectionnee et le rappel de
        // changement ; les poser sur chaque RadioListTile est deprecie.
        child: RadioGroup<String>(
          groupValue: provider.filters.sort,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.sortOptions.entries
                // Le tri par distance suppose une position connue : il vit sur
                // l'écran carte, pas ici.
                .where((e) => e.key != 'nearest')
                .map(
                  (e) => RadioListTile<String>(
                    value: e.key,
                    title: Text(e.value,
                        style: GoogleFonts.inter(fontSize: 14)),
                    activeColor: AppTheme.primaryGreen,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (result != null) provider.setSort(result);
  }

  Future<void> _saveAsAlert() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<PropertyProvider>();

    if (!auth.isSignedIn) {
      _snack('Connectez-vous pour enregistrer une alerte.');
      return;
    }
    if (provider.filters.activeCount == 0) {
      _snack('Appliquez au moins un filtre avant d\'enregistrer une alerte.');
      return;
    }

    try {
      await AlertService.instance.createFromFilters(
        userId: auth.uid!,
        filters: provider.filters,
      );
      _snack('Alerte creee. Vous serez prevenu des nouvelles annonces '
          'correspondantes.');
    } on StateError catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Creation de l\'alerte impossible.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropertyProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.args?.title ?? 'Logements',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: _isGrid ? 'Affichage liste' : 'Affichage grille',
            icon: Icon(_isGrid ? Icons.view_list_outlined : Icons.grid_view,
                size: 22),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
          IconButton(
            tooltip: 'Enregistrer en alerte',
            icon: const Icon(Icons.notification_add_outlined, size: 22),
            onPressed: _saveAsAlert,
          ),
        ],
      ),
      body: Column(
        children: [
          _searchField(isDark),
          _toolbar(provider, isDark),
          Expanded(child: _results(provider)),
        ],
      ),
    );
  }

  Widget _searchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) =>
            context.read<PropertyProvider>().setQuery(value),
        decoration: InputDecoration(
          hintText: 'Quartier, type de bien…',
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    context.read<PropertyProvider>().setQuery(null);
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: isDark ? AppTheme.cardDark : const Color(0xFFF0F3F1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _toolbar(PropertyProvider provider, bool isDark) {
    final activeCount = provider.filters.activeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              activeCount == 0 ? 'Filtres' : 'Filtres ($activeCount)',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  activeCount == 0 ? null : AppTheme.primaryGreen,
              side: BorderSide(
                color: activeCount == 0
                    ? (isDark ? AppTheme.dividerDark : AppTheme.dividerLight)
                    : AppTheme.primaryGreen,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _openSort,
            icon: const Icon(Icons.swap_vert_rounded, size: 18),
            label: Text(
              AppConstants.sortOptions[provider.filters.sort] ?? 'Trier',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          const Spacer(),
          if (activeCount > 0)
            TextButton(
              onPressed: provider.clearFilters,
              child: Text('Effacer',
                  style: GoogleFonts.inter(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  Widget _results(PropertyProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.items.isEmpty) {
      return _state(
        Icons.cloud_off_outlined,
        provider.error!,
        actionLabel: 'Reessayer',
        onAction: provider.refresh,
      );
    }

    if (provider.items.isEmpty) {
      return _state(
        Icons.search_off_rounded,
        'Aucun logement ne correspond a votre recherche.\n\n'
        'Essayez d\'elargir vos criteres ou de changer de quartier.',
        actionLabel: provider.filters.activeCount > 0 ? 'Effacer les filtres' : null,
        onAction: provider.filters.activeCount > 0
            ? provider.clearFilters
            : null,
      );
    }

    // Un élément supplémentaire porte l'indicateur de chargement de la page
    // suivante ou le message de fin de liste.
    final itemCount = provider.items.length + 1;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: _isGrid
          ? GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: itemCount,
              itemBuilder: (context, i) {
                if (i >= provider.items.length) {
                  return _footer(provider);
                }
                return _card(provider, i);
              },
            )
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i >= provider.items.length) {
                  return _footer(provider);
                }
                return SizedBox(
                  height: 268,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _card(provider, i, horizontal: true),
                  ),
                );
              },
            ),
    );
  }

  Widget _card(PropertyProvider provider, int index,
      {bool horizontal = false}) {
    final property = provider.items[index];
    return PropertyCard(
      property: property,
      variant: horizontal
          ? PropertyCardVariant.horizontal
          : PropertyCardVariant.vertical,
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.propertyDetail,
        arguments: PropertyDetailArgs.of(property),
      ),
    );
  }

  Widget _footer(PropertyProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!provider.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '${provider.items.length} logement(s) — fin des resultats',
            style: GoogleFonts.inter(
                fontSize: 12.5, color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    return const SizedBox(height: 40);
  }

  Widget _state(
    IconData icon,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel,
                    style: GoogleFonts.inter(fontSize: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Feuille de filtres avancés.
class _FilterSheet extends StatefulWidget {
  final PropertyFilters initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _type = widget.initial.type;
  late String? _quarter = widget.initial.quarter;
  late int? _minRooms = widget.initial.minRooms;
  late bool? _isFurnished = widget.initial.isFurnished;
  late RangeValues _priceRange = RangeValues(
    (widget.initial.minPrice ?? AppConstants.minPrice).toDouble(),
    (widget.initial.maxPrice ?? 1000000).toDouble(),
  );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text('Filtres',
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _label('Type de bien'),
                _chips(
                  values: AppConstants.propertyTypes,
                  selected: _type,
                  onSelected: (v) => setState(() => _type = v),
                ),
                const SizedBox(height: 20),
                _label('Quartier'),
                _chips(
                  values: AppConstants.popularQuarters,
                  selected: _quarter,
                  onSelected: (v) => setState(() => _quarter = v),
                ),
                const SizedBox(height: 20),
                _label('Loyer mensuel'),
                RangeSlider(
                  values: _priceRange,
                  min: AppConstants.minPrice.toDouble(),
                  max: 1000000,
                  divisions: 40,
                  activeColor: AppTheme.primaryGreen,
                  labels: RangeLabels(
                    AppConstants.formatPrice(_priceRange.start.round()),
                    AppConstants.formatPrice(_priceRange.end.round()),
                  ),
                  onChanged: (v) => setState(() => _priceRange = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppConstants.formatPrice(_priceRange.start.round()),
                        style: GoogleFonts.inter(fontSize: 12.5)),
                    Text(AppConstants.formatPrice(_priceRange.end.round()),
                        style: GoogleFonts.inter(fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 20),
                _label('Nombre de pieces (minimum)'),
                _chips(
                  values: const ['1', '2', '3', '4', '5'],
                  selected: _minRooms?.toString(),
                  onSelected: (v) =>
                      setState(() => _minRooms = v == null ? null : int.parse(v)),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isFurnished ?? false,
                  activeThumbColor: AppTheme.primaryGreen,
                  title: Text('Meuble uniquement',
                      style: GoogleFonts.inter(fontSize: 14)),
                  onChanged: (v) => setState(() => _isFurnished = v ? true : null),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _type = null;
                        _quarter = null;
                        _minRooms = null;
                        _isFurnished = null;
                        _priceRange = RangeValues(
                            AppConstants.minPrice.toDouble(), 1000000);
                      }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Reinitialiser',
                          style: GoogleFonts.inter(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        PropertyFilters(
                          query: widget.initial.query,
                          sort: widget.initial.sort,
                          type: _type,
                          quarter: _quarter,
                          minRooms: _minRooms,
                          isFurnished: _isFurnished,
                          // Une borne laissée à sa valeur extrême n'est pas un
                          // filtre : l'envoyer ajouterait une inégalité inutile
                          // qui contraindrait le tri côté Firestore.
                          minPrice:
                              _priceRange.start > AppConstants.minPrice
                                  ? _priceRange.start.round()
                                  : null,
                          maxPrice: _priceRange.end < 1000000
                              ? _priceRange.end.round()
                              : null,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Appliquer',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _chips({
    required List<String> values,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = selected == value;
        return ChoiceChip(
          label: Text(value, style: GoogleFonts.inter(fontSize: 13)),
          selected: isSelected,
          selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.18),
          onSelected: (_) => onSelected(isSelected ? null : value),
        );
      }).toList(),
    );
  }
}
