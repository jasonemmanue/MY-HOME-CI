import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/favorites_service.dart';

/// Favoris de l'utilisateur courant, connecte ou visiteur.
///
/// L'ensemble complet des identifiants est garde en memoire pour que chaque
/// carte d'annonce sache instantanement si elle est en favori. Interroger
/// Firestore par carte multiplierait les lectures sans rien apporter.
class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _service = FavoritesService.instance;

  Set<String> _ids = {};
  String? _uid;
  StreamSubscription<Set<String>>? _sub;

  Set<String> get ids => _ids;
  int get count => _ids.length;

  bool isFavorite(String propertyId) => _ids.contains(propertyId);

  /// Rebranche la source selon l'utilisateur connecte.
  /// [uid] a `null` bascule sur les favoris locaux du mode visiteur.
  Future<void> bind(String? uid) async {
    if (_uid == uid) return;
    _uid = uid;
    await _sub?.cancel();
    _sub = null;

    if (uid == null) {
      _ids = await _service.guestIds();
      notifyListeners();
      return;
    }

    _sub = _service.watchIds(uid).listen((ids) {
      _ids = ids;
      notifyListeners();
    });
  }

  /// Bascule le favori. Renvoie l'etat resultant.
  ///
  /// L'ensemble local est mis a jour immediatement : attendre l'aller-retour
  /// Firestore ferait clignoter le coeur pendant une seconde sur une
  /// connexion lente.
  Future<bool> toggle(String propertyId) async {
    final willBeFavorite = !_ids.contains(propertyId);

    if (willBeFavorite) {
      _ids = {..._ids, propertyId};
    } else {
      _ids = {..._ids}..remove(propertyId);
    }
    notifyListeners();

    try {
      if (_uid == null) {
        return await _service.toggleGuest(propertyId);
      }
      return await _service.toggle(_uid!, propertyId);
    } catch (_) {
      // Retour a l'etat anterieur si l'ecriture echoue.
      if (willBeFavorite) {
        _ids = {..._ids}..remove(propertyId);
      } else {
        _ids = {..._ids, propertyId};
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Identifiants ordonnes du plus recemment ajoute au plus ancien.
  Future<List<String>> orderedIds() async {
    if (_uid == null) return _ids.toList();
    return _service.fetchIdsOrdered(_uid!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
