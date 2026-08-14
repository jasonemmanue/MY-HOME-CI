import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/property.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Messagerie temps reel.
///
/// Deux choix structurants :
///  • L'identifiant de conversation est deterministe (`{propertyId}_{tenantId}`),
///    ce qui rend « Contacter le proprietaire » idempotent : recliquer rouvre
///    le fil existant au lieu d'en creer un second.
///  • Les compteurs de non-lus sont par participant. Un compteur unique serait
///    faux des que les deux cotes lisent a des moments differents.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _col.doc(conversationId).collection('messages');

  // ── Conversations ───────────────────────────────────────────────────────

  Stream<List<Conversation>> watchConversations(String userId) {
    return _col
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Conversation.fromFirestore).toList());
  }

  Stream<Conversation?> watchConversation(String conversationId) {
    return _col
        .doc(conversationId)
        .snapshots()
        .map((doc) => doc.exists ? Conversation.fromFirestore(doc) : null);
  }

  /// Total des messages non lus, tous fils confondus — alimente la pastille
  /// de la barre de navigation.
  Stream<int> watchUnreadTotal(String userId) {
    return watchConversations(userId).map(
      (list) => list.fold<int>(0, (total, c) => total + c.unreadFor(userId)),
    );
  }

  /// Ouvre le fil lie a une annonce, en le creant au besoin.
  ///
  /// Renvoie l'identifiant de la conversation.
  Future<String> openConversation({
    required Property property,
    required UserModel tenant,
  }) async {
    if (property.ownerId == tenant.id) {
      throw StateError(
          'Un proprietaire ne peut pas ouvrir une conversation sur sa propre annonce.');
    }

    final id = Conversation.buildId(property.id, tenant.id);
    final ref = _col.doc(id);
    final snap = await ref.get();

    if (snap.exists) return id;

    final conversation = Conversation(
      id: id,
      propertyId: property.id,
      propertyTitle: property.title,
      propertyImage: property.coverImage ?? '',
      propertyPrice: property.price,
      participants: [property.ownerId, tenant.id],
      ownerId: property.ownerId,
      tenantId: tenant.id,
      participantNames: {
        property.ownerId: property.ownerName,
        tenant.id: tenant.name,
      },
      participantPhotos: {
        property.ownerId: property.ownerPhotoUrl,
        tenant.id: tenant.photoUrl,
      },
      lastMessageTime: DateTime.now(),
    );

    await ref.set(conversation.toFirestoreForCreate());
    return id;
  }

  // ── Messages ────────────────────────────────────────────────────────────

  /// Flux des messages, du plus recent au plus ancien.
  ///
  /// [limit] borne l'historique charge : sans plafond, un fil de plusieurs
  /// milliers de messages serait entierement telecharge a chaque ouverture.
  Stream<List<Message>> watchMessages(String conversationId,
      {int limit = 50}) {
    return _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Message.fromFirestore).toList());
  }

  /// Charge une tranche d'historique plus ancienne que [before].
  Future<List<Message>> loadOlderMessages({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  }) async {
    final snap = await _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map(Message.fromFirestore).toList();
  }

  Future<void> sendText({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _send(
      conversationId: conversationId,
      message: Message(
        id: '',
        senderId: senderId,
        text: trimmed,
        timestamp: DateTime.now(),
      ),
      preview: trimmed,
    );
  }

  Future<void> sendImage({
    required String conversationId,
    required String senderId,
    required File file,
  }) async {
    final url = await StorageService.instance.uploadChatImage(
      conversationId: conversationId,
      file: file,
    );
    await _send(
      conversationId: conversationId,
      message: Message(
        id: '',
        senderId: senderId,
        text: '',
        type: MessageType.image,
        imageUrl: url,
        timestamp: DateTime.now(),
      ),
      preview: 'Photo',
    );
  }

  /// Ecrit le message et met a jour l'entete du fil dans la meme operation.
  ///
  /// Le lot garantit qu'un message ne peut pas exister sans que
  /// `lastMessage` / `unreadCounts` soient a jour : sinon la liste des
  /// conversations afficherait un apercu perime et un badge faux.
  Future<void> _send({
    required String conversationId,
    required Message message,
    required String preview,
  }) async {
    final convRef = _col.doc(conversationId);
    final snap = await convRef.get();
    if (!snap.exists) {
      throw StateError('Conversation introuvable : $conversationId');
    }

    final participants =
        List<String>.from(snap.data()?['participants'] as List? ?? const []);
    final recipients = participants.where((p) => p != message.senderId);

    final batch = _db.batch();

    batch.set(_messages(conversationId).doc(), message.toFirestore());

    batch.update(convRef, {
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': message.senderId,
      // On n'incremente que le compteur du destinataire.
      for (final r in recipients)
        'unreadCounts.$r': FieldValue.increment(1),
      // L'expediteur a forcement lu son propre message.
      'unreadCounts.${message.senderId}': 0,
      // Envoyer met fin a l'etat « en train d'ecrire ».
      'typing.${message.senderId}': FieldValue.delete(),
    });

    await batch.commit();
  }

  /// Remet a zero le compteur de non-lus du fil pour [userId].
  Future<void> markConversationRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _col.doc(conversationId).update({'unreadCounts.$userId': 0});
    } catch (_) {}
  }

  /// Pose l'accuse de lecture sur les messages recus non encore lus.
  ///
  /// Limite a 30 documents par appel : au-dela, l'utilisateur remonte un
  /// historique ancien et marquer tout serait couteux pour un affichage que
  /// personne ne regarde.
  Future<void> markMessagesRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final snap = await _messages(conversationId)
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      final unread =
          snap.docs.where((d) => d.data()['senderId'] != userId).toList();
      if (unread.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Signale que [userId] est en train d'ecrire.
  ///
  /// On ecrit un horodatage plutot qu'un booleen : un client qui disparait
  /// brutalement laisserait un booleen a `true` indefiniment, alors qu'un
  /// horodatage devient simplement perime (cf. `Conversation.isOtherTyping`).
  Future<void> setTyping({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await _col.doc(conversationId).update({
        'typing.$userId':
            isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> archiveConversation(String conversationId) async {
    await _col.doc(conversationId).update({'isArchived': true});
  }
}
