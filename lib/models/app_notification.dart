import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorie de notification. Determine l'icone et la destination du tap.
enum NotificationType {
  message,
  alertMatch,
  propertyApproved,
  propertyRejected,
  verificationApproved,
  verificationRejected,
  proActivated,
  boostActivated,
  admin;

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationType.admin,
    );
  }
}

/// Notification in-app (`users/{uid}/notifications/{id}`).
///
/// Doublee d'un push FCM, mais persistee ici pour que l'utilisateur retrouve
/// l'historique : un push balaye depuis l'ecran de verrouillage est perdu.
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;

  /// Cible du tap : id d'annonce, de conversation, selon [type].
  final String? targetId;

  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.targetId,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: NotificationType.fromString(d['type'] as String?),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      targetId: d['targetId'] as String?,
      isRead: d['isRead'] as bool? ?? false,
      createdAt: _toDate(d['createdAt']) ?? DateTime.now(),
      readAt: _toDate(d['readAt']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
