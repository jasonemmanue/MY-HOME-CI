import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/user_model.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../services/report_service.dart';
import '../../services/storage_service.dart';
import '../property_detail/property_detail_screen.dart';

class ChatDetailArgs {
  final String conversationId;
  final Conversation? conversation;

  const ChatDetailArgs({required this.conversationId, this.conversation});
}

/// Fil de discussion.
///
/// La liste est inversée (`reverse: true`) : le dernier message est en bas et
/// l'arrivée d'un nouveau ne bouscule pas la position de lecture quand on
/// remonte l'historique.
class ChatDetailScreen extends StatefulWidget {
  final ChatDetailArgs args;

  const ChatDetailScreen({super.key, required this.args});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _typingTimer;
  bool _typingSignalled = false;
  bool _sending = false;

  String get _conversationId => widget.args.conversationId;

  /// Derniere presence connue de l'autre participant.
  ///
  /// Sert a distinguer « envoye » de « remis » : un message ecrit dans
  /// Firestore n'est pas pour autant parvenu sur l'ecran d'en face.
  DateTime? _autreVuLe;
  String? _autreId;
  StreamSubscription<UserModel?>? _presenceSub;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyping);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  /// Suit la presence de l'interlocuteur. Idempotent : appele a chaque
  /// reconstruction, il ne reabonne que si l'interlocuteur a change.
  void _suivrePresence(String? autreId) {
    if (autreId == null || autreId.isEmpty || autreId == _autreId) return;
    _autreId = autreId;
    _presenceSub?.cancel();
    _presenceSub = UserService.instance.watch(autreId).listen((u) {
      if (mounted) setState(() => _autreVuLe = u?.lastSeenAt);
    });
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _typingTimer?.cancel();
    _clearTyping();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _uid => context.read<AuthProvider>().uid;

  void _markRead() {
    final uid = _uid;
    if (uid == null) return;
    ChatService.instance
        .markConversationRead(conversationId: _conversationId, userId: uid);
    ChatService.instance
        .markMessagesRead(conversationId: _conversationId, userId: uid);
  }

  /// Signale la frappe au plus une fois toutes les quatre secondes.
  ///
  /// Écrire à chaque caractère produirait une écriture Firestore par touche —
  /// coûteux, et suffisant pour saturer les quotas sur un échange animé.
  void _onTyping() {
    final uid = _uid;
    if (uid == null || _controller.text.isEmpty) return;

    if (!_typingSignalled) {
      _typingSignalled = true;
      ChatService.instance.setTyping(
        conversationId: _conversationId,
        userId: uid,
        isTyping: true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
  }

  void _clearTyping() {
    if (!_typingSignalled) return;
    _typingSignalled = false;
    final uid = _uid;
    if (uid == null) return;
    ChatService.instance.setTyping(
      conversationId: _conversationId,
      userId: uid,
      isTyping: false,
    );
  }

  Future<void> _sendText() async {
    final uid = _uid;
    final text = _controller.text.trim();
    if (uid == null || text.isEmpty || _sending) return;

    _controller.clear();
    _clearTyping();
    setState(() => _sending = true);

    try {
      await ChatService.instance.sendText(
        conversationId: _conversationId,
        senderId: uid,
        text: text,
      );
    } catch (_) {
      // On restitue le texte : le perdre après une coupure réseau est la
      // frustration classique des messageries mal fichues.
      _controller.text = text;
      _snack('Message non envoye. Verifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final uid = _uid;
    if (uid == null) return;

    final file = await StorageService.instance.pickSingleImage();
    if (file == null) return;

    setState(() => _sending = true);
    try {
      await ChatService.instance.sendImage(
        conversationId: _conversationId,
        senderId: uid,
        file: file,
      );
    } catch (_) {
      _snack('Envoi de la photo impossible.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reportConversation() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Signaler cette conversation',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            ...Report.reasons.map(
              (r) => ListTile(
                title: Text(r, style: GoogleFonts.inter(fontSize: 14)),
                onTap: () => Navigator.pop(context, r),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;

    await ReportService.instance.reportMessage(
      conversationId: _conversationId,
      reason: reason,
    );
    _snack('Signalement transmis a la moderation.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Connexion requise.')),
      );
    }

    return StreamBuilder<Conversation?>(
      stream: ChatService.instance.watchConversation(_conversationId),
      initialData: widget.args.conversation,
      builder: (context, snapshot) {
        final conversation = snapshot.data;
        _suivrePresence(conversation?.otherUserId(uid));

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: conversation == null
                ? const Text('Conversation')
                : _appBarTitle(conversation, uid, isDark),
            actions: [
              IconButton(
                icon: const Icon(Icons.flag_outlined, size: 20),
                tooltip: 'Signaler',
                onPressed: _reportConversation,
              ),
            ],
          ),
          body: Column(
            children: [
              if (conversation != null) _propertyBanner(conversation, isDark),
              Expanded(child: _messageList(uid, conversation, isDark)),
              if (conversation?.isOtherTyping(uid) ?? false)
                _typingIndicator(isDark),
              _composer(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _appBarTitle(Conversation conversation, String uid, bool isDark) {
    final photo = conversation.otherUserPhoto(uid);

    return Row(
      children: [
        CircleAvatar(
          radius: 17,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            conversation.otherUserName(uid),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Rappel de l'annonce concernée, en tête du fil.
  ///
  /// Un propriétaire gère souvent plusieurs biens : sans ce rappel, il ne sait
  /// pas de quel logement on lui parle.
  Widget _propertyBanner(Conversation conversation, bool isDark) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.propertyDetail,
        arguments: PropertyDetailArgs(propertyId: conversation.propertyId),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
            ),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: SizedBox(
                width: 46,
                height: 46,
                child: conversation.propertyImage.isEmpty
                    ? Container(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        child: const Icon(Icons.home_rounded,
                            size: 20, color: AppTheme.primaryGreen),
                      )
                    : CachedNetworkImage(
                        imageUrl: conversation.propertyImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          child: const Icon(Icons.home_rounded,
                              size: 20, color: AppTheme.primaryGreen),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.propertyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  if (conversation.propertyPrice > 0)
                    Text(
                      AppConstants.formatPricePerMonth(
                          conversation.propertyPrice),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.primaryGreen),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }

  Widget _messageList(String uid, Conversation? conversation, bool isDark) {
    return StreamBuilder<List<Message>>(
      stream: ChatService.instance.watchMessages(_conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? const <Message>[];
        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.waving_hand_outlined,
                      size: 48, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    'Entamez la conversation.\nPresentez-vous et demandez si le '
                    'logement est toujours disponible.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
          );
        }

        // Un nouveau message reçu pendant que l'écran est ouvert doit être
        // marqué lu immédiatement, sans quoi le badge resterait allumé.
        WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final message = messages[i];
            // La liste est décroissante : l'élément « précédent » à l'écran
            // est le suivant dans le tableau.
            final previous = i + 1 < messages.length ? messages[i + 1] : null;
            final showDate = previous == null ||
                !_sameDay(previous.timestamp, message.timestamp);

            return Column(
              children: [
                if (showDate) _dateSeparator(message.timestamp, isDark),
                _bubble(message, message.senderId == uid, isDark),
              ],
            );
          },
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateSeparator(DateTime date, bool isDark) {
    final now = DateTime.now();
    final String label;
    if (_sameDay(date, now)) {
      label = 'Aujourd\'hui';
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Hier';
    } else {
      label = DateFormat('d MMMM yyyy', 'fr_FR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : const Color(0xFFEDF1EF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 11.5, color: Theme.of(context).hintColor),
          ),
        ),
      ),
    );
  }

  Widget _bubble(Message message, bool isMine, bool isDark) {
    final background = isMine
        ? AppTheme.primaryGreen
        : (isDark ? AppTheme.cardDark : const Color(0xFFF0F3F1));
    final foreground = isMine
        ? Colors.white
        : (isDark ? Colors.white : AppTheme.textPrimaryLight);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: message.isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  width: 220,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 220,
                    height: 160,
                    color: Colors.black12,
                  ),
                ),
              )
            else
              Text(
                message.text,
                style: GoogleFonts.inter(
                    fontSize: 14.5, height: 1.4, color: foreground),
              ),
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.only(right: message.isImage ? 6 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.75)
                          : Theme.of(context).hintColor,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _accuse(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Accuse de reception, en trois etats.
  ///
  ///  * une coche pale  — le message est parti,
  ///  * deux coches pales — l'autre s'est connecte depuis l'envoi,
  ///  * deux coches bleues — il l'a lu.
  ///
  /// La distinction repose sur `lastSeenAt`, rafraichi a chaque retour de
  /// l'application au premier plan. Elle reste une approximation : elle dit
  /// que l'interlocuteur etait la apres l'envoi, pas qu'il a ouvert le fil.
  Widget _accuse(Message message) {
    if (message.isPending) {
      return Icon(Icons.schedule,
          size: 13, color: Colors.white.withValues(alpha: 0.75));
    }

    if (message.isRead) {
      // Bleu clair et non blanc : sur la bulle verte, un bleu soutenu
      // deviendrait illisible.
      return const Icon(Icons.done_all, size: 13, color: Color(0xFF53BDEB));
    }

    final remis =
        _autreVuLe != null && _autreVuLe!.isAfter(message.timestamp);

    return Icon(
      remis ? Icons.done_all : Icons.done,
      size: 13,
      color: Colors.white.withValues(alpha: 0.75),
    );
  }

  Widget _typingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, bottom: 8),
        child: Text(
          'en train d\'ecrire…',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Widget _composer(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 23),
              onPressed: _sending ? null : _sendImage,
              color: AppTheme.primaryGreen,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Votre message…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  filled: true,
                  fillColor:
                      isDark ? AppTheme.cardDark : const Color(0xFFF0F3F1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: AppTheme.primaryGreen,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _sendText,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
