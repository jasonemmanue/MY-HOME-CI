import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/geohash.dart';

/// Cycle de vie d'une annonce.
///
/// `pending` existe parce que la moderation est a priori : une annonce publiee
/// n'est visible du public qu'apres validation admin. C'est le prix a payer
/// pour la promesse « moins d'arnaques » du cahier des charges.
enum PropertyStatus {
  draft,
  pending,
  active,
  rented,
  archived,
  rejected;

  static PropertyStatus fromString(String? value) {
    return PropertyStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PropertyStatus.draft,
    );
  }

  String get label {
    switch (this) {
      case PropertyStatus.draft:
        return 'Brouillon';
      case PropertyStatus.pending:
        return 'En attente';
      case PropertyStatus.active:
        return 'Active';
      case PropertyStatus.rented:
        return 'Louee';
      case PropertyStatus.archived:
        return 'Archivee';
      case PropertyStatus.rejected:
        return 'Rejetee';
    }
  }
}

class Property {
  final String id;
  final String title;
  final String type;
  final String description;
  final int price;
  final String address;
  final String quarter;
  final String city;

  /// Coordonnees du bien. Nullable : un brouillon peut ne pas encore etre
  /// localise, mais la publication les exige (cf. [isPublishable]).
  final double? latitude;
  final double? longitude;

  /// Prefixe geospatial derive de (latitude, longitude). Recalcule a chaque
  /// ecriture par [copyWith] / [toFirestore] — jamais saisi a la main.
  final String? geohash;

  final double surface;
  final int rooms;
  final int bathrooms;
  final int floor;
  final bool isFurnished;
  final List<String> equipment;
  final List<String> images;

  final String ownerId;
  final String ownerName;
  final String? ownerPhotoUrl;
  final bool ownerIsVerified;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  final PropertyStatus status;
  final int views;
  final int favoritesCount;

  /// Fin de la mise en avant payante. Ecrit uniquement par les Cloud
  /// Functions apres paiement — les regles Firestore interdisent au client
  /// d'y toucher.
  final DateTime? boostedUntil;

  /// Fin de la fenetre de visibilite de 30 jours.
  ///
  /// Posee par la Cloud Function apres decompte du quota de publication, et
  /// interdite au client par les regles Firestore : pouvoir l'ecrire
  /// reviendrait a prolonger sa visibilite sans payer. Pendant la fenetre, le
  /// proprietaire modifie son annonce autant qu'il veut ; une fois echue,
  /// l'annonce est archivee et sa republication consomme une nouvelle unite.
  final DateTime? visibleUntil;

  /// Motif de rejet renseigne par la moderation, affiche au proprietaire.
  final String? rejectionReason;

  /// Mots-cles minuscules pour la recherche `array-contains`.
  final List<String> searchKeywords;

  const Property({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.price,
    required this.address,
    required this.quarter,
    required this.city,
    this.latitude,
    this.longitude,
    this.geohash,
    required this.surface,
    required this.rooms,
    required this.bathrooms,
    this.floor = 0,
    this.isFurnished = false,
    this.equipment = const [],
    this.images = const [],
    required this.ownerId,
    required this.ownerName,
    this.ownerPhotoUrl,
    this.ownerIsVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.status = PropertyStatus.draft,
    this.views = 0,
    this.favoritesCount = 0,
    this.boostedUntil,
    this.visibleUntil,
    this.rejectionReason,
    this.searchKeywords = const [],
  });

  // ── Etats derives ───────────────────────────────────────────────────────

  bool get isActive => status == PropertyStatus.active;

  bool get isBoosted =>
      boostedUntil != null && boostedUntil!.isAfter(DateTime.now());

  /// La fenetre de visibilite court-elle encore ?
  bool get isVisibilityActive =>
      visibleUntil != null && visibleUntil!.isAfter(DateTime.now());

  /// Jours restants avant expiration, `null` hors fenetre.
  int? get visibilityDaysLeft {
    if (!isVisibilityActive) return null;
    return visibleUntil!.difference(DateTime.now()).inDays;
  }

  bool get hasLocation => latitude != null && longitude != null;

  /// Une annonce ne part en moderation que si elle est complete. Verifie ici
  /// plutot que dans l'ecran : la meme regle sert au brouillon repris plus tard.
  bool get isPublishable =>
      title.trim().length >= 5 &&
      description.trim().length >= 20 &&
      price > 0 &&
      hasLocation &&
      images.isNotEmpty &&
      quarter.isNotEmpty;

  /// Premiere image, ou null si l'annonce n'en a pas encore.
  String? get coverImage => images.isEmpty ? null : images.first;

  // ── Serialisation ───────────────────────────────────────────────────────

  factory Property.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Property(
      id: doc.id,
      title: d['title'] as String? ?? '',
      type: d['type'] as String? ?? '',
      description: d['description'] as String? ?? '',
      price: (d['price'] as num?)?.toInt() ?? 0,
      address: d['address'] as String? ?? '',
      quarter: d['quarter'] as String? ?? '',
      city: d['city'] as String? ?? 'Abidjan',
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      geohash: d['geohash'] as String?,
      surface: (d['surface'] as num?)?.toDouble() ?? 0,
      rooms: (d['rooms'] as num?)?.toInt() ?? 0,
      bathrooms: (d['bathrooms'] as num?)?.toInt() ?? 0,
      floor: (d['floor'] as num?)?.toInt() ?? 0,
      isFurnished: d['isFurnished'] as bool? ?? false,
      equipment: List<String>.from(d['equipment'] as List? ?? const []),
      images: List<String>.from(d['images'] as List? ?? const []),
      ownerId: d['ownerId'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      ownerPhotoUrl: d['ownerPhotoUrl'] as String?,
      ownerIsVerified: d['ownerIsVerified'] as bool? ?? false,
      createdAt: _toDate(d['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(d['updatedAt']),
      publishedAt: _toDate(d['publishedAt']),
      status: PropertyStatus.fromString(d['status'] as String?),
      views: (d['views'] as num?)?.toInt() ?? 0,
      favoritesCount: (d['favoritesCount'] as num?)?.toInt() ?? 0,
      boostedUntil: _toDate(d['boostedUntil']),
      visibleUntil: _toDate(d['visibleUntil']),
      rejectionReason: d['rejectionReason'] as String?,
      searchKeywords:
          List<String>.from(d['searchKeywords'] as List? ?? const []),
    );
  }

  /// Payload d'ecriture.
  ///
  /// `views`, `favoritesCount`, `boostedUntil` et `visibleUntil` sont
  /// volontairement absents : les compteurs se manipulent par
  /// `FieldValue.increment`, le boost et la fenetre de visibilite sont poses
  /// par le serveur. Les inclure ici ecraserait des valeurs concurrentes — et
  /// les regles refuseraient l'ecriture.
  Map<String, dynamic> toFirestore() {
    final coords = (latitude != null && longitude != null)
        ? Geohash.encode(latitude!, longitude!)
        : null;

    return {
      'title': title,
      'type': type,
      'description': description,
      'price': price,
      'address': address,
      'quarter': quarter,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': coords,
      'surface': surface,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'floor': floor,
      'isFurnished': isFurnished,
      'equipment': equipment,
      'images': images,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhotoUrl': ownerPhotoUrl,
      'ownerIsVerified': ownerIsVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'publishedAt':
          publishedAt == null ? null : Timestamp.fromDate(publishedAt!),
      'status': status.name,
      'rejectionReason': rejectionReason,
      'searchKeywords': buildSearchKeywords(),
    };
  }

  /// Payload de creation : ajoute les champs que les regles exigent a la
  /// creation et que [toFirestore] omet volontairement pour les mises a jour.
  Map<String, dynamic> toFirestoreForCreate() {
    return {
      ...toFirestore(),
      'views': 0,
      'favoritesCount': 0,
      'boostedUntil': null,
      // Exige explicitement nul par les regles a la creation : c'est le
      // serveur qui ouvrira la fenetre, apres decompte du quota.
      'visibleUntil': null,
    };
  }

  /// Jeu de mots-cles minuscules servant la recherche `array-contains`.
  ///
  /// Firestore ne fait pas de recherche plein texte : on precalcule les tokens
  /// a l'ecriture. Limite assumee — la recherche porte sur des mots entiers du
  /// titre, du quartier, du type et de la ville, pas sur des sous-chaines.
  List<String> buildSearchKeywords() {
    final source = '$title $quarter $city $type';
    final tokens = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9à-ÿ\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toSet();
    // Firestore plafonne un `array-contains-any` a 30 valeurs ; on borne le
    // tableau stocke pour rester dans des couts d'index raisonnables.
    return tokens.take(30).toList();
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // ── Copie ───────────────────────────────────────────────────────────────

  Property copyWith({
    String? id,
    String? title,
    String? type,
    String? description,
    int? price,
    String? address,
    String? quarter,
    String? city,
    double? latitude,
    double? longitude,
    double? surface,
    int? rooms,
    int? bathrooms,
    int? floor,
    bool? isFurnished,
    List<String>? equipment,
    List<String>? images,
    String? ownerId,
    String? ownerName,
    String? ownerPhotoUrl,
    bool? ownerIsVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    PropertyStatus? status,
    int? views,
    int? favoritesCount,
    DateTime? boostedUntil,
    DateTime? visibleUntil,
    String? rejectionReason,
  }) {
    final lat = latitude ?? this.latitude;
    final lng = longitude ?? this.longitude;
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      price: price ?? this.price,
      address: address ?? this.address,
      quarter: quarter ?? this.quarter,
      city: city ?? this.city,
      latitude: lat,
      longitude: lng,
      geohash: (lat != null && lng != null) ? Geohash.encode(lat, lng) : null,
      surface: surface ?? this.surface,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      floor: floor ?? this.floor,
      isFurnished: isFurnished ?? this.isFurnished,
      equipment: equipment ?? this.equipment,
      images: images ?? this.images,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      ownerIsVerified: ownerIsVerified ?? this.ownerIsVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      status: status ?? this.status,
      views: views ?? this.views,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      boostedUntil: boostedUntil ?? this.boostedUntil,
      visibleUntil: visibleUntil ?? this.visibleUntil,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  /// Annonce vierge servant de point de depart au formulaire de publication.
  factory Property.empty({
    required String ownerId,
    required String ownerName,
    String? ownerPhotoUrl,
    bool ownerIsVerified = false,
  }) {
    return Property(
      id: '',
      title: '',
      type: '',
      description: '',
      price: 0,
      address: '',
      quarter: '',
      city: 'Abidjan',
      surface: 0,
      rooms: 1,
      bathrooms: 1,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerPhotoUrl: ownerPhotoUrl,
      ownerIsVerified: ownerIsVerified,
      createdAt: DateTime.now(),
      status: PropertyStatus.draft,
    );
  }

  @override
  bool operator ==(Object other) => other is Property && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
