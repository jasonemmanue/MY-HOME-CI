import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/search_alert.dart';
import 'property_service.dart';

/// Alertes de recherche.
///
/// La correspondance elle-meme est calculee cote serveur : une Cloud Function
/// declenchee a la validation d'une annonce parcourt les alertes actives et
/// notifie. Le client ne fait que gerer le cycle de vie des criteres.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Plafond volontaire : chaque alerte est evaluee a chaque publication, le
  /// cout serveur croit lineairement.
  static const int maxAlertsPerUser = 10;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('users').doc(userId).collection('alerts');

  Stream<List<SearchAlert>> watch(String userId) {
    return _col(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(SearchAlert.fromFirestore).toList());
  }

  Future<List<SearchAlert>> fetch(String userId) async {
    final snap =
        await _col(userId).orderBy('createdAt', descending: true).get();
    return snap.docs.map(SearchAlert.fromFirestore).toList();
  }

  /// Cree une alerte a partir des filtres courants.
  ///
  /// Leve si le quota est atteint — le message remonte tel quel a l'ecran.
  Future<String> createFromFilters({
    required String userId,
    required PropertyFilters filters,
    String? label,
  }) async {
    final existing = await _col(userId).count().get();
    if ((existing.count ?? 0) >= maxAlertsPerUser) {
      throw StateError(
          'Vous avez atteint la limite de $maxAlertsPerUser alertes. '
          'Supprimez-en une avant d\'en creer une nouvelle.');
    }

    final alert = SearchAlert(
      id: '',
      label: label?.trim().isNotEmpty == true
          ? label!.trim()
          : _autoLabel(filters),
      type: filters.type,
      quarter: filters.quarter,
      city: filters.city,
      minPrice: filters.minPrice,
      maxPrice: filters.maxPrice,
      minRooms: filters.minRooms,
      isFurnished: filters.isFurnished,
      createdAt: DateTime.now(),
    );

    final ref = await _col(userId).add(alert.toFirestore());
    return ref.id;
  }

  String _autoLabel(PropertyFilters f) {
    final parts = <String>[];
    if (f.type != null) parts.add(f.type!);
    if (f.quarter != null) parts.add('a ${f.quarter}');
    if (f.maxPrice != null) parts.add('< ${f.maxPrice! ~/ 1000}k');
    return parts.isEmpty ? 'Nouvelle alerte' : parts.join(' ');
  }

  Future<void> setActive({
    required String userId,
    required String alertId,
    required bool isActive,
  }) async {
    await _col(userId).doc(alertId).update({'isActive': isActive});
  }

  Future<void> delete({
    required String userId,
    required String alertId,
  }) async {
    await _col(userId).doc(alertId).delete();
  }

  /// Convertit une alerte en filtres, pour rouvrir la recherche correspondante.
  PropertyFilters toFilters(SearchAlert alert) {
    return PropertyFilters(
      type: alert.type,
      quarter: alert.quarter,
      city: alert.city,
      minPrice: alert.minPrice,
      maxPrice: alert.maxPrice,
      minRooms: alert.minRooms,
      isFurnished: alert.isFurnished,
    );
  }
}
