class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Messages mock pour une conversation
  static List<Message> mockMessages(String conversationId) {
    final now = DateTime.now();
    return [
      Message(
        id: '${conversationId}_m1',
        senderId: 'u_current',
        text: 'Bonjour, le logement est-il toujours disponible ?',
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      Message(
        id: '${conversationId}_m2',
        senderId: 'other',
        text: 'Oui, il est disponible. Quand souhaitez-vous visiter ?',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 30)),
        isRead: true,
      ),
      Message(
        id: '${conversationId}_m3',
        senderId: 'u_current',
        text: 'Est-ce possible ce samedi matin ?',
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      Message(
        id: '${conversationId}_m4',
        senderId: 'other',
        text: 'Samedi 10h, ca vous convient ?',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 45)),
        isRead: true,
      ),
      Message(
        id: '${conversationId}_m5',
        senderId: 'u_current',
        text: 'Parfait, merci ! A samedi alors.',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 30)),
        isRead: true,
      ),
    ];
  }
}
