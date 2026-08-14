import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'property_service.dart';

/// Favoris, avec un mode invite.
///
/// Le cahier des charges autorise la consultation sans compte ; refuser le
/// favori a un visiteur le pousserait a quitter l'application au moment ou il
/// s'y interesse. On stocke donc localement, puis on remonte ces favoris dans
/// Firestore a la premiere connexion ([migrateGuestFavorites]).
class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _guestKey = 'guest_favorites';

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('users').doc(userId).collection('favorites');

  // ── Utilisateur connecte ────────────────────────────────────────────────

  Stream<Set<String>> watchIds(String userId) {
    return _col(userId)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<Set<String>> fetchIds(String userId) async {
    final snap = await _col(userId).get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Future<void> add(String userId, String propertyId) async {
    await _col(userId).doc(propertyId).set({
      'addedAt': FieldValue.serverTimestamp(),
    });
    await PropertyService.instance.incrementFavorites(propertyId, 1);
  }

  Future<void> remove(String userId, String propertyId) async {
    await _col(userId).doc(propertyId).delete();
    await PropertyService.instance.incrementFavorites(propertyId, -1);
  }

  /// Bascule le favori et renvoie l'etat resultant.
  Future<bool> toggle(String userId, String propertyId) async {
    final doc = await _col(userId).doc(propertyId).get();
    if (doc.exists) {
      await remove(userId, propertyId);
      return false;
    }
    await add(userId, propertyId);
    return true;
  }

  /// Favoris ordonnes du plus recemment ajoute au plus ancien.
  Future<List<String>> fetchIdsOrdered(String userId) async {
    final snap =
        await _col(userId).orderBy('addedAt', descending: true).get();
    return snap.docs.map((d) => d.id).toList();
  }

  // ── Mode invite ─────────────────────────────────────────────────────────

  Future<Set<String>> guestIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_guestKey) ?? const <String>[]).toSet();
  }

  Future<bool> toggleGuest(String propertyId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_guestKey) ?? <String>[]).toList();
    final wasFavorite = current.remove(propertyId);
    if (!wasFavorite) current.insert(0, propertyId);
    await prefs.setStringList(_guestKey, current);
    return !wasFavorite;
  }

  /// Remonte les favoris locaux dans le compte, puis vide le stockage local.
  ///
  /// Appele apres chaque connexion reussie. Sans cela, un visiteur qui
  /// s'inscrit perdrait tout ce qu'il a mis de cote avant de creer son compte.
  Future<int> migrateGuestFavorites(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getStringList(_guestKey) ?? const <String>[];
    if (local.isEmpty) return 0;

    final batch = _db.batch();
    for (final id in local) {
      batch.set(
        _col(userId).doc(id),
        {'addedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    await prefs.remove(_guestKey);
    return local.length;
  }
}
