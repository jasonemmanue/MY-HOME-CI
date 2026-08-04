class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? photoUrl;
  final bool isOwner;
  final bool isVerified;
  final DateTime createdAt;
  final int propertyCount;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.photoUrl,
    this.isOwner = false,
    this.isVerified = false,
    required this.createdAt,
    this.propertyCount = 0,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    bool? isOwner,
    bool? isVerified,
    DateTime? createdAt,
    int? propertyCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isOwner: isOwner ?? this.isOwner,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      propertyCount: propertyCount ?? this.propertyCount,
    );
  }

  /// Utilisateur mock connecte
  static final UserModel mockCurrentUser = UserModel(
    id: 'u_current',
    name: 'Emmanuel Sakam',
    phone: '+225 07 00 00 00 00',
    email: 'emmanuel@myhomeci.com',
    photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    isOwner: false,
    isVerified: true,
    createdAt: DateTime(2026, 6, 1),
    propertyCount: 0,
  );

  /// Liste d'utilisateurs mock (proprietaires)
  static final List<UserModel> mockUsers = [
    UserModel(
      id: 'u1',
      name: 'Kouame Yao',
      phone: '+225 07 08 09 10 11',
      email: 'kouame.yao@email.ci',
      photoUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200',
      isOwner: true,
      isVerified: true,
      createdAt: DateTime(2026, 3, 15),
      propertyCount: 2,
    ),
    UserModel(
      id: 'u2',
      name: 'Awa Traore',
      phone: '+225 05 06 07 08 09',
      email: 'awa.traore@email.ci',
      photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
      isOwner: true,
      isVerified: true,
      createdAt: DateTime(2026, 4, 10),
      propertyCount: 1,
    ),
    UserModel(
      id: 'u3',
      name: 'Jean-Marc Koffi',
      phone: '+225 01 02 03 04 05',
      email: 'jm.koffi@email.ci',
      photoUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200',
      isOwner: true,
      isVerified: true,
      createdAt: DateTime(2026, 2, 20),
      propertyCount: 2,
    ),
    UserModel(
      id: 'u5',
      name: 'Fatou Diallo',
      phone: '+225 05 55 66 77 88',
      email: 'fatou.diallo@email.ci',
      photoUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
      isOwner: true,
      isVerified: true,
      createdAt: DateTime(2026, 1, 5),
      propertyCount: 2,
    ),
  ];
}
