import 'package:intl/intl.dart';

class AppConstants {
  AppConstants._();

  // ── Application ──
  static const String appName = 'MY HOME CI';
  static const String slogan = 'Trouvez votre chez-vous';
  static const String appVersion = '1.0.0';

  // ── Types de biens ──
  static const List<String> propertyTypes = [
    'Studio',
    'Appartement',
    'Villa',
    'Chambre',
    'Duplex',
    'Terrain',
    'Bureau',
    'Maison',
  ];

  // ── Equipements ──
  static const List<String> equipmentList = [
    'Eau courante',
    'Electricite',
    'Climatisation',
    'Internet/WiFi',
    'Parking',
    'Gardien',
    'Piscine',
    'Balcon',
    'Cuisine equipee',
    'Meuble',
  ];

  // ── Quartiers populaires d'Abidjan ──
  static const List<String> popularQuarters = [
    'Cocody',
    'Plateau',
    'Marcory',
    'Yopougon',
    'Treichville',
    'Adjame',
    'Abobo',
    'Koumassi',
    'Port-Bouet',
    'Bingerville',
  ];

  // ── Villes de Cote d'Ivoire ──
  static const List<String> cities = [
    'Abidjan',
    'Bouake',
    'Yamoussoukro',
    'San-Pedro',
    'Daloa',
    'Korhogo',
    'Man',
    'Gagnoa',
  ];

  // ── Filtres de distance (en metres) ──
  static const List<int> distanceFilters = [500, 1000, 3000, 5000, 10000];

  /// Labels lisibles pour les filtres de distance
  static String distanceLabel(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 1)}km';
  }

  // ── Options de tri ──
  static const Map<String, String> sortOptions = {
    'recent': 'Plus recents',
    'price_asc': 'Prix croissant',
    'price_desc': 'Prix decroissant',
    'surface_asc': 'Surface croissante',
    'surface_desc': 'Surface decroissante',
    'nearest': 'Plus proches',
  };

  // ── Format de prix ──
  static final NumberFormat _priceFormatter = NumberFormat('#,###', 'fr_FR');

  /// Formatte un prix en XOF.
  /// Exemple : 150000 => "150 000 FCFA"
  static String formatPrice(int price) {
    return '${_priceFormatter.format(price)} FCFA';
  }

  /// Formatte un prix avec "/mois".
  /// Exemple : 150000 => "150 000 FCFA/mois"
  static String formatPricePerMonth(int price) {
    return '${_priceFormatter.format(price)} FCFA/mois';
  }

  // ── Placeholder image ──
  static const String placeholderImage =
      'https://via.placeholder.com/600x400/2E7D5B/FFFFFF?text=MY+HOME+CI';

  // ── Limites ──
  static const int maxPhotos = 10;
  static const int maxDescriptionLength = 1000;
  static const int minPrice = 10000;
  static const int maxPrice = 5000000;
}
