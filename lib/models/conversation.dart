import 'package:cloud_firestore/cloud_firestore.dart';

/// Fil de discussion entre un locataire et un proprietaire, rattache a une
/// annonce (`conversations/{id}`).
///
/// L'identifiant est deterministe — `{propertyId}_{tenantId}` — pour qu'un
/// second clic sur « Contacter le proprietaire » retombe sur la conversation
/// existante au lieu d'en creer une nouvelle.
class Conversation {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String propertyImage;
  final int propertyPrice;

  /// Les deux uid participants. Champ indispensable : les regles Firestore
  /// s'appuient dessus (`request.auth.uid in resource.data.participants`) et
  /// la liste des conversations se requete par `array-contains`.
  final List<String> participants;

  final String ownerId;
  final String tenantId;

  /// Instantane du nom et de la photo de chaque participant, pour afficher la
  /// liste des conversations sans N lectures supplementaires sur `users`.
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;

  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;

  /// Non-lus par uid. Un compteur global serait faux : chaque participant a
  /// son propre etat de lecture.
  final Map<String, int> unreadCounts;

  /// uid en train d'ecrire, avec l'horodatage de la derniere frappe. On
  /// n'affiche l'indicateur que si la frappe date de moins de quelques
  /// secondes, sinon un client parti brutalement le laisserait allume.
  final Map<String, DateTime> typing;

  final bool isArchived;

  const Conversation({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    this.propertyImage = '',
    this.propertyPrice = 0,
    required this.participants,
    required this.ownerId,
    required this.tenantId,
    this.participantNames = const {},
    this.participantPhotos = const {},
    this.lastMessage = '',
    required this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.unreadCounts = const {},
    this.typing = const {},
    this.isArchived = false,
  });

  /// Identifiant deterministe d'une conversation.
  static String buildId(String propertyId, String tenantId) =>
      '${propertyId}_$tenantId';

  String otherUserId(String currentUserId) =>
      participants.firstWhere((p) => p != currentUserId, orElse: () => '');

  String otherUserName(String currentUserId) =>
      participantNames[otherUserId(currentUserId)] ?? 'Utilisateur';

  String? otherUserPhoto(String currentUserId) =>
      participantPhotos[otherUserId(currentUserId)];

  int unreadFor(String userId) => unreadCounts[userId] ?? 0;

  /// `true` si l'autre participant a tape dans les 6 dernieres secondes.
  bool isOtherTyping(String currentUserId) {
    final other = otherUserId(currentUserId);
    final at = typing[other];
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(seconds: 6);
  }

  factory Conversation.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};

    final rawTyping = (d['typing'] as Map?) ?? const {};
    final typing = <String, DateTime>{};
    rawTyping.forEach((key, value) {
      final date = _toDate(value);
      if (date != null) typing[key.toString()] = date;
    });

    return Conversation(
      id: doc.id,
      propertyId: d['propertyId'] as String? ?? '',
      propertyTitle: d['propertyTitle'] as String? ?? '',
      propertyImage: d['propertyImage'] as String? ?? '',
      propertyPrice: (d['propertyPrice'] as num?)?.toInt() ?? 0,
      participants: List<String>.from(d['participants'] as List? ?? const []),
      ownerId: d['ownerId'] as String? ?? '',
      tenantId: d['tenantId'] as String? ?? '',
      participantNames: Map<String, String>.from(
          (d['participantNames'] as Map?) ?? const {}),
      participantPhotos: Map<String, String?>.from(
          (d['participantPhotos'] as Map?) ?? const {}),
      lastMessage: d['lastMessage'] as String? ?? '',
      lastMessageTime: _toDate(d['lastMessageTime']) ?? DateTime.now(),
      lastMessageSenderId: d['lastMessageSenderId'] as String? ?? '',
      unreadCounts:
          Map<String, int>.from((d['unreadCounts'] as Map?) ?? const {})
              .map((k, v) => MapEntry(k, (v as num).toInt())),
      typing: typing,
      isArchived: d['isArchived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestoreForCreate() {
    return {
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'propertyImage': propertyImage,
      'propertyPrice': propertyPrice,
      'participants': participants,
      'ownerId': ownerId,
      'tenantId': tenantId,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': {for (final p in participants) p: 0},
      'typing': <String, dynamic>{},
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  bool operator ==(Object other) => other is Conversation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
