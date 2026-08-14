import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/constants.dart';
import '../models/quarter.dart';

/// Fiches quartier.
///
/// Alimente la rangee « Quartiers populaires » de l'accueil et la section
/// « Decouvrir le quartier » de la fiche detail. Tant que la collection n'est
/// pas peuplee cote admin, on retombe sur la liste statique des constantes :
/// un accueil sans rangee de quartiers parait casse, alors qu'une rangee sans
/// photo reste utilisable.
class QuarterService {
  QuarterService._();
  static final QuarterService instance = QuarterService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('quarters');

  List<Quarter>? _cache;

  Future<List<Quarter>> fetchPopular({int limit = 10}) async {
    if (_cache != null) return _cache!;
    try {
      final snap = await _col
          .where('isPopular', isEqualTo: true)
          .orderBy('sortOrder')
          .limit(limit)
          .get();

      if (snap.docs.isEmpty) return _fallback(limit);

      _cache = snap.docs.map(Quarter.fromFirestore).toList();
      return _cache!;
    } catch (_) {
      return _fallback(limit);
    }
  }

  Future<Quarter?> fetchByName(String name) async {
    try {
      final snap =
          await _col.where('name', isEqualTo: name).limit(1).get();
      if (snap.docs.isEmpty) return null;
      return Quarter.fromFirestore(snap.docs.first);
    } catch (_) {
      return null;
    }
  }

  List<Quarter> _fallback(int limit) {
    return AppConstants.popularQuarters
        .take(limit)
        .toList()
        .asMap()
        .entries
        .map((e) => Quarter(
              id: e.value.toLowerCase(),
              name: e.value,
              isPopular: true,
              sortOrder: e.key,
            ))
        .toList();
  }

  void invalidateCache() => _cache = null;
}
