class Property {
  final String id;
  final String title;
  final String type;
  final String description;
  final int price;
  final String address;
  final String quarter;
  final String city;
  final double surface;
  final int rooms;
  final int bathrooms;
  final int floor;
  final bool isFurnished;
  final List<String> equipment;
  final List<String> images;
  final String ownerId;
  final String ownerName;
  final String? ownerPhone;
  final DateTime createdAt;
  final bool isActive;
  final int views;

  const Property({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.price,
    required this.address,
    required this.quarter,
    required this.city,
    required this.surface,
    required this.rooms,
    required this.bathrooms,
    this.floor = 0,
    this.isFurnished = false,
    this.equipment = const [],
    this.images = const [],
    required this.ownerId,
    required this.ownerName,
    this.ownerPhone,
    required this.createdAt,
    this.isActive = true,
    this.views = 0,
  });

  static List<Property> mockProperties = [
    Property(
      id: 'prop_1',
      title: 'Appartement 3 pieces - Cocody',
      type: 'Appartement',
      description:
          'Bel appartement lumineux de 3 pieces situe dans un quartier calme de Cocody. Proche des commodites, ecoles et transports.',
      price: 250000,
      address: 'Rue des Jardins, Cocody',
      quarter: 'Cocody',
      city: 'Abidjan',
      surface: 85,
      rooms: 3,
      bathrooms: 2,
      floor: 2,
      isFurnished: false,
      equipment: ['Eau courante', 'Electricite', 'Parking', 'Balcon'],
      images: [],
      ownerId: 'owner_1',
      ownerName: 'Jean Kouame',
      ownerPhone: '+225 07 08 09 10',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      views: 342,
    ),
    Property(
      id: 'prop_2',
      title: 'Villa 4 pieces - Riviera',
      type: 'Villa',
      description:
          'Superbe villa avec jardin et piscine dans le quartier residentiel de la Riviera. Ideale pour famille.',
      price: 500000,
      address: 'Boulevard de la Riviera, Cocody',
      quarter: 'Cocody',
      city: 'Abidjan',
      surface: 200,
      rooms: 4,
      bathrooms: 3,
      floor: 0,
      isFurnished: true,
      equipment: [
        'Eau courante',
        'Electricite',
        'Climatisation',
        'Internet/WiFi',
        'Parking',
        'Gardien',
        'Piscine',
        'Cuisine equipee',
      ],
      images: [],
      ownerId: 'owner_1',
      ownerName: 'Jean Kouame',
      ownerPhone: '+225 07 08 09 10',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      views: 587,
    ),
    Property(
      id: 'prop_3',
      title: 'Studio meuble - Marcory',
      type: 'Studio',
      description:
          'Studio entierement meuble, pret a emmenager. Quartier securise et anime avec acces facile aux transports.',
      price: 120000,
      address: 'Avenue de la TSF, Marcory',
      quarter: 'Marcory',
      city: 'Abidjan',
      surface: 35,
      rooms: 1,
      bathrooms: 1,
      floor: 3,
      isFurnished: true,
      equipment: [
        'Eau courante',
        'Electricite',
        'Climatisation',
        'Internet/WiFi',
        'Meuble',
      ],
      images: [],
      ownerId: 'owner_2',
      ownerName: 'Awa Sangare',
      ownerPhone: '+225 05 12 34 56',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      views: 128,
    ),
    Property(
      id: 'prop_4',
      title: 'Duplex 5 pieces - Cocody Angre',
      type: 'Duplex',
      description:
          'Magnifique duplex spacieux avec terrasse et vue degagee. Quartier residentiel calme, ideal pour famille.',
      price: 450000,
      address: '8eme Tranche, Angre, Cocody',
      quarter: 'Cocody',
      city: 'Abidjan',
      surface: 180,
      rooms: 5,
      bathrooms: 3,
      floor: 0,
      isFurnished: false,
      equipment: [
        'Eau courante',
        'Electricite',
        'Climatisation',
        'Parking',
        'Gardien',
        'Balcon',
        'Cuisine equipee',
      ],
      images: [],
      ownerId: 'owner_1',
      ownerName: 'Jean Kouame',
      ownerPhone: '+225 07 08 09 10',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      views: 215,
    ),
    Property(
      id: 'prop_5',
      title: 'Appartement 2 pieces - Plateau',
      type: 'Appartement',
      description:
          'Appartement moderne au coeur du Plateau, le centre des affaires d\'Abidjan. Proche de tout.',
      price: 180000,
      address: 'Rue du Commerce, Plateau',
      quarter: 'Plateau',
      city: 'Abidjan',
      surface: 60,
      rooms: 2,
      bathrooms: 1,
      floor: 5,
      isFurnished: false,
      equipment: ['Eau courante', 'Electricite', 'Climatisation', 'Parking'],
      images: [],
      ownerId: 'owner_3',
      ownerName: 'Moussa Kone',
      ownerPhone: '+225 01 23 45 67',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      views: 75,
    ),
    Property(
      id: 'prop_6',
      title: 'Chambre meublee - Yopougon',
      type: 'Chambre',
      description:
          'Chambre meublee dans une residence securisee a Yopougon. Ideale pour etudiant ou jeune professionnel.',
      price: 55000,
      address: 'Quartier Millionnaire, Yopougon',
      quarter: 'Yopougon',
      city: 'Abidjan',
      surface: 20,
      rooms: 1,
      bathrooms: 1,
      floor: 1,
      isFurnished: true,
      equipment: ['Eau courante', 'Electricite', 'Meuble'],
      images: [],
      ownerId: 'owner_4',
      ownerName: 'Adama Toure',
      ownerPhone: '+225 09 87 65 43',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      views: 93,
    ),
  ];
}
