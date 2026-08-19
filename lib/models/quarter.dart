import 'package:cloud_firestore/cloud_firestore.dart';

/// Fiche d'un quartier (`quarters/{id}`), alimentee par l'administration.
///
/// Repond a la section « Decouvrir le quartier » de la fiche detail et a la
/// rangee « Quartiers populaires » de l'accueil.
class Quarter {
  final String id;
  final String name;
  final String city;
  final String description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;

  /// Commodites recensees, par categorie : `{'ecoles': 12, 'pharmacies': 4}`.
  final Map<String, int> amenities;

  /// Note de securite ressentie, de 1 a 5. Nullable tant que non renseignee —
  /// mieux vaut ne rien afficher qu'un zero trompeur.
  final double? safetyScore;

  final int propertyCount;
  final int averagePrice;
  final bool isPopular;
  final int sortOrder;

  const Quarter({
    required this.id,
    required this.name,
    this.city = 'Abidjan',
    this.description = '',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.amenities = const {},
    this.safetyScore,
    this.propertyCount = 0,
    this.averagePrice = 0,
    this.isPopular = false,
    this.sortOrder = 0,
  });

  Quarter copyWith({
    String? name,
    String? city,
    String? description,
    String? imageUrl,
    double? latitude,
    double? longitude,
    Map<String, int>? amenities,
    double? safetyScore,
    int? propertyCount,
    int? averagePrice,
    bool? isPopular,
    int? sortOrder,
  }) {
    return Quarter(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      amenities: amenities ?? this.amenities,
      safetyScore: safetyScore ?? this.safetyScore,
      propertyCount: propertyCount ?? this.propertyCount,
      averagePrice: averagePrice ?? this.averagePrice,
      isPopular: isPopular ?? this.isPopular,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Libelles lisibles des categories de commodites.
  static const Map<String, String> amenityLabels = {
    'shops': 'Commerces',
    'schools': 'Ecoles',
    'pharmacies': 'Pharmacies',
    'hospitals': 'Sante',
    'transport': 'Transports',
    'banks': 'Banques',
    'restaurants': 'Restaurants',
    'markets': 'Marches',
  };

  factory Quarter.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Quarter(
      id: doc.id,
      name: d['name'] as String? ?? doc.id,
      city: d['city'] as String? ?? 'Abidjan',
      description: d['description'] as String? ?? '',
      imageUrl: d['imageUrl'] as String?,
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      amenities: Map<String, int>.from((d['amenities'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      safetyScore: (d['safetyScore'] as num?)?.toDouble(),
      propertyCount: (d['propertyCount'] as num?)?.toInt() ?? 0,
      averagePrice: (d['averagePrice'] as num?)?.toInt() ?? 0,
      isPopular: d['isPopular'] as bool? ?? false,
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'city': city,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'amenities': amenities,
      'safetyScore': safetyScore,
      'propertyCount': propertyCount,
      'averagePrice': averagePrice,
      'isPopular': isPopular,
      'sortOrder': sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
