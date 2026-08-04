import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';

class ChatDetailScreen extends StatefulWidget {
  final Conversation? conversation;

  const ChatDetailScreen({super.key, this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<Message> _messages;
  late final Conversation _conv;

  static const String _currentUserId = 'u_current';

  @override
  void initState() {
    super.initState();
    _conv = _conv ?? Conversation.mockConversations.first;
    _messages = _generateMockMessages();
  }

  List<Message> _generateMockMessages() {
    final now = DateTime.now();
    return [
      Message(
        id: 'm1',
        senderId: _conv.otherUserId,
        text: 'Bonjour, je suis interesse par votre annonce.',
        timestamp: now.subtract(const Duration(days: 1, hours: 10)),
        isRead: true,
      ),
      Message(
        id: 'm2',
        senderId: _currentUserId,
        text: 'Bonjour ! Oui, le logement est toujours disponible.',
        timestamp: now.subtract(const Duration(days: 1, hours: 9, minutes: 45)),
        isRead: true,
      ),
      Message(
        id: 'm3',
        senderId: _conv.otherUserId,
        text: 'Tres bien. Quel est le montant de la caution ?',
        timestamp: now.subtract(const Duration(days: 1, hours: 9, minutes: 30)),
        isRead: true,
      ),
      Message(
        id: 'm4',
        senderId: _currentUserId,
        text: 'La caution est de 2 mois de loyer. Le logement est disponible immediatement.',
        timestamp: now.subtract(const Duration(days: 1, hours: 9)),
        isRead: true,
      ),
      Message(
        id: 'm5',
        senderId: _conv.otherUserId,
        text: 'D\'accord, c\'est note. Est-ce que je peux visiter ?',
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      Message(
        id: 'm6',
        senderId: _currentUserId,
        text: 'Bien sur ! Quand seriez-vous disponible ?',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 30)),
        isRead: true,
      ),
      Message(
        id: 'm7',
        senderId: _conv.otherUserId,
        text: 'Samedi matin, vers 10h, ca vous convient ?',
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      Message(
        id: 'm8',
        senderId: _currentUserId,
        text: 'Parfait, samedi 10h. Je vous envoie l\'adresse exacte.',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 45)),
        isRead: true,
      ),
      Message(
        id: 'm9',
        senderId: _conv.otherUserId,
        text: 'Merci beaucoup ! A samedi alors.',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 30)),
        isRead: true,
      ),
      Message(
        id: 'm10',
        senderId: _currentUserId,
        text: 'A samedi ! N\'hesitez pas si vous avez d\'autres questions.',
        timestamp: now.subtract(const Duration(hours: 3)),
        isRead: true,
      ),
    ];
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildPropertyBanner(context),
          Expanded(child: _buildMessageList(context)),
          _buildInputBar(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                AppTheme.primaryGreen.withValues(alpha: 0.12),
            child: Text(
              _conv.otherUserName[0].toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _conv.otherUserName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                  ],
                ),
                Text(
                  'En ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildPropertyBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigation vers le detail de la propriete
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.06),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.dividerLight,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.home_rounded,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conv.propertyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppConstants.formatPricePerMonth(250000),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondaryLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    // Regrouper les messages par date
    final Map<String, List<Message>> grouped = {};
    for (final msg in _messages) {
      final key = _dateLabel(msg.timestamp);
      grouped.putIfAbsent(key, () => []).add(msg);
    }

    final List<Widget> items = [];
    for (final entry in grouped.entries) {
      items.add(_buildDateSeparator(entry.key));
      for (final msg in entry.value) {
        items.add(_buildMessageBubble(context, msg));
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: items,
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) return 'Aujourd\'hui';
    if (messageDay == today.subtract(const Duration(days: 1))) return 'Hier';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message) {
    final bool isSent = message.senderId == _currentUserId;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSent ? AppTheme.primaryGreen : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: isSent ? Colors.white : AppTheme.textPrimaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSent
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                if (isSent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          top: BorderSide(color: AppTheme.dividerLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            color: AppTheme.textSecondaryLight,
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Ecrire un message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, size: 20),
              color: Colors.white,
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message envoye (demo)'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  _messageController.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
