import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/property.dart';
import '../services/analytics_service.dart';
import '../services/property_service.dart';

/// Etat de la recherche d'annonces : filtres, pagination, chargement.
///
/// Un seul provider pour la liste et la carte : les deux partagent les memes
/// filtres, et les separer obligerait a synchroniser deux etats qui doivent
/// rester identiques.
class PropertyProvider extends ChangeNotifier {
  final PropertyService _service = PropertyService.instance;

  final List<Property> _items = [];
  PropertyFilters _filters = const PropertyFilters();

  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  /// Annonces dont la vue a deja ete comptee dans cette session, pour ne pas
  /// incrementer le compteur a chaque reconstruction de la fiche detail.
  final Set<String> _countedViews = {};

  List<Property> get items => List.unmodifiable(_items);
  PropertyFilters get filters => _filters;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;

  /// Recharge depuis le debut. A appeler au premier affichage et sur
  /// « tirer pour rafraichir ».
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _service.fetchPage(filters: _filters);
      _items
        ..clear()
        ..addAll(page.items);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge la page suivante. Sans effet si une page est deja en vol ou si
  /// la fin des resultats est atteinte.
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.fetchPage(
        filters: _filters,
        startAfter: _cursor,
      );
      _items.addAll(page.items);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Remplace les filtres et relance la recherche.
  Future<void> applyFilters(PropertyFilters filters) async {
    if (filters == _filters) return;
    _filters = filters;
    await refresh();

    if (filters.query?.trim().isNotEmpty ?? false) {
      await AnalyticsService.instance.logSearch(
        query: filters.query!.trim(),
        type: filters.type,
        quarter: filters.quarter,
        resultCount: _items.length,
      );
    }
  }

  Future<void> setSort(String sort) =>
      applyFilters(_filters.copyWith(sort: sort));

  Future<void> setQuery(String? query) => applyFilters(
        (query == null || query.trim().isEmpty)
            ? _filters.copyWith(clearQuery: true)
            : _filters.copyWith(query: query.trim()),
      );

  Future<void> setType(String? type) => applyFilters(
        type == null
            ? _filters.copyWith(clearType: true)
            : _filters.copyWith(type: type),
      );

  Future<void> setQuarter(String? quarter) => applyFilters(
        quarter == null
            ? _filters.copyWith(clearQuarter: true)
            : _filters.copyWith(quarter: quarter),
      );

  Future<void> clearFilters() => applyFilters(
        PropertyFilters(sort: _filters.sort, query: _filters.query),
      );

  /// Compte une vue, au plus une fois par annonce et par session.
  void countView(Property property) {
    if (_countedViews.contains(property.id)) return;
    _countedViews.add(property.id);
    _service.incrementViews(property.id);
    AnalyticsService.instance.logViewProperty(
      propertyId: property.id,
      type: property.type,
      price: property.price,
      quarter: property.quarter,
    );
  }

  String _friendlyError(Object e) {
    final message = e.toString();
    if (message.contains('failed-precondition') ||
        message.contains('requires an index')) {
      // Cas classique en developpement : un index compose manque encore.
      return 'Recherche indisponible : un index Firestore est en cours de '
          'creation. Reessayez dans quelques minutes.';
    }
    if (message.contains('unavailable') ||
        message.contains('network') ||
        message.contains('SocketException')) {
      return 'Connexion indisponible. Verifiez votre reseau.';
    }
    return 'Impossible de charger les annonces pour le moment.';
  }
}
