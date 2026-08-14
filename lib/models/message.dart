import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image;

  static MessageType fromString(String? value) {
    return MessageType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Message d'une conversation (`conversations/{id}/messages/{id}`).
class Message {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;

  /// `true` tant que Firestore n'a pas confirme l'ecriture. Sert a afficher
  /// l'horloge « en cours d'envoi » sans attendre l'aller-retour reseau :
  /// avec la persistance offline, le message apparait immediatement depuis le
  /// cache local et cette information vient de `metadata.hasPendingWrites`.
  final bool isPending;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
    this.isPending = false,
  });

  bool get isImage => type == MessageType.image && imageUrl != null;

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Message(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      type: MessageType.fromString(d['type'] as String?),
      imageUrl: d['imageUrl'] as String?,
      // Un message tout juste ecrit a un `createdAt` encore null cote cache
      // (le serverTimestamp n'est pas resolu) : on retombe sur l'heure locale
      // pour que la bulle s'affiche au bon endroit dans la liste.
      timestamp: _toDate(d['createdAt']) ?? DateTime.now(),
      isRead: d['isRead'] as bool? ?? false,
      readAt: _toDate(d['readAt']),
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'readAt': null,
    };
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? text,
    MessageType? type,
    String? imageUrl,
    DateTime? timestamp,
    bool? isRead,
    DateTime? readAt,
    bool? isPending,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isPending: isPending ?? this.isPending,
    );
  }

  @override
  bool operator ==(Object other) => other is Message && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
