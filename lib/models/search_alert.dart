import 'package:cloud_firestore/cloud_firestore.dart';

/// Alerte de recherche (`users/{uid}/alerts/{id}`).
///
/// Une Cloud Function compare chaque annonce nouvellement validee aux alertes
/// actives et notifie les correspondances. Les criteres sont donc stockes a
/// plat, sous une forme directement comparable cote serveur.
class SearchAlert {
  final String id;
  final String label;
  final String? type;
  final String? quarter;
  final String? city;
  final int? minPrice;
  final int? maxPrice;
  final int? minRooms;
  final bool? isFurnished;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastNotifiedAt;
  final int matchCount;

  const SearchAlert({
    required this.id,
    required this.label,
    this.type,
    this.quarter,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.minRooms,
    this.isFurnished,
    this.isActive = true,
    required this.createdAt,
    this.lastNotifiedAt,
    this.matchCount = 0,
  });

  /// Resume lisible des criteres, affiche sous le nom de l'alerte.
  String get criteriaSummary {
    final parts = <String>[];
    if (type != null && type!.isNotEmpty) parts.add(type!);
    if (quarter != null && quarter!.isNotEmpty) parts.add(quarter!);
    if (minRooms != null) parts.add('$minRooms+ pieces');
    if (maxPrice != null) {
      parts.add('jusqu\'a ${maxPrice! ~/ 1000}k FCFA');
    } else if (minPrice != null) {
      parts.add('des ${minPrice! ~/ 1000}k FCFA');
    }
    if (isFurnished == true) parts.add('meuble');
    return parts.isEmpty ? 'Toutes les annonces' : parts.join(' · ');
  }

  factory SearchAlert.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return SearchAlert(
      id: doc.id,
      label: d['label'] as String? ?? 'Alerte',
      type: d['type'] as String?,
      quarter: d['quarter'] as String?,
      city: d['city'] as String?,
      minPrice: (d['minPrice'] as num?)?.toInt(),
      maxPrice: (d['maxPrice'] as num?)?.toInt(),
      minRooms: (d['minRooms'] as num?)?.toInt(),
      isFurnished: d['isFurnished'] as bool?,
      isActive: d['isActive'] as bool? ?? true,
      createdAt: _toDate(d['createdAt']) ?? DateTime.now(),
      lastNotifiedAt: _toDate(d['lastNotifiedAt']),
      matchCount: (d['matchCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'type': type,
      'quarter': quarter,
      'city': city,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'minRooms': minRooms,
      'isFurnished': isFurnished,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastNotifiedAt':
          lastNotifiedAt == null ? null : Timestamp.fromDate(lastNotifiedAt!),
      'matchCount': matchCount,
    };
  }

  SearchAlert copyWith({
    String? id,
    String? label,
    String? type,
    String? quarter,
    String? city,
    int? minPrice,
    int? maxPrice,
    int? minRooms,
    bool? isFurnished,
    bool? isActive,
  }) {
    return SearchAlert(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      quarter: quarter ?? this.quarter,
      city: city ?? this.city,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRooms: minRooms ?? this.minRooms,
      isFurnished: isFurnished ?? this.isFurnished,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastNotifiedAt: lastNotifiedAt,
      matchCount: matchCount,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
