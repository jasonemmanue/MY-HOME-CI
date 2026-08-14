import 'package:flutter_test/flutter_test.dart';
import 'package:my_home_ci/models/property.dart';
import 'package:my_home_ci/models/search_alert.dart';
import 'package:my_home_ci/services/property_service.dart';
import 'package:my_home_ci/utils/geohash.dart';

/// Tests unitaires du noyau métier.
///
/// Volontairement centrés sur ce qui n'est pas vérifiable à l'œil : le calcul
/// géospatial, la construction des mots-clés de recherche et les règles de
/// publication. Les tests de widgets exigeraient de simuler Firebase et
/// coûteraient plus qu'ils ne rapportent à ce stade.
void main() {
  group('Geohash', () {
    test('encode un point connu de maniere stable', () {
      // Le Plateau, Abidjan.
      final hash = Geohash.encode(5.3200, -4.0200, precision: 7);
      expect(hash.length, 7);
      // Deux appels doivent donner le même résultat : l'encodage ne doit
      // dépendre d'aucun état.
      expect(hash, Geohash.encode(5.3200, -4.0200, precision: 7));
    });

    test('deux points proches partagent un prefixe', () {
      final a = Geohash.encode(5.3200, -4.0200, precision: 5);
      final b = Geohash.encode(5.3210, -4.0210, precision: 5);
      expect(a.substring(0, 4), b.substring(0, 4));
    });

    test('deux points eloignes ne partagent pas de prefixe', () {
      final abidjan = Geohash.encode(5.3200, -4.0200, precision: 5);
      final bouake = Geohash.encode(7.6900, -5.0300, precision: 5);
      expect(abidjan[0] == bouake[0] && abidjan[1] == bouake[1], isFalse);
    });

    test('la distance Abidjan-Bouake est de l\'ordre de 300 km', () {
      final meters =
          Geohash.distanceBetween(5.3200, -4.0200, 7.6900, -5.0300);
      expect(meters, greaterThan(280000));
      expect(meters, lessThan(320000));
    });

    test('les plages de requete couvrent la cellule et ses voisines', () {
      final bounds = Geohash.queryBounds(5.3200, -4.0200, 3000);
      // Cellule centrale + huit voisines, dédupliquées.
      expect(bounds.length, greaterThanOrEqualTo(5));
      expect(bounds.length, lessThanOrEqualTo(9));
      for (final b in bounds) {
        expect(b.end.startsWith(b.start), isTrue);
      }
    });
  });

  group('Property', () {
    Property build({
      String title = 'Appartement 3 pieces Cocody',
      String description = 'Un logement lumineux et bien situe a Cocody.',
      int price = 250000,
      double? latitude = 5.35,
      double? longitude = -4.01,
      List<String> images = const ['https://example.com/a.jpg'],
      String quarter = 'Cocody',
    }) {
      return Property(
        id: 'p1',
        title: title,
        type: 'Appartement',
        description: description,
        price: price,
        address: 'Rue des Jardins',
        quarter: quarter,
        city: 'Abidjan',
        latitude: latitude,
        longitude: longitude,
        surface: 85,
        rooms: 3,
        bathrooms: 2,
        images: images,
        ownerId: 'o1',
        ownerName: 'Jean Kouame',
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('une annonce complete est publiable', () {
      expect(build().isPublishable, isTrue);
    });

    test('une annonce sans photo n\'est pas publiable', () {
      expect(build(images: const []).isPublishable, isFalse);
    });

    test('une annonce sans localisation n\'est pas publiable', () {
      expect(
        build(latitude: null, longitude: null).isPublishable,
        isFalse,
      );
    });

    test('une description trop courte bloque la publication', () {
      expect(build(description: 'Trop court').isPublishable, isFalse);
    });

    test('les mots-cles sont minuscules, sans doublon et sans mot court', () {
      final keywords = build().buildSearchKeywords();
      expect(keywords, contains('appartement'));
      expect(keywords, contains('cocody'));
      expect(keywords, contains('abidjan'));
      // « 3 » fait moins de trois caractères : il ne doit pas être indexé.
      expect(keywords.any((k) => k.length < 3), isFalse);
      expect(keywords.toSet().length, keywords.length);
      expect(keywords.every((k) => k == k.toLowerCase()), isTrue);
    });

    test('le statut par defaut est brouillon, et isActive le reflete', () {
      final property = build();
      expect(property.status, PropertyStatus.draft);
      expect(property.isActive, isFalse);
      expect(
        property.copyWith(status: PropertyStatus.active).isActive,
        isTrue,
      );
    });

    test('un boost expire n\'est plus considere comme actif', () {
      final expired = build().copyWith(
        boostedUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expired.isBoosted, isFalse);
    });

    test('copyWith recalcule le geohash quand la position change', () {
      final moved = build().copyWith(latitude: 5.40, longitude: -3.95);
      expect(moved.geohash, isNotNull);
      expect(moved.geohash, Geohash.encode(5.40, -3.95));
    });
  });

  group('PropertyFilters', () {
    test('le compte de filtres actifs ignore la recherche et le tri', () {
      const filters = PropertyFilters(query: 'cocody', sort: 'price_asc');
      expect(filters.activeCount, 0);
    });

    test('une fourchette de prix compte pour un seul filtre', () {
      const filters = PropertyFilters(minPrice: 50000, maxPrice: 300000);
      expect(filters.activeCount, 1);
    });

    test('les drapeaux clear effacent bien la valeur', () {
      const filters = PropertyFilters(type: 'Villa', quarter: 'Cocody');
      expect(filters.copyWith(clearType: true).type, isNull);
      expect(filters.copyWith(clearType: true).quarter, 'Cocody');
    });

    test('l\'egalite structurelle permet d\'eviter les rechargements', () {
      const a = PropertyFilters(type: 'Villa', minRooms: 3);
      const b = PropertyFilters(type: 'Villa', minRooms: 3);
      expect(a, equals(b));
    });
  });

  group('SearchAlert', () {
    test('le resume des criteres reste lisible', () {
      final alert = SearchAlert(
        id: 'a1',
        label: 'Villa Cocody',
        type: 'Villa',
        quarter: 'Cocody',
        maxPrice: 500000,
        minRooms: 4,
        createdAt: DateTime(2026, 1, 1),
      );
      final summary = alert.criteriaSummary;
      expect(summary, contains('Villa'));
      expect(summary, contains('Cocody'));
      expect(summary, contains('4+ pieces'));
      expect(summary, contains('500k'));
    });

    test('une alerte sans critere l\'annonce explicitement', () {
      final alert = SearchAlert(
        id: 'a2',
        label: 'Tout',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(alert.criteriaSummary, 'Toutes les annonces');
    });
  });
}
