import 'package:cloud_firestore/cloud_firestore.dart';

/// Role fonctionnel. `admin` n'est jamais pose depuis l'application : il vient
/// d'un custom claim attribue par une Cloud Function.
enum UserRole {
  tenant,
  owner,
  admin;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.tenant,
    );
  }

  String get label {
    switch (this) {
      case UserRole.tenant:
        return 'Locataire';
      case UserRole.owner:
        return 'Proprietaire';
      case UserRole.admin:
        return 'Administrateur';
    }
  }
}

/// Profil **public** d'un utilisateur (`users/{uid}`).
///
/// L'email et le telephone n'y figurent pas : ils vivent dans
/// `users/{uid}/private/contact`, lisible du seul titulaire. C'est ce qui rend
/// tenable la promesse du cahier des charges — « communication directe sans
/// echanger de numeros de telephone ».
class UserModel {
  final String id;
  final String name;
  final String? photoUrl;
  final UserRole role;

  /// Badge « proprietaire verifie ». Ecriture serveur uniquement.
  final bool isVerified;

  /// Pack Pro actif. Ecriture serveur uniquement (apres paiement).
  final bool isPro;
  final DateTime? proUntil;

  final bool isSuspended;
  final DateTime? suspendedUntil;

  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final int propertyCount;

  const UserModel({
    required this.id,
    required this.name,
    this.photoUrl,
    this.role = UserRole.tenant,
    this.isVerified = false,
    this.isPro = false,
    this.proUntil,
    this.isSuspended = false,
    this.suspendedUntil,
    required this.createdAt,
    this.lastSeenAt,
    this.propertyCount = 0,
  });

  bool get isOwner => role == UserRole.owner;
  bool get isAdmin => role == UserRole.admin;

  bool get hasActivePro =>
      isPro && (proUntil == null || proUntil!.isAfter(DateTime.now()));

  /// Initiales pour l'avatar de repli quand [photoUrl] est absent.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return UserModel(
      id: doc.id,
      name: d['name'] as String? ?? 'Utilisateur',
      photoUrl: d['photoUrl'] as String?,
      role: UserRole.fromString(d['role'] as String?),
      isVerified: d['isVerified'] as bool? ?? false,
      isPro: d['isPro'] as bool? ?? false,
      proUntil: _toDate(d['proUntil']),
      isSuspended: d['isSuspended'] as bool? ?? false,
      suspendedUntil: _toDate(d['suspendedUntil']),
      createdAt: _toDate(d['createdAt']) ?? DateTime.now(),
      lastSeenAt: _toDate(d['lastSeenAt']),
      propertyCount: (d['propertyCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Payload de creation du profil public.
  ///
  /// Les champs a privilege (`isVerified`, `isPro`, `isSuspended`) sont poses
  /// a `false` : les regles Firestore refusent la creation autrement.
  Map<String, dynamic> toFirestoreForCreate() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'role': role.name,
      'isVerified': false,
      'isPro': false,
      'proUntil': null,
      'isSuspended': false,
      'suspendedUntil': null,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'propertyCount': 0,
    };
  }

  /// Payload de mise a jour limite aux champs qu'un utilisateur peut editer.
  /// Tout le reste est refuse par `noPrivilegeEscalation` dans firestore.rules.
  Map<String, dynamic> toFirestoreForUpdate() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'lastSeenAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? photoUrl,
    UserRole? role,
    bool? isVerified,
    bool? isPro,
    DateTime? proUntil,
    bool? isSuspended,
    DateTime? suspendedUntil,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    int? propertyCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      isPro: isPro ?? this.isPro,
      proUntil: proUntil ?? this.proUntil,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      propertyCount: propertyCount ?? this.propertyCount,
    );
  }

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Coordonnees privees (`users/{uid}/private/contact`).
/// Jamais exposees dans le profil public.
class UserContact {
  final String? email;
  final String? phone;

  const UserContact({this.email, this.phone});

  factory UserContact.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const UserContact();
    return UserContact(
      email: d['email'] as String?,
      phone: d['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
