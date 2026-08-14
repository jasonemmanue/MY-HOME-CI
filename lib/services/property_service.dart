import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/property.dart';
import '../utils/geohash.dart';

/// Criteres de recherche. Regroupes dans un objet plutot qu'en parametres
/// nommes : ils circulent de l'ecran de filtres a la requete, sont compares
/// pour savoir s'il faut relancer une pagination, et sont serialises dans une
/// alerte de recherche.
class PropertyFilters {
  final String? query;
  final String? type;
  final String? quarter;
  final String? city;
  final int? minPrice;
  final int? maxPrice;
  final int? minRooms;
  final bool? isFurnished;
  final String sort; // recent | price_asc | price_desc | nearest

  const PropertyFilters({
    this.query,
    this.type,
    this.quarter,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.minRooms,
    this.isFurnished,
    this.sort = 'recent',
  });

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      type == null &&
      quarter == null &&
      city == null &&
      minPrice == null &&
      maxPrice == null &&
      minRooms == null &&
      isFurnished == null;

  /// Nombre de filtres actifs, pour la pastille du bouton « Filtres ».
  int get activeCount {
    var n = 0;
    if (type != null) n++;
    if (quarter != null) n++;
    if (city != null) n++;
    if (minPrice != null || maxPrice != null) n++;
    if (minRooms != null) n++;
    if (isFurnished != null) n++;
    return n;
  }

  PropertyFilters copyWith({
    String? query,
    String? type,
    String? quarter,
    String? city,
    int? minPrice,
    int? maxPrice,
    int? minRooms,
    bool? isFurnished,
    String? sort,
    bool clearType = false,
    bool clearQuarter = false,
    bool clearCity = false,
    bool clearPrice = false,
    bool clearRooms = false,
    bool clearFurnished = false,
    bool clearQuery = false,
  }) {
    return PropertyFilters(
      query: clearQuery ? null : (query ?? this.query),
      type: clearType ? null : (type ?? this.type),
      quarter: clearQuarter ? null : (quarter ?? this.quarter),
      city: clearCity ? null : (city ?? this.city),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      minRooms: clearRooms ? null : (minRooms ?? this.minRooms),
      isFurnished: clearFurnished ? null : (isFurnished ?? this.isFurnished),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PropertyFilters &&
      other.query == query &&
      other.type == type &&
      other.quarter == quarter &&
      other.city == city &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.minRooms == minRooms &&
      other.isFurnished == isFurnished &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
      query, type, quarter, city, minPrice, maxPrice, minRooms, isFurnished, sort);
}

/// Une page de resultats et le curseur permettant de demander la suivante.
class PropertyPage {
  final List<Property> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const PropertyPage({
    required this.items,
    this.cursor,
    required this.hasMore,
  });

  static const empty = PropertyPage(items: [], hasMore: false);
}

class PropertyService {
  PropertyService._();
  static final PropertyService instance = PropertyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int pageSize = 12;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('properties');

  // ── Lecture ─────────────────────────────────────────────────────────────

  /// Page d'annonces publiees correspondant aux [filters].
  ///
  /// Contrainte Firestore a garder en tete : une inegalite (`price >=`) et un
  /// `orderBy` sur un autre champ ne cohabitent pas. Quand une fourchette de
  /// prix est demandee avec un tri par date, on trie donc par prix cote
  /// serveur et on reordonne le lot en memoire. Acceptable a l'echelle d'une
  /// page ; ce serait faux sur un tri global, et c'est la limite a connaitre.
  Future<PropertyPage> fetchPage({
    PropertyFilters filters = const PropertyFilters(),
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> q =
        _col.where('status', isEqualTo: PropertyStatus.active.name);

    if (filters.type != null) {
      q = q.where('type', isEqualTo: filters.type);
    }
    if (filters.quarter != null) {
      q = q.where('quarter', isEqualTo: filters.quarter);
    }
    if (filters.city != null) {
      q = q.where('city', isEqualTo: filters.city);
    }
    if (filters.isFurnished != null) {
      q = q.where('isFurnished', isEqualTo: filters.isFurnished);
    }
    if (filters.minRooms != null) {
      q = q.where('rooms', isGreaterThanOrEqualTo: filters.minRooms);
    }

    final queryText = filters.query?.trim().toLowerCase();
    if (queryText != null && queryText.isNotEmpty) {
      final tokens = queryText
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 3)
          .take(10)
          .toList();
      if (tokens.isNotEmpty) {
        q = q.where('searchKeywords', arrayContainsAny: tokens);
      }
    }

    final hasPriceRange = filters.minPrice != null || filters.maxPrice != null;
    if (filters.minPrice != null) {
      q = q.where('price', isGreaterThanOrEqualTo: filters.minPrice);
    }
    if (filters.maxPrice != null) {
      q = q.where('price', isLessThanOrEqualTo: filters.maxPrice);
    }

    // Une inegalite impose que le premier orderBy porte sur le meme champ.
    final needsRoomsOrder = filters.minRooms != null && !hasPriceRange;
    if (hasPriceRange) {
      q = q.orderBy('price', descending: filters.sort == 'price_desc');
    } else if (needsRoomsOrder) {
      q = q.orderBy('rooms');
    } else {
      switch (filters.sort) {
        case 'price_asc':
          q = q.orderBy('price');
          break;
        case 'price_desc':
          q = q.orderBy('price', descending: true);
          break;
        default:
          q = q.orderBy('createdAt', descending: true);
      }
    }

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    // On demande un element de plus que la page : sa presence dit s'il reste
    // des resultats, sans requete de comptage supplementaire.
    final snap = await q.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    var items = pageDocs.map(Property.fromFirestore).toList();

    // Reordonnancement local quand le tri demande n'a pas pu etre applique
    // cote serveur.
    if (hasPriceRange && filters.sort == 'recent') {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Les annonces boostees remontent en tete de page.
    items = _boostedFirst(items);

    return PropertyPage(
      items: items,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  List<Property> _boostedFirst(List<Property> items) {
    final boosted = items.where((p) => p.isBoosted).toList();
    if (boosted.isEmpty) return items;
    final rest = items.where((p) => !p.isBoosted).toList();
    return [...boosted, ...rest];
  }

  /// Annonces les plus recentes, pour le carrousel de l'accueil.
  Future<List<Property>> fetchRecent({int limit = 10}) async {
    final snap = await _col
        .where('status', isEqualTo: PropertyStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Property.fromFirestore).toList();
  }

  /// Annonces dans un rayon autour d'un point.
  ///
  /// Firestore ne sait pas requeter un disque : on interroge les plages de
  /// geohash couvrant la zone (cellule centrale + huit voisines), puis on
  /// filtre a la distance exacte. Le surcout est reel — jusqu'a neuf requetes
  /// — mais c'est le seul moyen sans service tiers.
  Future<List<Property>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int limitPerBound = 20,
  }) async {
    final bounds = Geohash.queryBounds(latitude, longitude, radiusMeters);

    final futures = bounds.map((b) {
      return _col
          .where('status', isEqualTo: PropertyStatus.active.name)
          .orderBy('geohash')
          .startAt([b.start])
          .endAt([b.end])
          .limit(limitPerBound)
          .get();
    });

    final snapshots = await Future.wait(futures);

    // Les plages se recouvrent : on deduplique par id.
    final byId = <String, Property>{};
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        byId[doc.id] = Property.fromFirestore(doc);
      }
    }

    final withDistance = <MapEntry<Property, double>>[];
    for (final p in byId.values) {
      if (!p.hasLocation) continue;
      final d = Geohash.distanceBetween(
          latitude, longitude, p.latitude!, p.longitude!);
      if (d <= radiusMeters) {
        withDistance.add(MapEntry(p, d));
      }
    }

    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance.map((e) => e.key).toList();
  }

  Future<Property?> fetchById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Property.fromFirestore(doc);
  }

  Stream<Property?> watchById(String id) {
    return _col
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Property.fromFirestore(doc) : null);
  }

  /// Toutes les annonces d'un proprietaire, quel que soit leur statut.
  Stream<List<Property>> watchByOwner(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Property.fromFirestore).toList());
  }

  /// Annonces correspondant a une liste d'identifiants (favoris).
  ///
  /// `whereIn` plafonne a 30 valeurs : on decoupe en lots.
  Future<List<Property>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 30) {
      chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }

    final results = await Future.wait(
      chunks.map((c) => _col.where(FieldPath.documentId, whereIn: c).get()),
    );

    final byId = <String, Property>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        byId[doc.id] = Property.fromFirestore(doc);
      }
    }

    // On restitue l'ordre des favoris, pas celui de Firestore.
    return ids
        .map((id) => byId[id])
        .whereType<Property>()
        .toList();
  }

  // ── Ecriture ────────────────────────────────────────────────────────────

  /// Cree une annonce et renvoie son identifiant.
  Future<String> create(Property property) async {
    final ref = await _col.add(property.toFirestoreForCreate());
    return ref.id;
  }

  Future<void> update(Property property) async {
    if (property.id.isEmpty) {
      throw ArgumentError('Impossible de mettre a jour une annonce sans id.');
    }
    await _col.doc(property.id).update(property.toFirestore());
  }

  /// Cree ou met a jour selon que l'annonce a deja un id.
  Future<String> save(Property property) async {
    if (property.id.isEmpty) return create(property);
    await update(property);
    return property.id;
  }

  /// Soumet l'annonce a la moderation.
  ///
  /// Le passage a `active` est fait par l'administration, jamais ici : c'est
  /// tout l'objet de la moderation a priori.
  Future<void> submitForReview(String id) async {
    await _col.doc(id).update({
      'status': PropertyStatus.pending.name,
      'rejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRented(String id) async {
    await _col.doc(id).update({
      'status': PropertyStatus.rented.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archive(String id) async {
    await _col.doc(id).update({
      'status': PropertyStatus.archived.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remet une annonce louee ou archivee dans le circuit de moderation.
  Future<void> republish(String id) async {
    await _col.doc(id).update({
      'status': PropertyStatus.pending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// Incremente le compteur de vues.
  ///
  /// Deduplique par l'appelant (cf. `PropertyProvider`) : sans cela, chaque
  /// reconstruction de l'ecran de detail compterait une vue de plus et le
  /// chiffre affiche au proprietaire n'aurait aucun sens.
  Future<void> incrementViews(String id) async {
    try {
      await _col.doc(id).update({'views': FieldValue.increment(1)});
    } catch (_) {
      // Un compteur de vues n'est pas critique : on n'interrompt pas la
      // consultation de l'annonce si l'increment echoue.
    }
  }

  Future<void> incrementFavorites(String id, int delta) async {
    try {
      await _col.doc(id).update({'favoritesCount': FieldValue.increment(delta)});
    } catch (_) {}
  }
}
