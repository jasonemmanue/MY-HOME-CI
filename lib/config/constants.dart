import 'package:intl/intl.dart';

class AppConstants {
  AppConstants._();

  // ── Application ──
  static const String appName = 'My Home CI';
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

  /// Photo par defaut de chaque quartier, servant tant que l'administration
  /// n'a pas renseigne `imageUrl` dans `quarters/{id}` — la valeur Firestore
  /// reste prioritaire, ces liens ne sont qu'un repli pour que l'accueil ne
  /// s'affiche jamais avec une rangee de cartes vides.
  ///
  /// Fichiers Wikimedia Commons sous licence libre, servis via
  /// `Special:FilePath` : l'URL suit les renommages du fichier et le
  /// parametre `width` fait redimensionner l'image cote serveur, ce qui evite
  /// de telecharger des originaux de plusieurs megaoctets sur mobile.
  static const Map<String, String> quarterImages = {
    'Cocody':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Mairie_de_Cocody%2C_Abidjan.jpg?width=800',
    'Plateau':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Plateau_Abidjan_de_nuit.jpg?width=800',
    'Marcory':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Food_stall_in_Marcory_in_Abidjan_%281%29.JPG?width=800',
    'Yopougon':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Mairie_centrale_de_Yopougon_Abidjan.jpg?width=800',
    'Treichville':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Pont_de_Gaulle_et_Treichville%2C_Abidjan.jpg?width=800',
    'Adjame':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Adjame_abidjan_civ.jpg?width=800',
    'Abobo':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Cit%C3%A9_Sicogi_Concorde_Abobo_Pk18.jpg?width=800',
    'Koumassi':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Koumassi_rond-point_Philippe_Yace_Abidjan_C%C3%B4te_d%27ivoire.jpg?width=800',
    'Port-Bouet':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Abidjan_-_A%C3%A9roport_international_F%C3%A9lix_Houphou%C3%ABt_Boigny_vu_d%27un_avion.jpg?width=800',
    'Bingerville':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Passage_Jardin_Botanique%2C_Bingerville%2C_Abidjan.jpg?width=800',
  };

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
      'https://via.placeholder.com/600x400/2E7D5B/FFFFFF?text=My+Home+CI';

  // ── Limites ──
  static const int maxPhotos = 10;
  static const int maxDescriptionLength = 1000;
  static const int minPrice = 10000;
  static const int maxPrice = 5000000;
}
