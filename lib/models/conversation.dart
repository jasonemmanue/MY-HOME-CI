class Conversation {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String propertyImage;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyImage,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  static List<Conversation> mockConversations = [
    Conversation(
      id: 'conv_1',
      propertyId: 'prop_1',
      propertyTitle: 'Appartement 3 pieces - Cocody',
      propertyImage: '',
      otherUserId: 'user_2',
      otherUserName: 'Aminata Diallo',
      lastMessage: 'Bonjour, l\'appartement est-il toujours disponible ?',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 12)),
      unreadCount: 2,
    ),
    Conversation(
      id: 'conv_2',
      propertyId: 'prop_2',
      propertyTitle: 'Villa 4 pieces - Riviera',
      propertyImage: '',
      otherUserId: 'user_3',
      otherUserName: 'Kouadio Serge',
      lastMessage: 'Je souhaiterais visiter ce samedi si possible.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
    ),
    Conversation(
      id: 'conv_3',
      propertyId: 'prop_3',
      propertyTitle: 'Studio meuble - Marcory',
      propertyImage: '',
      otherUserId: 'user_4',
      otherUserName: 'Fatou Bamba',
      lastMessage: 'D\'accord, merci pour les informations.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
      unreadCount: 1,
    ),
    Conversation(
      id: 'conv_4',
      propertyId: 'prop_4',
      propertyTitle: 'Duplex 5 pieces - Cocody Angre',
      propertyImage: '',
      otherUserId: 'user_5',
      otherUserName: 'Ibrahim Coulibaly',
      lastMessage: 'Le loyer inclut-il les charges ?',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
    ),
    Conversation(
      id: 'conv_5',
      propertyId: 'prop_5',
      propertyTitle: 'Appartement 2 pieces - Plateau',
      propertyImage: '',
      otherUserId: 'user_6',
      otherUserName: 'Marie-Claire Aka',
      lastMessage: 'Pouvez-vous m\'envoyer plus de photos ?',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 3,
    ),
    Conversation(
      id: 'conv_6',
      propertyId: 'prop_6',
      propertyTitle: 'Chambre meublee - Yopougon',
      propertyImage: '',
      otherUserId: 'user_7',
      otherUserName: 'Ousmane Traore',
      lastMessage: 'Merci, je vous recontacte bientot.',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
      unreadCount: 0,
    ),
  ];
}
