import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/conversation.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import 'chat_detail_screen.dart';

/// Liste des conversations.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: auth.isSignedIn
          ? _list(context, auth.uid!, isDark)
          : _signInPrompt(context),
    );
  }

  Widget _list(BuildContext context, String uid, bool isDark) {
    return StreamBuilder<List<Conversation>>(
      stream: ChatService.instance.watchConversations(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _message(
            context,
            Icons.cloud_off_outlined,
            'Impossible de charger vos conversations.',
          );
        }

        final conversations = (snapshot.data ?? const <Conversation>[])
            .where((c) => !c.isArchived)
            .toList();

        if (conversations.isEmpty) {
          return _message(
            context,
            Icons.chat_bubble_outline,
            'Aucune conversation.\n\nContactez un proprietaire depuis une '
            'annonce pour demarrer un echange.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: conversations.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 82, endIndent: 16),
          itemBuilder: (context, i) =>
              _tile(context, conversations[i], uid, isDark),
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    Conversation conversation,
    String uid,
    bool isDark,
  ) {
    final unread = conversation.unreadFor(uid);
    final hasUnread = unread > 0;
    final photo = conversation.otherUserPhoto(uid);
    final isMine = conversation.lastMessageSenderId == uid;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.chatDetail,
        arguments: ChatDetailArgs(
          conversationId: conversation.id,
          conversation: conversation,
        ),
      ),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
            backgroundImage:
                (photo?.isNotEmpty ?? false) ? NetworkImage(photo!) : null,
            child: (photo?.isNotEmpty ?? false)
                ? null
                : Text(
                    conversation.otherUserName(uid).isEmpty
                        ? '?'
                        : conversation.otherUserName(uid)[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
          ),
          // Vignette du logement concerné : sur plusieurs échanges avec le
          // même interlocuteur, elle évite de confondre les biens.
          if (conversation.propertyImage.isNotEmpty)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 24,
                height: 24,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: conversation.propertyImage,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: AppTheme.primaryGreen),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.otherUserName(uid),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
          ),
          Text(
            timeago.format(conversation.lastMessageTime,
                locale: 'fr_short'),
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: hasUnread
                  ? AppTheme.primaryGreen
                  : Theme.of(context).hintColor,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation.propertyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMine
                        ? 'Vous : ${conversation.lastMessage}'
                        : conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread
                          ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 21),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _signInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 60, color: Theme.of(context).disabledColor),
            const SizedBox(height: 20),
            Text(
              'Vos messages, en un seul endroit',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Connectez-vous pour echanger avec les proprietaires sans '
              'communiquer votre numero de telephone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.auth),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
              ),
              child: Text('Se connecter',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
